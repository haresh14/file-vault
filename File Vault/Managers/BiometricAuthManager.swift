//
//  BiometricAuthManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import LocalAuthentication

enum BiometricType {
    case none
    case touchID
    case faceID
}

class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    private let maxFailureAttempts = 3
    private let failureResetInterval: TimeInterval = 30 // 30 seconds
    
    @UserDefaultsBacked(key: "biometricFailureCount", defaultValue: 0)
    private var failureCount: Int
    
    @UserDefaultsBacked(key: "lastBiometricFailureTime", defaultValue: Date.distantPast)
    private var lastFailureTime: Date
    
    private init() {}
    
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("DEBUG: Cannot evaluate biometric policy. Error: \(error?.localizedDescription ?? "Unknown")")
            return .none
        }
        
        let type: BiometricType
        switch context.biometryType {
        case .touchID:
            type = .touchID
        case .faceID:
            type = .faceID
        default:
            type = .none
        }
        
        print("DEBUG: Biometric type detected: \(type)")
        return type
    }
    
    func canUseBiometrics() -> Bool {
        // Check if we've exceeded failure attempts
        if shouldBlockBiometric() {
            print("DEBUG: Biometric blocked due to too many failures")
            return false
        }
        
        let context = LAContext()
        var error: NSError?
        let can = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if !can {
            print("DEBUG: Biometrics not available. Error: \(error?.localizedDescription ?? "Unknown")")
        } else {
            print("DEBUG: Biometrics available")
        }
        
        return can
    }
    
    private func shouldBlockBiometric() -> Bool {
        // Reset failure count if enough time has passed
        if Date().timeIntervalSince(lastFailureTime) > failureResetInterval {
            failureCount = 0
        }
        
        return failureCount >= maxFailureAttempts
    }
    
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        // Check if we should block biometric
        if shouldBlockBiometric() {
            let error = NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Too many failed attempts. Please use passcode."])
            completion(false, error)
            return
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        // Disable fallback to device passcode
        context.localizedFallbackTitle = ""
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // Reset failure count on success
                        self.failureCount = 0
                        completion(success, error)
                    } else {
                        // Increment failure count
                        self.failureCount += 1
                        self.lastFailureTime = Date()
                        
                        print("DEBUG: Biometric failure count: \(self.failureCount)")
                        completion(success, error)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false, error)
            }
        }
    }
    
    func authenticateWithDevicePasscode(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false, error)
            }
        }
    }
    
    func resetFailureCount() {
        failureCount = 0
        lastFailureTime = Date.distantPast
    }
}

// Property wrapper for UserDefaults
@propertyWrapper
struct UserDefaultsBacked<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
} 