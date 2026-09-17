//
//  KeychainManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case noPassword
    case invalidData
}

enum AuthenticationType: String, CaseIterable {
    case passcode4 = "passcode4"
    case passcode6 = "passcode6"
    case password = "password"
    
    var displayName: String {
        switch self {
        case .passcode4: return "4-Digit Passcode"
        case .passcode6: return "6-Digit Passcode"
        case .password: return "Password"
        }
    }
    
    var isPasscode: Bool {
        return self == .passcode4 || self == .passcode6
    }
    
    var digitCount: Int? {
        switch self {
        case .passcode4: return 4
        case .passcode6: return 6
        case .password: return nil
        }
    }
}

class KeychainManager: KeychainManaging {
    static let shared = KeychainManager()
    
    private let service: String
    private let defaults: UserDefaults
    private let passwordKey = "userPassword"
    private let fakePasswordKey = "fakePassword"
    private let keyDerivationAccount = "vaultKeyDerivation"
    private let biometricEnabledKey = "biometricEnabled"
    private let authTypeKey = "authenticationType"
    
    private init() {
        service = "com.haresh.keepshire"
        defaults = .standard
    }

    /// Creates isolated Keychain and defaults namespaces for tests.
    init(service: String, defaults: UserDefaults) {
        self.service = service
        self.defaults = defaults
    }
    
    // MARK: - Password Management
    
    func savePassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Delete any existing password first
        try? deletePassword()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    func getPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.noPassword
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return password
    }
    
    func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    func isPasswordSet() -> Bool {
        do {
            _ = try getPassword()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Fake Password Management
    
    func saveFakePassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Validate that fake password is different from main password
        if let mainPassword = try? getPassword(), mainPassword == password {
            throw KeychainError.duplicateEntry
        }
        
        // Delete any existing fake password first
        try? deleteFakePassword()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fakePasswordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    func getFakePassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fakePasswordKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.noPassword
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return password
    }
    
    func deleteFakePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fakePasswordKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    func isFakePasswordSet() -> Bool {
        do {
            _ = try getFakePassword()
            return true
        } catch {
            return false
        }
    }
    
    func setFakePassword(_ password: String) throws {
        try saveFakePassword(password)
    }
    
    func validatePassword(_ inputPassword: String) -> (isValid: Bool, isFakeLogin: Bool) {
        do {
            let mainPassword = try getPassword()
            if inputPassword == mainPassword {
                return (true, false)
            }
            
            if isFakePasswordSet() {
                let fakePassword = try getFakePassword()
                if inputPassword == fakePassword {
                    return (true, true)
                }
            }
            
            return (false, false)
        } catch {
            return (false, false)
        }
    }
    
    // MARK: - Authentication Type Management
    
    func setAuthenticationType(_ type: AuthenticationType) {
        defaults.set(type.rawValue, forKey: authTypeKey)
    }
    
    func getAuthenticationType() -> AuthenticationType {
        guard let rawValue = defaults.string(forKey: authTypeKey),
              let type = AuthenticationType(rawValue: rawValue) else {
            return .passcode4 // Default to 4-digit passcode
        }
        return type
    }
    
    func isAuthenticationTypeSet() -> Bool {
        return defaults.string(forKey: authTypeKey) != nil
    }
    
    // MARK: - Biometric Settings
    
    func setBiometricEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: biometricEnabledKey)
    }
    
    func isBiometricEnabled() -> Bool {
        return defaults.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - App Lock State
    
    private let lastBackgroundTimeKey = "lastBackgroundTime"
    private let lockTimeoutKey = "lockTimeout"
    
    enum LockTimeout: Int, CaseIterable {
        case immediate = 0
        case fiveSeconds = 5
        case tenSeconds = 10
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case never = -1
        
        var displayName: String {
            switch self {
            case .immediate: return "Immediately"
            case .fiveSeconds: return "5 Seconds"
            case .tenSeconds: return "10 Seconds"
            case .fifteenSeconds: return "15 Seconds"
            case .thirtySeconds: return "30 Seconds"
            case .oneMinute: return "1 Minute"
            case .fiveMinutes: return "5 Minutes"
            case .never: return "Never"
            }
        }
    }
    
    func setLockTimeout(_ timeout: Int) {
        defaults.set(timeout, forKey: lockTimeoutKey)
    }
    
    func getLockTimeout() -> Int {
        let rawValue = defaults.integer(forKey: lockTimeoutKey)
        // Check if key exists in UserDefaults - if not, default to 30 seconds
        if defaults.object(forKey: lockTimeoutKey) == nil {
            return LockTimeout.thirtySeconds.rawValue
        }
        return rawValue
    }
    
    func setLastBackgroundTime() {
        defaults.set(Date(), forKey: lastBackgroundTimeKey)
    }
    
    func shouldRequireAuthentication() -> Bool {
        let timeout = getLockTimeout()
        
        // If set to never, don't require authentication
        if timeout == LockTimeout.never.rawValue {
            return false
        }
        
        // If set to immediate, always require authentication
        if timeout == LockTimeout.immediate.rawValue {
            return true
        }
        
        guard let lastBackgroundTime = defaults.object(forKey: lastBackgroundTimeKey) as? Date else {
            return true // First launch
        }
        
        let timeInterval = Date().timeIntervalSince(lastBackgroundTime)
        return timeInterval > Double(timeout)
    }
    
    func clearLastBackgroundTime() {
        defaults.removeObject(forKey: lastBackgroundTimeKey)
    }
    
    // MARK: - Data Cleanup
    
    // MARK: - Vault key derivation (PBKDF2 salt + parameters)

    func saveKeyDerivationRecord(_ record: VaultKeyDerivationRecord) throws {
        let data = try JSONEncoder().encode(record)
        deleteKeyDerivationRecord()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyDerivationAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    func loadKeyDerivationRecord() -> VaultKeyDerivationRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyDerivationAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(VaultKeyDerivationRecord.self, from: data)
    }

    func deleteKeyDerivationRecord() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyDerivationAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clearAllKeychainData() {
        VaultLog.debug("DEBUG: Clearing all keychain data...")
        
        // Clear password from keychain
        try? deletePassword()
        
        // Clear fake password from keychain
        try? deleteFakePassword()

        deleteKeyDerivationRecord()
        
        VaultLog.debug("DEBUG: Keychain data cleared")
    }
    
    func clearAllUserDefaultsData() {
        VaultLog.debug("DEBUG: Clearing all UserDefaults data...")
        
        // Clear authentication settings
        defaults.removeObject(forKey: authTypeKey)
        defaults.removeObject(forKey: biometricEnabledKey)
        
        // Clear lock timeout settings
        defaults.removeObject(forKey: lockTimeoutKey)
        defaults.removeObject(forKey: lastBackgroundTimeKey)
        
        // Clear biometric failure data (from BiometricAuthManager)
        defaults.removeObject(forKey: "biometricFailureCount")
        defaults.removeObject(forKey: "lastBiometricFailureTime")
        
        // Synchronize to ensure changes are written
        defaults.synchronize()
        
        VaultLog.debug("DEBUG: UserDefaults data cleared")
    }
} 