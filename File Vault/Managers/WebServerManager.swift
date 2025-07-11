//
//  WebServerManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation
import Network
import UIKit

class WebServerManager: ObservableObject {
    static let shared = WebServerManager()
    
    @Published var isServerRunning = false
    @Published var serverURL: String = ""
    @Published var connectedDevices: [String] = []
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let serverPort: NWEndpoint.Port = 8080
    
    private init() {}
    
    // MARK: - Server Control
    
    func startServer() {
        guard !isServerRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true
            
            listener = try NWListener(using: parameters, on: serverPort)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isServerRunning = true
                        self?.updateServerURL()
                        print("DEBUG: Web server started on port \(self?.serverPort.rawValue ?? 0)")
                    case .failed(let error):
                        print("DEBUG: Web server failed: \(error)")
                        self?.isServerRunning = false
                    case .cancelled:
                        self?.isServerRunning = false
                        print("DEBUG: Web server cancelled")
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            print("DEBUG: Failed to start web server: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        DispatchQueue.main.async {
            self.isServerRunning = false
            self.serverURL = ""
            self.connectedDevices.removeAll()
        }
        
        print("DEBUG: Web server stopped")
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        print("DEBUG: New connection added, total connections: \(connections.count)")
        
        connection.stateUpdateHandler = { [weak self] state in
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
        
        connection.start(queue: .global(qos: .userInitiated))
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
        let maxRequestSize = 50 * 1024 * 1024 // 50MB max
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
                        self.sendHTTPResponse(connection: connection, statusCode: 413, body: "Request Entity Too Large")
                        return
                    }
                    
                    // Check if we have complete headers (look for double CRLF)
                    if !headersComplete, let requestString = String(data: receivedData, encoding: .utf8),
                       let headerEndRange = requestString.range(of: "\r\n\r\n") {
                        headersComplete = true
                        print("DEBUG: Headers complete, parsing Content-Length")
                        
                        // Extract Content-Length from headers
                        let headerSection = String(requestString[..<headerEndRange.lowerBound])
                        let headerLines = headerSection.components(separatedBy: "\r\n")
                        
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
                        let headerEndIndex = requestString.distance(from: requestString.startIndex, to: headerEndRange.upperBound)
                        let totalExpected = headerEndIndex + (expectedContentLength ?? 0)
                        print("DEBUG: Headers end at \(headerEndIndex), total expected: \(totalExpected)")
                    }
                    
                    // Check if we have all the data we need
                    if headersComplete {
                        if let contentLength = expectedContentLength {
                            // Calculate header size
                            if let requestString = String(data: receivedData, encoding: .utf8),
                               let headerEndRange = requestString.range(of: "\r\n\r\n") {
                                let headerEndIndex = requestString.distance(from: requestString.startIndex, to: headerEndRange.upperBound)
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
        
        guard let requestString = String(data: data, encoding: .utf8) else {
            print("DEBUG: Failed to convert request data to UTF-8 string")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        print("DEBUG: Request string length: \(requestString.count)")
        print("DEBUG: Request preview: \(requestString.prefix(500))")
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            print("DEBUG: No valid request line found")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        print("DEBUG: Request line: \(requestLine)")
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            print("DEBUG: Invalid request line format: \(components)")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let method = components[0]
        let path = components[1]
        
        print("DEBUG: Method: \(method), Path: \(path)")
        
        switch (method, path) {
        case ("GET", "/"):
            print("DEBUG: Serving upload page for /")
            serveUploadPage(connection: connection)
        case ("GET", "/upload"):
            print("DEBUG: Serving upload page for /upload")
            serveUploadPage(connection: connection)
        case ("GET", "/test"):
            print("DEBUG: Serving test page")
            sendHTTPResponse(connection: connection, statusCode: 200, body: "<html><body><h1>Test Page</h1><p>Server is working!</p></body></html>")
        case ("POST", "/upload"):
            print("DEBUG: Handling file upload")
            handleFileUpload(requestData: data, connection: connection)
        case ("GET", "/status"):
            print("DEBUG: Serving status page")
            serveStatusPage(connection: connection)
        case ("GET", "/favicon.ico"):
            print("DEBUG: Serving 404 for favicon")
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
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
    
    private func serveUploadPage(connection: NWConnection) {
        let html = generateUploadHTML()
        sendHTTPResponse(connection: connection, statusCode: 200, body: html)
    }
    
    private func serveStatusPage(connection: NWConnection) {
        let html = generateStatusHTML()
        sendHTTPResponse(connection: connection, statusCode: 200, body: html)
    }
    
    // MARK: - File Upload Handling
    
    private func handleFileUpload(requestData: Data, connection: NWConnection) {
        print("DEBUG: handleFileUpload called with data size: \(requestData.count)")
        
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            print("DEBUG: Failed to convert request data to string")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        // Parse multipart form data
        let boundary = extractBoundary(from: requestString)
        print("DEBUG: Extracted boundary: '\(boundary)'")
        guard !boundary.isEmpty else {
            print("DEBUG: No boundary found in request")
            sendHTTPResponse(connection: connection, statusCode: 400, body: "No boundary found")
            return
        }
        
        let parts = parseMultipartData(data: requestData, boundary: boundary)
        print("DEBUG: Parsed \(parts.count) multipart parts")
        
        var uploadedFiles: [String] = []
        
        for (index, part) in parts.enumerated() {
            print("DEBUG: Processing part \(index)")
            print("DEBUG: Part headers: \(part.headers)")
            print("DEBUG: Part data size: \(part.data?.count ?? 0)")
            print("DEBUG: Part filename: \(part.fileName ?? "none")")
            
            if let fileName = part.fileName, let fileData = part.data, !fileData.isEmpty {
                do {
                    // Determine file type based on extension
                    let fileType = determineFileType(from: fileName)
                    print("DEBUG: Determined file type: \(fileType) for file: \(fileName)")
                    
                    // Save file using FileStorageManager
                    let _ = try FileStorageManager.shared.saveFile(
                        data: fileData,
                        fileName: fileName,
                        fileType: fileType
                    )
                    
                    uploadedFiles.append(fileName)
                    print("DEBUG: Successfully uploaded file: \(fileName)")
                    
                } catch {
                    print("DEBUG: Error saving uploaded file \(fileName): \(error)")
                }
            } else {
                print("DEBUG: Skipping part \(index) - missing filename or data")
            }
        }
        
        print("DEBUG: Total uploaded files: \(uploadedFiles.count)")
        
        // Send success response
        let successHTML = generateSuccessHTML(uploadedFiles: uploadedFiles)
        sendHTTPResponse(connection: connection, statusCode: 200, body: successHTML)
        
        // Notify UI to refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        }
    }
    
    // MARK: - Utility Methods
    
    private func updateServerURL() {
        if let localIP = getLocalIPAddress() {
            serverURL = "http://\(localIP):\(serverPort.rawValue)"
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
    
    private func determineFileType(from fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "gif":
            return "image/gif"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "doc", "docx":
            return "application/msword"
        default:
            return "application/octet-stream"
        }
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
        let boundaryData = "--\(boundary)".data(using: .utf8)!
        let endBoundaryData = "--\(boundary)--".data(using: .utf8)!
        
        var parts: [MultipartPart] = []
        var searchRange = data.startIndex..<data.endIndex
        
        while let boundaryRange = data.range(of: boundaryData, in: searchRange) {
            searchRange = boundaryRange.upperBound..<data.endIndex
            
            // Find next boundary or end boundary
            let nextBoundaryRange = data.range(of: boundaryData, in: searchRange) ?? data.range(of: endBoundaryData, in: searchRange)
            
            guard let nextRange = nextBoundaryRange else { break }
            
            let partData = data.subdata(in: boundaryRange.upperBound..<nextRange.lowerBound)
            
            if let part = parseMultipartPart(data: partData) {
                parts.append(part)
            }
            
            searchRange = nextRange.upperBound..<data.endIndex
        }
        
        return parts
    }
    
    private func parseMultipartPart(data: Data) -> MultipartPart? {
        // Find the double CRLF that separates headers from body
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        
        guard let separatorRange = data.range(of: headerBodySeparator) else { return nil }
        
        let headerData = data.subdata(in: data.startIndex..<separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound..<data.endIndex)
        
        // Parse headers as string
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        
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
        
        // Keep body as binary data
        return MultipartPart(headers: headers, data: bodyData)
    }
} 