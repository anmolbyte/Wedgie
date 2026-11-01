import Foundation

enum SleepError: Error {
    case invalidPassword
    case pmsetFailed(code: Int32, stderr: String)
}

/// Wraps `sudo pmset` calls.
/// Uses `-S` to read password from stdin so we can drive it programmatically.
enum SleepController {

    static func validate(password: String) -> Bool {
        run(args: ["-S", "-k", "-v"], password: password).status == 0
    }

    static func setDisableSleep(_ disabled: Bool, password: String) throws {
        let result = run(
            args: ["-S", "-k", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"],
            password: password
        )
        switch result.status {
        case 0: return
        case 1 where result.stderr.contains("incorrect password"),
             1 where result.stderr.contains("Sorry"):
            throw SleepError.invalidPassword
        default:
            throw SleepError.pmsetFailed(code: result.status, stderr: result.stderr)
        }
    }

    /// Best-effort cleanup. Tries to flip disablesleep back to 0 without prompting.
    /// Called on app quit / signal handler.
    static func forceCleanup(password: String?) {
        guard let password else { return }
        _ = run(
            args: ["-S", "-k", "/usr/bin/pmset", "-a", "disablesleep", "0"],
            password: password
        )
    }

    private struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private static func run(args: [String], password: String) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = args

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(error)")
        }

        let payload = (password + "\n").data(using: .utf8) ?? Data()
        stdinPipe.fileHandleForWriting.write(payload)
        try? stdinPipe.fileHandleForWriting.close()

        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
