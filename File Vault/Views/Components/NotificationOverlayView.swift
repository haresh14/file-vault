//
//  NotificationOverlayView.swift
//  File Vault
//
//  Created on 11/07/25.
//

import SwiftUI

struct NotificationOverlayView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.inAppNotifications) { notification in
                NotificationCardView(notification: notification)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50) // Account for safe area
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false) // Allow touches to pass through to content below
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.inAppNotifications)
    }
}

struct NotificationCardView: View {
    let notification: InAppNotification
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .foregroundColor(notification.type.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Button(action: {
                notificationManager.removeInAppNotification(id: notification.id)
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .allowsHitTesting(true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Upload Progress View

struct UploadProgressOverlayView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        if !notificationManager.uploadProgress.isEmpty {
            VStack(spacing: 12) {
                ForEach(Array(notificationManager.uploadProgress.values), id: \.uploadId) { progress in
                    UploadProgressCardView(progress: progress)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Account for tab bar
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct UploadProgressCardView: View {
    let progress: UploadNotificationProgress
    
    private var progressPercent: Double {
        guard progress.totalFiles > 0 else { return 0 }
        return Double(progress.processedFiles) / Double(progress.totalFiles)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.blue)
                
                Text("Background Upload")
                    .font(.headline)
                
                Spacer()
                
                Text("\(progress.progressPercentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progressPercent)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                Text("\(progress.processedFiles) of \(progress.totalFiles) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if progress.failedFiles > 0 {
                    Text("\(progress.failedFiles) failed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            NotificationOverlayView()
            Spacer()
            UploadProgressOverlayView()
        }
    }
    .onAppear {
        // Preview data
        NotificationManager.shared.showInAppNotification(
            title: "Upload Completed",
            message: "Successfully uploaded 5 files",
            type: .success
        )
        
        NotificationManager.shared.startUploadProgress(uploadId: "test", totalFiles: 10)
        NotificationManager.shared.updateUploadProgress(uploadId: "test", processedFiles: 6, uploadedFiles: 5, failedFiles: 1)
    }
}