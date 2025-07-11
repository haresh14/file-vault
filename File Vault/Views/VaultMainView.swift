//
//  VaultMainView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import PhotosUI
import Photos

struct VaultMainView: View {
    @State private var showSettings = false
    @State private var showPhotoPicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var vaultItems: [VaultItem] = []
    @State private var selectedVaultItems: Set<VaultItem> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    @State private var searchText = ""
    
    @Environment(\.managedObjectContext) var context
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var filteredItems: [VaultItem] {
        if searchText.isEmpty {
            return vaultItems
        } else {
            return vaultItems.filter { item in
                item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if vaultItems.isEmpty && !isImporting {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(filteredItems) { item in
                                VaultItemCell(
                                    item: item,
                                    isSelected: selectedVaultItems.contains(item),
                                    isSelectionMode: isSelectionMode,
                                    onTap: {
                                        if isSelectionMode {
                                            toggleSelection(for: item)
                                        } else {
                                            viewItem(item)
                                        }
                                    },
                                    onLongPress: {
                                        if !isSelectionMode {
                                            isSelectionMode = true
                                            selectedVaultItems.insert(item)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .searchable(text: $searchText, prompt: "Search files")
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        if isSelectionMode {
                            HStack(spacing: 16) {
                                // Delete button
                                Button(action: {
                                    showDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .disabled(selectedVaultItems.isEmpty)
                                
                                // Cancel selection
                                Button(action: {
                                    isSelectionMode = false
                                    selectedVaultItems.removeAll()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Color.gray)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                            }
                        } else {
                            Button(action: {
                                showPhotoPicker = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isSelectionMode ? "\(selectedVaultItems.count) selected" : "File Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Select All") {
                            selectedVaultItems = Set(vaultItems)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSelectionMode {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { assets in
                    importAssets(assets)
                }
            }
            .overlay(
                Group {
                    if isImporting {
                        ImportProgressView(progress: importProgress)
                    }
                }
            )
            .alert("Delete Items", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedItems()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedVaultItems.count) item(s)? This action cannot be undone.")
            }
        }
        .onAppear {
            loadVaultItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))) { _ in
            print("DEBUG: Received refresh notification")
            loadVaultItems()
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Your Vault is Empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to add photos and videos")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Functions
    
    private func loadVaultItems() {
        print("DEBUG: loadVaultItems called")
        let items = CoreDataManager.shared.fetchAllVaultItems()
        print("DEBUG: Fetched \(items.count) vault items")
        vaultItems = items
        
        // Debug print all items
        for item in items {
            print("DEBUG: Item - fileName: \(item.fileName ?? "nil"), thumbnail: \(item.thumbnailFileName ?? "nil")")
        }
    }
    
    private func toggleSelection(for item: VaultItem) {
        if selectedVaultItems.contains(item) {
            selectedVaultItems.remove(item)
        } else {
            selectedVaultItems.insert(item)
        }
    }
    
    private func viewItem(_ item: VaultItem) {
        // TODO: Navigate to detail view
        print("View item: \(item.fileName ?? "")")
    }
    
    private func importAssets(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        print("DEBUG: Starting import of \(assets.count) assets")
        showPhotoPicker = false
        isImporting = true
        importProgress = 0
        
        let totalItems = Double(assets.count)
        var processedItems = 0.0
        
        for asset in assets {
            print("DEBUG: Processing asset type: \(asset.mediaType.rawValue)")
            FileStorageManager.shared.importFromPhotoLibrary(asset: asset) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let vaultItem):
                        print("DEBUG: Successfully imported asset: \(vaultItem.fileName ?? "")")
                        print("DEBUG: Thumbnail filename: \(vaultItem.thumbnailFileName ?? "none")")
                    case .failure(let error):
                        print("DEBUG: Error importing asset: \(error)")
                    }
                    
                    processedItems += 1
                    importProgress = processedItems / totalItems
                    
                    if processedItems == totalItems {
                        print("DEBUG: All items imported, reloading vault items")
                        isImporting = false
                        loadVaultItems()
                    }
                }
            }
        }
    }
    
    private func deleteSelectedItems() {
        for item in selectedVaultItems {
            do {
                try FileStorageManager.shared.deleteFile(vaultItem: item)
            } catch {
                print("Error deleting item: \(error)")
            }
        }
        
        selectedVaultItems.removeAll()
        isSelectionMode = false
        loadVaultItems()
    }
}

// MARK: - Supporting Views

struct VaultItemCell: View {
    let item: VaultItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    
    var body: some View {
        ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                } else if isLoadingThumbnail {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
                
                // Video indicator
                if item.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(4)
                    }
                }
                
                // Selection indicator
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .blue : .white)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        print("DEBUG: VaultItemCell onAppear for \(item.fileName ?? "")")
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: item)
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
                self.isLoadingThumbnail = false
                print("DEBUG: Thumbnail loaded for \(item.fileName ?? ""): \(loadedThumbnail != nil)")
            }
        }
    }
}

struct ImportProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
                
                Text("Importing...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
}

#Preview {
    VaultMainView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    let completion: ([PHAsset]) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 50
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !results.isEmpty else { return }
            
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            parent.completion(assets)
        }
    }
} 