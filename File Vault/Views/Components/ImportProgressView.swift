//
//  ImportProgressView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import Combine

/// ViewModel for managing import progress state
final class ImportProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isImporting: Bool = false
    @Published var progress: Double = 0.0
    @Published var message: String = "Importing..."
    @Published var currentFileName: String = ""
    @Published var processedCount: Int = 0
    @Published var totalCount: Int = 0
    
    // MARK: - Computed Properties
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var progressText: String {
        if totalCount > 0 {
            return "\(processedCount) of \(totalCount) items"
        } else {
            return "\(progressPercentage)%"
        }
    }
    
    // MARK: - Methods
    
    /// Start import operation
    func startImport(totalItems: Int, message: String = "Importing...") {
        isImporting = true
        progress = 0.0
        self.message = message
        processedCount = 0
        totalCount = totalItems
        currentFileName = ""
    }
    
    /// Update progress
    func updateProgress(completed: Int, total: Int, currentFile: String = "") {
        processedCount = completed
        totalCount = total
        progress = total > 0 ? Double(completed) / Double(total) : 0.0
        currentFileName = currentFile
    }
    
    /// Finish import operation
    func finishImport() {
        isImporting = false
        progress = 1.0
        processedCount = totalCount
        currentFileName = ""
        
        // Auto-hide after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reset()
        }
    }
    
    /// Reset all progress state
    func reset() {
        isImporting = false
        progress = 0.0
        message = "Importing..."
        currentFileName = ""
        processedCount = 0
        totalCount = 0
    }
}

/// Reusable import progress view with enhanced features
struct ImportProgressView: View {
    @ObservedObject var viewModel: ImportProgressViewModel
    let style: ImportProgressStyle
    
    init(
        viewModel: ImportProgressViewModel,
        style: ImportProgressStyle = .overlay
    ) {
        self.viewModel = viewModel
        self.style = style
    }
    
    // Convenience initializer for simple progress display
    init(
        progress: Double,
        message: String = "Importing...",
        style: ImportProgressStyle = .overlay
    ) {
        let vm = ImportProgressViewModel()
        vm.progress = progress
        vm.message = message
        vm.isImporting = true
        self.viewModel = vm
        self.style = style
    }
    
    var body: some View {
        if viewModel.isImporting {
            Group {
                switch style {
                case .overlay:
                    overlayStyle
                case .compact:
                    compactStyle
                case .banner:
                    bannerStyle
                case .minimal:
                    minimalStyle
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: viewModel.isImporting)
        }
    }
    
    // MARK: - Style Variants
    
    @ViewBuilder
    private var overlayStyle: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                
                Text(viewModel.message)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundColor(.white)
                
                if !viewModel.currentFileName.isEmpty {
                    Text(viewModel.currentFileName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    @ViewBuilder
    private var compactStyle: some View {
        VStack(spacing: 12) {
            HStack {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(CircularProgressViewStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(viewModel.progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !viewModel.currentFileName.isEmpty {
                HStack {
                    Text("Processing:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.currentFileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var bannerStyle: some View {
        VStack {
            Spacer()
            
            HStack {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.message)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(viewModel.progressText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
    }
    
    @ViewBuilder
    private var minimalStyle: some View {
        HStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(CircularProgressViewStyle())
                .frame(width: 16, height: 16)
            
            Text(viewModel.progressText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Available styles for import progress display
enum ImportProgressStyle {
    case overlay    // Full screen overlay with dark background
    case compact    // Card-style view with background
    case banner     // Bottom banner style
    case minimal    // Small inline progress indicator
}

// MARK: - Convenience Extensions

extension View {
    /// Add import progress overlay to any view
    func importProgressOverlay(
        viewModel: ImportProgressViewModel,
        style: ImportProgressStyle = .overlay
    ) -> some View {
        overlay(
            ImportProgressView(viewModel: viewModel, style: style)
        )
    }
    
    /// Add simple import progress overlay
    func importProgressOverlay(
        isImporting: Bool,
        progress: Double,
        message: String = "Importing..."
    ) -> some View {
        overlay(
            Group {
                if isImporting {
                    ImportProgressView(
                        progress: progress,
                        message: message,
                        style: .overlay
                    )
                }
            }
        )
    }
}

// MARK: - Preview Support

#Preview("Overlay Style") {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        ImportProgressView(
            progress: 0.65,
            message: "Importing Photos...",
            style: .overlay
        )
    }
}

#Preview("Compact Style") {
    VStack {
        ImportProgressView(
            progress: 0.35,
            message: "Processing Files...",
            style: .compact
        )
        
        Spacer()
    }
    .padding()
}