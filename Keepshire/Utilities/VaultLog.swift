import Foundation
import OSLog

/// Privacy-safe application logging.
///
/// Verbose diagnostics are compiled out of Release builds so request details,
/// paths, and security state never reach a production console.
enum VaultLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.haresh.keepshire",
        category: "application"
    )

    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let value = message()
        logger.debug("\(value, privacy: .public)")
        #endif
    }

    static func error(_ message: @autoclosure () -> String) {
        let value = message()
        logger.error("\(value, privacy: .public)")
    }
}
