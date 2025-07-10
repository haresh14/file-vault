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
    
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        // Disable fallback to device passcode
        context.localizedFallbackTitle = ""
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
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
} 