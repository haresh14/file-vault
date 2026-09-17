//
//  FilePreviewSharingService.swift
//  Keepshire
//

import SwiftUI
import UIKit

struct FilePreviewSharingService {
    static func shareFile(fileData: Data?, fileName: String?) {
        guard let fileData, let fileName else { return }

        let sharing = TemporarySharingService(fileManager: .default)
        do {
            let tempURL = try sharing.prepare(data: fileData, fileName: fileName)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                sharing.cleanup(at: tempURL)
            }

            if let window = activeKeyWindow(),
               let rootVC = window.rootViewController {
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                }

                var presentingVC = rootVC
                while let presented = presentingVC.presentedViewController {
                    presentingVC = presented
                }
                presentingVC.present(activityVC, animated: true)
            } else {
                sharing.cleanup(at: tempURL)
            }
        } catch {
            VaultLog.debug("Failed to share file: \(error)")
        }
    }

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
}
