//
//  ErrorManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Custom app errors with user-friendly messages
enum AppError: LocalizedError, Identifiable {
    case fileNotFound(String)
    case permissionDenied
    case networkError(String)
    case storageError(String)
    case importError(String)
    case exportError(String)
    case authenticationError
    case invalidData(String)
    case unknownError(String)
    
    var id: String { errorDescription ?? "unknown" }
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "File '\(fileName)' could not be found"
        case .permissionDenied:
            return "Permission denied. Please check your access settings"
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .importError(let message):
            return "Import failed: \(message)"
        case .exportError(let message):
            return "Export failed: \(message)"
        case .authenticationError:
            return "Authentication failed. Please try again"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please verify the file exists and try again"
        case .permissionDenied:
            return "Go to Settings > Privacy & Security to grant necessary permissions"
        case .networkError:
            return "Check your internet connection and try again"
        case .storageError:
            return "Free up some storage space and try again"
        case .importError:
            return "Verify the file format is supported and try again"
        case .exportError:
            return "Check available storage space and try again"
        case .authenticationError:
            return "Verify your credentials and try again"
        case .invalidData:
            return "Please check the data format and try again"
        case .unknownError:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    /// Severity level for error display
    var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .invalidData:
            return .warning
        case .permissionDenied, .authenticationError:
            return .error
        case .networkError, .storageError, .importError, .exportError:
            return .error
        case .unknownError:
            return .critical
        }
    }
}

/// Error severity levels
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var iconName: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// Protocol for ViewModels that need error handling capabilities
protocol ErrorManageable: ObservableObject {
    /// Current error to display to user
    var currentError: AppError? { get set }
    
    /// Whether an error alert should be shown
    var showErrorAlert: Bool { get set }
    
    /// Handle an error and prepare it for display
    func handleError(_ error: Error)
    
    /// Handle an app-specific error
    func handleAppError(_ appError: AppError)
    
    /// Clear the current error
    func clearError()
    
    /// Perform an operation with error handling
    func performWithErrorHandling<T>(_ operation: @escaping () async throws -> T) async -> T?
}

/// Default implementation for ErrorManageable
extension ErrorManageable {
    func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            if let appError = error as? AppError {
                self?.handleAppError(appError)
            } else {
                // Convert generic errors to AppError
                let appError = AppError.unknownError(error.localizedDescription)
                self?.handleAppError(appError)
            }
        }
    }
    
    func handleAppError(_ appError: AppError) {
        currentError = appError
        showErrorAlert = true
        
        // Log error for debugging
        print("🚨 Error: \(appError.errorDescription ?? "Unknown")")
        if let recovery = appError.recoverySuggestion {
            print("💡 Suggestion: \(recovery)")
        }
    }
    
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    func performWithErrorHandling<T>(_ operation: @escaping () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            await MainActor.run {
                handleError(error)
            }
            return nil
        }
    }
}