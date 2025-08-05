//
//  TrashViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class TrashViewModel: ObservableObject, MediaViewerManageable {
    // MARK: - Published Properties
    @Published var deletedItems: [VaultItem] = []
    @Published var selectedItems: Set<VaultItem> = []
    @Published var isSelectionMode: Bool = false
    
    // MARK: - Alert States
    @Published var showDeleteAlert: Bool = false
    @Published var showRestoreAlert: Bool = false
    @Published var showEmptyTrashAlert: Bool = false
    
    // MARK: - File Preview States
    @Published var showFilePreview: Bool = false
    @Published var filePreviewItem: VaultItem?
    
    // MARK: - MediaViewerManageable Properties
    @Published var showUnifiedMediaViewer: Bool = false
    @Published var mediaViewerIndex: Int = -1
    
    // MARK: - Computed Properties
    var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { self.showUnifiedMediaViewer && self.mediaViewerIndex > -1 },
            set: { newValue in
                if !newValue {
                    self.showUnifiedMediaViewer = false
                    self.mediaViewerIndex = -1
                }
            }
        )
    }
    
    // MARK: - Initialization
    init() {
        loadDeletedItems()
    }
    
    // MARK: - Data Loading
    func loadDeletedItems() {
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        request.predicate = NSPredicate(format: "isTrashed == true")
        request.sortDescriptors = [NSSortDescriptor(key: "trashedAt", ascending: false)]
        
        do {
            deletedItems = try CoreDataManager.shared.context.fetch(request)
        } catch {
            print("Error loading deleted items: \(error)")
            deletedItems = []
        }
    }
    
    // MARK: - Selection Management
    func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
    }
    
    func toggleSelection(_ item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    func selectAllItems() {
        selectedItems = Set(deletedItems)
    }
    
    // MARK: - File Operations
    func restoreSelected() {
        for item in selectedItems {
            item.isTrashed = false
            item.trashedAt = nil
        }
        
        CoreDataManager.shared.save()
        exitSelectionMode()
        loadDeletedItems()
        
        // Notify other views to refresh
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }
    
    func permanentlyDeleteSelected() {
        for item in selectedItems {
            do {
                try FileStorageManager.shared.permanentlyDeleteFile(vaultItem: item)
            } catch {
                print("Error permanently deleting file: \(error)")
            }
        }
        
        exitSelectionMode()
        loadDeletedItems()
        
        // Notify other views to refresh
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }
    
    func emptyAllTrash() {
        for item in deletedItems {
            do {
                try FileStorageManager.shared.permanentlyDeleteFile(vaultItem: item)
            } catch {
                print("Error permanently deleting file: \(error)")
            }
        }
        
        loadDeletedItems()
        
        // Notify other views to refresh
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }
    
    // MARK: - MediaViewerManageable Protocol Support
    func showMediaViewer(at index: Int) {
        mediaViewerIndex = index
        showUnifiedMediaViewer = true
    }
    
    func hideMediaViewer() {
        showUnifiedMediaViewer = false
        mediaViewerIndex = -1
    }
    
    func shouldPresentMediaViewer() -> Bool {
        return showUnifiedMediaViewer && mediaViewerIndex > -1
    }
    
    // MARK: - File Preview Logic
    /// Get files suitable for media viewer (using deleted items to match UI order)
    func getMediaFiles() -> [VaultItem] {
        deletedItems.filter { item in
            item.isImage || item.isVideo
        }
    }
    
    /// Show media viewer for a specific file
    func showMediaViewerForFile(_ file: VaultItem) {
        let mediaFiles = getMediaFiles()
        if let index = mediaFiles.firstIndex(where: { $0.objectID == file.objectID }) {
            showMediaViewer(at: index)
        }
    }
    
    /// View a file - show media viewer for images/videos, file preview for others
    func viewFile(_ file: VaultItem) {
        if file.isImage || file.isVideo {
            showMediaViewerForFile(file)
        } else {
            showFilePreview(for: file)
        }
    }
    
    /// Show file preview for non-media files
    func showFilePreview(for item: VaultItem) {
        filePreviewItem = item
        showFilePreview = true
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(for item: VaultItem) {
        FileStorageManager.shared.toggleFavorite(for: item)
        // Refresh the view to reflect the change
        loadDeletedItems()
    }
    
    // MARK: - Share Management
    
    func shareItem(_ item: VaultItem) {
        ShareManager.shared.shareVaultItem(item)
    }
} 