//
//  AlertViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Centralized alert management ViewModel
final class AlertViewModel: ObservableObject, AlertManageable {
    // MARK: - Published Properties
    
    @Published var currentAlert: AlertType?
    @Published var isShowingAlert: Bool = false
    
    // MARK: - Private Properties
    
    private var alertQueue: [AlertType] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-dismiss logic
        $isShowingAlert
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.processNextAlert()
            }
            .store(in: &cancellables)
    }
    
    private func processNextAlert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if !self.alertQueue.isEmpty {
                let nextAlert = self.alertQueue.removeFirst()
                self.showAlert(nextAlert)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Queue an alert to be shown (useful when multiple alerts need to be shown)
    func queueAlert(_ alertType: AlertType) {
        if currentAlert != nil {
            alertQueue.append(alertType)
        } else {
            showAlert(alertType)
        }
    }
    
    /// Clear all queued alerts
    func clearQueue() {
        alertQueue.removeAll()
    }
    
    /// Check if a specific alert type is currently being shown
    func isShowingAlert(of type: AlertType) -> Bool {
        currentAlert?.id == type.id
    }
}

/// View modifier for handling alerts with AlertManageable
struct AlertHandler: ViewModifier {
    @ObservedObject var alertManager: AlertViewModel
    
    func body(content: Content) -> some View {
        content
            .alert(item: $alertManager.currentAlert) { alertType in
                createAlert(for: alertType)
            }
    }
    
    private func createAlert(for alertType: AlertType) -> Alert {
        switch alertType {
        case .deleteConfirmation(let itemCount, let itemType):
            return Alert(
                title: Text("Delete Items"),
                message: Text("Are you sure you want to delete \(itemCount) \(itemType)? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    // This should be handled by the calling view
                },
                secondaryButton: .cancel {
                    alertManager.dismissAlert()
                }
            )
            
        case .createFolder(let name):
            return Alert(
                title: Text("Create Folder"),
                message: Text("Enter a name for the new folder"),
                primaryButton: .default(Text("Create")) {
                    // This should be handled by the calling view
                },
                secondaryButton: .cancel {
                    alertManager.dismissAlert()
                }
            )
            
        case .renameFolder(let name, let folder):
            return Alert(
                title: Text("Rename Folder"),
                message: Text("Enter a new name for '\(folder)'"),
                primaryButton: .default(Text("Rename")) {
                    // This should be handled by the calling view
                },
                secondaryButton: .cancel {
                    alertManager.dismissAlert()
                }
            )
            
        case .error(let message, let recovery):
            var alertButtons: [Alert.Button] = [.default(Text("OK")) {
                alertManager.dismissAlert()
            }]
            
            if let recovery = recovery {
                alertButtons.insert(.default(Text(recovery)) {
                    // Recovery action should be handled by calling view
                }, at: 0)
            }
            
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: alertButtons.last
            )
            
        case .biometricAuth(let message):
            return Alert(
                title: Text("Biometric Authentication"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    alertManager.dismissAlert()
                }
            )
            
        case .resetConfirmation(let resetType):
            return Alert(
                title: Text(resetType.title),
                message: Text(resetType.message),
                primaryButton: .destructive(Text("Reset")) {
                    // This should be handled by the calling view
                },
                secondaryButton: .cancel {
                    alertManager.dismissAlert()
                }
            )
            
        case .fakePassword(let message):
            return Alert(
                title: Text("Fake Password"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    alertManager.dismissAlert()
                }
            )
            
        case .authChange(let message):
            return Alert(
                title: Text("Authentication Changed"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    alertManager.dismissAlert()
                }
            )
            
        case .customAlert(let title, let message, let actions):
            if actions.count == 1 {
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text(actions[0].title)) {
                        actions[0].action()
                        alertManager.dismissAlert()
                    }
                )
            } else if actions.count == 2 {
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    primaryButton: alertButtonFromAction(actions[0]),
                    secondaryButton: alertButtonFromAction(actions[1])
                )
            } else {
                // Fallback for more than 2 actions
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        alertManager.dismissAlert()
                    }
                )
            }
        }
    }
    
    private func alertButtonFromAction(_ alertAction: AlertAction) -> Alert.Button {
        switch alertAction.style {
        case .destructive:
            return .destructive(Text(alertAction.title)) {
                alertAction.action()
                alertManager.dismissAlert()
            }
        case .cancel:
            return .cancel(Text(alertAction.title)) {
                alertAction.action()
                alertManager.dismissAlert()
            }
        default:
            return .default(Text(alertAction.title)) {
                alertAction.action()
                alertManager.dismissAlert()
            }
        }
    }
}

/// View extension for easy alert handling
extension View {
    func alertHandler(_ alertManager: AlertViewModel) -> some View {
        modifier(AlertHandler(alertManager: alertManager))
    }
}