//
//  MigrationProgressView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct MigrationProgressView: View {
    let currentProgress: Int
    let totalItems: Int
    let onCancel: () -> Void
    
    private var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(currentProgress) / Double(totalItems)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            headerSection
            progressSection
            descriptionSection
            
            Spacer()
        }
        .padding()
        .navigationTitle("Updating Vault")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
            
            Text("Updating Encryption")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 20) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.2)
                    .foregroundColor(.blue)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progressPercentage, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(270))
                    .animation(.linear, value: progressPercentage)
                
                VStack {
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(currentProgress) of \(totalItems)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            // Progress Bar (alternative visual)
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(height: 6)
        }
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text("Re-encrypting your files with the new authentication method")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Your files are being updated for security", systemImage: "shield.checkered")
                Label("This may take a few moments", systemImage: "clock")
                Label("Please don't close the app", systemImage: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        MigrationProgressView(
            currentProgress: 15,
            totalItems: 50,
            onCancel: { print("Migration cancelled") }
        )
    }
}