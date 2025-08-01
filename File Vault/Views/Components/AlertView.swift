//
//  AlertView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Collection of reusable alert components and builders
struct AlertView {
    
    /// Builder for creating standardized delete confirmation alerts
    static func deleteConfirmation(
        itemCount: Int,
        itemType: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> Alert {
        let message = itemCount == 1 
            ? "Are you sure you want to delete this \(itemType)? This action cannot be undone."
            : "Are you sure you want to delete \(itemCount) \(itemType)? This action cannot be undone."
        
        return Alert(
            title: Text("Delete \(itemType.capitalized)"),
            message: Text(message),
            primaryButton: .destructive(Text("Delete")) {
                onConfirm()
            },
            secondaryButton: .cancel(Text("Cancel")) {
                onCancel()
            }
        )
    }
    
    /// Builder for creating folder creation alerts
    static func createFolder(
        folderName: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> Alert {
        Alert(
            title: Text("Create Folder"),
            message: Text("Enter a name for the new folder"),
            primaryButton: .default(Text("Create")) {
                onConfirm()
            },
            secondaryButton: .cancel(Text("Cancel")) {
                folderName.wrappedValue = ""
                onCancel()
            }
        )
    }
    
    /// Builder for creating folder rename alerts
    static func renameFolder(
        currentName: String,
        newName: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> Alert {
        Alert(
            title: Text("Rename Folder"),
            message: Text("Enter a new name for '\(currentName)'"),
            primaryButton: .default(Text("Rename")) {
                onConfirm()
            },
            secondaryButton: .cancel(Text("Cancel")) {
                newName.wrappedValue = ""
                onCancel()
            }
        )
    }
    
    /// Builder for creating error alerts
    static func error(
        message: String,
        recovery: String? = nil,
        onRecovery: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void = {}
    ) -> Alert {
        if let recovery = recovery, let onRecovery = onRecovery {
            return Alert(
                title: Text("Error"),
                message: Text(message),
                primaryButton: .default(Text(recovery)) {
                    onRecovery()
                },
                secondaryButton: .cancel(Text("OK")) {
                    onDismiss()
                }
            )
        } else {
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    onDismiss()
                }
            )
        }
    }
    
    /// Builder for creating reset confirmation alerts
    static func resetConfirmation(
        type: ResetType,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> Alert {
        Alert(
            title: Text(type.title),
            message: Text(type.message),
            primaryButton: .destructive(Text("Reset")) {
                onConfirm()
            },
            secondaryButton: .cancel(Text("Cancel")) {
                onCancel()
            }
        )
    }
    
    /// Builder for creating biometric authentication alerts
    static func biometricAuth(
        message: String,
        onDismiss: @escaping () -> Void = {}
    ) -> Alert {
        Alert(
            title: Text("Biometric Authentication"),
            message: Text(message),
            dismissButton: .default(Text("OK")) {
                onDismiss()
            }
        )
    }
    
    /// Builder for creating custom alerts with flexible actions
    static func custom(
        title: String,
        message: String,
        primaryAction: AlertAction,
        secondaryAction: AlertAction? = nil
    ) -> Alert {
        if let secondaryAction = secondaryAction {
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: alertButton(from: primaryAction),
                secondaryButton: alertButton(from: secondaryAction)
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: alertButton(from: primaryAction)
            )
        }
    }
    
    private static func alertButton(from action: AlertAction) -> Alert.Button {
        switch action.style {
        case .destructive:
            return .destructive(Text(action.title)) {
                action.action()
            }
        case .cancel:
            return .cancel(Text(action.title)) {
                action.action()
            }
        default:
            return .default(Text(action.title)) {
                action.action()
            }
        }
    }
}

/// View modifier for simplified alert management
struct StandardAlertModifier<T: AlertManageable>: ViewModifier {
    @ObservedObject var alertManager: T
    
    func body(content: Content) -> some View {
        content
            .alert(item: Binding<AlertType?>(
                get: { alertManager.currentAlert },
                set: { _ in alertManager.dismissAlert() }
            )) { alertType in
                createStandardAlert(for: alertType)
            }
    }
    
    private func createStandardAlert(for alertType: AlertType) -> Alert {
        switch alertType {
        case .deleteConfirmation(let itemCount, let itemType):
            return AlertView.deleteConfirmation(
                itemCount: itemCount,
                itemType: itemType,
                onConfirm: {
                    // Override in specific implementations
                }
            )
            
        case .error(let message, let recovery):
            return AlertView.error(
                message: message,
                recovery: recovery
            )
            
        case .resetConfirmation(let resetType):
            return AlertView.resetConfirmation(
                type: resetType,
                onConfirm: {
                    // Override in specific implementations  
                }
            )
            
        case .biometricAuth(let message):
            return AlertView.biometricAuth(message: message)
            
        default:
            return Alert(
                title: Text("Alert"),
                message: Text("An alert was triggered"),
                dismissButton: .default(Text("OK")) {
                    alertManager.dismissAlert()
                }
            )
        }
    }
}

/// Convenient view extension
extension View {
    func standardAlerts<T: AlertManageable>(_ alertManager: T) -> some View {
        modifier(StandardAlertModifier(alertManager: alertManager))
    }
}