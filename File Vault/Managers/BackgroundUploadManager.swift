import Foundation
import UIKit

/// Manager responsible for handling background uploads
/// Uses URLSession with background configuration to ensure uploads continue even when app is suspended
class BackgroundUploadManager: NSObject {
    static let shared = BackgroundUploadManager()
    
    private let backgroundSessionIdentifier = "com.haresh.FileVault.background-upload"
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var uploadTasks: [Int: UploadTaskInfo] = [:]
    private var uploadCompletionHandlers: [String: () -> Void] = [:]
    
    struct UploadTaskInfo {
        let uploadId: String
        let fileName: String
        let folderPath: String?
        let temporaryFileURL: URL
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Store the background session completion handler
    func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
        uploadCompletionHandlers[identifier] = completionHandler
    }
    
    /// Upload data in the background
    func uploadDataInBackground(data: Data, fileName: String, folderPath: String? = nil, uploadId: String) -> URLSessionUploadTask? {
        // Save data to temporary file (required for background uploads)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try data.write(to: tempURL)
        } catch {
            print("Failed to write temporary file for background upload: \(error)")
            return nil
        }
        
        // Create upload request
        let serverURLString = WebServerManager.shared.serverURL
        guard !serverURLString.isEmpty, let serverURL = URL(string: serverURLString) else {
            print("Server URL not available or invalid: \(serverURLString)")
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
        
        let uploadURL = serverURL.appendingPathComponent("upload")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create the multipart body
        var body = Data()
        
        // Add folder ID if present
        if let folderPath = folderPath {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"folderPath\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(folderPath)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Save the complete multipart data to temporary file
        let multipartTempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try body.write(to: multipartTempURL)
            try? FileManager.default.removeItem(at: tempURL) // Remove the original temp file
        } catch {
            print("Failed to write multipart data to temporary file: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
        
        // Create upload task
        let task = backgroundSession.uploadTask(with: request, fromFile: multipartTempURL)
        
        // Store task info
        uploadTasks[task.taskIdentifier] = UploadTaskInfo(
            uploadId: uploadId,
            fileName: fileName,
            folderPath: folderPath,
            temporaryFileURL: multipartTempURL
        )
        
        task.resume()
        return task
    }
    
    /// Cancel all upload tasks
    func cancelAllUploads() {
        backgroundSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
    
    /// Get active upload tasks count
    func getActiveUploadsCount(completion: @escaping (Int) -> Void) {
        backgroundSession.getAllTasks { tasks in
            let activeTasks = tasks.filter { $0.state == .running || $0.state == .suspended }
            completion(activeTasks.count)
        }
    }
}

// MARK: - URLSessionDelegate
extension BackgroundUploadManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            if let completionHandler = self.uploadCompletionHandlers[session.configuration.identifier ?? ""] {
                completionHandler()
                self.uploadCompletionHandlers.removeValue(forKey: session.configuration.identifier ?? "")
            }
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension BackgroundUploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let uploadTask = task as? URLSessionUploadTask,
              let taskInfo = uploadTasks[task.taskIdentifier] else { return }
        
        // Clean up temporary file
        try? FileManager.default.removeItem(at: taskInfo.temporaryFileURL)
        uploadTasks.removeValue(forKey: task.taskIdentifier)
        
        if let error = error {
            print("Upload failed for \(taskInfo.fileName): \(error)")
            NotificationCenter.default.post(
                name: Notification.Name("BackgroundUploadFailed"),
                object: nil,
                userInfo: ["uploadId": taskInfo.uploadId, "error": error]
            )
        } else {
            print("Upload completed for \(taskInfo.fileName)")
            NotificationCenter.default.post(
                name: Notification.Name("BackgroundUploadCompleted"),
                object: nil,
                userInfo: ["uploadId": taskInfo.uploadId]
            )
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let taskInfo = uploadTasks[task.taskIdentifier] else { return }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        NotificationCenter.default.post(
            name: Notification.Name("BackgroundUploadProgress"),
            object: nil,
            userInfo: [
                "uploadId": taskInfo.uploadId,
                "progress": progress,
                "bytesSent": totalBytesSent,
                "totalBytes": totalBytesExpectedToSend
            ]
        )
    }
}

// MARK: - URLSessionDataDelegate
extension BackgroundUploadManager: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Handle response data if needed
        if let responseString = String(data: data, encoding: .utf8) {
            print("Upload response: \(responseString)")
        }
    }
}