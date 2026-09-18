import Foundation
import Testing
@testable import Keepshire

struct DiagnosticsManagerTests {
    @Test func recordsOnlyTheDiagnosticDeliveryDate() {
        let suite = "DiagnosticsManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = DiagnosticsManager(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1234)

        manager.recordDiagnosticDelivery(at: date)

        #expect(manager.lastDiagnosticDate == date)
    }
}
