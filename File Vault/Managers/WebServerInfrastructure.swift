import Foundation

struct WebHTTPResponse: Equatable {
    let headerData: Data
    let bodyData: Data

    var serializedData: Data {
        var data = headerData
        data.append(bodyData)
        return data
    }

    static func text(
        statusCode: Int,
        contentType: String = "text/html; charset=utf-8",
        body: String,
        extraHeaders: [String: String] = [:]
    ) -> WebHTTPResponse {
        let bodyData = Data(body.utf8)
        let additional = extraHeaders
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)\r\n" }
            .joined()
        let header = """
        HTTP/1.1 \(statusCode) \(HTTPStatusText.text(for: statusCode))\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        Cache-Control: no-cache\r

        """ + additional + "\r\n"
        return WebHTTPResponse(headerData: Data(header.utf8), bodyData: bodyData)
    }

    static func download(data: Data, fileName: String, contentType: String) -> WebHTTPResponse {
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
        let header = """
        HTTP/1.1 200 \(HTTPStatusText.text(for: 200))\r
        Content-Type: \(contentType)\r
        Content-Length: \(data.count)\r
        Content-Disposition: attachment; filename="\(encodedFileName)"\r
        Cache-Control: no-cache\r
        Connection: close\r
        \r

        """
        return WebHTTPResponse(headerData: Data(header.utf8), bodyData: data)
    }
}

