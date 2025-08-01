//
//  ImportManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import PhotosUI
import SwiftUI

/// Protocol for managing import functionality in views that support file imports
protocol ImportManageable: ObservableObject {
    /// Whether an import operation is currently in progress
    var isImporting: Bool { get set }
    
    /// Progress of current import operation (0.0 to 1.0)
    var importProgress: Double { get set }
    
    /// Import assets from photo picker results
    func importAssets(_ results: [PHPickerResult])
    
    /// Import documents from document picker
    func importDocuments(_ dataArray: [(Data, String)])
    
    /// Called when import operation starts
    func startImport()
    
    /// Called when import operation completes
    func finishImport()
    
    /// Update import progress
    func updateProgress(completed: Double, total: Double)
}

/// Default implementation for ImportManageable
extension ImportManageable {
    func startImport() {
        isImporting = true
        importProgress = 0
    }
    
    func finishImport() {
        isImporting = false
        importProgress = 0
    }
    
    func updateProgress(completed: Double, total: Double) {
        importProgress = completed / total
    }
}

/// Import result for handling completion
enum ImportResult {
    case success(fileName: String)
    case failure(fileName: String, error: Error)
}

/// Import operation context
struct ImportContext {
    let targetFolder: Folder?
    let onCompletion: (() -> Void)?
    
    init(targetFolder: Folder? = nil, onCompletion: (() -> Void)? = nil) {
        self.targetFolder = targetFolder
        self.onCompletion = onCompletion
    }
}