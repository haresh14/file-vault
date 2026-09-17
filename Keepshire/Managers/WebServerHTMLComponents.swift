import Foundation

enum WebHTMLEscaping {
    static func text(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func javaScriptSingleQuotedAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

struct WebFolderRowFixture {
    let id: String
    let name: String
    let itemCount: Int
}

struct WebFileRowFixture {
    let id: String
    let name: String
    let fileType: String
    let fileSize: Int64
}

enum WebHTMLRowBuilder {
    static func folderRow(_ folder: WebFolderRowFixture, downloadEnabled: Bool) -> String {
        let escapedName = WebHTMLEscaping.text(folder.name)
        let actionName = WebHTMLEscaping.javaScriptSingleQuotedAttribute(folder.name)
        return """
            <div class="file-item folder-item" data-type="folder" data-id="\(folder.id)" data-name="\(actionName)">
                <div class="item-checkbox">
                    <input type="checkbox" class="item-select" onchange="updateSelectionState()">
                </div>
                <div class="file-icon">📁</div>
                <div class="file-info" onclick="navigateToFolder('\(folder.id)')" style="cursor: pointer; flex: 1;">
                    <div class="file-name">\(escapedName)</div>
                    <div class="file-meta">\(folder.itemCount) items</div>
                </div>
                <div class="file-actions">
                    \(downloadEnabled ? """
                    <button class="action-btn download-btn" onclick="event.stopPropagation(); downloadFolder('\(folder.id)')" title="Download folder as ZIP">
                        📥
                    </button>
                    """ : "")
                    <button class="action-btn rename-btn" onclick="event.stopPropagation(); showRenameDialog('\(folder.id)', '\(actionName)')" title="Rename folder">
                        ✏️
                    </button>
                    <button class="action-btn delete-btn" onclick="event.stopPropagation(); showDeleteConfirmation('folder', '\(folder.id)', '\(actionName)')" title="Delete folder">
                        🗑️
                    </button>
                </div>
            </div>
        """
    }

    static func fileRow(_ file: WebFileRowFixture, downloadEnabled: Bool) -> String {
        let escapedName = WebHTMLEscaping.text(file.name)
        let actionName = WebHTMLEscaping.javaScriptSingleQuotedAttribute(file.name)
        return """
            <div class="file-item" data-type="file" data-id="\(file.id)" data-name="\(actionName)">
                <div class="item-checkbox">
                    <input type="checkbox" class="item-select" onchange="updateSelectionState()">
                </div>
                <div class="file-icon">\(fileIcon(for: file.fileType))</div>
                <div class="file-info" style="flex: 1;">
                    <div class="file-name">\(escapedName)</div>
                    <div class="file-meta">\(formattedFileSize(file.fileSize))</div>
                </div>
                <div class="file-actions">
                    \(downloadEnabled ? """
                    <button class="action-btn download-btn" onclick="downloadFile('\(file.id)')" title="Download file">
                        📥
                    </button>
                    """ : "")
                    <button class="action-btn delete-btn" onclick="showDeleteConfirmation('file', '\(file.id)', '\(actionName)')" title="Delete file">
                        🗑️
                    </button>
                </div>
            </div>
        """
    }

    static func fileIcon(for fileType: String) -> String {
        if fileType.hasPrefix("image/") { return "🖼️" }
        if fileType.hasPrefix("video/") { return "🎥" }
        if fileType.hasPrefix("audio/") { return "🎵" }
        if fileType.contains("pdf") { return "📄" }
        if fileType.contains("word") || fileType.contains("document") { return "📝" }
        if fileType.contains("spreadsheet") || fileType.contains("excel") { return "📊" }
        if fileType.contains("zip") || fileType.contains("rar") { return "📦" }
        return "📄"
    }

    static func formattedFileSize(_ size: Int64) -> String {
        guard size != 0 else { return "0 Bytes" }
        let unit = 1024.0
        let labels = ["Bytes", "KB", "MB", "GB"]
        let index = min(Int(floor(log(Double(size)) / log(unit))), labels.count - 1)
        return String(format: "%.1f %@", Double(size) / pow(unit, Double(index)), labels[index])
    }
}

struct WebBreadcrumbFixture {
    let id: String
    let name: String
}

enum WebHTMLBreadcrumbBuilder {
    static func render(_ path: [WebBreadcrumbFixture]) -> String {
        path.reduce("<a onclick=\"navigateToFolder('')\">📁 Root</a>") { result, folder in
            result + " > <a onclick=\"navigateToFolder('\(folder.id)')\">\(WebHTMLEscaping.text(folder.name))</a>"
        }
    }
}

enum WebHTMLTemplate {
    static func document(title: String, style: String, body: String, script: String? = nil) -> String {
        let scriptChunk = script.map { "\n<script>\n\($0)\n</script>" } ?? ""
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(WebHTMLEscaping.text(title))</title>
        <style>
        \(style)
        </style>
        </head>
        <body>
        \(body)\(scriptChunk)
        </body>
        </html>
        """
    }
}

enum WebHTMLChunks {
    static let statusStyle = """
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    .container { max-width: 500px; margin: 0 auto; }
    """

    static let successStyle = statusStyle
    static let successScript = "setTimeout(() => { window.location.href = '/'; }, 10000);"
}

enum WebHTMLPages {
    static func status(fileCount: Int, formattedSize: String, serverURL: String) -> String {
        WebHTMLTemplate.document(
            title: "Keepshire - Status",
            style: WebHTMLChunks.statusStyle,
            body: """
            <div class="container">
            <h1>Vault Status</h1>
            <div class="stat-number">\(fileCount)</div>
            <div class="stat-number">\(WebHTMLEscaping.text(formattedSize))</div>
            <div class="server-url">\(WebHTMLEscaping.text(serverURL))</div>
            <a href="/">Upload Files</a>
            </div>
            """
        )
    }

    static func success(uploadedFiles: [String]) -> String {
        let files = uploadedFiles.map { "• \(WebHTMLEscaping.text($0))" }.joined(separator: "<br>")
        return WebHTMLTemplate.document(
            title: "Upload Successful - Keepshire",
            style: WebHTMLChunks.successStyle,
            body: "<div class=\"container\"><h1>Upload Successful!</h1><div class=\"file-list\">\(files)</div></div>",
            script: WebHTMLChunks.successScript
        )
    }
}
