//
//  MediaViewerManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI

/// Protocol for managing media viewer presentation in views that display media
protocol MediaViewerManageable: ObservableObject {
    /// Whether the unified media viewer is currently shown
    var showUnifiedMediaViewer: Bool { get set }
    
    /// Index of the media item to display in the viewer
    var mediaViewerIndex: Int { get set }
    
    /// Computed binding for presenting the media viewer
    var isMediaViewerPresented: Binding<Bool> { get }
    
    /// Show media viewer for a specific item at given index
    func showMediaViewer(at index: Int)
    
    /// Hide the media viewer
    func hideMediaViewer()
    
    /// Check if media viewer should be presented
    func shouldPresentMediaViewer() -> Bool
}

/// Default implementation for MediaViewerManageable
extension MediaViewerManageable {
    var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { [self] in self.showUnifiedMediaViewer && self.mediaViewerIndex > -1 },
            set: { [self] newValue in
                if !newValue {
                    self.showUnifiedMediaViewer = false
                    self.mediaViewerIndex = -1
                }
            }
        )
    }
    
    func showMediaViewer(at index: Int) {
        mediaViewerIndex = index
        DispatchQueue.main.async {
            self.showUnifiedMediaViewer = true
        }
    }
    
    func hideMediaViewer() {
        showUnifiedMediaViewer = false
        mediaViewerIndex = -1
    }
    
    func shouldPresentMediaViewer() -> Bool {
        showUnifiedMediaViewer && mediaViewerIndex > -1
    }
}