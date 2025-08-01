//
//  AlertManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Represents different types of alerts with their configurations
enum AlertType: Identifiable, Equatable {
    case deleteConfirmation(itemCount: Int, itemType: String)
    case createFolder(name: Binding<String>)
    case renameFolder(name: Binding<String>, folder: String)
    case error(message: String, recovery: String? = nil)
    case biometricAuth(message: String)
    case resetConfirmation(type: ResetType)
    case fakePassword(message: String)
    case authChange(message: String)
    case customAlert(title: String, message: String, actions: [AlertAction])
    
    var id: String {
        switch self {
        case .deleteConfirmation: return "delete"
        case .createFolder: return "createFolder"
        case .renameFolder: return "renameFolder"
        case .error: return "error"
        case .biometricAuth: return "biometric"
        case .resetConfirmation: return "reset"
        case .fakePassword: return "fakePassword"
        case .authChange: return "authChange"
        case .customAlert(let title, _, _): return "custom_\(title)"
        }
    }
    
    static func ==(lhs: AlertType, rhs: AlertType) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of reset operations
enum ResetType {
    case completeReset
    case deleteFiles
    case authSettings
    
    var title: String {
        switch self {
        case .completeReset: return "Complete App Reset"
        case .deleteFiles: return "Delete All Files"
        case .authSettings: return "Reset Authentication"
        }
    }
    
    var message: String {
        switch self {
        case .completeReset: return "This will delete all files, folders, and reset all settings. This action cannot be undone."
        case .deleteFiles: return "This will permanently delete all files and folders. Settings will be preserved."
        case .authSettings: return "This will reset your authentication settings to default."
        }
    }
}

/// Represents an alert action button
struct AlertAction {
    let title: String
    let style: ButtonRole?
    let action: () -> Void
    
    init(title: String, style: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    static func cancel(action: @escaping () -> Void = {}) -> AlertAction {
        AlertAction(title: "Cancel", style: .cancel, action: action)
    }
    
    static func destructive(title: String, action: @escaping () -> Void) -> AlertAction {
        AlertAction(title: title, style: .destructive, action: action)
    }
    
    static func `default`(title: String, action: @escaping () -> Void) -> AlertAction {
        AlertAction(title: title, style: nil, action: action)
    }
}

/// Protocol for managing alert presentation in ViewModels
protocol AlertManageable: ObservableObject {
    /// Current alert to be presented
    var currentAlert: AlertType? { get set }
    
    /// Whether an alert is currently being shown
    var isShowingAlert: Bool { get set }
    
    /// Show a specific alert type
    func showAlert(_ alertType: AlertType)
    
    /// Dismiss the current alert
    func dismissAlert()
    
    /// Show a delete confirmation alert
    func showDeleteConfirmation(itemCount: Int, itemType: String, onConfirm: @escaping () -> Void)
    
    /// Show an error alert
    func showError(message: String, recovery: String?)
    
    /// Show a custom alert with actions
    func showCustomAlert(title: String, message: String, actions: [AlertAction])
}

/// Default implementation for AlertManageable
extension AlertManageable {
    func showAlert(_ alertType: AlertType) {
        currentAlert = alertType
        isShowingAlert = true
    }
    
    func dismissAlert() {
        currentAlert = nil
        isShowingAlert = false
    }
    
    func showDeleteConfirmation(itemCount: Int, itemType: String, onConfirm: @escaping () -> Void) {
        let alertType = AlertType.deleteConfirmation(itemCount: itemCount, itemType: itemType)
        showAlert(alertType)
    }
    
    func showError(message: String, recovery: String? = nil) {
        let alertType = AlertType.error(message: message, recovery: recovery)
        showAlert(alertType)
    }
    
    func showCustomAlert(title: String, message: String, actions: [AlertAction]) {
        let alertType = AlertType.customAlert(title: title, message: message, actions: actions)
        showAlert(alertType)
    }
}