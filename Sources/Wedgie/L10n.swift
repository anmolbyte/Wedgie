import Foundation

/// Thin wrapper around NSLocalizedString. Use the English string as the
/// lookup key — Localizable.strings files map it to a translation.
enum L10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
