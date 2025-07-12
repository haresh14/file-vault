//
//  VaultMainView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation

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
    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var showWebUpload = false
    @StateObject private var webServer = WebServerManager.shared
    
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
    
    var filteredImages: [VaultItem] {
        return filteredItems.filter { $0.isImage }
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
            .navigationTitle(isSelectionMode ? "\(selectedVaultItems.count) selected" : "")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Select All") {
                            selectedVaultItems = Set(vaultItems)
                        }
                    } else {
                        Button(action: { showWebUpload = true }) {
                            ZStack {
                                Image(systemName: "globe")
                                
                                if webServer.isRunning {
                                    // Running indicator - small green dot
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
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
            .sheet(isPresented: $showWebUpload) {
                WebUploadView()
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
            .fullScreenCover(isPresented: $showUnifiedMediaViewer) {
                UnifiedMediaViewerView(
                    mediaItems: filteredItems,
                    initialIndex: mediaViewerIndex
                )
            }
        }
        .onAppear {
            loadVaultItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))) { _ in
            // Refreshing vault items
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
        let items = CoreDataManager.shared.fetchAllVaultItems()
        vaultItems = items
        
        // Items loaded successfully
    }
    
    private func toggleSelection(for item: VaultItem) {
        if selectedVaultItems.contains(item) {
            selectedVaultItems.remove(item)
        } else {
            selectedVaultItems.insert(item)
        }
    }
    
    private func viewItem(_ item: VaultItem) {
        if item.isImage {
            // Show photo viewer for images - but now use unified viewer
            if let index = filteredItems.firstIndex(where: { $0.objectID == item.objectID }) {
                mediaViewerIndex = index
                showUnifiedMediaViewer = true
            }
        } else if item.isVideo {
            // Show video player for videos - but now use unified viewer
            if let index = filteredItems.firstIndex(where: { $0.objectID == item.objectID }) {
                mediaViewerIndex = index
                showUnifiedMediaViewer = true
            }
        } else {
            // Handle other file types if needed
            print("Unsupported file type: \(item.fileType ?? "unknown")")
        }
    }
    
    private func importAssets(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        showPhotoPicker = false
        isImporting = true
        importProgress = 0
        
        let totalItems = Double(assets.count)
        var processedItems = 0.0
        
        for asset in assets {
            FileStorageManager.shared.importFromPhotoLibrary(asset: asset) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        // Asset imported successfully
                        break
                    case .failure(let error):
                        print("Error importing asset: \(error)")
                    }
                    
                    processedItems += 1
                    importProgress = processedItems / totalItems
                    
                    if processedItems == totalItems {
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
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
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
        }
        .aspectRatio(1, contentMode: .fit)
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
        // Loading thumbnail for item
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: item)
            
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
                self.isLoadingThumbnail = false
                
                if loadedThumbnail == nil {
                    // Try to regenerate thumbnail if it's missing
                    if item.thumbnailFileName == nil || item.thumbnailFileName?.isEmpty == true {
                        self.regenerateThumbnail()
                    }
                }
            }
        }
    }
    
    private func regenerateThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let fileData = try FileStorageManager.shared.loadFile(vaultItem: item)
                
                if item.isImage {
                    // Generate image thumbnail
                    if let image = UIImage(data: fileData) {
                        let thumbnailSize = CGSize(width: 200, height: 200)
                        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                        
                        let thumbnail = renderer.image { context in
                            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                        }
                        
                        DispatchQueue.main.async {
                            self.thumbnail = thumbnail
                        }
                    }
                } else if item.isVideo {
                    // Generate video thumbnail
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString + ".mov")
                    
                    try fileData.write(to: tempURL)
                    defer { try? FileManager.default.removeItem(at: tempURL) }
                    
                    let asset = AVURLAsset(url: tempURL)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    
                    let time = CMTime(seconds: 1, preferredTimescale: 60)
                    
                    if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                        let thumbnail = UIImage(cgImage: cgImage)
                        
                        DispatchQueue.main.async {
                            self.thumbnail = thumbnail
                        }
                    }
                }
            } catch {
                print("Error regenerating thumbnail: \(error)")
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