//
//  FilePreviewSharingService.swift
//  File Vault
//
//  Service for handling file sharing from preview views
//

import SwiftUI
import UIKit

struct FilePreviewSharingService {
    
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
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                // For iPad
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                }
                
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to share file: \(error)")
        }
    }
}