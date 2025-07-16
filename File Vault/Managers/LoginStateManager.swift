//
//  LoginStateManager.swift
//  File Vault
//
//  Created on 12/07/25.
//

import Foundation
import SwiftUI

class LoginStateManager: ObservableObject {
    static let shared = LoginStateManager()
    
    @Published var isFakeLogin: Bool = false
    
    private init() {}
    
    // MARK: - Login State Management
    
    func setLoginState(isFakeLogin: Bool) {
        self.isFakeLogin = isFakeLogin
        print("DEBUG: Login state set to \(isFakeLogin ? "fake" : "real") login")
    }
    
    func resetLoginState() {
        isFakeLogin = false
    }
    
    // MARK: - Restriction Checks
    
    var canAddFiles: Bool {
        return !isFakeLogin
    }
    
    var canCreateFolders: Bool {
        return !isFakeLogin
    }
    
    var canChangePassword: Bool {
        return !isFakeLogin
    }
    
    var canAccessFullSettings: Bool {
        return !isFakeLogin
    }
    
    var shouldShowEmptyVault: Bool {
        return isFakeLogin
    }
    
    // MARK: - UI State for Fake Login
    
    var emptyVaultItems: [VaultItem] {
        return []
    }
    
    var emptyFolders: [Folder] {
        return []
    }
    
    // MARK: - Settings Restrictions
    
    var visibleSettingSections: [SettingsSection] {
        if isFakeLogin {
            return [.about]
        } else {
            return [.security, .advancedSecurity, .lockBehavior, .disk, .about]
        }
    }
}

enum SettingsSection: String, CaseIterable {
    case security = "Security"
    case advancedSecurity = "Advanced Security"
    case lockBehavior = "Lock Behavior"
    case disk = "Disk"
    case about = "About"
} 