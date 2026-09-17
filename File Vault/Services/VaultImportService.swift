import Foundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

protocol VaultImportServicing {
    func importAssets(
        _ results: [PHPickerResult],
        targetFolder: Folder?,
        progress: @escaping (_ completed: Double, _ total: Double) -> Void,
        completion: @escaping () -> Void
    )

    func importDocuments(
        _ documents: [(Data, String)],
        targetFolder: Folder?,
        progress: @escaping (_ completed: Double, _ total: Double) -> Void,
        completion: @escaping () -> Void
    )
}

final class VaultImportService: VaultImportServicing {
    private let fileStorageManager: FileStorageManaging

    init(fileStorageManager: FileStorageManaging = FileStorageManager.shared) {
        self.fileStorageManager = fileStorageManager
    }

    func importAssets(
        _ results: [PHPickerResult],
        targetFolder: Folder?,
        progress: @escaping (Double, Double) -> Void,
        completion: @escaping () -> Void
    ) {
        guard !results.isEmpty else { return }

        let total = Double(results.count)
        let group = DispatchGroup()
        let progressQueue = DispatchQueue(label: "VaultImportService.progress")
        var processed = 0.0

        func recordProcessed() {
            progressQueue.async {
                processed += 1
                progress(processed, total)
            }
        }

        for result in results {
            group.enter()

            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    defer {
                        recordProcessed()
                        group.leave()
                    }
                    guard let image = image as? UIImage,
                          let data = image.jpegData(compressionQuality: 1.0) ?? image.pngData()
                    else { return }
                    self?.save(
                        data: data,
                        fileName: "Photo.jpg",
                        fileType: "image/jpeg",
                        targetFolder: targetFolder
                    )
                }
            } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, _ in
                    defer {
                        recordProcessed()
                        group.leave()
                    }
                    guard let url, let data = try? Data(contentsOf: url) else { return }
                    self?.save(
                        data: data,
                        fileName: "Video.mov",
                        fileType: "video/quicktime",
                        targetFolder: targetFolder
                    )
                }
            } else {
                recordProcessed()
                group.leave()
            }
        }

        group.notify(queue: progressQueue) {
            DispatchQueue.main.async(execute: completion)
        }
    }

    func importDocuments(
        _ documents: [(Data, String)],
        targetFolder: Folder?,
        progress: @escaping (Double, Double) -> Void,
        completion: @escaping () -> Void
    ) {
        guard !documents.isEmpty else { return }

        let total = Double(documents.count)
        for (index, document) in documents.enumerated() {
            let fileType = fileStorageManager.determineFileType(from: document.1)
            save(
                data: document.0,
                fileName: document.1,
                fileType: fileType,
                targetFolder: targetFolder
            )
            progress(Double(index + 1), total)
        }
        completion()
    }

    private func save(data: Data, fileName: String, fileType: String, targetFolder: Folder?) {
        do {
            _ = try fileStorageManager.saveFile(
                data: data,
                fileName: fileName,
                fileType: fileType,
                targetFolder: targetFolder
            )
            VaultLog.debug("Successfully imported file: \(fileName)")
        } catch FileStorageError.duplicateFile {
            VaultLog.debug("Skipped duplicate file: \(fileName)")
        } catch {
            VaultLog.debug("Error importing file \(fileName): \(error)")
        }
    }
}
