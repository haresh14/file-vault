//
//  FilePreviewSharingService.swift
//  File Vault
//
//  Service for handling file sharing from preview views
//

import SwiftUI
import UIKit

struct FilePreviewSharingService {
    
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

    /// Share a file using the native iOS share sheet
    /// - Parameters:
    ///   - fileData: The file data to share
    ///   - fileName: The name of the file
    static func shareFile(fileData: Data?, fileName: String?) {
        guard let fileData = fileData,
              let fileName = fileName else { return }
        
        // Create temporary file for sharing
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try fileData.write(to: tempURL)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Present the share sheet
            if let window = activeKeyWindow(),
               let rootVC = window.rootViewController {
                
                // For iPad
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                }
                
                // The preview itself is presented modally, so share from the topmost controller
                var presentingVC = rootVC
                while let presented = presentingVC.presentedViewController {
                    presentingVC = presented
                }

                presentingVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to share file: \(error)")
        }
    }
}