import Foundation

enum Preferences {
    private static let dimDisplayKey = "wedgie.dimDisplayOnLidClose"
    private static let legacyDimDisplayKey = "wedge.dimDisplayOnLidClose"
    private static let startSessionOnLaunchKey = "wedgie.startSessionOnLaunch"

    static var dimDisplayOnLidClose: Bool {
        get {
            if let val = UserDefaults.standard.object(forKey: dimDisplayKey) as? Bool {
                return val
            }
            if let legacyVal = UserDefaults.standard.object(forKey: legacyDimDisplayKey) as? Bool {
                return legacyVal
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dimDisplayKey)
        }
    }

    static var startSessionOnLaunch: Bool {
        get {
            UserDefaults.standard.bool(forKey: startSessionOnLaunchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: startSessionOnLaunchKey)
        }
    }
}
