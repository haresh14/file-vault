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

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.filevault.app"
    private let passwordKey = "userPassword"
    private let biometricEnabledKey = "biometricEnabled"
    
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
    
    // MARK: - Biometric Settings
    
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricEnabledKey)
    }
    
    func isBiometricEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - App Lock State
    
    private let lastBackgroundTimeKey = "lastBackgroundTime"
    private let lockTimeoutInterval: TimeInterval = 30 // 30 seconds
    
    func setLastBackgroundTime() {
        UserDefaults.standard.set(Date(), forKey: lastBackgroundTimeKey)
    }
    
    func shouldRequireAuthentication() -> Bool {
        guard let lastBackgroundTime = UserDefaults.standard.object(forKey: lastBackgroundTimeKey) as? Date else {
            return true // First launch
        }
        
        return Date().timeIntervalSince(lastBackgroundTime) > lockTimeoutInterval
    }
    
    func clearLastBackgroundTime() {
        UserDefaults.standard.removeObject(forKey: lastBackgroundTimeKey)
    }
} 