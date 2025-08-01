//
//  WebServerManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation
import Network
import CoreData
import SwiftUI
import BackgroundTasks
import UIKit

class WebServerManager: ObservableObject, WebServerManaging {
    static let shared = WebServerManager()
    
    @Published var isRunning = false
    @Published var serverURL: String = ""
    @Published var connectedDevices: [String] = []
    @Published var isDownloadEnabled = false // Default to disabled
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let serverPort = 8080
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var activeUploads: Set<String> = []
    
    // UserDefaults key for download setting
    private let downloadEnabledKey = "webServerDownloadEnabled"
    
    private init() {
        setupBackgroundTaskSupport()
        setupAppLifecycleObservers()
        loadDownloadSetting()
    }
    
    func startServer() {
        print("DEBUG: startServer called")
        
        guard let port = NWEndpoint.Port(rawValue: UInt16(serverPort)) else {
            print("DEBUG: Invalid port: \(serverPort)")
            return
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        do {
            let listener = try NWListener(using: parameters, on: port)
            print("DEBUG: Listener created successfully")
            
            listener.newConnectionHandler = { [weak self] (connection: NWConnection) in
                print("DEBUG: newConnectionHandler called")
                self?.handleNewConnection(connection)
            }
            
            listener.stateUpdateHandler = { [weak self] (state: NWListener.State) in
                print("DEBUG: Listener state changed to: \(state)")
                switch state {
                case .ready:
                    print("DEBUG: Server started successfully on port \(self?.serverPort ?? 0)")
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.updateServerURL()
                    }
                case .failed(let error):
                    print("DEBUG: Server failed to start: \(error)")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                case .cancelled:
                    print("DEBUG: Server cancelled")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                default:
                    print("DEBUG: Server state: \(state)")
                }
            }
            
            self.listener = listener
            listener.start(queue: DispatchQueue.global(qos: .userInitiated))
            print("DEBUG: Listener started")
        } catch {
            print("DEBUG: Failed to create listener: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        endBackgroundTask()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.serverURL = ""
            self.connectedDevices.removeAll()
        }
        
        print("DEBUG: Web server stopped")
    }
    
    // MARK: - Background Task Support
    
    private func setupBackgroundTaskSupport() {
        // Register background task identifier
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.haresh.FileVault.upload-processing", using: nil) { task in
            self.handleBackgroundUploadTask(task as! BGProcessingTask)
        }
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterBackground() {
        if isRunning && !activeUploads.isEmpty {
            startBackgroundTask()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // Background processing is no longer needed when app is active
        endBackgroundTask()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "WebServerUpload") {
            // This block is called when the background time is about to expire
            print("DEBUG: Background task time expiring, ending gracefully")
            self.endBackgroundTask()
        }
        
        print("DEBUG: Started background task for web server uploads")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
            print("DEBUG: Ended background task")
        }
    }
    
    private func handleBackgroundUploadTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Keep the server running for background uploads
        if !isRunning {
            startServer()
        }
        
        // Complete the task when uploads are done
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        print("DEBUG: New connection added, total connections: \(connections.count)")
        
        connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            print("DEBUG: Connection state changed to: \(state)")
            switch state {
            case .ready:
                print("DEBUG: Connection ready - starting to receive HTTP request")
                self?.receiveHTTPRequest(on: connection)
            case .failed(let error):
                print("DEBUG: Connection failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                print("DEBUG: Connection cancelled")
                self?.removeConnection(connection)
            case .waiting(let error):
                print("DEBUG: Connection waiting: \(error)")
            case .preparing:
                print("DEBUG: Connection preparing")
            case .setup:
                print("DEBUG: Connection setup")
            @unknown default:
                print("DEBUG: Connection unknown state: \(state)")
            }
        }
        
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        print("DEBUG: Connection started")
    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
    }
    
    // MARK: - HTTP Request Handling
    
    private func receiveHTTPRequest(on connection: NWConnection) {
        var receivedData = Data()
        let maxRequestSize = 2 * 1024 * 1024 * 1024 // 2GB max
        var expectedContentLength: Int?
        var headersComplete = false
        
        func receiveData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                
                if let error = error {
                    print("DEBUG: Error receiving data: \(error)")
                    connection.cancel()
                    return
                }
                
                if let data = data, !data.isEmpty {
                    receivedData.append(data)
                    print("DEBUG: Received \(data.count) bytes, total: \(receivedData.count)")
                    
                    // Check for max size limit
                    if receivedData.count > maxRequestSize {
                        print("DEBUG: Request too large: \(receivedData.count) bytes")
                        let errorResponse = """
                        {
                            "success": false,
                            "message": "File too large. Maximum size is 2GB."
                        }
                        """
                        self.sendHTTPResponse(connection: connection, statusCode: 413, contentType: "application/json", body: errorResponse)
                        return
                    }
                    
                    // Check if we have complete headers (look for double CRLF in binary data)
                    if !headersComplete {
                        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
                        if let headerEndRange = receivedData.range(of: headerEndMarker) {
                            headersComplete = true
                            print("DEBUG: Headers complete, parsing Content-Length")
                            
                            // Extract headers only (safe to convert to UTF-8)
                            let headerData = receivedData.subdata(in: receivedData.startIndex..<headerEndRange.lowerBound)
                            if let headerString = String(data: headerData, encoding: .utf8) {
                                let headerLines = headerString.components(separatedBy: "\r\n")
                                
                                for line in headerLines {
                                    if line.lowercased().hasPrefix("content-length:") {
                                        let lengthString = line.replacingOccurrences(of: "content-length:", with: "", options: .caseInsensitive)
                                            .trimmingCharacters(in: .whitespaces)
                                        expectedContentLength = Int(lengthString)
                                        print("DEBUG: Expected Content-Length: \(expectedContentLength ?? 0)")
                                        break
                                    }
                                }
                                
                                // Calculate how much data we need
                                let headerEndIndex = receivedData.startIndex.distance(to: headerEndRange.upperBound)
                                let totalExpected = headerEndIndex + (expectedContentLength ?? 0)
                                print("DEBUG: Headers end at \(headerEndIndex), total expected: \(totalExpected)")
                            }
                        }
                    }
                    
                    // Check if we have all the data we need
                    if headersComplete {
                        if let contentLength = expectedContentLength {
                            // Calculate header size using binary data
                            let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
                            if let headerEndRange = receivedData.range(of: headerEndMarker) {
                                let headerEndIndex = receivedData.startIndex.distance(to: headerEndRange.upperBound)
                                let totalExpected = headerEndIndex + contentLength
                                
                                if receivedData.count >= totalExpected {
                                    print("DEBUG: Complete request received (\(receivedData.count)/\(totalExpected) bytes), processing")
                                    self.processHTTPRequest(data: receivedData, connection: connection)
                                    return
                                } else {
                                    print("DEBUG: Still receiving data (\(receivedData.count)/\(totalExpected) bytes)")
                                }
                            }
                        } else {
                            // No Content-Length header, process what we have
                            print("DEBUG: No Content-Length found, processing request with \(receivedData.count) bytes")
                            self.processHTTPRequest(data: receivedData, connection: connection)
                            return
                        }
                    }
                }
                
                if isComplete {
                    print("DEBUG: Connection marked complete")
                    if receivedData.count > 0 {
                        print("DEBUG: Processing final request with \(receivedData.count) bytes")
                        self.processHTTPRequest(data: receivedData, connection: connection)
                    } else {
                        print("DEBUG: No data received on complete connection")
                        connection.cancel()
                    }
                } else {
                    // Continue receiving more data
                    receiveData()
                }
            }
        }
        
        print("DEBUG: Starting to receive HTTP request")
        receiveData()
    }
    
    private func processHTTPRequest(data: Data, connection: NWConnection) {
        print("DEBUG: processHTTPRequest called with \(data.count) bytes")
        
        // Find the end of HTTP headers (double CRLF)
        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
        guard let headerEndRange = data.range(of: headerEndMarker) else {
            print("DEBUG: No HTTP header end marker found")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        // Extract headers (safe to convert to UTF-8)
        let headerData = data.subdata(in: data.startIndex..<headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            print("DEBUG: Failed to convert header data to UTF-8 string")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        print("DEBUG: Header string length: \(headerString.count)")
        print("DEBUG: Header preview: \(headerString.prefix(500))")
        
        // Parse request line
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            print("DEBUG: No request line found")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        print("DEBUG: Request line: \(requestLine)")
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 3 else {
            print("DEBUG: Invalid request line format")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let method = components[0]
        let path = components[1]
        print("DEBUG: Method: \(method), Path: \(path)")
        
        // Route the request
        switch (method, path) {
        case ("GET", "/"):
            print("DEBUG: Serving upload page for /")
            serveUploadPage(connection: connection, path: path)
        case ("GET", let p) where p.hasPrefix("/upload"):
            print("DEBUG: Serving upload page for \(p)")
            serveUploadPage(connection: connection, path: p)
        case ("GET", "/test"):
            print("DEBUG: Serving test page")
            sendHTTPResponse(connection: connection, statusCode: 200, body: "<html><body><h1>Test Page</h1><p>Server is working!</p></body></html>")
        case ("POST", "/upload"):
            print("DEBUG: ⬆️ POST /upload request received - Handling file upload")
            print("DEBUG: ⬆️ Request data size: \(data.count) bytes")
            handleFileUpload(requestData: data, connection: connection)
        case ("POST", "/api/folder/create"):
            print("DEBUG: 📁 POST /api/folder/create - Creating folder")
            handleCreateFolder(requestData: data, connection: connection)
        case ("POST", "/api/folder/rename"):
            print("DEBUG: ✏️ POST /api/folder/rename - Renaming folder")
            handleRenameFolder(requestData: data, connection: connection)
        case ("POST", "/api/folder/delete"):
            print("DEBUG: 🗑️ POST /api/folder/delete - Deleting folder")
            handleDeleteFolder(requestData: data, connection: connection)
        case ("POST", "/api/file/delete"):
            print("DEBUG: 🗑️ POST /api/file/delete - Deleting file")
            handleDeleteFile(requestData: data, connection: connection)
        case ("POST", "/api/bulk/delete"):
            print("DEBUG: 🗑️ POST /api/bulk/delete - Bulk deleting items")
            handleBulkDelete(requestData: data, connection: connection)
        case ("GET", let p) where p.hasPrefix("/download/file/"):
            print("DEBUG: 📥 GET /download/file/ - Downloading file")
            handleFileDownload(path: p, connection: connection)
        case ("GET", let p) where p.hasPrefix("/download/folder/"):
            print("DEBUG: 📥 GET /download/folder/ - Downloading folder as ZIP")
            handleFolderDownload(path: p, connection: connection)
        case ("GET", "/status"):
            print("DEBUG: Serving status page")
            serveStatusPage(connection: connection)
        default:
            print("DEBUG: Unknown request: \(method) \(path)")
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    // MARK: - HTTP Response Helpers
    
    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, contentType: String = "text/html; charset=utf-8", body: String) {
        let statusText = HTTPStatusText.text(for: statusCode)
        let bodyData = body.data(using: .utf8) ?? Data()
        
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        Cache-Control: no-cache\r
        \r
        \(body)
        """
        
        guard let responseData = response.data(using: .utf8) else {
            print("DEBUG: Failed to create response data")
            connection.cancel()
            return
        }
        
        print("DEBUG: Sending HTTP response: \(statusCode) \(statusText), body length: \(bodyData.count)")
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("DEBUG: Error sending response: \(error)")
            } else {
                print("DEBUG: Response sent successfully")
            }
            
            // Give a small delay before closing to ensure data is sent
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                connection.cancel()
            }
        })
    }
    
    // MARK: - Page Serving
    
    private func serveUploadPage(connection: NWConnection, path: String) {
        print("DEBUG: serveUploadPage called with path: \(path)")
        
        // Extract folder parameter from URL
        var currentFolderId: String? = nil
        if let url = URL(string: "http://localhost:8080\(path)"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            print("DEBUG: URL components parsed successfully")
            print("DEBUG: Query items: \(queryItems)")
            currentFolderId = queryItems.first(where: { $0.name == "folder" })?.value
            print("DEBUG: Extracted folder ID from URL: '\(currentFolderId ?? "nil")'")
            
            // Validate the folder ID if it exists
            if let folderIdString = currentFolderId, !folderIdString.isEmpty {
                if let folderId = UUID(uuidString: folderIdString) {
                    if let folder = CoreDataManager.shared.fetchFolder(by: folderId) {
                        print("DEBUG: Folder validation successful: \(folder.displayName)")
                    } else {
                        print("DEBUG: WARNING: Folder ID exists but folder not found in database")
                        currentFolderId = nil
                    }
                } else {
                    print("DEBUG: WARNING: Invalid folder ID format, resetting to nil")
                    currentFolderId = nil
                }
            }
        } else {
            print("DEBUG: Failed to parse URL or no query items found")
        }
        
        print("DEBUG: Final currentFolderId being passed to HTML: '\(currentFolderId ?? "nil")'")
        let html = generateUploadHTML(currentFolderId: currentFolderId, downloadEnabled: isDownloadEnabled)
        sendHTTPResponse(connection: connection, statusCode: 200, body: html)
    }
    
    private func serveStatusPage(connection: NWConnection) {
        let html = generateStatusHTML()
        sendHTTPResponse(connection: connection, statusCode: 200, body: html)
    }
    
    // MARK: - File Upload Handling
    
    private func handleFileUpload(requestData: Data, connection: NWConnection) {
        print("DEBUG: 🔄 handleFileUpload called with data size: \(requestData.count)")
        print("DEBUG: 🔄 Starting file upload processing...")
        
        // Generate unique upload ID for tracking
        let uploadId = UUID().uuidString
        activeUploads.insert(uploadId)
        
        // Start background task if app is backgrounded
        if UIApplication.shared.applicationState != .active {
            startBackgroundTask()
        }
        
        // Find the end of HTTP headers (double CRLF)
        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
        guard let headerEndRange = requestData.range(of: headerEndMarker) else {
            print("DEBUG: No HTTP header end marker found in upload request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        // Extract headers (safe to convert to UTF-8)
        let headerData = requestData.subdata(in: requestData.startIndex..<headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            print("DEBUG: Failed to convert header data to UTF-8 string")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        print("DEBUG: Upload request header string preview (first 1000 chars): \(headerString.prefix(1000))")
        
        // Parse multipart form data
        let boundary = extractBoundary(from: headerString)
        print("DEBUG: Extracted boundary: '\(boundary)'")
        guard !boundary.isEmpty else {
            print("DEBUG: No boundary found in request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "No boundary found")
            return
        }
        
        let parts = parseMultipartData(data: requestData, boundary: boundary)
        print("DEBUG: Parsed \(parts.count) multipart parts")
        
        // Extract folder ID from form data OR headers
        var targetFolder: Folder? = nil
        print("DEBUG: Starting folder ID extraction from \(parts.count) parts")
        
        // First, try to get folder ID from headers
        let headerLines = headerString.components(separatedBy: "\r\n")
        for line in headerLines {
            if line.lowercased().hasPrefix("x-folder-id:") {
                let folderIdFromHeader = line.replacingOccurrences(of: "x-folder-id:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                print("DEBUG: 🎯 Found folder ID in header: '\(folderIdFromHeader)'")
                if let folderId = UUID(uuidString: folderIdFromHeader) {
                    targetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
                    if let folder = targetFolder {
                        print("DEBUG: ✅ Target folder found from header: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
                        break
                    }
                }
            }
        }
        
        // If not found in headers, try form data
        if targetFolder == nil {
            print("DEBUG: No folder ID in headers, checking form data...")
        
        for part in parts {
            print("DEBUG: Examining part - fieldName: '\(part.fieldName ?? "nil")', hasData: \(part.data != nil), dataSize: \(part.data?.count ?? 0)")
            if let data = part.data, let stringValue = String(data: data, encoding: .utf8) {
                print("DEBUG: Part data as string: '\(stringValue)'")
            }
            
            if let fieldName = part.fieldName, fieldName == "folderId",
               let data = part.data, let folderIdString = String(data: data, encoding: .utf8),
               !folderIdString.isEmpty {
                print("DEBUG: ✅ Found folder ID in form data: '\(folderIdString)'")
                if let folderId = UUID(uuidString: folderIdString) {
                    targetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
                    if let folder = targetFolder {
                        print("DEBUG: ✅ Target folder found: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
                    } else {
                        print("DEBUG: ❌ Folder ID is valid UUID but folder not found in database")
                    }
                } else {
                    print("DEBUG: ❌ Invalid folder ID format: \(folderIdString)")
                }
                break
            } else if let fieldName = part.fieldName, fieldName == "folderId" {
                print("DEBUG: ❌ Found folderId field but data is empty or invalid")
                if let data = part.data {
                    print("DEBUG: Raw folderId data: \(data)")
                }
            }
        }
        } // End of form data checking
        
        if targetFolder == nil {
            print("DEBUG: ❌ No target folder specified, uploading to root level")
        } else {
            print("DEBUG: ✅ Will upload to folder: \(targetFolder!.displayName)")
        }
        
        var uploadedFiles: [String] = []
        var failedFiles: [String] = []
        
        for (index, part) in parts.enumerated() {
            print("DEBUG: Processing part \(index)")
            print("DEBUG: Part headers: \(part.headers)")
            print("DEBUG: Part data size: \(part.data?.count ?? 0)")
            print("DEBUG: Part filename: \(part.fileName ?? "none")")
            
            if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                do {
                    // Determine file type based on extension
                    let fileType = FileStorageManager.shared.determineFileType(from: fileName)
                    print("DEBUG: Determined file type: \(fileType) for file: \(fileName)")
                    
                    // Save file using FileStorageManager
                    let savedItem = try FileStorageManager.shared.saveFile(
                        data: fileData,
                        fileName: fileName,
                        fileType: fileType,
                        targetFolder: targetFolder
                    )
                    
                    uploadedFiles.append(fileName)
                    print("DEBUG: Successfully uploaded file: \(fileName), saved with ID: \(savedItem.id?.uuidString ?? "unknown")")
                    
                } catch {
                    print("DEBUG: Error saving uploaded file \(fileName): \(error)")
                    failedFiles.append(fileName)
                }
            } else {
                print("DEBUG: Skipping part \(index) - missing filename or data")
                print("DEBUG: fileName exists: \(part.fileName != nil)")
                print("DEBUG: fileData exists: \(part.data != nil)")
                print("DEBUG: fileData not empty: \(!(part.data?.isEmpty ?? true))")
            }
        }
        
        print("DEBUG: Total uploaded files: \(uploadedFiles.count)")
        print("DEBUG: Total failed files: \(failedFiles.count)")
        
        // Send JSON response
        let isSuccess = uploadedFiles.count > 0
        let statusCode = isSuccess ? 200 : 500
        let message = if failedFiles.count > 0 {
            "Uploaded \(uploadedFiles.count) file(s), failed \(failedFiles.count) file(s)"
        } else {
            "Successfully uploaded \(uploadedFiles.count) file(s)"
        }
        
        let response = """
        {
            "success": \(isSuccess),
            "message": "\(message)",
            "uploaded": [\(uploadedFiles.map { "\"\($0)\"" }.joined(separator: ", "))],
            "failed": [\(failedFiles.map { "\"\($0)\"" }.joined(separator: ", "))]
        }
        """
        sendHTTPResponse(connection: connection, statusCode: statusCode, contentType: "application/json", body: response)
        
        // Clean up upload tracking
        activeUploads.remove(uploadId)
        
        // End background task if no more active uploads
        if activeUploads.isEmpty {
            endBackgroundTask()
        }
        
        // Notify UI to refresh with more comprehensive notifications
        DispatchQueue.main.async {
            // Save Core Data context to ensure changes are persisted
            CoreDataManager.shared.save()
            
            // Post multiple notifications to ensure all UI components refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: CoreDataManager.shared.context)
            
            // Also trigger a general refresh notification
            NotificationCenter.default.post(name: Notification.Name("VaultDataChanged"), object: nil)
        }
    }
    
    // MARK: - Folder Management Handlers
    
    private func handleCreateFolder(requestData: Data, connection: NWConnection) {
        print("DEBUG: 📁 handleCreateFolder called")
        
        guard let jsonData = extractJSONFromRequest(requestData: requestData) else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Invalid JSON data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let folderName = json["name"] as? String,
                  !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Folder name is required")
                return
            }
            
            let parentFolderId = json["parentId"] as? String
            let parentFolder: Folder?
            
            if let parentIdString = parentFolderId, !parentIdString.isEmpty,
               let parentId = UUID(uuidString: parentIdString) {
                parentFolder = CoreDataManager.shared.fetchFolder(by: parentId)
            } else {
                parentFolder = nil
            }
            
            let newFolder = CoreDataManager.shared.createFolder(name: folderName.trimmingCharacters(in: .whitespacesAndNewlines), parent: parentFolder)
            
            if let folder = newFolder {
                print("DEBUG: ✅ Created folder: \(folder.displayName)")
            } else {
                print("DEBUG: ❌ Failed to create folder")
            }
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder created successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            }
            
        } catch {
            print("DEBUG: ❌ Error creating folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to create folder")
        }
    }
    
    private func handleRenameFolder(requestData: Data, connection: NWConnection) {
        print("DEBUG: ✏️ handleRenameFolder called")
        
        guard let jsonData = extractJSONFromRequest(requestData: requestData) else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Invalid JSON data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let folderIdString = json["folderId"] as? String,
                  let newName = json["newName"] as? String,
                  let folderId = UUID(uuidString: folderIdString),
                  !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Folder ID and new name are required")
                return
            }
            
            guard let folder = CoreDataManager.shared.fetchFolder(by: folderId) else {
                sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "Folder not found")
                return
            }
            
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            CoreDataManager.shared.updateFolder(folder, name: trimmedName)
            
            print("DEBUG: ✅ Renamed folder to: \(trimmedName)")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder renamed successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            }
            
        } catch {
            print("DEBUG: ❌ Error renaming folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to rename folder")
        }
    }
    
    private func handleDeleteFolder(requestData: Data, connection: NWConnection) {
        print("DEBUG: 🗑️ handleDeleteFolder called")
        
        guard let jsonData = extractJSONFromRequest(requestData: requestData) else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Invalid JSON data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let folderIdString = json["folderId"] as? String,
                  let folderId = UUID(uuidString: folderIdString) else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Folder ID is required")
                return
            }
            
            guard let folder = CoreDataManager.shared.fetchFolder(by: folderId) else {
                sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "Folder not found")
                return
            }
            
            // Delete the folder completely (includes file storage cleanup and Core Data cascade deletion)
            CoreDataManager.shared.deleteFolderCompletely(folder)
            
            print("DEBUG: ✅ Deleted folder and all its contents completely")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder deleted successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            }
            
        } catch {
            print("DEBUG: ❌ Error deleting folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to delete folder")
        }
    }
    
    private func handleDeleteFile(requestData: Data, connection: NWConnection) {
        print("DEBUG: 🗑️ handleDeleteFile called")
        
        guard let jsonData = extractJSONFromRequest(requestData: requestData) else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Invalid JSON data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let fileIdString = json["fileId"] as? String,
                  let fileId = UUID(uuidString: fileIdString) else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "File ID is required")
                return
            }
            
            let vaultItems = CoreDataManager.shared.fetchAllVaultItems()
            guard let vaultItem = vaultItems.first(where: { $0.id == fileId }) else {
                sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "File not found")
                return
            }
            
            try FileStorageManager.shared.deleteFile(vaultItem: vaultItem)
            
            print("DEBUG: ✅ Deleted file: \(vaultItem.fileName ?? "Unknown")")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "File deleted successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            }
            
        } catch {
            print("DEBUG: ❌ Error deleting file: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to delete file")
        }
    }
    
    private func handleBulkDelete(requestData: Data, connection: NWConnection) {
        print("DEBUG: 🗑️ handleBulkDelete called")
        
        guard let jsonData = extractJSONFromRequest(requestData: requestData) else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Invalid JSON data")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Items array is required")
                return
            }
            
            var deletedCount = 0
            var failedCount = 0
            var errors: [String] = []
            
            for item in items {
                guard let type = item["type"] as? String,
                      let idString = item["id"] as? String,
                      let id = UUID(uuidString: idString) else {
                    failedCount += 1
                    errors.append("Invalid item format")
                    continue
                }
                
                do {
                    if type == "folder" {
                        guard let folder = CoreDataManager.shared.fetchFolder(by: id) else {
                            failedCount += 1
                            errors.append("Folder not found: \(idString)")
                            continue
                        }
                        
                        // Delete the folder completely (includes file storage cleanup and Core Data cascade deletion)
                        CoreDataManager.shared.deleteFolderCompletely(folder)
                        deletedCount += 1
                        
                    } else if type == "file" {
                        let vaultItems = CoreDataManager.shared.fetchAllVaultItems()
                        guard let vaultItem = vaultItems.first(where: { $0.id == id }) else {
                            failedCount += 1
                            errors.append("File not found: \(idString)")
                            continue
                        }
                        
                        try FileStorageManager.shared.deleteFile(vaultItem: vaultItem)
                        deletedCount += 1
                        
                    } else {
                        failedCount += 1
                        errors.append("Unknown item type: \(type)")
                    }
                } catch {
                    failedCount += 1
                    errors.append("Error deleting \(type): \(error.localizedDescription)")
                }
            }
            
            let isSuccess = deletedCount > 0
            let statusCode = failedCount == 0 ? 200 : (deletedCount > 0 ? 207 : 400) // 207 = Partial success
            
            var message = "Deleted \(deletedCount) item(s)"
            if failedCount > 0 {
                message += ", failed to delete \(failedCount) item(s)"
            }
            
            var responseData: [String: Any] = [
                "deletedCount": deletedCount,
                "failedCount": failedCount
            ]
            
            if !errors.isEmpty {
                responseData["errors"] = errors
            }
            
            sendJSONResponse(connection: connection, statusCode: statusCode, success: isSuccess, message: message, data: responseData)
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            }
            
        } catch {
            print("DEBUG: ❌ Error in bulk delete: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to process bulk delete")
        }
    }
    
    // MARK: - Download Handlers
    
    private func handleFileDownload(path: String, connection: NWConnection) {
        print("DEBUG: 📥 handleFileDownload called with path: \(path)")
        
        // Check if downloads are enabled
        guard isDownloadEnabled else {
            print("DEBUG: ❌ Downloads are disabled")
            sendHTTPResponse(connection: connection, statusCode: 403, body: "Downloads are currently disabled")
            return
        }
        
        // Extract file ID from path: /download/file/{fileId}
        let pathComponents = path.components(separatedBy: "/")
        guard pathComponents.count >= 4,
              pathComponents[1] == "download",
              pathComponents[2] == "file",
              let fileId = UUID(uuidString: pathComponents[3]) else {
            print("DEBUG: ❌ Invalid file download path: \(path)")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Invalid file ID")
            return
        }
        
        // Find the file
        let vaultItems = CoreDataManager.shared.fetchAllVaultItems()
        guard let vaultItem = vaultItems.first(where: { $0.id == fileId }) else {
            print("DEBUG: ❌ File not found: \(fileId)")
            sendHTTPResponse(connection: connection, statusCode: 404, body: "File not found")
            return
        }
        
        // Get file data
        do {
            let fileData = try FileStorageManager.shared.loadFile(vaultItem: vaultItem)
            let fileName = vaultItem.fileName ?? "download"
            let fileType = vaultItem.fileType ?? "application/octet-stream"
            
            print("DEBUG: ✅ Serving file: \(fileName), size: \(fileData.count) bytes, type: \(fileType)")
            
            // Send file with proper headers
            sendFileResponse(
                connection: connection,
                data: fileData,
                fileName: fileName,
                contentType: fileType
            )
            
        } catch {
            print("DEBUG: ❌ Error reading file data: \(error)")
            sendHTTPResponse(connection: connection, statusCode: 500, body: "Error reading file")
        }
    }
    
    private func handleFolderDownload(path: String, connection: NWConnection) {
        print("DEBUG: 📥 handleFolderDownload called with path: \(path)")
        
        // Check if downloads are enabled
        guard isDownloadEnabled else {
            print("DEBUG: ❌ Downloads are disabled")
            sendHTTPResponse(connection: connection, statusCode: 403, body: "Downloads are currently disabled")
            return
        }
        
        // Extract folder ID from path: /download/folder/{folderId}
        let pathComponents = path.components(separatedBy: "/")
        guard pathComponents.count >= 4,
              pathComponents[1] == "download",
              pathComponents[2] == "folder",
              let folderId = UUID(uuidString: pathComponents[3]) else {
            print("DEBUG: ❌ Invalid folder download path: \(path)")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Invalid folder ID")
            return
        }
        
        // Find the folder
        guard let folder = CoreDataManager.shared.fetchFolder(by: folderId) else {
            print("DEBUG: ❌ Folder not found: \(folderId)")
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Folder not found")
            return
        }
        
        // Create ZIP file
        do {
            let zipData = try createZipFromFolder(folder)
            let zipFileName = "\(folder.displayName).zip"
            
            print("DEBUG: ✅ Created ZIP for folder: \(folder.displayName), size: \(zipData.count) bytes")
            
            // Send ZIP file
            sendFileResponse(
                connection: connection,
                data: zipData,
                fileName: zipFileName,
                contentType: "application/zip"
            )
            
        } catch {
            print("DEBUG: ❌ Error creating ZIP: \(error)")
            sendHTTPResponse(connection: connection, statusCode: 500, body: "Error creating ZIP file")
        }
    }
    
    private func sendFileResponse(connection: NWConnection, data: Data, fileName: String, contentType: String) {
        let statusText = HTTPStatusText.text(for: 200)
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
        
        let response = """
        HTTP/1.1 200 \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(data.count)\r
        Content-Disposition: attachment; filename="\(encodedFileName)"\r
        Cache-Control: no-cache\r
        Connection: close\r
        \r

        """
        
        guard let responseHeaderData = response.data(using: .utf8) else {
            print("DEBUG: Failed to create response header data")
            connection.cancel()
            return
        }
        
        print("DEBUG: Sending file response: \(fileName), size: \(data.count) bytes")
        
        // Send headers first
        connection.send(content: responseHeaderData, completion: .contentProcessed { error in
            if let error = error {
                print("DEBUG: Error sending file headers: \(error)")
                connection.cancel()
                return
            }
            
            // Then send file data
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("DEBUG: Error sending file data: \(error)")
                } else {
                    print("DEBUG: File sent successfully: \(fileName)")
                }
                
                // Close connection after sending
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    connection.cancel()
                }
            })
        })
    }
    
    private func createZipFromFolder(_ folder: Folder) throws -> Data {
        // Create a temporary directory for the ZIP operation
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create folder structure and copy files
        try createFolderStructure(folder: folder, in: tempDir, relativePath: "")
        
        // Create ZIP file
        let zipFileURL = tempDir.appendingPathComponent("\(folder.displayName).zip")
        try createZipFile(from: tempDir, to: zipFileURL, excluding: [zipFileURL.lastPathComponent])
        
        // Read ZIP data
        return try Data(contentsOf: zipFileURL)
    }
    
    private func createFolderStructure(folder: Folder, in baseURL: URL, relativePath: String) throws {
        let folderPath = relativePath.isEmpty ? folder.displayName : "\(relativePath)/\(folder.displayName)"
        let folderURL = baseURL.appendingPathComponent(folderPath)
        
        // Create folder directory
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        // Copy all files in this folder
        for item in folder.itemsArray {
            let fileData = try FileStorageManager.shared.loadFile(vaultItem: item)
            let fileName = item.fileName ?? "unknown"
            let fileURL = folderURL.appendingPathComponent(fileName)
            try fileData.write(to: fileURL)
        }
        
        // Recursively handle subfolders
        for subfolder in folder.subfoldersArray {
            try createFolderStructure(folder: subfolder, in: baseURL, relativePath: folderPath)
        }
    }
    
    private func createZipFile(from sourceURL: URL, to destinationURL: URL, excluding excludeFiles: [String] = []) throws {
        // Use the built-in Archive functionality
        let fileManager = FileManager.default
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: sourceURL, options: [.forUploading], error: &error) { (zipURL) in
            do {
                // Copy the automatically created zip to our destination
                if fileManager.fileExists(atPath: zipURL.path) {
                    try fileManager.copyItem(at: zipURL, to: destinationURL)
                } else {
                    // Fallback: create a simple archive by manually writing ZIP structure
                    // For now, just throw an error if the automatic zip fails
                    throw FileStorageError.importFailed
                }
            } catch {
                print("DEBUG: Error in ZIP creation: \(error)")
            }
        }
        
        if let error = error {
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractJSONFromRequest(requestData: Data) -> Data? {
        // Find the end of HTTP headers (double CRLF)
        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
        guard let headerEndRange = requestData.range(of: headerEndMarker) else {
            print("DEBUG: No HTTP header end marker found")
            return nil
        }
        
        // Extract body (JSON data)
        let bodyData = requestData.subdata(in: headerEndRange.upperBound..<requestData.endIndex)
        return bodyData.isEmpty ? nil : bodyData
    }
    
    private func sendJSONResponse(connection: NWConnection, statusCode: Int, success: Bool, message: String, data: [String: Any]? = nil) {
        var responseData: [String: Any] = [
            "success": success,
            "message": message
        ]
        
        if let additionalData = data {
            responseData.merge(additionalData) { _, new in new }
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            sendHTTPResponse(connection: connection, statusCode: statusCode, contentType: "application/json", body: jsonString)
        } catch {
            print("DEBUG: Error creating JSON response: \(error)")
            sendHTTPResponse(connection: connection, statusCode: 500, contentType: "application/json", body: "{\"success\": false, \"message\": \"Internal server error\"}")
        }
    }
    

    
    // MARK: - Utility Methods
    
    private func updateServerURL() {
        if let localIP = getLocalIPAddress() {
            serverURL = "http://\(localIP):\(serverPort)"
        }
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" || name == "en1" { // WiFi interfaces
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    // MARK: - Download Setting Management
    
    private func loadDownloadSetting() {
        let defaults = UserDefaults.standard
        isDownloadEnabled = defaults.bool(forKey: downloadEnabledKey)
        print("DEBUG: Loaded download setting: \(isDownloadEnabled)")
    }
    
    private func saveDownloadSetting() {
        let defaults = UserDefaults.standard
        defaults.set(isDownloadEnabled, forKey: downloadEnabledKey)
        print("DEBUG: Saved download setting: \(isDownloadEnabled)")
    }
    
    func setDownloadEnabled(_ enabled: Bool) {
        isDownloadEnabled = enabled
        saveDownloadSetting()
    }

}

// MARK: - HTTP Status Codes

struct HTTPStatusText {
    static func text(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Multipart Data Parsing

struct MultipartPart {
    let headers: [String: String]
    let data: Data?
    
    var fieldName: String? {
        guard let contentDisposition = headers["content-disposition"] else { return nil }
        
        // Extract field name from Content-Disposition header
        let components = contentDisposition.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name=") {
                let fieldName = trimmed.replacingOccurrences(of: "name=", with: "")
                return fieldName.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }
    
    var fileName: String? {
        guard let contentDisposition = headers["content-disposition"] else { return nil }
        
        // Extract filename from Content-Disposition header
        let components = contentDisposition.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("filename=") {
                let filename = trimmed.replacingOccurrences(of: "filename=", with: "")
                return filename.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }
}

extension WebServerManager {
    
    private func extractBoundary(from requestString: String) -> String {
        let lines = requestString.components(separatedBy: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("content-type:") && line.contains("boundary=") {
                let components = line.components(separatedBy: "boundary=")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
    
    private func parseMultipartData(data: Data, boundary: String) -> [MultipartPart] {
        print("DEBUG: parseMultipartData called with boundary: '\(boundary)', data size: \(data.count)")
        
        let boundaryData = "--\(boundary)".data(using: .utf8)!
        let endBoundaryData = "--\(boundary)--".data(using: .utf8)!
        
        print("DEBUG: Looking for boundary data: \(boundaryData.count) bytes")
        print("DEBUG: Boundary string: '--\(boundary)'")
        print("DEBUG: End boundary string: '--\(boundary)--'")
        
        var parts: [MultipartPart] = []
        
        // Find all boundary positions first
        var boundaryPositions: [Range<Data.Index>] = []
        var tempSearchRange = data.startIndex..<data.endIndex
        
        // First, find all regular boundaries
        while let boundaryRange = data.range(of: boundaryData, in: tempSearchRange) {
            boundaryPositions.append(boundaryRange)
            tempSearchRange = boundaryRange.upperBound..<data.endIndex
        }
        
        // Then, find the end boundary (but don't add it if it's too close to the last regular boundary)
        if let endBoundaryRange = data.range(of: endBoundaryData, in: data.startIndex..<data.endIndex) {
            // Check if this end boundary is different from the last regular boundary
            if let lastBoundary = boundaryPositions.last {
                if endBoundaryRange.lowerBound > lastBoundary.upperBound {
                    boundaryPositions.append(endBoundaryRange)
                } else {
                    print("DEBUG: End boundary overlaps with last regular boundary, using end boundary instead")
                    boundaryPositions[boundaryPositions.count - 1] = endBoundaryRange
                }
            } else {
                boundaryPositions.append(endBoundaryRange)
            }
        }
        
        // Sort boundaries by position to ensure proper order
        boundaryPositions.sort { $0.lowerBound < $1.lowerBound }
        
        print("DEBUG: Found \(boundaryPositions.count) total boundaries")
        
        // Debug: Print all boundary positions
        for (index, boundary) in boundaryPositions.enumerated() {
            print("DEBUG: Boundary \(index): \(boundary)")
        }
        
        // Process each part between boundaries
        for i in 0..<boundaryPositions.count - 1 {
            let currentBoundary = boundaryPositions[i]
            let nextBoundary = boundaryPositions[i + 1]
            
            print("DEBUG: Processing part \(i) between boundaries at \(currentBoundary) and \(nextBoundary)")
            
            // Validate that we have a valid range
            if currentBoundary.upperBound >= nextBoundary.lowerBound {
                print("DEBUG: ❌ Invalid range detected: currentBoundary.upperBound (\(currentBoundary.upperBound)) >= nextBoundary.lowerBound (\(nextBoundary.lowerBound))")
                print("DEBUG: Skipping part \(i) due to invalid range")
                continue
            }
            
            let partData = data.subdata(in: currentBoundary.upperBound..<nextBoundary.lowerBound)
            print("DEBUG: Part \(i) raw data size: \(partData.count)")
            
            if let part = parseMultipartPart(data: partData) {
                parts.append(part)
                print("DEBUG: ✅ Successfully parsed part \(i + 1), fieldName: '\(part.fieldName ?? "nil")', filename: '\(part.fileName ?? "nil")', dataSize: \(part.data?.count ?? 0)")
            } else {
                print("DEBUG: ❌ Failed to parse part \(i)")
            }
        }
        
        print("DEBUG: parseMultipartData completed, found \(parts.count) parts")
        return parts
    }
    
    private func parseMultipartPart(data: Data) -> MultipartPart? {
        print("DEBUG: parseMultipartPart called with data size: \(data.count)")
        
        // Show first 200 bytes of raw data for debugging
        let previewData = data.prefix(200)
        if let previewString = String(data: previewData, encoding: .utf8) {
            print("DEBUG: Part data preview: \(previewString.replacingOccurrences(of: "\r\n", with: "\\r\\n"))")
        }
        
        // Find the double CRLF that separates headers from body
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        
        guard let separatorRange = data.range(of: headerBodySeparator) else { 
            print("DEBUG: No header-body separator found")
            // Try single CRLF as fallback
            let singleCRLF = "\r\n".data(using: .utf8)!
            if let singleSeparatorRange = data.range(of: singleCRLF) {
                print("DEBUG: Found single CRLF at position \(singleSeparatorRange)")
                let headerData = data.subdata(in: data.startIndex..<singleSeparatorRange.lowerBound)
                let bodyData = data.subdata(in: singleSeparatorRange.upperBound..<data.endIndex)
                
                if let headerString = String(data: headerData, encoding: .utf8) {
                    print("DEBUG: Single CRLF header: \(headerString)")
                    print("DEBUG: Body data size after single CRLF: \(bodyData.count)")
                }
            }
            return nil 
        }
        
        let headerData = data.subdata(in: data.startIndex..<separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound..<data.endIndex)
        
        print("DEBUG: Header data size: \(headerData.count), Body data size: \(bodyData.count)")
        
        // Parse headers as string
        guard let headerString = String(data: headerData, encoding: .utf8) else { 
            print("DEBUG: Failed to convert header data to string")
            return nil 
        }
        
        print("DEBUG: Header string: \(headerString)")
        
        var headers: [String: String] = [:]
        let headerLines = headerString.components(separatedBy: "\r\n")
        
        for line in headerLines {
            if line.contains(":") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    headers[key] = value
                }
            }
        }
        
        print("DEBUG: Parsed headers: \(headers)")
        
        // Keep body as binary data
        let part = MultipartPart(headers: headers, data: bodyData)
        print("DEBUG: Created part with filename: \(part.fileName ?? "none"), fieldName: \(part.fieldName ?? "none")")
        return part
    }
} 