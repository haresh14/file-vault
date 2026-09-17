//
//  WebServerManager.swift
//  Keepshire
//
//  Created on 11/07/25.
//

import Foundation
import Network
import CoreData
import SwiftUI
import UIKit

class WebServerManager: ObservableObject, WebServerManaging {
    static let shared = WebServerManager()
    
    @Published var isRunning = false
    @Published var serverURL: String = ""
    /// SHA-256 of the session TLS certificate, shown so a person can check the browser warning.
    @Published var certificateFingerprint: String = ""
    @Published var connectedDevices: [String] = []
    /// Short code the user types in the browser to pair a device with this session.
    @Published var pairingCode: String = ""
    /// Set while downloads are allowed; nil once the export session expires.
    @Published var exportSessionExpiresAt: Date?

    let accessControl = WebAccessControl()
    private(set) var tlsIdentity: LANWebTLSIdentity?

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let serverPort = 8080
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var activeUploads: Set<String> = []
    private var exportSessionTimer: Timer?
    /// Mirrors `UIApplication.isProtectedDataAvailable`, which connection handlers cannot
    /// read directly because they run off the main thread.
    private let protectedDataLock = NSLock()
    private var protectedDataAvailable = true

    private init() {
        // UIApplication reports protected data as unavailable until the app finishes
        // launching, and this singleton is built before that. Start optimistic and let
        // the lifecycle refreshes below correct it.
        setupAppLifecycleObservers()
    }

    private var isProtectedDataAvailable: Bool {
        protectedDataLock.lock()
        defer { protectedDataLock.unlock() }
        return protectedDataAvailable
    }
    
