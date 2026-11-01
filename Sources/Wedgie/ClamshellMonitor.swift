import Foundation
import IOKit

/// Subscribes to lid open/closed transitions via IOKit's IOPMrootDomain.
/// Reports state as a Bool: true = lid open, false = lid closed.
@MainActor
final class ClamshellMonitor {
    var onStateChange: ((Bool) -> Void)?

    nonisolated(unsafe) private var notificationPort: IONotificationPortRef?
    nonisolated(unsafe) private var notification: io_object_t = 0
    nonisolated(unsafe) private var rootDomain: io_service_t = 0

    private(set) var isLidOpen: Bool = true

    init() {
        start()
    }

    deinit {
        if notification != 0 { IOObjectRelease(notification) }
        if rootDomain != 0   { IOObjectRelease(rootDomain) }
        if let port = notificationPort { IONotificationPortDestroy(port) }
    }

    /// Current state (true = open, false = closed).
    func currentState() -> Bool {
        !isClamshellClosed()
    }

    // MARK: - Setup

    private func start() {
        rootDomain = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard rootDomain != 0 else { return }

        isLidOpen = currentState()

        let port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        notificationPort = port

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            Task { @MainActor in
                let monitor = Unmanaged<ClamshellMonitor>.fromOpaque(refcon).takeUnretainedValue()
                let newState = monitor.currentState()
                if newState != monitor.isLidOpen {
                    monitor.isLidOpen = newState
                    monitor.onStateChange?(newState)
                }
            }
        }

        IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            callback,
            selfPtr,
            &notification
        )
    }

    private func isClamshellClosed() -> Bool {
        guard rootDomain != 0 else { return false }
        let prop = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )
        guard let value = prop?.takeRetainedValue() as? NSNumber else { return false }
        return value.boolValue
    }
}
