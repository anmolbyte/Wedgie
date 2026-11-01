import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: SettingsModel

    init() {
        let model = SettingsModel()
        self.model = model

        let hosting = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.tr("Wedgie")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func showAndFocus() {
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
