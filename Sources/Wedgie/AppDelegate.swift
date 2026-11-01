import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isOn = false
    private var menu: NSMenu!
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private lazy var settingsWindow = SettingsWindowController()

    private var clamshellMonitor: ClamshellMonitor?
    private var isLidClosed = false
    private var brightnessTrackingTimer: Timer?
    private var brightnessRestoreTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []

    private static let savedBrightnessKey = "wedgie.savedBrightness"
    private static let legacySavedBrightnessKey = "wedge.savedBrightness"
    private static let lastActiveBrightnessKey = "wedgie.lastActiveBrightness"
    private static let didDimForLidCloseKey = "wedgie.didDimForLidClose"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installSignalHandlers()
        recoverBrightnessIfPreviousRunCrashed()
        setupStatusItem()
        setupMenu()
        refreshUI()
        setupWorkspaceObservers()

        if Preferences.startSessionOnLaunch {
            Task { @MainActor in
                if !self.isOn {
                    await self.performToggle()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Best-effort: if Wedgie was active, release the lock on quit so the user doesn't
        // ship a Mac that never sleeps after uninstall. Also restore any
        // brightness we forced to zero while the lid was closed.
        if isOn, let password = KeychainStore.load() {
            SleepController.forceCleanup(password: password)
        }
        restoreBrightnessOnExit()
    }

    // MARK: - UI

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenubarIcon.image(isOn: false)
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.toolTip = L10n.tr("Wedgie: Disabled")
            button.target = self
            button.action = #selector(handleStatusClick(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        statusMenuItem = NSMenuItem(title: L10n.tr("Disabled"), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        toggleMenuItem = NSMenuItem(
            title: L10n.tr("Enable"),
            action: #selector(toggle),
            keyEquivalent: "w"
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: L10n.tr("Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.tr("Quit Wedgie"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func refreshUI() {
        statusItem.button?.image = MenubarIcon.image(isOn: isOn)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = isOn
            ? L10n.tr("Wedgie: Enabled")
            : L10n.tr("Wedgie: Disabled")
        statusMenuItem.title = isOn
            ? L10n.tr("Enabled")
            : L10n.tr("Disabled")
        toggleMenuItem.title = isOn
            ? L10n.tr("Disable")
            : L10n.tr("Enable")
    }

    // MARK: - Status item interaction

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.type == .rightMouseDown
            || event.modifierFlags.contains(.control)
        if isRightClick {
            showContextMenu()
            return
        }
        toggle()
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    // MARK: - Actions

    @objc private func toggle() {
        Task { @MainActor in
            await performToggle()
        }
    }

    private func performToggle() async {
        let target = !isOn
        guard let password = obtainPassword() else { return }

        do {
            try SleepController.setDisableSleep(target, password: password)
            isOn = target
            refreshUI()
            if target {
                startBrightnessGuard()
            } else {
                stopBrightnessGuard()
            }
        } catch SleepError.invalidPassword {
            KeychainStore.delete()
            showError(
                title: L10n.tr("Password rejected"),
                message: L10n.tr("Your saved password didn't work. Try again — Wedgie will ask once more.")
            )
        } catch SleepError.pmsetFailed(let code, let stderr) {
            showError(
                title: String(format: L10n.tr("pmset failed (exit %d)"), Int(code)),
                message: stderr.isEmpty ? L10n.tr("Unknown error from pmset.") : stderr
            )
        } catch {
            showError(title: L10n.tr("Unexpected error"), message: "\(error)")
        }
    }

    private func obtainPassword() -> String? {
        if let cached = KeychainStore.load() { return cached }
        guard let entered = PasswordPrompt.ask(
            reason: L10n.tr("Wedgie uses pmset to keep your Mac from sleeping. macOS requires admin rights for this.")
        ) else { return nil }

        guard SleepController.validate(password: entered) else {
            showError(
                title: L10n.tr("Wrong password"),
                message: L10n.tr("macOS didn't accept that password.")
            )
            return nil
        }

        KeychainStore.save(password: entered)
        return entered
    }

    @objc private func openSettings() {
        settingsWindow.showAndFocus()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: - Brightness tracking & guard

    private func updateLastActiveBrightnessIfNeeded() {
        guard !isLidClosed else { return }
        if let current = BrightnessController.getBrightness(), current > 0.08 {
            Self.persistLastActiveBrightness(current)
        }
    }

    private func startBrightnessGuard() {
        guard Preferences.dimDisplayOnLidClose else { return }
        guard clamshellMonitor == nil else { return }

        updateLastActiveBrightnessIfNeeded()
        brightnessTrackingTimer?.invalidate()
        brightnessTrackingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLastActiveBrightnessIfNeeded()
            }
        }

        let monitor = ClamshellMonitor()
        isLidClosed = !monitor.isLidOpen
        monitor.onStateChange = { [weak self] isOpen in
            self?.handleClamshell(isOpen: isOpen)
        }
        clamshellMonitor = monitor
    }

    private func stopBrightnessGuard() {
        brightnessTrackingTimer?.invalidate()
        brightnessTrackingTimer = nil
        clamshellMonitor = nil
        restoreSavedBrightness()
    }

    private func handleClamshell(isOpen: Bool) {
        isLidClosed = !isOpen
        if isOpen {
            restoreSavedBrightness()
        } else {
            if let current = BrightnessController.getBrightness(), current > 0.08 {
                Self.persistLastActiveBrightness(current)
            }
            let targetToRemember = Self.loadLastActiveBrightness() ?? 0.5
            Self.persistSavedBrightness(targetToRemember)
            Self.persistDidDimForLidClose(true)
            BrightnessController.setBrightness(0)
        }
    }

    private func restoreSavedBrightness() {
        guard Self.loadDidDimForLidClose() || Self.loadSavedBrightness() != nil else { return }
        let target = Self.loadSavedBrightness() ?? Self.loadLastActiveBrightness() ?? 0.5
        let clampedTarget = max(0.1, min(1.0, target))

        brightnessRestoreTask?.cancel()
        brightnessRestoreTask = Task { @MainActor in
            // Multi-pass restoration across the display wake window.
            // When waking after display was forced to 0, macOS WindowServer often
            // sets brightness to 1 notch above minimum (~0.0625) ~100-300ms after wake.
            // Retrying across the wake window ensures the pre-close brightness is reliably restored.
            let intervals: [UInt64] = [
                0,
                100_000_000,
                250_000_000,
                500_000_000,
                1_000_000_000,
                1_800_000_000,
                2_500_000_000
            ]

            for delay in intervals {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }
                guard !Task.isCancelled, !self.isLidClosed else { break }

                let current = BrightnessController.getBrightness()
                if current == nil || abs((current ?? 0) - clampedTarget) > 0.03 || (current ?? 0) <= 0.08 {
                    BrightnessController.setBrightness(clampedTarget)
                }
            }

            if !self.isLidClosed {
                Self.persistDidDimForLidClose(false)
                Self.clearSavedBrightness()
            }
        }
    }

    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let wakeObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn, !self.isLidClosed else { return }
                if Self.loadDidDimForLidClose() || (BrightnessController.getBrightness() ?? 0) <= 0.08 {
                    self.restoreSavedBrightness()
                }
            }
        }
        workspaceObservers.append(wakeObserver)

        let systemWakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn, !self.isLidClosed else { return }
                if Self.loadDidDimForLidClose() || (BrightnessController.getBrightness() ?? 0) <= 0.08 {
                    self.restoreSavedBrightness()
                }
            }
        }
        workspaceObservers.append(systemWakeObserver)
    }

    private static func loadLastActiveBrightness() -> Float? {
        let val = UserDefaults.standard.float(forKey: lastActiveBrightnessKey)
        guard UserDefaults.standard.object(forKey: lastActiveBrightnessKey) != nil, val > 0.08 else {
            return nil
        }
        return val
    }

    private static func persistLastActiveBrightness(_ value: Float) {
        guard value > 0.08 else { return }
        UserDefaults.standard.set(value, forKey: lastActiveBrightnessKey)
    }

    private static func loadSavedBrightness() -> Float? {
        if let obj = UserDefaults.standard.object(forKey: savedBrightnessKey) as? NSNumber {
            let val = obj.floatValue
            if val > 0.08 { return val }
        }
        if let obj = UserDefaults.standard.object(forKey: legacySavedBrightnessKey) as? NSNumber {
            let val = obj.floatValue
            if val > 0.08 { return val }
        }
        return nil
    }

    private static func persistSavedBrightness(_ value: Float) {
        guard value > 0.08 else { return }
        UserDefaults.standard.set(value, forKey: savedBrightnessKey)
    }

    private static func clearSavedBrightness() {
        UserDefaults.standard.removeObject(forKey: savedBrightnessKey)
        UserDefaults.standard.removeObject(forKey: legacySavedBrightnessKey)
    }

    private static func loadDidDimForLidClose() -> Bool {
        UserDefaults.standard.bool(forKey: didDimForLidCloseKey)
    }

    private static func persistDidDimForLidClose(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: didDimForLidCloseKey)
    }

    /// If we crashed last run with the lid closed, brightness is still stuck at
    /// 0 right now. Detect the leftover value and restore it on launch.
    private func recoverBrightnessIfPreviousRunCrashed() {
        if Self.loadDidDimForLidClose() {
            let target = Self.loadSavedBrightness() ?? Self.loadLastActiveBrightness() ?? 0.5
            let clampedTarget = max(0.1, min(1.0, target))
            BrightnessController.setBrightness(clampedTarget)
            Self.persistDidDimForLidClose(false)
            Self.clearSavedBrightness()
        }
    }

    private func restoreBrightnessOnExit() {
        if Self.loadDidDimForLidClose() {
            let target = Self.loadSavedBrightness() ?? Self.loadLastActiveBrightness() ?? 0.5
            let clampedTarget = max(0.1, min(1.0, target))
            BrightnessController.setBrightness(clampedTarget)
            Self.persistDidDimForLidClose(false)
            Self.clearSavedBrightness()
        }
    }

    // MARK: - Safety nets

    private func installSignalHandlers() {
        // pmset disablesleep persists across processes. If we get SIGTERM/SIGINT,
        // try to release the lock before dying.
        let handler: @convention(c) (Int32) -> Void = { _ in
            if let password = KeychainStore.load() {
                SleepController.forceCleanup(password: password)
            }
            _exit(0)
        }
        signal(SIGTERM, handler)
        signal(SIGINT, handler)
        signal(SIGHUP, handler)
    }
}