    func startServer() {
        VaultLog.debug("DEBUG: startServer called")

        refreshProtectedDataAvailability()
        accessControl.rotateToken()
        let code = accessControl.pairingCode ?? ""
        let lanIP = getLocalIPAddress()
        var addresses = ["127.0.0.1"]
        if let lanIP, !addresses.contains(lanIP) { addresses.append(lanIP) }

        let identity: LANWebTLSIdentity
        do {
            identity = try LANWebTLSIdentity.make(ipAddresses: addresses)
        } catch {
            VaultLog.debug("DEBUG: Failed to create TLS identity: \(error)")
            accessControl.invalidate()
            return
        }
        tlsIdentity?.removeFromKeychain()
        tlsIdentity = identity

        DispatchQueue.main.async {
            self.pairingCode = code
            self.certificateFingerprint = identity.fingerprint
        }

        guard let port = NWEndpoint.Port(rawValue: UInt16(serverPort)) else {
            VaultLog.debug("DEBUG: Invalid port: \(serverPort)")
            identity.removeFromKeychain()
            tlsIdentity = nil
            return
        }

        let parameters = identity.listenerParameters()

        do {
            let listener = try NWListener(using: parameters, on: port)
            VaultLog.debug("DEBUG: Listener created successfully")
            
            listener.newConnectionHandler = { [weak self] (connection: NWConnection) in
                VaultLog.debug("DEBUG: newConnectionHandler called")
                self?.handleNewConnection(connection)
            }
            
            listener.stateUpdateHandler = { [weak self] (state: NWListener.State) in
                VaultLog.debug("DEBUG: Listener state changed to: \(state)")
                switch state {
                case .ready:
                    VaultLog.debug("DEBUG: Server started successfully on port \(self?.serverPort ?? 0)")
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.updateServerURL()
                    }
                case .failed(let error):
                    VaultLog.debug("DEBUG: Server failed to start: \(error)")
                    self?.tlsIdentity?.removeFromKeychain()
                    self?.tlsIdentity = nil
                    DispatchQueue.main.async {
                        self?.isRunning = false
                        self?.certificateFingerprint = ""
                    }
                case .cancelled:
                    VaultLog.debug("DEBUG: Server cancelled")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                default:
                    VaultLog.debug("DEBUG: Server state: \(state)")
                }
            }
            
            self.listener = listener
            listener.start(queue: DispatchQueue.global(qos: .userInitiated))
            VaultLog.debug("DEBUG: Listener started")
        } catch {
            VaultLog.debug("DEBUG: Failed to create listener: \(error)")
            identity.removeFromKeychain()
            tlsIdentity = nil
            DispatchQueue.main.async { self.certificateFingerprint = "" }
        }
    }
    
    func stopServer() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        endBackgroundTask()
        accessControl.invalidate()
        tlsIdentity?.removeFromKeychain()
        tlsIdentity = nil

        DispatchQueue.main.async {
            self.isRunning = false
            self.serverURL = ""
            self.certificateFingerprint = ""
            self.pairingCode = ""
            self.exportSessionExpiresAt = nil
            self.exportSessionTimer?.invalidate()
            self.exportSessionTimer = nil
            self.connectedDevices.removeAll()
        }
        
        VaultLog.debug("DEBUG: Web server stopped")
    }

    // MARK: - Export Session

    /// Opens the download window. Callers gate this behind biometric confirmation.
    func beginExportSession(duration: TimeInterval = WebAccessControl.exportSessionLifetime) {
        let expiry = accessControl.beginExportSession(duration: duration)
        DispatchQueue.main.async {
            self.exportSessionExpiresAt = expiry
            self.exportSessionTimer?.invalidate()
            self.exportSessionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.endExportSession()
            }
        }
    }

    func endExportSession() {
        accessControl.endExportSession()
        DispatchQueue.main.async {
            self.exportSessionExpiresAt = nil
            self.exportSessionTimer?.invalidate()
            self.exportSessionTimer = nil
        }
    }

    var isExportSessionActive: Bool {
        accessControl.isExportSessionActive()
    }
    
    // MARK: - Background Task Support

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataWillBecomeUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataDidBecomeAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }

    @objc private func protectedDataWillBecomeUnavailable() {
        setProtectedDataAvailable(false)
        // Downloads must not stay armed while the phone is locked.
        endExportSession()
    }

    @objc private func protectedDataDidBecomeAvailable() {
        setProtectedDataAvailable(true)
    }

    /// Reads the live value on the main thread. The cached copy exists because connection
    /// handlers run off the main thread and cannot touch UIApplication.
    private func refreshProtectedDataAvailability() {
        setProtectedDataAvailable(UIApplication.shared.isProtectedDataAvailable)
    }

    private func setProtectedDataAvailable(_ available: Bool) {
        protectedDataLock.lock()
        protectedDataAvailable = available
        protectedDataLock.unlock()
    }
    
    @objc private func appWillEnterBackground() {
        // Downloads stay tied to a user who is looking at the app.
        endExportSession()
        if isRunning && !activeUploads.isEmpty {
            startBackgroundTask()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // Background processing is no longer needed when app is active
        endBackgroundTask()
        refreshProtectedDataAvailability()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "WebServerUpload") {
            // This block is called when the background time is about to expire
            VaultLog.debug("DEBUG: Background task time expiring, ending gracefully")
            self.endBackgroundTask()
        }
        
        VaultLog.debug("DEBUG: Started background task for web server uploads")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
            VaultLog.debug("DEBUG: Ended background task")
        }
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        VaultLog.debug("DEBUG: New connection added, total connections: \(connections.count)")
        
        connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            VaultLog.debug("DEBUG: Connection state changed to: \(state)")
            switch state {
            case .ready:
                VaultLog.debug("DEBUG: Connection ready - starting to receive HTTP request")
                self?.receiveHTTPRequest(on: connection)
            case .failed(let error):
                VaultLog.debug("DEBUG: Connection failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                VaultLog.debug("DEBUG: Connection cancelled")
                self?.removeConnection(connection)
            case .waiting(let error):
                VaultLog.debug("DEBUG: Connection waiting: \(error)")
            case .preparing:
                VaultLog.debug("DEBUG: Connection preparing")
            case .setup:
                VaultLog.debug("DEBUG: Connection setup")
            @unknown default:
                VaultLog.debug("DEBUG: Connection unknown state: \(state)")
            }
        }
        
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        VaultLog.debug("DEBUG: Connection started")
    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
    }
    
    // MARK: - HTTP Request Handling
    
    private func receiveHTTPRequest(on connection: NWConnection) {
        var receivedData = Data()
        // No size limit - handle any file size
        var expectedContentLength: Int?
        var headersComplete = false
        
        func receiveData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                
                if let error = error {
                    VaultLog.debug("DEBUG: Error receiving data: \(error)")
                    connection.cancel()
                    return
                }
                
                if let data = data, !data.isEmpty {
                    receivedData.append(data)
                    VaultLog.debug("DEBUG: Received \(data.count) bytes, total: \(receivedData.count)")
                    
                    // No size limit check - we can handle any file size
                    
                    // Check if we have complete headers (look for double CRLF in binary data)
                    if !headersComplete {
                        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
                        if let headerEndRange = receivedData.range(of: headerEndMarker) {
                            headersComplete = true
                            VaultLog.debug("DEBUG: Headers complete, parsing Content-Length")
                            
                            // Extract headers only (safe to convert to UTF-8)
                            let headerData = receivedData.subdata(in: receivedData.startIndex..<headerEndRange.lowerBound)
                            if let headerString = String(data: headerData, encoding: .utf8) {
                                let headerLines = headerString.components(separatedBy: "\r\n")
                                
                                for line in headerLines {
                                    if line.lowercased().hasPrefix("content-length:") {
                                        let lengthString = line.replacingOccurrences(of: "content-length:", with: "", options: .caseInsensitive)
                                            .trimmingCharacters(in: .whitespaces)
                                        expectedContentLength = Int(lengthString)
                                        VaultLog.debug("DEBUG: Expected Content-Length: \(expectedContentLength ?? 0)")
                                        break
                                    }
                                }
                                
                                // Calculate how much data we need
                                let headerEndIndex = receivedData.startIndex.distance(to: headerEndRange.upperBound)
                                let totalExpected = headerEndIndex + (expectedContentLength ?? 0)
                                VaultLog.debug("DEBUG: Headers end at \(headerEndIndex), total expected: \(totalExpected)")
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
                                    VaultLog.debug("DEBUG: Complete request received (\(receivedData.count)/\(totalExpected) bytes), processing")
                                    self.processHTTPRequest(data: receivedData, connection: connection)
                                    return
                                } else {
                                    VaultLog.debug("DEBUG: Still receiving data (\(receivedData.count)/\(totalExpected) bytes)")
                                }
                            }
                        } else {
                            // No Content-Length header, process what we have
                            VaultLog.debug("DEBUG: No Content-Length found, processing request with \(receivedData.count) bytes")
                            self.processHTTPRequest(data: receivedData, connection: connection)
                            return
                        }
                    }
                }
                
                if isComplete {
                    VaultLog.debug("DEBUG: Connection marked complete")
                    if receivedData.count > 0 {
                        VaultLog.debug("DEBUG: Processing final request with \(receivedData.count) bytes")
                        self.processHTTPRequest(data: receivedData, connection: connection)
                    } else {
                        VaultLog.debug("DEBUG: No data received on complete connection")
                        connection.cancel()
                    }
                } else {
                    // Continue receiving more data
                    receiveData()
                }
            }
        }
        
        VaultLog.debug("DEBUG: Starting to receive HTTP request")
        receiveData()
    }
    
    private func processHTTPRequest(data: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: processHTTPRequest called with \(data.count) bytes")
        guard let request = WebHTTPRequest.parse(data) else {
            VaultLog.debug("DEBUG: Invalid HTTP request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        VaultLog.debug("DEBUG: Method: \(request.method), Path: \(request.path)")
        let route = WebRequestRouter.route(request, fakeLoginActive: LoginStateManager.shared.shouldShowEmptyVault)

        switch accessControl.authorize(request, route: route) {
        case .allow:
            break
        case .unauthorized:
            // A browser that typed the address by hand gets the pairing form instead of a bare 401.
            if route == .uploadPage {
                servePairingPage(connection: connection, message: nil)
            } else {
                sendPreparedResponse(connection: connection, response: WebRequestRouter.unauthorizedResponse)
            }
            return
        case .exportSessionRequired:
            sendPreparedResponse(connection: connection, response: WebRequestRouter.exportSessionResponse)
            return
        }

        if route.needsUnlockedDevice, !isProtectedDataAvailable {
            sendDeviceLockedResponse(route: route, connection: connection)
            return
        }

        switch route {
        case .fakeLoginForbidden:
            sendPreparedResponse(connection: connection, response: WebRequestRouter.fakeLoginResponse)
        case .pair:
            handlePairing(request: request, connection: connection)
        case .issueDownloadTicket:
            handleDownloadTicket(request: request, connection: connection)
        case .ticketDownload:
            handleTicketDownload(request: request, connection: connection)
        case .sessionState:
            sendJSONResponse(
                connection: connection,
                statusCode: 200,
                success: true,
                message: "ok",
                data: ["exportActive": accessControl.isExportSessionActive()]
            )
        case .uploadPage:
            serveUploadPage(connection: connection, path: request.path)
        case .testPage:
            sendHTTPResponse(connection: connection, statusCode: 200, body: "<html><body><h1>Test Page</h1><p>Server is working!</p></body></html>")
        case .upload:
            handleFileUpload(requestData: data, connection: connection)
        case .streamUpload:
            handleStreamingFileUpload(requestData: data, connection: connection)
        case .createFolder:
            handleCreateFolder(requestData: data, connection: connection)
        case .renameFolder:
            handleRenameFolder(requestData: data, connection: connection)
        case .deleteFolder:
            handleDeleteFolder(requestData: data, connection: connection)
        case .deleteFile:
            handleDeleteFile(requestData: data, connection: connection)
        case .bulkDelete:
            handleBulkDelete(requestData: data, connection: connection)
        case .status:
            serveStatusPage(connection: connection)
        case .notFound:
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    // MARK: - HTTP Response Helpers

    private func sendDeviceLockedResponse(route: WebRequestRoute, connection: NWConnection) {
        if route.expectsJSON {
            sendJSONResponse(
                connection: connection,
                statusCode: 503,
                success: false,
                message: WebRequestRouter.deviceLockedMessage
            )
        } else {
            sendPreparedResponse(connection: connection, response: WebRequestRouter.deviceLockedResponse)
        }
    }

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, contentType: String = "text/html; charset=utf-8", body: String) {
        sendPreparedResponse(
            connection: connection,
            response: WebHTTPResponse.text(statusCode: statusCode, contentType: contentType, body: body)
        )
    }

    private func sendPreparedResponse(connection: NWConnection, response: WebHTTPResponse) {
        connection.send(content: response.serializedData, completion: .contentProcessed { error in
            if let error = error {
                VaultLog.debug("DEBUG: Error sending response: \(error)")
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                connection.cancel()
            }
        })
    }
    
    // MARK: - Page Serving
    
    private func serveUploadPage(connection: NWConnection, path: String) {
        VaultLog.debug("DEBUG: serveUploadPage called with path: \(path)")
        
        // Extract folder parameter from URL
        var currentFolderId: String? = nil
        if let url = URL(string: "http://localhost:8080\(path)"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            VaultLog.debug("DEBUG: URL components parsed successfully")
            VaultLog.debug("DEBUG: Query items: \(queryItems)")
            currentFolderId = queryItems.first(where: { $0.name == "folder" })?.value
            VaultLog.debug("DEBUG: Extracted folder ID from URL: '\(currentFolderId ?? "nil")'")
            
            // Validate the folder ID if it exists
            if let folderIdString = currentFolderId, !folderIdString.isEmpty {
                if let folderId = UUID(uuidString: folderIdString) {
                    if let folder = CoreDataManager.shared.fetchFolder(by: folderId) {
                        VaultLog.debug("DEBUG: Folder validation successful: \(folder.displayName)")
                    } else {
                        VaultLog.debug("DEBUG: WARNING: Folder ID exists but folder not found in database")
                        currentFolderId = nil
                    }
                } else {
                    VaultLog.debug("DEBUG: WARNING: Invalid folder ID format, resetting to nil")
                    currentFolderId = nil
                }
            }
        } else {
            VaultLog.debug("DEBUG: Failed to parse URL or no query items found")
        }
        
        VaultLog.debug("DEBUG: Final currentFolderId being passed to HTML: '\(currentFolderId ?? "nil")'")
        let token = accessControl.currentToken ?? ""
        let html = generateUploadHTML(
            currentFolderId: currentFolderId,
            downloadEnabled: accessControl.isExportSessionActive(),
            sessionToken: token
        )
        // Refresh the cookie so links opened from the app keep working as the user navigates.
        sendPreparedResponse(
            connection: connection,
            response: WebHTTPResponse.text(
                statusCode: 200,
                body: html,
                extraHeaders: [
                    "Set-Cookie": WebAccessControl.sessionCookieHeader(token: token)
                ]
            )
        )
    }
    
    private func serveStatusPage(connection: NWConnection) {
        let html = generateStatusHTML()
        sendHTTPResponse(connection: connection, statusCode: 200, body: html)
    }
    
    // MARK: - File Upload Handling
    
    private func handleFileUpload(requestData: Data, connection: NWConnection) {
        // For very large files, we should use streaming instead of loading everything into memory
        // Check the content length to decide whether to use regular or streaming upload
        let contentLength = extractContentLength(from: requestData)
        
        // If file is larger than 100MB, use streaming upload with background support
        if contentLength > 100 * 1024 * 1024 {
            handleLargeFileUpload(requestData: requestData, connection: connection)
            return
        }
        
        // Continue with regular upload for smaller files
        VaultLog.debug("DEBUG: 🔄 handleFileUpload called with data size: \(requestData.count)")
        VaultLog.debug("DEBUG: 🔄 Starting file upload processing...")
        
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
            VaultLog.debug("DEBUG: No HTTP header end marker found in upload request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        // Extract headers (safe to convert to UTF-8)
        let headerData = requestData.subdata(in: requestData.startIndex..<headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            VaultLog.debug("DEBUG: Failed to convert header data to UTF-8 string")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        VaultLog.debug("DEBUG: Upload request header string preview (first 1000 chars): \(headerString.prefix(1000))")
        
        // Parse multipart form data
        let boundary = extractBoundary(from: headerString)
        VaultLog.debug("DEBUG: Extracted boundary: '\(boundary)'")
        guard !boundary.isEmpty else {
            VaultLog.debug("DEBUG: No boundary found in request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "No boundary found")
            return
        }
        
        let parts = parseMultipartData(data: requestData, boundary: boundary)
        VaultLog.debug("DEBUG: Parsed \(parts.count) multipart parts")
        
        // Extract folder ID from form data OR headers
        var targetFolder: Folder? = nil
        VaultLog.debug("DEBUG: Starting folder ID extraction from \(parts.count) parts")
        
        // First, try to get folder ID from headers
        let headerLines = headerString.components(separatedBy: "\r\n")
        for line in headerLines {
            if line.lowercased().hasPrefix("x-folder-id:") {
                let folderIdFromHeader = line.replacingOccurrences(of: "x-folder-id:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                VaultLog.debug("DEBUG: 🎯 Found folder ID in header: '\(folderIdFromHeader)'")
                if let folderId = UUID(uuidString: folderIdFromHeader) {
                    targetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
                    if let folder = targetFolder {
                        VaultLog.debug("DEBUG: ✅ Target folder found from header: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
                        break
                    }
                }
            }
        }
        
        // If not found in headers, try form data
        if targetFolder == nil {
            VaultLog.debug("DEBUG: No folder ID in headers, checking form data...")
        
        for part in parts {
            VaultLog.debug("DEBUG: Examining part - fieldName: '\(part.fieldName ?? "nil")', hasData: \(part.data != nil), dataSize: \(part.data?.count ?? 0)")
            if let data = part.data, let stringValue = String(data: data, encoding: .utf8) {
                VaultLog.debug("DEBUG: Part data as string: '\(stringValue)'")
            }
            
            if let fieldName = part.fieldName, fieldName == "folderId",
               let data = part.data, let folderIdString = String(data: data, encoding: .utf8),
               !folderIdString.isEmpty {
                let trimmedFolderId = folderIdString.trimmingCharacters(in: .whitespacesAndNewlines)
                VaultLog.debug("DEBUG: ✅ Found folder ID in form data: '\(trimmedFolderId)'")
                if let folderId = UUID(uuidString: trimmedFolderId) {
                    targetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
                    if let folder = targetFolder {
                        VaultLog.debug("DEBUG: ✅ Target folder found: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
                    } else {
                        VaultLog.debug("DEBUG: ❌ Folder ID is valid UUID but folder not found in database")
                    }
                } else {
                    VaultLog.debug("DEBUG: ❌ Invalid folder ID format: \(trimmedFolderId)")
                }
                break
            } else if let fieldName = part.fieldName, fieldName == "folderId" {
                VaultLog.debug("DEBUG: ❌ Found folderId field but data is empty or invalid")
                if let data = part.data {
                    VaultLog.debug("DEBUG: Raw folderId data: \(data)")
                }
            }
        }
        } // End of form data checking
        
        if targetFolder == nil {
            VaultLog.debug("DEBUG: ❌ No target folder specified, uploading to root level")
            VaultLog.debug("DEBUG: Headers checked, Form data checked - no folderId found anywhere")
        } else {
            VaultLog.debug("DEBUG: ✅ Will upload to folder: \(targetFolder!.displayName) (ID: \(targetFolder!.id?.uuidString ?? "nil"))")
        }
        
        // Always use "whole" folder upload mode (folders preserve their structure)
        let folderUploadMode = "whole"
        
        // Extract file paths for folder structure preservation
        var filePaths: [String] = []
        for part in parts {
            if let fieldName = part.fieldName, fieldName == "filePaths",
               let data = part.data, let filePath = String(data: data, encoding: .utf8) {
                filePaths.append(filePath.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        VaultLog.debug("DEBUG: Extracted \(filePaths.count) file paths")
        
        // Count actual file parts for notification
        let fileParts = parts.filter { $0.fileName != nil && $0.data != nil && !$0.data!.isEmpty }
        let totalFiles = fileParts.count
        let isLargeUpload = totalFiles > 50
        
        VaultLog.debug("DEBUG: Starting regular file upload with \(totalFiles) files (large upload: \(isLargeUpload))")
        
        // Start upload progress tracking
        NotificationManager.shared.startUploadProgress(uploadId: uploadId, totalFiles: totalFiles)
        
        var uploadedFiles: [String] = []
        var failedFiles: [String] = []
        var filePartIndex = 0
        
        // For large uploads, use batch processing
        if isLargeUpload {
            do {
                                        try processBatchUpload(
                            parts: parts,
                            filePaths: filePaths,
                            targetFolder: targetFolder,
                            uploadId: uploadId,
                            uploadedFiles: &uploadedFiles,
                            failedFiles: &failedFiles,
                            filePartIndex: &filePartIndex,
                            folderUploadMode: folderUploadMode
                        )
            } catch {
                VaultLog.debug("DEBUG: Error in batch upload processing: \(error)")
                // Fall back to sequential processing for this upload
                for (_, part) in parts.enumerated() {
                    if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                        failedFiles.append(fileName)
                        filePartIndex += 1
                    }
                }
            }
        } else {
            // Use original processing for small uploads
            for (index, part) in parts.enumerated() {
                if !isLargeUpload {
                    VaultLog.debug("DEBUG: Processing part \(index)")
                    VaultLog.debug("DEBUG: Part filename: \(part.fileName ?? "none")")
                }
                
                if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                    do {
                        // Get the corresponding file path
                        let filePath = filePartIndex < filePaths.count ? filePaths[filePartIndex] : ""
                        
                        // Determine target folder based on file path
                        let actualTargetFolder = try createFolderStructureForFile(
                            filePath: filePath,
                            baseFolder: targetFolder,
                            folderUploadMode: folderUploadMode
                        )
                        
                        // Extract just the filename (without path) for FileStorageManager
                        let actualFileName = URL(fileURLWithPath: fileName).lastPathComponent
                        
                        // Determine file type based on extension
                        let fileType = FileStorageManager.shared.determineFileType(from: actualFileName)
                        
                        // Save file using FileStorageManager
                        _ = try FileStorageManager.shared.saveFile(
                            data: fileData,
                            fileName: actualFileName,
                            fileType: fileType,
                            targetFolder: actualTargetFolder
                        )
                        
                        uploadedFiles.append(fileName)
                        if !isLargeUpload {
                            VaultLog.debug("DEBUG: Successfully uploaded file: \(fileName)")
                        }
                        
                        filePartIndex += 1
                        
                        // Update progress notification less frequently for large uploads
                        if !isLargeUpload || filePartIndex % 50 == 0 {
                            NotificationManager.shared.updateUploadProgress(
                                uploadId: uploadId,
                                processedFiles: filePartIndex,
                                uploadedFiles: uploadedFiles.count,
                                failedFiles: failedFiles.count
                            )
                        }
                        
                    } catch FileStorageError.duplicateFile {
                        if !isLargeUpload {
                            VaultLog.debug("DEBUG: Skipped duplicate file: \(fileName)")
                        }
                        filePartIndex += 1
                        
                        if !isLargeUpload || filePartIndex % 50 == 0 {
                            NotificationManager.shared.updateUploadProgress(
                                uploadId: uploadId,
                                processedFiles: filePartIndex,
                                uploadedFiles: uploadedFiles.count,
                                failedFiles: failedFiles.count
                            )
                        }
                    } catch {
                        VaultLog.debug("DEBUG: Error saving uploaded file \(fileName): \(error)")
                        failedFiles.append(fileName)
                        filePartIndex += 1
                        
                        if !isLargeUpload || filePartIndex % 50 == 0 {
                            NotificationManager.shared.updateUploadProgress(
                                uploadId: uploadId,
                                processedFiles: filePartIndex,
                                uploadedFiles: uploadedFiles.count,
                                failedFiles: failedFiles.count
                            )
                        }
                    }
                }
            }
        }
        
        // Final progress update for large uploads
        if isLargeUpload {
            NotificationManager.shared.updateUploadProgress(
                uploadId: uploadId,
                processedFiles: filePartIndex,
                uploadedFiles: uploadedFiles.count,
                failedFiles: failedFiles.count
            )
        }
        
        VaultLog.debug("DEBUG: Total uploaded files: \(uploadedFiles.count)")
        VaultLog.debug("DEBUG: Total failed files: \(failedFiles.count)")
        
        // Complete upload progress tracking
        NotificationManager.shared.completeUpload(
            uploadId: uploadId, 
            uploadedFiles: uploadedFiles.count, 
            failedFiles: failedFiles.count
        )
        
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
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: CoreDataManager.shared.context)
            
            // Also trigger a general refresh notification
            NotificationCenter.default.post(name: .vaultDataChanged, object: nil)
        }
    }
    
    // MARK: - Streaming Upload Handler
    
    private func handleStreamingFileUpload(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 🌊 Starting streaming file upload processing...")
        
        // Generate unique upload ID for tracking
        let uploadId = UUID().uuidString
        activeUploads.insert(uploadId)
        
        // Find the end of HTTP headers (double CRLF)
        let headerEndMarker = "\r\n\r\n".data(using: .utf8)!
        guard let headerEndRange = requestData.range(of: headerEndMarker) else {
            VaultLog.debug("DEBUG: No HTTP header end marker found in streaming upload request")
            sendStreamingResponse(connection: connection, success: false, message: "Bad Request")
            return
        }
        
        // Extract headers (safe to convert to UTF-8)
        let headerData = requestData.subdata(in: requestData.startIndex..<headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            VaultLog.debug("DEBUG: Failed to convert header data to UTF-8 string")
            sendStreamingResponse(connection: connection, success: false, message: "Bad Request")
            return
        }
        
        // Extract folder ID from headers (streaming uploads use headers for metadata)
        var targetFolder: Folder? = nil
        let headerLines = headerString.components(separatedBy: "\r\n")
        
        for line in headerLines {
            if line.lowercased().hasPrefix("x-folder-id:") {
                let folderIdFromHeader = line.replacingOccurrences(of: "x-folder-id:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                VaultLog.debug("DEBUG: 🌊 Found folder ID in header: '\(folderIdFromHeader)'")
                if let folderId = UUID(uuidString: folderIdFromHeader) {
                    targetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
                    if let folder = targetFolder {
                        VaultLog.debug("DEBUG: ✅ Target folder found: \(folder.displayName)")
                        break
                    }
                }
            }
        }
        
        // Extract file metadata from headers
        var fileName: String?
        var filePath: String?
        
        for line in headerLines {
            if line.lowercased().hasPrefix("x-file-name:") {
                fileName = line.replacingOccurrences(of: "x-file-name:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                // URL decode the filename
                fileName = fileName?.removingPercentEncoding
            } else if line.lowercased().hasPrefix("x-file-path:") {
                filePath = line.replacingOccurrences(of: "x-file-path:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                // URL decode the file path
                filePath = filePath?.removingPercentEncoding
            }
        }
        
        guard let fileName = fileName, !fileName.isEmpty else {
            VaultLog.debug("DEBUG: 🌊 No filename found in streaming upload")
            sendStreamingResponse(connection: connection, success: false, message: "Filename required")
            activeUploads.remove(uploadId)
            return
        }
        
        // Extract file data (everything after headers)
        let fileData = requestData.subdata(in: headerEndRange.upperBound..<requestData.endIndex)
        VaultLog.debug("DEBUG: 🌊 Processing single file: \(fileName), size: \(fileData.count) bytes")
        
        // Process the file immediately in an autoreleasepool
        autoreleasepool {
            do {
                // Determine target folder based on file path if provided
                let actualTargetFolder: Folder?
                if let filePath = filePath, !filePath.isEmpty {
                    actualTargetFolder = try createFolderStructureForFile(
                        filePath: filePath,
                        baseFolder: targetFolder,
                        folderUploadMode: "whole"
                    )
                } else {
                    actualTargetFolder = targetFolder
                }
                
                // Extract just the filename (without path) for FileStorageManager
                let actualFileName = URL(fileURLWithPath: fileName).lastPathComponent
                
                // Determine file type based on extension
                let fileType = FileStorageManager.shared.determineFileType(from: actualFileName)
                
                // Save file using FileStorageManager
                _ = try FileStorageManager.shared.saveFile(
                    data: fileData,
                    fileName: actualFileName,
                    fileType: fileType,
                    targetFolder: actualTargetFolder
                )
                
                VaultLog.debug("DEBUG: 🌊 ✅ Successfully processed streaming file: \(fileName)")
                
                // Send success response
                sendStreamingResponse(connection: connection, success: true, message: "File uploaded successfully", fileName: fileName)
                
                // Notify UI to refresh
                DispatchQueue.main.async {
                    CoreDataManager.shared.save()
                    NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
                    NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: CoreDataManager.shared.context)
                    NotificationCenter.default.post(name: .vaultDataChanged, object: nil)
                }
                
            } catch FileStorageError.duplicateFile {
                VaultLog.debug("DEBUG: 🌊 Skipped duplicate file: \(fileName)")
                sendStreamingResponse(connection: connection, success: true, message: "File already exists (skipped)", fileName: fileName)
            } catch {
                VaultLog.debug("DEBUG: 🌊 ❌ Error processing streaming file \(fileName): \(error)")
                sendStreamingResponse(connection: connection, success: false, message: "Failed to save file: \(error.localizedDescription)")
            }
        }
        
        // Clean up upload tracking
        activeUploads.remove(uploadId)
    }
    
    private func sendStreamingResponse(connection: NWConnection, success: Bool, message: String, fileName: String? = nil) {
        var response: [String: Any] = [
            "success": success,
            "message": message
        ]
        
        if let fileName = fileName {
            response["fileName"] = fileName
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            sendHTTPResponse(
                connection: connection,
                statusCode: success ? 200 : 400,
                contentType: "application/json",
                body: jsonString
            )
        } catch {
            VaultLog.debug("DEBUG: Error creating streaming response: \(error)")
            sendHTTPResponse(
                connection: connection,
                statusCode: 500,
                contentType: "application/json",
                body: "{\"success\": false, \"message\": \"Internal server error\"}"
            )
        }
    }
    
    // MARK: - Folder Management Handlers
    
    private func handleCreateFolder(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 📁 handleCreateFolder called")
        
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
                VaultLog.debug("DEBUG: ✅ Created folder: \(folder.displayName)")
            } else {
                VaultLog.debug("DEBUG: ❌ Failed to create folder")
            }
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder created successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            }
            
        } catch {
            VaultLog.debug("DEBUG: ❌ Error creating folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to create folder")
        }
    }
    
    private func handleRenameFolder(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: ✏️ handleRenameFolder called")
        
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
            
            VaultLog.debug("DEBUG: ✅ Renamed folder to: \(trimmedName)")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder renamed successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            }
            
        } catch {
            VaultLog.debug("DEBUG: ❌ Error renaming folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to rename folder")
        }
    }
    
    private func handleDeleteFolder(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 🗑️ handleDeleteFolder called")
        
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
            
            VaultLog.debug("DEBUG: ✅ Deleted folder and all its contents completely")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "Folder deleted successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            }
            
        } catch {
            VaultLog.debug("DEBUG: ❌ Error deleting folder: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to delete folder")
        }
    }
    
    private func handleDeleteFile(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 🗑️ handleDeleteFile called")
        
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
            
            VaultLog.debug("DEBUG: ✅ Deleted file: \(vaultItem.fileName ?? "Unknown")")
            sendJSONResponse(connection: connection, statusCode: 200, success: true, message: "File deleted successfully")
            
            // Notify UI to refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            }
            
        } catch {
            VaultLog.debug("DEBUG: ❌ Error deleting file: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to delete file")
        }
    }
    
    private func handleBulkDelete(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 🗑️ handleBulkDelete called")
        
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
                NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            }
            
        } catch {
            VaultLog.debug("DEBUG: ❌ Error in bulk delete: \(error)")
            sendJSONResponse(connection: connection, statusCode: 500, success: false, message: "Failed to process bulk delete")
        }
    }
    
    // MARK: - Download Handlers
    
    /// Hands the browser a one-shot link for a single file or folder. The link dies on first
    /// use, after a minute, when the export session ends, or if another device tries it.
    private func handleDownloadTicket(request: WebHTTPRequest, connection: NWConnection) {
        guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "File or folder id is required")
            return
        }

        let target: WebDownloadTarget
        if let items = json["items"] as? [[String: Any]] {
            guard let selection = selectionTarget(from: items) else {
                sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "Nothing in the selection could be found")
                return
            }
            target = selection
        } else {
            guard let type = json["type"] as? String,
                  let idString = json["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "File or folder id is required")
                return
            }
            switch type {
            case "file":
                guard CoreDataManager.shared.fetchAllVaultItems().contains(where: { $0.id == id }) else {
                    sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "File not found")
                    return
                }
                target = .file(id)
            case "folder":
                guard CoreDataManager.shared.fetchFolder(by: id) != nil else {
                    sendJSONResponse(connection: connection, statusCode: 404, success: false, message: "Folder not found")
                    return
                }
                target = .folder(id)
            default:
                sendJSONResponse(connection: connection, statusCode: 400, success: false, message: "Unknown download type")
                return
            }
        }

        guard let ticket = accessControl.issueTicket(for: target, client: clientIdentity(for: connection)) else {
            sendJSONResponse(connection: connection, statusCode: 403, success: false, message: "Start an export session in Keepshire to download files")
            return
        }
        sendJSONResponse(
            connection: connection,
            statusCode: 200,
            success: true,
            message: "Download ready",
            data: ["url": "/download/t/\(ticket)"]
        )
    }

    private func handleTicketDownload(request: WebHTTPRequest, connection: NWConnection) {
        guard let ticket = WebDownloadPathResolver.ticket(from: request.path),
              let target = accessControl.redeemTicket(ticket, client: clientIdentity(for: connection)) else {
            sendHTTPResponse(connection: connection, statusCode: 403, body: "This download link has expired. Request the file again.")
            return
        }

        switch target {
        case .file(let id):
            guard let vaultItem = CoreDataManager.shared.fetchAllVaultItems().first(where: { $0.id == id }) else {
                sendHTTPResponse(connection: connection, statusCode: 404, body: "File not found")
                return
            }
            do {
                let fileData = try FileStorageManager.shared.loadFile(vaultItem: vaultItem)
                sendFileResponse(
                    connection: connection,
                    data: fileData,
                    fileName: vaultItem.fileName ?? "download",
                    contentType: vaultItem.fileType ?? "application/octet-stream"
                )
            } catch {
                VaultLog.debug("DEBUG: ❌ Error reading file data: \(error)")
                sendHTTPResponse(connection: connection, statusCode: 500, body: "Error reading file")
            }
        case .folder(let id):
            guard let folder = CoreDataManager.shared.fetchFolder(by: id) else {
                sendHTTPResponse(connection: connection, statusCode: 404, body: "Folder not found")
                return
            }
            do {
                let zipData = try createZipFromFolder(folder)
                sendFileResponse(
                    connection: connection,
                    data: zipData,
                    fileName: "\(folder.displayName).zip",
                    contentType: "application/zip"
                )
            } catch {
                VaultLog.debug("DEBUG: ❌ Error creating ZIP: \(error)")
                sendHTTPResponse(connection: connection, statusCode: 500, body: "Error creating ZIP file")
            }
        case .selection(let fileIDs, let folderIDs):
            let items = CoreDataManager.shared.fetchAllVaultItems().filter { item in
                item.id.map(fileIDs.contains) ?? false
            }
            let folders = folderIDs.compactMap { CoreDataManager.shared.fetchFolder(by: $0) }
            guard !items.isEmpty || !folders.isEmpty else {
                sendHTTPResponse(connection: connection, statusCode: 404, body: "Nothing in the selection could be found")
                return
            }
            do {
                let zipData = try createZipFromSelection(items: items, folders: folders)
                sendFileResponse(
                    connection: connection,
                    data: zipData,
                    fileName: "Keepshire Selection.zip",
                    contentType: "application/zip"
                )
            } catch {
                VaultLog.debug("DEBUG: ❌ Error creating selection ZIP: \(error)")
                sendHTTPResponse(connection: connection, statusCode: 500, body: "Error creating ZIP file")
            }
        }
    }

    /// Keeps only ids that still exist, so a stale page cannot ask for deleted content.
    private func selectionTarget(from items: [[String: Any]]) -> WebDownloadTarget? {
        let knownFileIDs = Set(CoreDataManager.shared.fetchAllVaultItems().compactMap(\.id))
        var files: [UUID] = []
        var folders: [UUID] = []

        for item in items {
            guard let type = item["type"] as? String,
                  let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString) else { continue }
            switch type {
            case "file" where knownFileIDs.contains(id):
                files.append(id)
            case "folder" where CoreDataManager.shared.fetchFolder(by: id) != nil:
                folders.append(id)
            default:
                continue
            }
        }

        guard !files.isEmpty || !folders.isEmpty else { return nil }
        return .selection(files: files, folders: folders)
    }

    // MARK: - Pairing

    private func handlePairing(request: WebHTTPRequest, connection: NWConnection) {
        let submitted = WebFormDecoder.value(named: "code", in: request.body) ?? ""
        guard let token = accessControl.redeemPairingCode(submitted) else {
            let message = accessControl.isPairingLocked
                ? "Too many attempts. Restart the server in Keepshire to get a new code."
                : "That code is not right. Check Keepshire on your iPhone."
            servePairingPage(connection: connection, message: message, statusCode: 401)
            return
        }

        sendPreparedResponse(
            connection: connection,
            response: WebHTTPResponse.text(
                statusCode: 200,
                body: WebPairingPage.successHTML(),
                extraHeaders: [
                    "Set-Cookie": WebAccessControl.sessionCookieHeader(token: token)
                ]
            )
        )
    }

    private func servePairingPage(connection: NWConnection, message: String?, statusCode: Int = 401) {
        sendPreparedResponse(
            connection: connection,
            response: WebHTTPResponse.text(
                statusCode: statusCode,
                body: WebPairingPage.html(message: message)
            )
        )
    }

    private func clientIdentity(for connection: NWConnection) -> String {
        if case let .hostPort(host, _) = connection.endpoint {
            return "\(host)"
        }
        return "\(connection.endpoint)"
    }
    
    private func sendFileResponse(connection: NWConnection, data: Data, fileName: String, contentType: String) {
        let response = WebHTTPResponse.download(data: data, fileName: fileName, contentType: contentType)
        VaultLog.debug("DEBUG: Sending file response: \(fileName), size: \(data.count) bytes")
        
        // Send headers first
        connection.send(content: response.headerData, completion: .contentProcessed { error in
            if let error = error {
                VaultLog.debug("DEBUG: Error sending file headers: \(error)")
                connection.cancel()
                return
            }
            
            // Then send file data
            connection.send(content: response.bodyData, completion: .contentProcessed { error in
                if let error = error {
                    VaultLog.debug("DEBUG: Error sending file data: \(error)")
                } else {
                    VaultLog.debug("DEBUG: File sent successfully: \(fileName)")
                }
                
                // Close connection after sending
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    connection.cancel()
                }
            })
        })
    }
    
    private func createZipFromFolder(_ folder: Folder) throws -> Data {
        // Staging holds decrypted bytes, so it gets the same protection class as the vault
        // and is removed as soon as the archive is built.
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        
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
    
    /// Zips a mixed selection of loose files and folders into one archive.
    private func createZipFromSelection(items: [VaultItem], folders: [Folder]) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stagingDir = tempDir.appendingPathComponent("Keepshire Selection")
        try FileManager.default.createDirectory(
            at: stagingDir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        defer { try? FileManager.default.removeItem(at: tempDir) }

        for item in items {
            let fileData = try FileStorageManager.shared.loadFile(vaultItem: item)
            let fileURL = uniqueURL(for: item.fileName ?? "unknown", in: stagingDir)
            try fileData.write(to: fileURL, options: .completeFileProtection)
        }
        for folder in folders {
            try createFolderStructure(folder: folder, in: stagingDir, relativePath: "")
        }

        let zipFileURL = tempDir.appendingPathComponent("Keepshire Selection.zip")
        try createZipFile(from: stagingDir, to: zipFileURL)
        return try Data(contentsOf: zipFileURL)
    }

    /// Two vault items can share a display name; the archive cannot.
    private func uniqueURL(for fileName: String, in directory: URL) -> URL {
        let candidate = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension
        var suffix = 2
        while true {
            let name = ext.isEmpty ? "\(base) (\(suffix))" : "\(base) (\(suffix)).\(ext)"
            let next = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: next.path) { return next }
            suffix += 1
        }
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
            try fileData.write(to: fileURL, options: .completeFileProtection)
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
                VaultLog.debug("DEBUG: Error in ZIP creation: \(error)")
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
            VaultLog.debug("DEBUG: No HTTP header end marker found")
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
            VaultLog.debug("DEBUG: Error creating JSON response: \(error)")
            sendHTTPResponse(connection: connection, statusCode: 500, contentType: "application/json", body: "{\"success\": false, \"message\": \"Internal server error\"}")
        }
    }
    

    
    // MARK: - Utility Methods
    
    private func updateServerURL() {
        if let localIP = getLocalIPAddress() {
            serverURL = "https://\(localIP):\(serverPort)"
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
    
}

extension WebServerManager {
    
    private func extractBoundary(from requestString: String) -> String {
        WebHTTPHeaderParser.boundary(from: requestString) ?? ""
    }
    
    private func extractContentLength(from data: Data) -> Int {
        WebHTTPHeaderParser.contentLength(from: data)
    }
    
    /// Creates folder structure based on file path and returns the target folder for the file
    private func createFolderStructureForFile(filePath: String, baseFolder: Folder?, folderUploadMode: String = "whole") throws -> Folder? {
        guard !filePath.isEmpty else {
            return baseFolder
        }
        
        guard let folderComponents = WebUploadPathResolver.folderComponents(
            for: filePath,
            mode: folderUploadMode
        ) else {
            throw NSError(
                domain: "InvalidUploadPath",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsafe upload path"]
            )
        }
        guard !folderComponents.isEmpty else { return baseFolder }
        
        VaultLog.debug("DEBUG: Creating folder structure for path: \(folderComponents.joined(separator: "/"))")
        
        var currentParent = baseFolder
        
        // Create each folder in the path
        for folderName in folderComponents {
            guard !folderName.isEmpty else { continue }
            
            // Check if folder already exists
            let existingFolders = CoreDataManager.shared.fetchFolders(in: currentParent)
            if let existingFolder = existingFolders.first(where: { $0.name == folderName }) {
                VaultLog.debug("DEBUG: Folder '\(folderName)' already exists")
                currentParent = existingFolder
            } else {
                // Create new folder
                VaultLog.debug("DEBUG: Creating folder '\(folderName)'")
                guard let newFolder = CoreDataManager.shared.createFolder(name: folderName, parent: currentParent) else {
                    throw NSError(domain: "FolderCreationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create folder: \(folderName)"])
                }
                currentParent = newFolder
            }
        }
        
        return currentParent
    }
    
    private func handleLargeFileUpload(requestData: Data, connection: NWConnection) {
        VaultLog.debug("DEBUG: 📦 Handling large file upload with background support")
        
        // Generate unique upload ID for tracking
        let uploadId = UUID().uuidString
        activeUploads.insert(uploadId)
        
        // Parse the initial headers and multipart data
        guard let headerEndRange = requestData.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let headerData = requestData.subdata(in: requestData.startIndex..<headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let boundary = extractBoundary(from: headerString)
        guard !boundary.isEmpty else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "No boundary found")
            return
        }
        
        // Parse multipart data
        let parts = parseMultipartData(data: requestData, boundary: boundary)
        
        // Count actual file parts for notification
        let fileParts = parts.filter { $0.fileName != nil && $0.data != nil && !$0.data!.isEmpty }
        let totalFiles = fileParts.count
        VaultLog.debug("DEBUG: Starting large file upload with \(totalFiles) files")
        
        // Extract folder information and file paths  
        var targetFolderId: String? = nil
        var filePaths: [String] = []
        
        // Always use "whole" folder upload mode (folders preserve their structure)
        let folderUploadMode = "whole"
        
        for part in parts {
            if let fieldName = part.fieldName, fieldName == "folderId",
               let data = part.data, let folderIdString = String(data: data, encoding: .utf8),
               !folderIdString.isEmpty {
                targetFolderId = folderIdString.trimmingCharacters(in: .whitespacesAndNewlines)
                VaultLog.debug("DEBUG: Large upload - found folder ID: '\(targetFolderId!)'")
            } else if let fieldName = part.fieldName, fieldName == "filePaths",
                      let data = part.data, let filePath = String(data: data, encoding: .utf8) {
                filePaths.append(filePath.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // Extract target folder from folder ID
        var baseTargetFolder: Folder? = nil
        if let targetFolderId = targetFolderId, !targetFolderId.isEmpty,
           let folderId = UUID(uuidString: targetFolderId) {
            baseTargetFolder = CoreDataManager.shared.fetchFolder(by: folderId)
            if let folder = baseTargetFolder {
                VaultLog.debug("DEBUG: Large upload - target folder: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
            } else {
                VaultLog.debug("DEBUG: Large upload - target folder ID \(targetFolderId) not found in database")
            }
        } else {
            VaultLog.debug("DEBUG: Large upload - no target folder specified, uploading to root level")
            VaultLog.debug("DEBUG: Large upload - targetFolderId was: '\(targetFolderId ?? "nil")'")
        }
        
        // Start upload progress tracking
        NotificationManager.shared.startUploadProgress(uploadId: uploadId, totalFiles: totalFiles)
        
        // Pre-create folder structure on main thread to avoid Core Data conflicts
        var folderStructureMap: [String: Folder?] = [:]
        var filePartIndexForMapping = 0
        for part in parts {
            if let fileName = part.fileName, !fileName.isEmpty {
                let filePath = filePartIndexForMapping < filePaths.count ? filePaths[filePartIndexForMapping] : ""
                filePartIndexForMapping += 1
                
                if !filePath.isEmpty && folderStructureMap[filePath] == nil {
                    do {
                        folderStructureMap[filePath] = try createFolderStructureForFile(
                            filePath: filePath,
                            baseFolder: baseTargetFolder,
                            folderUploadMode: folderUploadMode
                        )
                    } catch {
                        VaultLog.debug("DEBUG: Error pre-creating folder structure for \(filePath): \(error)")
                        folderStructureMap[filePath] = baseTargetFolder
                    }
                }
            }
        }
        
        // Process file uploads with folder structure preservation
        var uploadedFiles: [String] = []
        var failedFiles: [String] = []
        var filePartIndex = 0
        var processedFiles = 0
        
        // Start background task for large file processing
        startBackgroundTask()
        
        // Process files sequentially for thread safety and memory management
        for part in parts {
            autoreleasepool {
                if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                    do {
                        // Get the corresponding file path
                        let filePath = filePartIndex < filePaths.count ? filePaths[filePartIndex] : ""
                        VaultLog.debug("DEBUG: Large file - processing \(fileName) with path: '\(filePath)'")
                        
                        // Use pre-created folder structure to avoid Core Data conflicts
                        let actualTargetFolder = folderStructureMap[filePath] ?? baseTargetFolder
                        
                        // Extract just the filename (without path) for FileStorageManager
                        let actualFileName = URL(fileURLWithPath: fileName).lastPathComponent
                        VaultLog.debug("DEBUG: Large file - extracted filename: \(actualFileName) from full path: \(fileName)")
                        
                        // Determine file type based on extension
                        let fileType = FileStorageManager.shared.determineFileType(from: actualFileName)
                        
                        // Use synchronous saving for large files to avoid threading issues
                        _ = try FileStorageManager.shared.saveFile(
                            data: fileData,
                            fileName: actualFileName,
                            fileType: fileType,
                            targetFolder: actualTargetFolder
                        )
                        
                        uploadedFiles.append(fileName)
                        processedFiles += 1
                        VaultLog.debug("DEBUG: Large file upload success: \(fileName)")
                        
                        filePartIndex += 1
                        
                        // Update progress notification less frequently
                        if processedFiles % 25 == 0 || processedFiles >= totalFiles {
                            NotificationManager.shared.updateUploadProgress(
                                uploadId: uploadId,
                                processedFiles: processedFiles,
                                uploadedFiles: uploadedFiles.count,
                                failedFiles: failedFiles.count
                            )
                        }
                        
                    } catch FileStorageError.duplicateFile {
                        VaultLog.debug("DEBUG: Large file upload - skipped duplicate: \(fileName)")
                        // Count duplicates as successful uploads
                        uploadedFiles.append(fileName)
                        processedFiles += 1
                        filePartIndex += 1
                    } catch {
                        VaultLog.debug("DEBUG: Error processing large file \(fileName): \(error)")
                        failedFiles.append(fileName)
                        processedFiles += 1
                        filePartIndex += 1
                    }
                }
            }
        }
        
        // Complete upload tracking
        activeUploads.remove(uploadId)
        NotificationManager.shared.completeUpload(
            uploadId: uploadId, 
            uploadedFiles: uploadedFiles.count, 
            failedFiles: failedFiles.count
        )
        VaultLog.debug("DEBUG: Large file upload completed: \(uploadedFiles.count) uploaded, \(failedFiles.count) failed")
        
        // End background task when processing is complete
        endBackgroundTask()
        
        // Send immediate response acknowledging upload started
        let response = """
        {
            "success": true,
            "message": "Large file upload initiated in background",
            "uploadedFiles": [],
            "failedFiles": []
        }
        """
        sendHTTPResponse(connection: connection, statusCode: 200, contentType: "application/json", body: response)
    }
    
    private func parseMultipartData(data: Data, boundary: String) -> [MultipartPart] {
        WebMultipartParser.parse(data: data, boundary: boundary)
    }
    
    // MARK: - Batch Upload Processing
    
    private func processBatchUpload(
        parts: [MultipartPart],
        filePaths: [String],
        targetFolder: Folder?,
        uploadId: String,
        uploadedFiles: inout [String],
        failedFiles: inout [String],
        filePartIndex: inout Int,
        folderUploadMode: String
    ) throws {
        
        VaultLog.debug("DEBUG: Starting batch upload processing for \(parts.count) parts")
        
        // Batch size for Core Data operations - reduced for memory safety
        let batchSize = 10
        var batchItems: [(fileName: String, fileData: Data, actualFileName: String, fileType: String, targetFolder: Folder?)] = []
        var processedInBatch = 0
        var batchCounter = 0
        
        for (index, part) in parts.enumerated() {
            if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                do {
                    // Get the corresponding file path
                    let filePath = filePartIndex < filePaths.count ? filePaths[filePartIndex] : ""
                    
                    // Determine target folder based on file path
                    let actualTargetFolder = try createFolderStructureForFile(
                        filePath: filePath,
                        baseFolder: targetFolder,
                        folderUploadMode: folderUploadMode
                    )
                    
                    // Extract just the filename (without path) for FileStorageManager
                    let actualFileName = URL(fileURLWithPath: fileName).lastPathComponent
                    
                    // Determine file type based on extension
                    let fileType = FileStorageManager.shared.determineFileType(from: actualFileName)
                    
                    // Add to batch instead of processing immediately
                    batchItems.append((
                        fileName: fileName,
                        fileData: fileData,
                        actualFileName: actualFileName,
                        fileType: fileType,
                        targetFolder: actualTargetFolder
                    ))
                    
                    filePartIndex += 1
                    processedInBatch += 1
                    
                    // Process batch when it reaches the batch size or at the end
                    if batchItems.count >= batchSize || index == parts.count - 1 {
                        try processBatch(
                            batchItems: batchItems,
                            uploadedFiles: &uploadedFiles,
                            failedFiles: &failedFiles
                        )
                        
                        batchCounter += 1
                        
                        // Update progress notification less frequently (every 5 batches = 50 files)
                        if batchCounter % 5 == 0 || index == parts.count - 1 {
                            NotificationManager.shared.updateUploadProgress(
                                uploadId: uploadId,
                                processedFiles: filePartIndex,
                                uploadedFiles: uploadedFiles.count,
                                failedFiles: failedFiles.count
                            )
                        }
                        
                        VaultLog.debug("DEBUG: Processed batch of \(batchItems.count) files. Total processed: \(filePartIndex)")
                        
                        // Clear batch for next iteration
                        batchItems.removeAll()
                    }
                    
                } catch {
                    VaultLog.debug("DEBUG: Error preparing file \(fileName) for batch: \(error)")
                    failedFiles.append(fileName)
                    filePartIndex += 1
                }
            }
        }
        
        VaultLog.debug("DEBUG: Batch upload processing completed. Total processed: \(filePartIndex)")
    }
    
    private func processBatch(
        batchItems: [(fileName: String, fileData: Data, actualFileName: String, fileType: String, targetFolder: Folder?)],
        uploadedFiles: inout [String],
        failedFiles: inout [String]
    ) throws {
        
        // Process files sequentially but in smaller batches to avoid memory issues
        // Core Data operations must happen on main thread for thread safety
        
        for item in batchItems {
            autoreleasepool {
                do {
                    // Check for duplicate content first
                    let fileSize = Int64(item.fileData.count)
                    if FileStorageManager.shared.isDuplicateContent(fileSize: fileSize, fileType: item.fileType, targetFolder: item.targetFolder) {
                        // Don't count duplicates as failures, just skip
                        return
                    }
                    
                    // Save file using FileStorageManager on main thread for Core Data safety
                    _ = try FileStorageManager.shared.saveFile(
                        data: item.fileData,
                        fileName: item.actualFileName,
                        fileType: item.fileType,
                        targetFolder: item.targetFolder
                    )
                    
                    uploadedFiles.append(item.fileName)
                    
                } catch FileStorageError.duplicateFile {
                    // Don't count duplicates as failures
                    return
                } catch {
                    failedFiles.append(item.fileName)
                    VaultLog.debug("DEBUG: Error in batch processing file \(item.fileName): \(error)")
                }
            }
        }
    }
} 