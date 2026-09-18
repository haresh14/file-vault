import Foundation
import MetricKit

final class DiagnosticsManager: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsManager()
    static let lastDiagnosticDateKey = "lastMetricKitDiagnosticDate"

    private let defaults: UserDefaults

    private override convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    var lastDiagnosticDate: Date? {
        defaults.object(forKey: Self.lastDiagnosticDateKey) as? Date
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard !payloads.isEmpty else { return }
        VaultLog.debug("MetricKit delivered an aggregated metric payload")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }
        recordDiagnosticDelivery()
    }

    func recordDiagnosticDelivery(at date: Date = Date()) {
        defaults.set(date, forKey: Self.lastDiagnosticDateKey)
        VaultLog.error("MetricKit delivered a crash or hang diagnostic")
    }
}
