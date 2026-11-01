import Foundation
import CoreGraphics

/// Reads/writes the built-in display brightness via the private DisplayServices
/// framework. This isn't App Store-safe but works fine for direct distribution.
enum BrightnessController {

    private typealias GetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (UInt32, Float) -> Int32

    nonisolated(unsafe) private static let lib: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getFn: GetBrightnessFn? = {
        guard let lib, let sym = dlsym(lib, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFn.self)
    }()

    private static let setFn: SetBrightnessFn? = {
        guard let lib, let sym = dlsym(lib, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFn.self)
    }()

    static var internalDisplayID: CGDirectDisplayID? {
        var count: UInt32 = 0
        // Check active displays first
        if CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 {
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
            if CGGetActiveDisplayList(count, &displays, &count) == .success {
                for id in displays where CGDisplayIsBuiltin(id) != 0 {
                    return id
                }
            }
        }
        // Fallback to online displays in case display is waking or in transitional state
        count = 0
        if CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 {
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
            if CGGetOnlineDisplayList(count, &displays, &count) == .success {
                for id in displays where CGDisplayIsBuiltin(id) != 0 {
                    return id
                }
            }
        }
        // Fallback to main display if builtin
        let main = CGMainDisplayID()
        if CGDisplayIsBuiltin(main) != 0 {
            return main
        }
        return nil
    }

    static var isAvailable: Bool {
        getFn != nil && setFn != nil && internalDisplayID != nil
    }

    /// Returns the current built-in display brightness 0.0...1.0, or nil if
    /// the private API or the internal display is unavailable.
    static func getBrightness() -> Float? {
        guard let getFn, let id = internalDisplayID else { return nil }
        var value: Float = 0
        let status = getFn(id, &value)
        return status == 0 ? value : nil
    }

    /// Sets the built-in display brightness, clamped to 0.0...1.0.
    /// Silently no-ops if the API isn't available.
    @discardableResult
    static func setBrightness(_ value: Float) -> Bool {
        guard let setFn, let id = internalDisplayID else { return false }
        let clamped = max(0, min(1, value))
        return setFn(id, clamped) == 0
    }
}
