//
//  NotificationManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation
import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var inAppNotifications: [InAppNotification] = []
    @Published var uploadProgress: [String: UploadNotificationProgress] = [:]
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - Permission
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    // MARK: - Upload Progress Tracking
    
    func startUploadProgress(uploadId: String, totalFiles: Int) {
        DispatchQueue.main.async {
            self.uploadProgress[uploadId] = UploadNotificationProgress(
                uploadId: uploadId,
                totalFiles: totalFiles,
                processedFiles: 0,
                uploadedFiles: 0,
                failedFiles: 0,
                isCompleted: false,
                startTime: Date()
            )
            
            self.showInAppNotification(
                title: "Upload Started",
                message: "Processing \(totalFiles) file(s) in background...",
                type: .info,
                duration: 1.5
            )
        }
    }
    
    func updateUploadProgress(uploadId: String, processedFiles: Int, uploadedFiles: Int, failedFiles: Int) {
        DispatchQueue.main.async {
            if var progress = self.uploadProgress[uploadId] {
                progress.processedFiles = processedFiles
                progress.uploadedFiles = uploadedFiles
                progress.failedFiles = failedFiles
                self.uploadProgress[uploadId] = progress
                
                // Show progress update only at major milestones (25%, 50%, 75%) or completion
                let totalFiles = progress.totalFiles
                let progressPercent = totalFiles > 0 ? (processedFiles * 100) / totalFiles : 0
                
                if progressPercent > 0 && (progressPercent == 25 || progressPercent == 50 || progressPercent == 75 || progressPercent >= 100) {
                    self.showInAppNotification(
                        title: "Upload Progress",
                        message: "Processed \(processedFiles) of \(totalFiles) files (\(progressPercent)%)",
                        type: .info,
                        duration: 1.0
                    )
                }
            }
        }
    }
    
    func completeUpload(uploadId: String, uploadedFiles: Int, failedFiles: Int) {
        DispatchQueue.main.async {
            if var progress = self.uploadProgress[uploadId] {
                progress.isCompleted = true
                progress.uploadedFiles = uploadedFiles
                progress.failedFiles = failedFiles
                self.uploadProgress[uploadId] = progress
                
                let title: String
                let message: String
                let type: NotificationType
                
                if failedFiles > 0 {
                    title = "Upload Completed with Issues"
                    message = "\(uploadedFiles) uploaded, \(failedFiles) failed"
                    type = .warning
                } else {
                    title = "Upload Completed"
                    message = "Successfully uploaded \(uploadedFiles) file(s)"
                    type = .success
                }
                
                // Show in-app notification
                self.showInAppNotification(
                    title: title,
                    message: message,
                    type: type,
                    duration: 2.5
                )
                
                // Show system notification for background uploads
                self.showSystemNotification(title: title, message: message)
                
                // Clean up after brief delay to let users see completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.uploadProgress.removeValue(forKey: uploadId)
                }
            }
        }
    }
    
    // MARK: - In-App Notifications
    
    func showInAppNotification(title: String, message: String, type: NotificationType, duration: Double = 2.0) {
        let notification = InAppNotification(
            id: UUID(),
            title: title,
            message: message,
            type: type,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.inAppNotifications.append(notification)
            
            // Auto-remove after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.removeInAppNotification(id: notification.id)
            }
        }
    }
    
    func removeInAppNotification(id: UUID) {
        DispatchQueue.main.async {
            self.inAppNotifications.removeAll { $0.id == id }
        }
    }
    
    // MARK: - System Notifications
    
    private func showSystemNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing system notification: \(error)")
            }
        }
    }
}

// MARK: - Data Models

struct InAppNotification: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let type: NotificationType
    let timestamp: Date
}

struct UploadNotificationProgress {
    let uploadId: String
    let totalFiles: Int
    var processedFiles: Int
    var uploadedFiles: Int
    var failedFiles: Int
    var isCompleted: Bool
    let startTime: Date
    
    var progressPercentage: Int {
        guard totalFiles > 0 else { return 0 }
        return (processedFiles * 100) / totalFiles
    }
}

enum NotificationType {
    case success
    case warning
    case error
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}