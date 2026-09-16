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
        body: String
    ) -> WebHTTPResponse {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(statusCode) \(HTTPStatusText.text(for: statusCode))\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        Cache-Control: no-cache\r
        \r

        """
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
    case fileDownload
    case folderDownload
    case status
    case fakeLoginForbidden
    case notFound
}

enum WebRequestRouter {
    // Intentionally public on the user-started LAN listener: the browser upload UI has no
    // account/session credential. Fake-login mode blocks every route, and vault downloads
    // remain separately opt-in through the persisted download toggle.
    static let fakeLoginResponse = WebHTTPResponse.text(
        statusCode: 403,
        body: "<html><body><h2>Access disabled</h2><p>Web access is disabled in fake login mode.</p></body></html>"
    )

    static func route(_ request: WebHTTPRequest, fakeLoginActive: Bool = false) -> WebRequestRoute {
        if fakeLoginActive {
            return .fakeLoginForbidden
        }

        switch (request.method, request.path) {
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
        case ("GET", let path) where path.hasPrefix("/download/file/"): return .fileDownload
        case ("GET", let path) where path.hasPrefix("/download/folder/"): return .folderDownload
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

enum WebDownloadPathResolver {
    static func fileID(from path: String) -> UUID? {
        identifier(from: path, expectedKind: "file")
    }

    static func folderID(from path: String) -> UUID? {
        identifier(from: path, expectedKind: "folder")
    }

    private static func identifier(from path: String, expectedKind: String) -> UUID? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 4,
              components[0].isEmpty,
              components[1] == "download",
              components[2] == Substring(expectedKind) else {
            return nil
        }
        return UUID(uuidString: String(components[3]))
    }
}
