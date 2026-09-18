import Foundation
import PhotosUI
import SwiftUI

struct FolderContentSheetsModifier: ViewModifier {
    @ObservedObject var viewModel: FolderViewModel
    let folder: Folder?
    let mediaViewerPresented: Binding<Bool>
    let importAssets: ([PHPickerResult]) -> Void
    let importDocuments: ([(Data, String)]) -> Void
    let selectSort: (FolderSortOption) -> Void
    let addPhotos: () -> Void
    let addFiles: () -> Void
    let createFolder: () -> Void
    let move: (Folder?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showPhotoPicker) {
                PhotoPickerView(completion: importAssets)
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPickerView(completion: importDocuments)
            }
            .sheet(isPresented: $viewModel.showSortActionSheet) {
                FolderSortPopupView(
                    currentSortOption: viewModel.sortOption,
                    sortAscending: viewModel.sortAscending,
                    onSortSelected: selectSort
                )
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
                .presentationSizing(.form)
            }
            .sheet(isPresented: $viewModel.showAddActionSheet) {
                UniversalAddContentView.forFolder(
                    onAddPhotos: addPhotos,
                    onAddFiles: addFiles,
                    onCreateFolder: createFolder
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
                .presentationSizing(.form)
            }
            .sheet(isPresented: $viewModel.showMoveSheet) {
                FolderPickerView(
                    selectedFolders: viewModel.selectedFolders,
                    selectedFiles: viewModel.selectedFiles,
                    currentFolder: folder,
                    onMove: move
                )
                .presentationSizing(.form)
            }
            .fullScreenCover(isPresented: mediaViewerPresented) {
                UnifiedMediaViewerView(
                    mediaItems: viewModel.getMediaFiles(),
                    initialIndex: viewModel.mediaViewerIndex
                )
            }
            .fullScreenCover(isPresented: $viewModel.showFilePreview) {
                if let item = viewModel.filePreviewItem {
                    FilePreviewView(vaultItem: item)
                }
            }
    }
}

struct FolderContentAlertsModifier: ViewModifier {
    @ObservedObject var viewModel: FolderViewModel
    @Binding var showFileRenameAlert: Bool
    @Binding var fileRenameText: String
    let createFolder: () -> Void
    let renameFolder: () -> Void
    let cancelFileRename: () -> Void
    let renameFile: () -> Void
    let deleteSelected: () -> Void
    let deleteSwiped: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Create Folder", isPresented: $viewModel.showCreateFolder) {
                TextField("Folder Name", text: $viewModel.newFolderName)
                Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
                Button("Create", action: createFolder)
            } message: {
                Text("Enter a name for the new folder")
            }
            .alert("Rename Folder", isPresented: $viewModel.showRenameFolder) {
                TextField("Folder Name", text: $viewModel.renameText)
                Button("Cancel", role: .cancel) {
                    viewModel.renameText = ""
                    viewModel.folderToRename = nil
                }
                Button("Rename", action: renameFolder)
            } message: {
                Text("Enter a new name for the folder")
            }
            .alert("Rename File", isPresented: $showFileRenameAlert) {
                TextField("File Name", text: $fileRenameText)
                Button("Cancel", role: .cancel, action: cancelFileRename)
                Button("Rename", action: renameFile)
            } message: {
                Text("Enter a new name for the file")
            }
            .alert("Delete Items", isPresented: $viewModel.showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteSelected)
            } message: {
                Text("Are you sure you want to delete \(viewModel.selectedFolders.count + viewModel.selectedFiles.count) item(s)? This action cannot be undone.")
            }
            .alert("Delete Items", isPresented: $viewModel.showSwipeDeleteAlert) {
                Button("Cancel", role: .cancel) { viewModel.itemsToDelete.removeAll() }
                Button("Delete", role: .destructive, action: deleteSwiped)
            } message: {
                Text("Are you sure you want to delete \(viewModel.itemsToDelete.count) item(s)? This action cannot be undone.")
            }
    }
}
