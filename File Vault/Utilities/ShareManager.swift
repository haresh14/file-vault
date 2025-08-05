//
//  ShareManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import UIKit
import SwiftUI

/// Manages file sharing functionality for the app
class ShareManager {
    static let shared = ShareManager()
    
    private init() {}
    
    /// Share a vault item using the system share sheet
    /// - Parameters:
    ///   - vaultItem: The vault item to share
    ///   - sourceView: The source view for the share sheet on iPad
    ///   - onCompletion: Optional completion handler called after sharing
    func shareVaultItem(_ vaultItem: VaultItem, from sourceView: UIView? = nil, onCompletion: (() -> Void)? = nil) {
        shareVaultItems([vaultItem], from: sourceView, onCompletion: onCompletion)
    }
    
    /// Share multiple vault items using the system share sheet
    /// - Parameters:
    ///   - vaultItems: The vault items to share
    ///   - sourceView: The source view for the share sheet on iPad
    ///   - onCompletion: Optional completion handler called after sharing
    func shareVaultItems(_ vaultItems: [VaultItem], from sourceView: UIView? = nil, onCompletion: (() -> Void)? = nil) {
        guard !vaultItems.isEmpty else {
            print("Error: No items to share")
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Error: Unable to get root view controller for sharing")
            return
        }
        
        // Find the topmost presented view controller
        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }
        
        var temporaryURLs: [URL] = []
        
        do {
            // Prepare all files for sharing
            for vaultItem in vaultItems {
                let tempFileURL = try FileStorageManager.shared.prepareForSharing(vaultItem: vaultItem)
                temporaryURLs.append(tempFileURL)
            }
            
            // Create the activity view controller with all files
            let activityViewController = UIActivityViewController(
                activityItems: temporaryURLs,
                applicationActivities: nil
            )
            
            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                if let sourceView = sourceView {
                    popover.sourceView = sourceView
                    popover.sourceRect = sourceView.bounds
                } else {
                    popover.sourceView = presentingViewController.view
                    popover.sourceRect = CGRect(x: presentingViewController.view.bounds.midX, y: presentingViewController.view.bounds.midY, width: 0, height: 0)
                }
                popover.permittedArrowDirections = []
            }
            
            // Set completion handler to clean up all temporary files and call completion
            activityViewController.completionWithItemsHandler = { [weak self] _, _, _, _ in
                for url in temporaryURLs {
                    self?.cleanupTemporaryFile(at: url)
                }
                onCompletion?()
            }
            
            // Present the share sheet from the topmost view controller
            presentingViewController.present(activityViewController, animated: true)
            
        } catch {
            print("Error preparing files for sharing: \(error)")
            
            // Clean up any temporary files that were created
            for url in temporaryURLs {
                cleanupTemporaryFile(at: url)
            }
            
            // Show error alert
            let alert = UIAlertController(
                title: "Share Error", 
                message: "Unable to prepare \(vaultItems.count > 1 ? "files" : "file") for sharing.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
    }
    
    /// Clean up temporary sharing file
    private func cleanupTemporaryFile(at url: URL) {
        FileStorageManager.shared.cleanupTemporaryFile(at: url)
    }
}

/// SwiftUI wrapper for sharing functionality
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onCompletion: (() -> Void)?
    
    init(items: [Any], onCompletion: (() -> Void)? = nil) {
        self.items = items
        self.onCompletion = onCompletion
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            onCompletion?()
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}