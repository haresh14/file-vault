import Foundation
import Combine
import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers

/// View-model backing FolderContentView, responsible for loading folders & files,
/// sorting, selection, CRUD, and import operations.
final class FolderViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var files: [VaultItem] = []

    @Published var sortOption: FolderSortOption = .name
    @Published var sortAscending: Bool = true

    // Selection state
    @Published var isSelectionMode: Bool = false
    @Published var selectedFolders: Set<Folder> = []
    @Published var selectedFiles: Set<VaultItem> = []

    // Import progress state
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0

    // MARK: - Dependencies
    private let folder: Folder?
    private var cancellables = Set<AnyCancellable>()

    init(folder: Folder?) {
        self.folder = folder
        loadContent()

        // reload when Core Data saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in self?.loadContent() }
            .store(in: &cancellables)
    }

    deinit { cancellables.forEach { $0.cancel() } }

    // MARK: - Derived Collections
    var sortedFolders: [Folder] {
        sort(folders: folders)
    }
    var sortedFiles: [VaultItem] {
        sort(files: files)
    }

    // MARK: - Public API
    func toggleFolderSelection(_ folder: Folder) {
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
        } else {
            selectedFolders.insert(folder)
        }
    }

    func toggleFileSelection(_ file: VaultItem) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }

    func enterSelectionMode() {
        isSelectionMode = true
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }

    func selectAll() {
        selectedFolders = Set(folders)
        selectedFiles = Set(files)
    }

    func moveSelectedItems(to destination: Folder?) {
        for folder in selectedFolders {
            CoreDataManager.shared.moveFolder(folder, to: destination)
        }
        for file in selectedFiles {
            CoreDataManager.shared.moveVaultItem(file, to: destination)
        }
        exitSelectionMode()
        notifyRefresh()
    }

    func deleteSelectedItems() {
        for folder in selectedFolders {
            CoreDataManager.shared.deleteFolderCompletely(folder)
        }
        for file in selectedFiles {
            try? FileStorageManager.shared.deleteFile(vaultItem: file)
        }
        exitSelectionMode()
        notifyRefresh()
    }

    func createFolder(named name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = CoreDataManager.shared.createFolder(name: name, parent: folder)
        loadContent()
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        CoreDataManager.shared.updateFolder(folder, name: newName)
        loadContent()
    }

    // MARK: - Imports
    func importDocuments(_ dataArray: [(Data, String)]) {
        guard !dataArray.isEmpty else { return }
        isImporting = true; importProgress = 0
        let total = Double(dataArray.count)
        var processed = 0.0
        for (data, fileName) in dataArray {
            let fileType = FileStorageManager.shared.determineFileType(from: fileName)
            _ = try? FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: fileType, targetFolder: folder)
            processed += 1
            importProgress = processed / total
        }
        isImporting = false
        loadContent()
    }

    func importAssets(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }
        isImporting = true
        importProgress = 0
        let total = Double(results.count)
        var processed = 0.0
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    guard let uiImage = image as? UIImage else { updateProgress(); return }
                    guard let data = uiImage.jpegData(compressionQuality: 1.0) ?? uiImage.pngData() else { updateProgress(); return }
                    let fileName = "IMG_\(Date().timeIntervalSince1970).jpg"
                    do {
                        _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: "image/jpeg", targetFolder: self.folder)
                    } catch { print("Error saving image: \(error)") }
                    updateProgress()
                }
            } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url = url else { updateProgress(); return }
                    do {
                        let data = try Data(contentsOf: url)
                        let fileName = "VID_\(Date().timeIntervalSince1970).mov"
                        _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: "video/quicktime", targetFolder: self.folder)
                    } catch { print("Error saving video: \(error)") }
                    updateProgress()
                }
            } else { updateProgress() }
        }
        func updateProgress() {
            DispatchQueue.main.async {
                processed += 1
                self.importProgress = processed / total
                if processed == total { self.isImporting = false; self.loadContent() }
            }
        }
    }

    // Remove or adjust finishImportingAssets if no longer needed
    func finishImportingAssets() {
        isImporting = false
        loadContent()
    }

    // MARK: - Helpers
    private func notifyRefresh() {
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        loadContent()
    }

    private func loadContent() {
        if let folder = folder {
            folders = folder.subfoldersArray
            files = folder.itemsArray
        } else {
            folders = CoreDataManager.shared.fetchRootFolders()
            files = CoreDataManager.shared.fetchVaultItems(in: nil)
        }
    }

    private func sort(folders: [Folder]) -> [Folder] {
        let sorted: [Folder]
        switch sortOption {
        case .name:
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .date:
            sorted = folders.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .size:
            sorted = folders.sorted { $0.totalItemCount < $1.totalItemCount }
        case .kind:
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    private func sort(files: [VaultItem]) -> [VaultItem] {
        let sorted: [VaultItem]
        switch sortOption {
        case .name:
            sorted = files.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .date:
            sorted = files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .size:
            sorted = files.sorted { $0.fileSize < $1.fileSize }
        case .kind:
            sorted = files.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }
} 