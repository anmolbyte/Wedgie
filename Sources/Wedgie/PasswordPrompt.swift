import AppKit

enum PasswordPrompt {
    /// Shows a modal prompt for the admin password.
    /// Returns nil if user cancelled.
    @MainActor
    static func ask(reason: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Wedgie needs your admin password")
        alert.informativeText = "\(reason)\n\n\(L10n.tr("The password is stored in your Keychain and only used to toggle macOS sleep behavior. You can revoke access any time by quitting Wedgie."))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("Allow"))
        alert.addButton(withTitle: L10n.tr("Cancel"))

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = L10n.tr("macOS account password")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue
        return value.isEmpty ? nil : value
    }
}
