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

enum SortOption: String, CaseIterable {
    case userDefault = "User Default"
    case name = "Name"
    case size = "Size"
    case date = "Date"
    case kind = "Kind"
    
    var systemImage: String {
        switch self {
        case .userDefault:
            return "person"
        case .name:
            return "textformat.abc"
        case .size:
            return "arrow.up.arrow.down"
        case .date:
            return "calendar"
        case .kind:
            return "folder"
        }
    }
}

struct VaultMainView: View {
    @State private var showSettings = false
    @State private var showPhotoPicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var vaultItems: [VaultItem] = []
    @State private var selectedVaultItems: Set<VaultItem> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    @State private var hasTriggeredSelectionHaptic = false
    @State private var searchText = ""
    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var showWebUpload = false
    @State private var showSortActionSheet = false
    @State private var sortOption: SortOption = .userDefault
    @State private var sortAscending: Bool = true
    @StateObject private var webServer = WebServerManager.shared
    
    @Environment(\.managedObjectContext) var context
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var filteredItems: [VaultItem] {
        let items = searchText.isEmpty ? vaultItems : vaultItems.filter { item in
            item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        
        return sortItems(items)
    }
    
    private func sortItems(_ items: [VaultItem]) -> [VaultItem] {
        let sorted: [VaultItem]
        
        switch sortOption {
        case .userDefault:
            sorted = items.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .name:
            sorted = items.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .size:
            sorted = items.sorted { $0.fileSize < $1.fileSize }
        case .date:
            sorted = items.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .kind:
            sorted = items.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        
        return sortAscending ? sorted : sorted.reversed()
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
                                            // Trigger haptic feedback only when entering selection mode
                                            if !hasTriggeredSelectionHaptic {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                hasTriggeredSelectionHaptic = true
                                            }
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
                                    hasTriggeredSelectionHaptic = false
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
            .navigationTitle(isSelectionMode ? "\(selectedVaultItems.count) selected" : "Gallery")
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
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !isSelectionMode {
                        Button(action: { showSortActionSheet = true }) {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
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
            .sheet(isPresented: $showSortActionSheet) {
                SortPopupView(
                    currentSortOption: sortOption,
                    sortAscending: sortAscending,
                    onSortSelected: { option in
                        if option == sortOption {
                            // Toggle sort direction if same option is selected
                            sortAscending.toggle()
                        } else {
                            // Set new sort option and default to ascending
                            sortOption = option
                            sortAscending = true
                        }
                        showSortActionSheet = false
                    }
                )
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
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
            
            Text("No Media Files")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add photos and videos to see them here from all your folders")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Functions
    
    private func loadVaultItems() {
        let items = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
        vaultItems = items
        
        // Items loaded successfully from all folders
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
        hasTriggeredSelectionHaptic = false
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
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
    @State private var isPressed = false
    
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
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundColor(isSelected ? .blue : .gray)
                            }
                            .padding(2)
                        }
                    }
                }
            }
            .cornerRadius(4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
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

// MARK: - Sort Popup View

struct SortPopupView: View {
    let currentSortOption: SortOption
    let sortAscending: Bool
    let onSortSelected: (SortOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort options
                VStack(spacing: 0) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)
                            
                            Text(option.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if option == currentSortOption {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSortSelected(option)
                        }
                        
                        if option != SortOption.allCases.last {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Sort by")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

