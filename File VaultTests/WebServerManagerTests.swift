import Testing
import Foundation
@testable import File_Vault

@MainActor
@Suite(.serialized)
struct WebServerManagerTests {
    final class FakeWebServerManager: ObservableObject, WebServerManaging {
        @Published var isRunning = false
        @Published var serverURL = ""
        @Published var connectedDevices: [String] = []
        @Published var isDownloadEnabled = false

        func startServer() {
            guard !isRunning else { return }
            isRunning = true
            serverURL = "http://127.0.0.1:8080"
        }

        func stopServer() {
            isRunning = false
            serverURL = ""
            connectedDevices = []
        }

        func setDownloadEnabled(_ enabled: Bool) {
            isDownloadEnabled = enabled
    }
    }

    @Test func testWebServerManagerSingleton() {
        #expect(WebServerManager.shared === WebServerManager.shared)
    }

    @Test func testInjectedServerLifecycle() {
        let manager = FakeWebServerManager()

        #expect(!manager.isRunning)
        #expect(manager.serverURL.isEmpty)

        manager.startServer()
        #expect(manager.isRunning)
        #expect(manager.serverURL == "http://127.0.0.1:8080")

        manager.stopServer()
        #expect(!manager.isRunning)
        #expect(manager.serverURL.isEmpty)
    }

    @Test func testInjectedServerStartAndStopAreIdempotent() {
        let manager = FakeWebServerManager()

                manager.startServer()
                manager.startServer()
        #expect(manager.isRunning)

        manager.stopServer()
            manager.stopServer()
        #expect(!manager.isRunning)
        }

    @Test func testInjectedDownloadSetting() {
        let manager = FakeWebServerManager()

        manager.setDownloadEnabled(true)
        #expect(manager.isDownloadEnabled)
        manager.setDownloadEnabled(false)
        #expect(!manager.isDownloadEnabled)
        }

    @Test func testTestingContainerUsesInjectedWebServer() {
        let manager = FakeWebServerManager()
        let container = DependencyContainer.createForTesting(webServerManager: manager)

        #expect(container.webServerManager === manager)
    }

    @Test func testHTTPStatusText() {
        #expect(HTTPStatusText.text(for: 200) == "OK")
        #expect(HTTPStatusText.text(for: 400) == "Bad Request")
        #expect(HTTPStatusText.text(for: 403) == "Unknown")
        #expect(HTTPStatusText.text(for: 404) == "Not Found")
        #expect(HTTPStatusText.text(for: 500) == "Internal Server Error")
    }

    @Test func testMultipartMetadataParsing() {
        let part = MultipartPart(
            headers: ["content-disposition": "form-data; name=\"files\"; filename=\"report.pdf\""],
            data: Data("contents".utf8)
        )

        #expect(part.fieldName == "files")
        #expect(part.fileName == "report.pdf")
        #expect(part.data == Data("contents".utf8))
    }

