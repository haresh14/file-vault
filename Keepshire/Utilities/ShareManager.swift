//
//  ShareManager.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import UIKit
import SwiftUI

/// Manages file sharing functionality for the app
class ShareManager {
    static let shared = ShareManager()
    
    private init() {}
    
    /// Key window of the scene the user is currently interacting with, falling back to
    /// another visible window in that same scene when no window reports itself as key.
    private static func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ordered = scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState == .foregroundInactive }
            + scenes.filter {
                $0.activationState != .foregroundActive && $0.activationState != .foregroundInactive
            }

        for scene in ordered {
            if let window = scene.windows.first(where: { $0.isKeyWindow })
                ?? scene.windows.first(where: { !$0.isHidden })
                ?? scene.windows.first {
                return window
            }
        }
        return nil
    }

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
            VaultLog.debug("Error: No items to share")
            return
        }
        
        guard let rootViewController = ShareManager.activeKeyWindow()?.rootViewController else {
            VaultLog.debug("Error: Unable to get root view controller for sharing")
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
            VaultLog.debug("Error preparing files for sharing: \(error)")
            
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