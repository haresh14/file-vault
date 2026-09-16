import Foundation

final class SecurityEventLogger {
    private let defaults: UserDefaults
    private let logsKey = "SecurityLogs"
    private let maximumLogCount = 100

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func log(_ event: String) {
        let logEntry = "\(Date()): \(event)"
        print("SECURITY LOG: \(logEntry)")

        var logs = defaults.stringArray(forKey: logsKey) ?? []
        logs.append(logEntry)
        if logs.count > maximumLogCount {
            logs = Array(logs.suffix(maximumLogCount))
        }
        defaults.set(logs, forKey: logsKey)
    }

    func logs() -> [String] {
        defaults.stringArray(forKey: logsKey) ?? []
    }

    func clear() {
        defaults.removeObject(forKey: logsKey)
    }
}
