import SwiftUI
import ServiceManagement
import AppKit

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var hasSavedPassword: Bool

    @Published var startSessionOnLaunch: Bool {
        didSet { Preferences.startSessionOnLaunch = startSessionOnLaunch }
    }

    @Published var dimDisplayOnLidClose: Bool {
        didSet { Preferences.dimDisplayOnLidClose = dimDisplayOnLidClose }
    }

    var brightnessAvailable: Bool { BrightnessController.isAvailable }

    init() {
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        self.hasSavedPassword = (KeychainStore.load() != nil)
        self.startSessionOnLaunch = Preferences.startSessionOnLaunch
        self.dimDisplayOnLidClose = Preferences.dimDisplayOnLidClose
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let currentlyEnabled = (SMAppService.mainApp.status == .enabled)
        if enabled == currentlyEnabled {
            launchAtLogin = currentlyEnabled
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    func forgetPassword() {
        KeychainStore.delete()
        hasSavedPassword = false
    }

    func refresh() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        hasSavedPassword = (KeychainStore.load() != nil)
        startSessionOnLaunch = Preferences.startSessionOnLaunch
        dimDisplayOnLidClose = Preferences.dimDisplayOnLidClose
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private var version: String {
        let dict = Bundle.main.infoDictionary
        let short = dict?["CFBundleShortVersionString"] as? String ?? "?"
        let build = dict?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch Wedgie at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))

                Toggle(isOn: $model.startSessionOnLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start session on startup")
                        Text("Automatically keep your Mac awake when Wedgie launches.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $model.dimDisplayOnLidClose) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turn off internal display when lid closes")
                        Text("Saves battery while Wedgie keeps the Mac awake.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.brightnessAvailable)

                LabeledContent("Saved password") {
                    HStack(spacing: 8) {
                        Text(model.hasSavedPassword ? "Stored in Keychain" : "Not stored")
                            .foregroundStyle(.secondary)
                        if model.hasSavedPassword {
                            Button("Forget", role: .destructive) {
                                model.forgetPassword()
                            }
                        }
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: version)
                LabeledContent("Source") {
                    Link("github.com/anmolbyte/Wedgie",
                         destination: URL(string: "https://github.com/anmolbyte/Wedgie")!)
                }
                Text("Wedgie holds your Mac awake by toggling pmset disablesleep. It needs your admin password the first time you use it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 360)
        .onAppear { model.refresh() }
    }
}
