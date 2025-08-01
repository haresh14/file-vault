//
//  ErrorView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Reusable error display components with different presentation styles
struct ErrorView {
    
    /// Main error alert view for critical errors
    struct Alert: View {
        let error: AppError
        let onDismiss: () -> Void
        let onRetry: (() -> Void)?
        
        init(error: AppError, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil) {
            self.error = error
            self.onDismiss = onDismiss
            self.onRetry = onRetry
        }
        
        var body: some View {
            VStack(spacing: 20) {
                // Error Icon
                Image(systemName: error.severity.iconName)
                    .font(.system(size: 50))
                    .foregroundColor(error.severity.color)
                
                // Error Message
                VStack(spacing: 8) {
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(error.errorDescription ?? "An unknown error occurred")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    if let onRetry = onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(24)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 32)
        }
    }
    
    /// Compact banner view for non-critical errors
    struct Banner: View {
        let error: AppError
        let onDismiss: () -> Void
        @State private var isVisible = true
        
        var body: some View {
            if isVisible {
                HStack(spacing: 12) {
                    Image(systemName: error.severity.iconName)
                        .foregroundColor(error.severity.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.errorDescription ?? "Error")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: dismissBanner) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(error.severity.color.opacity(0.1))
                .cornerRadius(8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    // Auto-dismiss after 5 seconds for warning and info
                    if error.severity == .warning || error.severity == .info {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            dismissBanner()
                        }
                    }
                }
            }
        }
        
        private func dismissBanner() {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }
    
    /// Inline error view for form validation
    struct Inline: View {
        let error: AppError
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(error.errorDescription ?? "Error")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
    
    /// Empty state view when errors prevent content from loading
    struct EmptyState: View {
        let error: AppError
        let onRetry: () -> Void
        
        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: error.severity.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(error.severity.color)
                
                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(error.errorDescription ?? "An unknown error occurred")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 40)
        }
    }
}

/// View modifier for adding error handling to any view
struct ErrorHandling: ViewModifier {
    @ObservedObject var errorViewModel: ErrorViewModel
    let style: ErrorDisplayStyle
    let onRetry: (() -> Void)?
    
    enum ErrorDisplayStyle {
        case alert
        case banner
        case inline
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            // Banner style error display
            if style == .banner, let error = errorViewModel.currentError {
                ErrorView.Banner(error: error) {
                    errorViewModel.clearError()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .alert("Error", isPresented: $errorViewModel.showErrorAlert) {
            Button("OK") {
                errorViewModel.clearError()
            }
            
            if let onRetry = onRetry {
                Button("Retry") {
                    errorViewModel.clearError()
                    onRetry()
                }
            }
        } message: {
            if let error = errorViewModel.currentError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.errorDescription ?? "An unknown error occurred")
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

/// View extension for easy error handling
extension View {
    func errorHandling(
        _ errorViewModel: ErrorViewModel,
        style: ErrorHandling.ErrorDisplayStyle = .alert,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorHandling(errorViewModel: errorViewModel, style: style, onRetry: onRetry))
    }
}