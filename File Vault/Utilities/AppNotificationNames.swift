import Foundation

extension Notification.Name {
    static let refreshVaultItems = Notification.Name("RefreshVaultItems")
    static let tabDidChange = Notification.Name("TabDidChange")
    static let vaultDataChanged = Notification.Name("VaultDataChanged")
    static let triggerSecurityLock = Notification.Name("TriggerSecurityLock")
    static let backgroundUploadFailed = Notification.Name("BackgroundUploadFailed")
    static let backgroundUploadCompleted = Notification.Name("BackgroundUploadCompleted")
    static let backgroundUploadProgress = Notification.Name("BackgroundUploadProgress")
}
