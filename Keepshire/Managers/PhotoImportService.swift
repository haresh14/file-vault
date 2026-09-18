import Foundation
import Photos
import AVFoundation

final class PhotoImportService {
    func importAsset(
        _ asset: PHAsset,
        imageHandler: @escaping (Data, String, String) -> Void,
        videoHandler: @escaping (URL, String, String) -> Void,
        completion: @escaping (Result<VaultItem, Error>) -> Void
    ) {
        if asset.mediaType == .image {
            let options = PHImageRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, uti, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    completion(.failure(error))
                    return
                }
                guard let data else {
                    completion(.failure(FileStorageError.importFailed))
                    return
                }
                let fileName = asset.value(forKey: "filename") as? String
                    ?? "IMG_\(Date().timeIntervalSince1970).jpg"
                imageHandler(data, fileName, uti ?? "image/jpeg")
            }
        } else if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) {
                avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    completion(.failure(error))
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset else {
                    completion(.failure(FileStorageError.importFailed))
                    return
                }
                let fileName = asset.value(forKey: "filename") as? String
                    ?? "VID_\(Date().timeIntervalSince1970).mov"
                videoHandler(urlAsset.url, fileName, "video/quicktime")
            }
        } else {
            completion(.failure(FileStorageError.importFailed))
        }
    }
}
