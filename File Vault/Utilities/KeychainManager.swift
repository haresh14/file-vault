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

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.filevault.app"
    private let passwordKey = "userPassword"
    private let fakePasswordKey = "fakePassword"
    private let biometricEnabledKey = "biometricEnabled"
    private let authTypeKey = "authenticationType"
    
    private init() {}
    
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
        UserDefaults.standard.set(type.rawValue, forKey: authTypeKey)
    }
    
    func getAuthenticationType() -> AuthenticationType {
        guard let rawValue = UserDefaults.standard.string(forKey: authTypeKey),
              let type = AuthenticationType(rawValue: rawValue) else {
            return .passcode4 // Default to 4-digit passcode
        }
        return type
    }
    
    func isAuthenticationTypeSet() -> Bool {
        return UserDefaults.standard.string(forKey: authTypeKey) != nil
    }
    
    // MARK: - Biometric Settings
    
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricEnabledKey)
    }
    
    func isBiometricEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: biometricEnabledKey)
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
    
    func setLockTimeout(_ timeout: LockTimeout) {
        UserDefaults.standard.set(timeout.rawValue, forKey: lockTimeoutKey)
    }
    
    func getLockTimeout() -> LockTimeout {
        let rawValue = UserDefaults.standard.integer(forKey: lockTimeoutKey)
        // Default to 30 seconds if not set
        return LockTimeout(rawValue: rawValue) ?? .thirtySeconds
    }
    
    func setLastBackgroundTime() {
        UserDefaults.standard.set(Date(), forKey: lastBackgroundTimeKey)
    }
    
    func shouldRequireAuthentication() -> Bool {
        let timeout = getLockTimeout()
        
        // If set to never, don't require authentication
        if timeout == .never {
            return false
        }
        
        // If set to immediate, always require authentication
        if timeout == .immediate {
            return true
        }
        
        guard let lastBackgroundTime = UserDefaults.standard.object(forKey: lastBackgroundTimeKey) as? Date else {
            return true // First launch
        }
        
        let timeInterval = Date().timeIntervalSince(lastBackgroundTime)
        return timeInterval > Double(timeout.rawValue)
    }
    
    func clearLastBackgroundTime() {
        UserDefaults.standard.removeObject(forKey: lastBackgroundTimeKey)
    }
    
    // MARK: - Data Cleanup
    
    func clearAllKeychainData() {
        print("DEBUG: Clearing all keychain data...")
        
        // Clear password from keychain
        try? deletePassword()
        
        // Clear fake password from keychain
        try? deleteFakePassword()
        
        print("DEBUG: Keychain data cleared")
    }
    
    func clearAllUserDefaultsData() {
        print("DEBUG: Clearing all UserDefaults data...")
        
        // Clear authentication settings
        UserDefaults.standard.removeObject(forKey: authTypeKey)
        UserDefaults.standard.removeObject(forKey: biometricEnabledKey)
        
        // Clear lock timeout settings
        UserDefaults.standard.removeObject(forKey: lockTimeoutKey)
        UserDefaults.standard.removeObject(forKey: lastBackgroundTimeKey)
        
        // Clear biometric failure data (from BiometricAuthManager)
        UserDefaults.standard.removeObject(forKey: "biometricFailureCount")
        UserDefaults.standard.removeObject(forKey: "lastBiometricFailureTime")
        
        // Synchronize to ensure changes are written
        UserDefaults.standard.synchronize()
        
        print("DEBUG: UserDefaults data cleared")
    }
} 