    @Test func testHTTPResponsePreservesExactWireFormat() {
        let response = WebHTTPResponse.text(statusCode: 200, body: "Hello")

        #expect(String(decoding: response.serializedData, as: UTF8.self) == """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: 5\r
        Connection: close\r
        Cache-Control: no-cache\r
        \r
        Hello
        """)
    }

    @Test func testBinaryDownloadResponsePreservesHeadersAndBytes() {
        let payload = Data([0x00, 0xFF, 0x41])
        let response = WebHTTPResponse.download(
            data: payload,
            fileName: "report 1.pdf",
            contentType: "application/pdf"
        )

        #expect(String(decoding: response.headerData, as: UTF8.self) == """
        HTTP/1.1 200 OK\r
        Content-Type: application/pdf\r
        Content-Length: 3\r
        Content-Disposition: attachment; filename="report%201.pdf"\r
        Cache-Control: no-cache\r
        Connection: close\r
        \r

        """)
        #expect(response.bodyData == payload)
    }

    @Test func testRequestParsingAndRouteCompatibility() {
        let routes: [(String, WebRequestRoute)] = [
            ("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n", .uploadPage),
            ("GET /upload?folder=abc HTTP/1.1\r\n\r\n", .uploadPage),
            ("GET /test HTTP/1.1\r\n\r\n", .testPage),
            ("POST /upload HTTP/1.1\r\nContent-Length: 0\r\n\r\n", .upload),
            ("POST /upload/stream HTTP/1.1\r\n\r\n", .streamUpload),
            ("POST /api/folder/create HTTP/1.1\r\n\r\n", .createFolder),
            ("POST /api/folder/rename HTTP/1.1\r\n\r\n", .renameFolder),
            ("POST /api/folder/delete HTTP/1.1\r\n\r\n", .deleteFolder),
            ("POST /api/file/delete HTTP/1.1\r\n\r\n", .deleteFile),
            ("POST /api/bulk/delete HTTP/1.1\r\n\r\n", .bulkDelete),
            ("GET /download/file/123 HTTP/1.1\r\n\r\n", .fileDownload),
            ("GET /download/folder/123 HTTP/1.1\r\n\r\n", .folderDownload),
            ("GET /status HTTP/1.1\r\n\r\n", .status),
            ("GET /missing HTTP/1.1\r\n\r\n", .notFound)
        ]

        for (wireRequest, expectedRoute) in routes {
            let request = WebHTTPRequest.parse(Data(wireRequest.utf8))
            #expect(request != nil)
            #expect(WebRequestRouter.route(request!) == expectedRoute)
        }
    }

    @Test func testMalformedRequestsAndFakeLoginRouting() {
        #expect(WebHTTPRequest.parse(Data("GET /\r\n\r\n".utf8)) == nil)
        #expect(WebHTTPRequest.parse(Data("not http".utf8)) == nil)

        let request = WebHTTPRequest.parse(Data("GET /status HTTP/1.1\r\n\r\n".utf8))!
        #expect(WebRequestRouter.route(request, fakeLoginActive: true) == .fakeLoginForbidden)
        #expect(WebRequestRouter.fakeLoginResponse.serializedData == WebHTTPResponse.text(
            statusCode: 403,
            body: "<html><body><h2>Access disabled</h2><p>Web access is disabled in fake login mode.</p></body></html>"
        ).serializedData)
    }

    @Test func testBoundaryAndContentLengthParsing() {
        let quoted = "POST /upload HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=\"AaB03x\"\r\nContent-Length: 104857601\r\n\r\n"
        let request = WebHTTPRequest.parse(Data(quoted.utf8))!

        #expect(request.multipartBoundary == "AaB03x")
        #expect(request.contentLength == 104_857_601)
        #expect(request.isLargeUpload)

        let malformed = WebHTTPRequest.parse(Data(
            "POST /upload HTTP/1.1\r\nContent-Type: multipart/form-data\r\nContent-Length: nope\r\n\r\n".utf8
        ))!
        #expect(malformed.multipartBoundary == nil)
        #expect(malformed.contentLength == 0)
        #expect(!malformed.isLargeUpload)
    }

    @Test func testMultipartSmallAndLargeBinaryPayloads() {
        let boundary = "vault-boundary"
        let binary = Data([0x00, 0x01, 0xFF, 0x0D, 0x0A])
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"folderId\"\r\n\r\nfolder-1\r\n".utf8)
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"a.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(binary)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let parts = WebMultipartParser.parse(data: body, boundary: boundary)
        #expect(parts.count == 2)
        #expect(parts[0].fieldName == "folderId")
        #expect(parts[0].data == Data("folder-1".utf8))
        #expect(parts[1].fileName == "a.bin")
        #expect(parts[1].data == binary)

        let largePayload = Data(repeating: 0x5A, count: 2 * 1024 * 1024)
        var largeBody = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"large.bin\"\r\n\r\n".utf8)
        largeBody.append(largePayload)
        largeBody.append(Data("\r\n--\(boundary)--\r\n".utf8))
        #expect(WebMultipartParser.parse(data: largeBody, boundary: boundary).first?.data == largePayload)
    }

    @Test func testMalformedMultipartBoundariesReturnNoParts() {
        #expect(WebMultipartParser.parse(data: Data("payload".utf8), boundary: "").isEmpty)
        #expect(WebMultipartParser.parse(data: Data("--wrong\r\nvalue".utf8), boundary: "expected").isEmpty)
        #expect(WebMultipartParser.parse(
            data: Data("--b\r\nContent-Disposition: form-data; name=\"file\"\r\nmissing separator\r\n--b--".utf8),
            boundary: "b"
        ).isEmpty)
    }

    @Test func testUploadPathResolutionRejectsTraversal() {
        #expect(WebUploadPathResolver.folderComponents(for: "Photos/Trips/a.jpg") == ["Photos", "Trips"])
        #expect(WebUploadPathResolver.folderComponents(for: "Photos/a.jpg", mode: "contents") == [])
        #expect(WebUploadPathResolver.folderComponents(for: "a.jpg") == [])
        #expect(WebUploadPathResolver.folderComponents(for: "../secret.txt") == nil)
        #expect(WebUploadPathResolver.folderComponents(for: "safe/../../secret.txt") == nil)
        #expect(WebUploadPathResolver.folderComponents(for: "/absolute/secret.txt") == nil)
        #expect(WebUploadPathResolver.folderComponents(for: #"safe\..\secret.txt"#) == nil)
    }

    @Test func testDownloadPathResolution() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        #expect(WebDownloadPathResolver.fileID(from: "/download/file/\(id.uuidString)") == id)
        #expect(WebDownloadPathResolver.folderID(from: "/download/folder/\(id.uuidString)") == id)
        #expect(WebDownloadPathResolver.fileID(from: "/download/file/../../etc/passwd") == nil)
        #expect(WebDownloadPathResolver.folderID(from: "/download/folder/not-a-uuid") == nil)
    }

    @Test func testPureHTMLRowsEscapeUntrustedValuesAndToggleDownloads() {
        let folder = WebFolderRowFixture(
            id: "folder-id",
            name: #"<script>alert('x')</script>"#,
            itemCount: 2
        )
        let file = WebFileRowFixture(
            id: "file-id",
            name: #"a'b<&".pdf"#,
            fileType: "application/pdf",
            fileSize: 1_024
        )

        let disabledFolder = WebHTMLRowBuilder.folderRow(folder, downloadEnabled: false)
        let enabledFolder = WebHTMLRowBuilder.folderRow(folder, downloadEnabled: true)
        let disabledFile = WebHTMLRowBuilder.fileRow(file, downloadEnabled: false)
        let enabledFile = WebHTMLRowBuilder.fileRow(file, downloadEnabled: true)

        #expect(!disabledFolder.contains("downloadFolder("))
        #expect(enabledFolder.contains("downloadFolder('folder-id')"))
        #expect(!disabledFile.contains("downloadFile("))
        #expect(enabledFile.contains("downloadFile('file-id')"))
        #expect(!enabledFolder.contains("<script>alert"))
        #expect(enabledFolder.contains("&lt;script&gt;alert"))
        #expect(enabledFile.contains("a\\'b&lt;&amp;&quot;.pdf"))
    }

    @Test func testBreadcrumbFixtureAndPageChunks() {
        let breadcrumbs = WebHTMLBreadcrumbBuilder.render([
            .init(id: "one", name: "Parent & More"),
            .init(id: "two", name: #"<Child '2'>"#)
        ])

        #expect(breadcrumbs == "<a onclick=\"navigateToFolder('')\">📁 Root</a> > <a onclick=\"navigateToFolder('one')\">Parent &amp; More</a> > <a onclick=\"navigateToFolder('two')\">&lt;Child &#39;2&#39;&gt;</a>")
        #expect(WebHTMLTemplate.document(title: "T", style: "S", body: "B", script: "J").contains("<style>\nS\n</style>"))
        #expect(WebHTMLTemplate.document(title: "T", style: "S", body: "B", script: "J").contains("<script>\nJ\n</script>"))
        #expect(WebHTMLPages.success(uploadedFiles: ["a&b.txt"]).contains("• a&amp;b.txt"))
        #expect(WebHTMLPages.status(fileCount: 3, formattedSize: "1 KB", serverURL: "http://127.0.0.1:8080").contains("3"))
    }
}
