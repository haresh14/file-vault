//
//  ErrorViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Centralized error management ViewModel
final class ErrorViewModel: ObservableObject, ErrorManageable {
    // MARK: - Published Properties
    
    @Published var currentError: AppError?
    @Published var showErrorAlert: Bool = false
    @Published var errorHistory: [ErrorHistoryItem] = []
    
    // MARK: - Error History
    
    struct ErrorHistoryItem: Identifiable {
        let id = UUID()
        let error: AppError
        let timestamp: Date
        let context: String?
        
        init(error: AppError, context: String? = nil) {
            self.error = error
            self.timestamp = Date()
            self.context = context
        }
    }
    
    // MARK: - Configuration
    
    private let maxHistoryItems = 50
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    
    init() {
        setupErrorLogging()
    }
    
    // MARK: - Error Management
    
    func handleAppError(_ appError: AppError) {
        currentError = appError
        showErrorAlert = true
        addToHistory(appError)
        
        // Log error for debugging
        print("🚨 Error: \(appError.errorDescription ?? "Unknown")")
        if let recovery = appError.recoverySuggestion {
            print("💡 Suggestion: \(recovery)")
        }
    }
    
    func handleError(_ error: Error, context: String? = nil) {
        let appError: AppError
        
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = convertToAppError(error)
        }
        
        handleAppError(appError)
        addToHistory(appError, context: context)
    }
    
    // MARK: - Error History Management
    
    private func addToHistory(_ error: AppError, context: String? = nil) {
        let historyItem = ErrorHistoryItem(error: error, context: context)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.errorHistory.insert(historyItem, at: 0)
            
            // Limit history size
            if self.errorHistory.count > self.maxHistoryItems {
                self.errorHistory = Array(self.errorHistory.prefix(self.maxHistoryItems))
            }
        }
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Error Conversion
    
    private func convertToAppError(_ error: Error) -> AppError {
        switch error {
        case let nsError as NSError:
            switch nsError.domain {
            case NSURLErrorDomain:
                return .networkError(nsError.localizedDescription)
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError {
                    return .fileNotFound(nsError.localizedFailureReason ?? "Unknown file")
                } else if nsError.code == NSFileWriteFileExistsError {
                    return .storageError("File already exists")
                } else {
                    return .storageError(nsError.localizedDescription)
                }
            default:
                return .unknownError(nsError.localizedDescription)
            }
        default:
            return .unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - Error Logging
    
    private func setupErrorLogging() {
        // Log errors for debugging in development
        #if DEBUG
        $currentError
            .compactMap { $0 }
            .sink { error in
                print("🚨 [ErrorViewModel] \(error.errorDescription ?? "Unknown error")")
                if let recovery = error.recoverySuggestion {
                    print("💡 [ErrorViewModel] Recovery: \(recovery)")
                }
            }
            .store(in: &cancellables)
        #endif
    }
    
    // MARK: - Convenience Methods
    
    /// Quick method to show a simple error message
    func showSimpleError(_ message: String) {
        let error = AppError.unknownError(message)
        handleAppError(error)
    }
    
    /// Quick method to show a storage error
    func showStorageError(_ message: String) {
        let error = AppError.storageError(message)
        handleAppError(error)
    }
    
    /// Quick method to show an import error
    func showImportError(_ message: String) {
        let error = AppError.importError(message)
        handleAppError(error)
    }
    
    /// Quick method to show a network error
    func showNetworkError(_ message: String) {
        let error = AppError.networkError(message)
        handleAppError(error)
    }
}