struct HTTPStatusText {
    static func text(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

struct WebHTTPRequest {
    let method: String
    let path: String
    let version: String
    let headers: [String: String]
    let body: Data

    var contentLength: Int {
        Int(headers["content-length"] ?? "") ?? 0
    }

    var multipartBoundary: String? {
        guard let contentType = headers["content-type"] else { return nil }
        for parameter in contentType.split(separator: ";").dropFirst() {
            let pair = parameter.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard pair.count == 2, pair[0].lowercased() == "boundary" else { continue }
            let boundary = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return boundary.isEmpty ? nil : boundary
        }
        return nil
    }

    var isLargeUpload: Bool {
        contentLength > 100 * 1024 * 1024
    }

    static func parse(_ data: Data) -> WebHTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let separatorRange = data.range(of: separator),
              let headerString = String(
                data: data[data.startIndex..<separatorRange.lowerBound],
                encoding: .utf8
              ) else {
            return nil
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 3 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        return WebHTTPRequest(
            method: String(requestParts[0]),
            path: String(requestParts[1]),
            version: String(requestParts[2]),
            headers: headers,
            body: data.subdata(in: separatorRange.upperBound..<data.endIndex)
        )
    }
}

enum WebHTTPHeaderParser {
    static func boundary(from headerString: String) -> String? {
        for line in headerString.components(separatedBy: "\r\n") {
            guard let colon = line.firstIndex(of: ":"),
                  line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == "content-type" else {
                continue
            }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            for parameter in value.split(separator: ";").dropFirst() {
                let pair = parameter.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard pair.count == 2, pair[0].lowercased() == "boundary" else { continue }
                let boundary = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return boundary.isEmpty ? nil : boundary
            }
        }
        return nil
    }

    static func contentLength(from data: Data) -> Int {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let headerString = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else {
            return 0
        }
        for line in headerString.components(separatedBy: "\r\n") {
            guard let colon = line.firstIndex(of: ":"),
                  line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                continue
            }
            return Int(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return 0
    }
}

enum WebRequestRoute: Equatable {
    case uploadPage
    case testPage
    case upload
    case streamUpload
    case createFolder
    case renameFolder
    case deleteFolder
    case deleteFile
    case bulkDelete
    case issueDownloadTicket
    case ticketDownload
    case pair
    case sessionState
    case status
    case fakeLoginForbidden
    case notFound
}

extension WebRequestRoute {
    /// Vault files and thumbnails carry complete file protection, so iOS refuses to read or
    /// write them while the device is locked. These routes answer with a plain explanation
    /// instead of letting a file-permission error reach the browser.
    var needsUnlockedDevice: Bool {
        switch self {
        case .uploadPage, .upload, .streamUpload, .createFolder, .renameFolder, .deleteFolder,
             .deleteFile, .bulkDelete, .issueDownloadTicket, .ticketDownload:
            return true
        case .testPage, .pair, .sessionState, .status, .fakeLoginForbidden, .notFound:
            return false
        }
    }

    /// The browser calls these with fetch and reads `success` / `message` out of JSON.
    var expectsJSON: Bool {
        switch self {
        case .upload, .streamUpload, .createFolder, .renameFolder, .deleteFolder,
             .deleteFile, .bulkDelete, .issueDownloadTicket, .sessionState:
            return true
        case .uploadPage, .testPage, .pair, .ticketDownload, .status, .fakeLoginForbidden, .notFound:
            return false
        }
    }
}

enum WebRequestRouter {
    static let fakeLoginResponse = WebHTTPResponse.text(
        statusCode: 403,
        body: "<html><body><h2>Access disabled</h2><p>Web access is disabled in fake login mode.</p></body></html>"
    )

    static let unauthorizedResponse = WebHTTPResponse.text(
        statusCode: 401,
        body: "<html><body><h2>Not authorized</h2><p>Open the address shown in Keepshire on your iPhone. The link carries a one-time session code that expires when the server stops.</p></body></html>"
    )

    static let exportSessionResponse = WebHTTPResponse.text(
        statusCode: 403,
        body: "<html><body><h2>Downloads are off</h2><p>Start an export session in Keepshire on your iPhone to download files.</p></body></html>"
    )

    static let deviceLockedMessage =
        "iPhone is locked. Unlock it to continue, then try again."

    static let deviceLockedResponse = WebHTTPResponse.text(
        statusCode: 503,
        body: "<html><body><h2>iPhone is locked</h2><p>\(deviceLockedMessage)</p></body></html>"
    )

    static func route(_ request: WebHTTPRequest, fakeLoginActive: Bool = false) -> WebRequestRoute {
        if fakeLoginActive {
            return .fakeLoginForbidden
        }

        let path = request.path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.path
        switch (request.method, path) {
        case ("GET", "/"): return .uploadPage
        case ("GET", let path) where path.hasPrefix("/upload"): return .uploadPage
        case ("GET", "/test"): return .testPage
        case ("POST", "/upload"): return .upload
        case ("POST", "/upload/stream"): return .streamUpload
        case ("POST", "/api/folder/create"): return .createFolder
        case ("POST", "/api/folder/rename"): return .renameFolder
        case ("POST", "/api/folder/delete"): return .deleteFolder
        case ("POST", "/api/file/delete"): return .deleteFile
        case ("POST", "/api/bulk/delete"): return .bulkDelete
        case ("POST", "/api/download/ticket"): return .issueDownloadTicket
        // Public by design: exchanges the short code shown in the app for a session token.
        // Attempts are capped in WebAccessControl and the code dies with the server.
        case ("POST", "/pair"): return .pair
        case ("GET", let path) where path.hasPrefix("/download/t/"): return .ticketDownload
        case ("GET", "/api/session"): return .sessionState
        case ("GET", "/status"): return .status
        default: return .notFound
        }
    }
}

struct MultipartPart {
    let headers: [String: String]
    let data: Data?

    var fieldName: String? {
        dispositionParameter(named: "name")
    }

    var fileName: String? {
        dispositionParameter(named: "filename")
    }

    private func dispositionParameter(named name: String) -> String? {
        guard let disposition = headers["content-disposition"] else { return nil }
        for component in disposition.components(separatedBy: ";") {
            let pair = component.trimmingCharacters(in: .whitespaces)
                .split(separator: "=", maxSplits: 1)
            guard pair.count == 2, pair[0] == Substring(name) else { continue }
            return pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }
}

enum WebMultipartParser {
    static func parse(data: Data, boundary: String) -> [MultipartPart] {
        guard !boundary.isEmpty else { return [] }
        let delimiter = Data("--\(boundary)".utf8)
        let terminator = Data("--\(boundary)--".utf8)
        guard data.range(of: delimiter) != nil,
              data.range(of: terminator) != nil else {
            return []
        }

        var parts: [MultipartPart] = []
        var searchStart = data.startIndex

        while let boundaryRange = data.range(of: delimiter, in: searchStart..<data.endIndex) {
            var partStart = boundaryRange.upperBound
            if data[partStart...].starts(with: Data("--".utf8)) {
                break
            }
            if data[partStart...].starts(with: Data("\r\n".utf8)) {
                partStart += 2
            }

            guard let nextBoundary = data.range(of: delimiter, in: partStart..<data.endIndex) else {
                break
            }
            var partEnd = nextBoundary.lowerBound
            if partEnd >= 2, data[(partEnd - 2)..<partEnd] == Data("\r\n".utf8) {
                partEnd -= 2
            }

            if let part = parsePart(data.subdata(in: partStart..<partEnd)) {
                parts.append(part)
            }
            searchStart = nextBoundary.lowerBound
        }
        return parts
    }

    private static func parsePart(_ data: Data) -> MultipartPart? {
        let separator = Data("\r\n\r\n".utf8)
        guard let separatorRange = data.range(of: separator),
              let headerString = String(
                data: data[data.startIndex..<separatorRange.lowerBound],
                encoding: .utf8
              ) else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in headerString.components(separatedBy: "\r\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard !headers.isEmpty else { return nil }
        return MultipartPart(
            headers: headers,
            data: data.subdata(in: separatorRange.upperBound..<data.endIndex)
        )
    }
}

enum WebUploadPathResolver {
    static func folderComponents(for filePath: String, mode: String = "whole") -> [String]? {
        guard !filePath.hasPrefix("/"), !filePath.hasPrefix("\\") else { return nil }
        let normalized = filePath.replacingOccurrences(of: "\\", with: "/")
        let allComponents = normalized.components(separatedBy: "/")
        guard !allComponents.contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        guard allComponents.count > 1 else { return [] }

        var folders = Array(allComponents.dropLast()).filter { !$0.isEmpty }
        if mode == "contents", !folders.isEmpty {
            folders.removeFirst()
        }
        return folders
    }
}

enum WebFormDecoder {
    /// Reads a field out of an `application/x-www-form-urlencoded` body.
    static func value(named name: String, in body: Data) -> String? {
        guard let string = String(data: body, encoding: .utf8) else { return nil }
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, parts[0] == Substring(name) else { continue }
            let value = parts[1].replacingOccurrences(of: "+", with: " ")
            return value.removingPercentEncoding ?? value
        }
        return nil
    }
}

enum WebPairingPage {
    static func html(message: String?) -> String {
        let notice = message.map {
            "<p class=\"notice\">\(WebHTMLEscaping.text($0))</p>"
        } ?? ""
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Keepshire</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #111; color: #f5f5f7; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: #1c1c1e; padding: 32px; border-radius: 16px; width: 320px; text-align: center; }
        h1 { font-size: 20px; margin: 0 0 8px; }
        p { color: #98989d; font-size: 14px; line-height: 1.4; }
        .notice { color: #ff453a; }
        input { width: 100%; box-sizing: border-box; font-size: 28px; letter-spacing: 8px; text-align: center; padding: 12px; margin: 16px 0; border-radius: 10px; border: 1px solid #3a3a3c; background: #2c2c2e; color: #fff; }
        button { width: 100%; padding: 14px; border: 0; border-radius: 10px; background: #0a84ff; color: #fff; font-size: 16px; }
        </style></head>
        <body><div class="card">
        <h1>Enter pairing code</h1>
        <p>Open Keepshire on your iPhone and type the 6-digit code shown under Web Upload. You are already on HTTPS to this phone.</p>
        \(notice)
        <form method="POST" action="/pair">
        <input name="code" inputmode="numeric" pattern="[0-9]*" maxlength="6" autocomplete="off" autofocus>
        <button type="submit">Connect</button>
        </form>
        </div></body></html>
        """
    }

    static func successHTML() -> String {
        """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=/"></head>
        <body>Connected. <a href="/">Continue</a></body></html>
        """
    }
}

enum WebDownloadPathResolver {
    /// Reads the one-shot ticket out of `/download/t/<ticket>`.
    static func ticket(from path: String) -> String? {
        let withoutQuery = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        let components = withoutQuery.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 4,
              components[0].isEmpty,
              components[1] == "download",
              components[2] == "t",
              !components[3].isEmpty else {
            return nil
        }
        return String(components[3])
    }
}
