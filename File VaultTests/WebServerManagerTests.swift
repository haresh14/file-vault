import Testing
import Foundation
import Network
@testable import File_Vault

@MainActor
@Suite(.serialized)
struct WebServerManagerTests {
    final class FakeWebServerManager: ObservableObject, WebServerManaging {
        @Published var isRunning = false
        @Published var serverURL = ""
        @Published var certificateFingerprint = ""
        @Published var connectedDevices: [String] = []
        @Published var pairingCode = ""
        @Published var exportSessionExpiresAt: Date?

        func startServer() {
            guard !isRunning else { return }
            isRunning = true
            serverURL = "https://127.0.0.1:8080"
            certificateFingerprint = "AA:BB:CC"
            pairingCode = "123456"
        }

        func stopServer() {
            isRunning = false
            serverURL = ""
            certificateFingerprint = ""
            pairingCode = ""
            exportSessionExpiresAt = nil
            connectedDevices = []
        }

        func beginExportSession(duration: TimeInterval) {
            exportSessionExpiresAt = Date().addingTimeInterval(duration)
        }

        func endExportSession() {
            exportSessionExpiresAt = nil
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
        #expect(manager.serverURL == "https://127.0.0.1:8080")
        #expect(manager.certificateFingerprint == "AA:BB:CC")

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

    @Test func testInjectedExportSession() {
        let manager = FakeWebServerManager()

        manager.beginExportSession(duration: 600)
        #expect(manager.exportSessionExpiresAt != nil)
        manager.endExportSession()
        #expect(manager.exportSessionExpiresAt == nil)
    }

    @Test func testTestingContainerUsesInjectedWebServer() {
        let manager = FakeWebServerManager()
        let container = DependencyContainer.createForTesting(webServerManager: manager)

        #expect(container.webServerManager === manager)
    }

    @Test func testHTTPStatusText() {
        #expect(HTTPStatusText.text(for: 200) == "OK")
        #expect(HTTPStatusText.text(for: 400) == "Bad Request")
        #expect(HTTPStatusText.text(for: 401) == "Unauthorized")
        #expect(HTTPStatusText.text(for: 403) == "Forbidden")
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
            ("POST /api/download/ticket HTTP/1.1\r\n\r\n", .issueDownloadTicket),
            ("GET /download/t/abc123 HTTP/1.1\r\n\r\n", .ticketDownload),
            ("POST /pair HTTP/1.1\r\n\r\n", .pair),
            ("GET /api/session HTTP/1.1\r\n\r\n", .sessionState),
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
        #expect(WebDownloadPathResolver.ticket(from: "/download/t/abc123") == "abc123")
        #expect(WebDownloadPathResolver.ticket(from: "/download/t/abc123?x=1") == "abc123")
        #expect(WebDownloadPathResolver.ticket(from: "/download/t/") == nil)
        #expect(WebDownloadPathResolver.ticket(from: "/download/t/a/b") == nil)
        #expect(WebDownloadPathResolver.ticket(from: "/download/file/123") == nil)
    }

    // MARK: - Access control

    private func request(_ wire: String) -> WebHTTPRequest {
        WebHTTPRequest.parse(Data(wire.utf8))!
    }

    @Test func testEveryRouteRejectsRequestsWithoutTheSessionToken() {
        let control = WebAccessControl()
        control.rotateToken()

        let unauthenticated: [(String, WebRequestRoute)] = [
            ("GET / HTTP/1.1\r\n\r\n", .uploadPage),
            ("POST /upload HTTP/1.1\r\n\r\n", .upload),
            ("POST /api/file/delete HTTP/1.1\r\n\r\n", .deleteFile),
            ("POST /api/bulk/delete HTTP/1.1\r\n\r\n", .bulkDelete),
            ("POST /api/download/ticket HTTP/1.1\r\n\r\n", .issueDownloadTicket),
            ("GET /download/t/abc HTTP/1.1\r\n\r\n", .ticketDownload),
            ("GET /api/session HTTP/1.1\r\n\r\n", .sessionState),
            ("GET /status HTTP/1.1\r\n\r\n", .status)
        ]

        for (wire, route) in unauthenticated {
            #expect(control.authorize(request(wire), route: route) == .unauthorized)
        }
        // Pairing is the one public route, so a browser can exchange the code for a session.
        #expect(control.authorize(request("POST /pair HTTP/1.1\r\n\r\n"), route: .pair) == .allow)
    }

    @Test func testTokenIsAcceptedFromHeaderCookieAndLink() {
        let control = WebAccessControl()
        let token = control.rotateToken()

        #expect(control.authorize(
            request("POST /upload HTTP/1.1\r\nX-Vault-Token: \(token)\r\n\r\n"),
            route: .upload
        ) == .allow)
        #expect(control.authorize(
            request("GET / HTTP/1.1\r\nCookie: fv_session=\(token)\r\n\r\n"),
            route: .uploadPage
        ) == .allow)
        #expect(control.authorize(
            request("GET /?token=\(token) HTTP/1.1\r\n\r\n"),
            route: .uploadPage
        ) == .allow)

        // A cookie alone cannot drive a write, which keeps another site from forging one.
        #expect(control.authorize(
            request("POST /api/bulk/delete HTTP/1.1\r\nCookie: fv_session=\(token)\r\n\r\n"),
            route: .bulkDelete
        ) == .unauthorized)
    }

    @Test func testRotatingTheTokenInvalidatesOldSessions() {
        let control = WebAccessControl()
        let first = control.rotateToken()
        control.rotateToken()

        #expect(control.authorize(
            request("POST /upload HTTP/1.1\r\nX-Vault-Token: \(first)\r\n\r\n"),
            route: .upload
        ) == .unauthorized)
    }

    @Test func testPairingCodeIsSingleUseAndLocksAfterFiveWrongGuesses() {
        let control = WebAccessControl()
        let token = control.rotateToken()
        let code = control.pairingCode!

        let wrongGuess = code == "000000" ? "111111" : "000000"
        for _ in 0..<WebAccessControl.maxPairingAttempts {
            #expect(control.redeemPairingCode(wrongGuess) == nil)
        }
        #expect(control.isPairingLocked)
        #expect(control.redeemPairingCode(code) == nil)

        control.rotateToken()
        #expect(!control.isPairingLocked)
        #expect(control.redeemPairingCode(control.pairingCode!) != nil)
        #expect(control.redeemPairingCode(control.pairingCode!) != token)
    }

    @Test func testDownloadsRequireAnActiveExportSession() {
        let control = WebAccessControl()
        let token = control.rotateToken()
        let ticketRequest = request("POST /api/download/ticket HTTP/1.1\r\nX-Vault-Token: \(token)\r\n\r\n")

        #expect(control.authorize(ticketRequest, route: .issueDownloadTicket) == .exportSessionRequired)
        #expect(control.issueTicket(for: .file(UUID()), client: "192.168.1.5") == nil)

        control.beginExportSession(duration: 600)
        #expect(control.authorize(ticketRequest, route: .issueDownloadTicket) == .allow)

        control.endExportSession()
        #expect(control.authorize(ticketRequest, route: .issueDownloadTicket) == .exportSessionRequired)
    }

    @Test func testExportSessionExpiresOnItsOwn() {
        let control = WebAccessControl()
        control.rotateToken()
        let start = Date()
        control.beginExportSession(now: start, duration: 600)

        #expect(control.isExportSessionActive(now: start.addingTimeInterval(599)))
        #expect(!control.isExportSessionActive(now: start.addingTimeInterval(601)))
        #expect(control.exportSessionExpiry(now: start.addingTimeInterval(601)) == nil)
    }

    @Test func testDownloadTicketIsSingleUseAndBoundToOneDevice() {
        let control = WebAccessControl()
        control.rotateToken()
        control.beginExportSession(duration: 600)
        let fileID = UUID()

        let ticket = control.issueTicket(for: .file(fileID), client: "192.168.1.5")!
        #expect(control.redeemTicket(ticket, client: "192.168.1.9") == nil, "another device must not redeem it")
        #expect(control.redeemTicket(ticket, client: "192.168.1.5") == .file(fileID))
        #expect(control.redeemTicket(ticket, client: "192.168.1.5") == nil, "a ticket works only once")
    }

    @Test func testSelectionTicketCarriesEveryPickedItem() {
        let control = WebAccessControl()
        control.rotateToken()
        control.beginExportSession(duration: 600)
        let files = [UUID(), UUID(), UUID()]
        let folders = [UUID()]

        let ticket = control.issueTicket(for: .selection(files: files, folders: folders), client: "client")!
        #expect(control.redeemTicket(ticket, client: "client") == .selection(files: files, folders: folders))
    }

    @Test func testDownloadTicketExpiresAndDiesWithTheExportSession() {
        let control = WebAccessControl()
        control.rotateToken()
        let start = Date()
        control.beginExportSession(now: start, duration: 600)

        let stale = control.issueTicket(for: .folder(UUID()), client: "client", now: start)!
        #expect(control.redeemTicket(stale, client: "client", now: start.addingTimeInterval(61)) == nil)

        let live = control.issueTicket(for: .folder(UUID()), client: "client", now: start)!
        control.endExportSession()
        #expect(control.redeemTicket(live, client: "client", now: start) == nil)
    }

    @Test func testPairingResponseSetsASessionCookie() {
        let header = WebAccessControl.sessionCookieHeader(token: "abc")
        let response = WebHTTPResponse.text(
            statusCode: 200,
            body: "ok",
            extraHeaders: ["Set-Cookie": header]
        )
        let wire = String(decoding: response.serializedData, as: UTF8.self)

        #expect(header.contains("Secure"))
        #expect(wire.contains("Set-Cookie: fv_session=abc; Path=/; SameSite=Strict; HttpOnly; Secure\r\n"))
        #expect(wire.hasSuffix("\r\n\r\nok"))
    }

    @Test func testFormDecodingReadsThePairingCode() {
        #expect(WebFormDecoder.value(named: "code", in: Data("code=123456".utf8)) == "123456")
        #expect(WebFormDecoder.value(named: "code", in: Data("other=1&code=99+88".utf8)) == "99 88")
        #expect(WebFormDecoder.value(named: "code", in: Data("nothing=1".utf8)) == nil)
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
        #expect(WebHTMLPages.status(fileCount: 3, formattedSize: "1 KB", serverURL: "https://127.0.0.1:8080").contains("3"))
    }

    @Test func testSelfSignedCertificateIsValidAndIncludesTheLANAddress() throws {
        let identity = try LANWebTLSIdentity.make(ipAddresses: ["10.0.0.42"])
        defer { identity.removeFromKeychain() }

        #expect(SecCertificateCreateWithData(nil, identity.certificateDER as CFData) != nil)
        #expect(identity.fingerprint.split(separator: ":").count == 32)
        #expect(identity.fingerprint == LANWebTLSIdentity.fingerprint(of: identity.certificateDER))
        // SAN iPAddress for 10.0.0.42 is context tag 7, length 4, then the octets.
        #expect(identity.certificateDER.contains(Data([0x87, 0x04, 10, 0, 0, 42])))
    }

    @Test func testTLSListenerCompletesAHandshake() async throws {
        let identity = try LANWebTLSIdentity.make(ipAddresses: ["127.0.0.1"])
        defer { identity.removeFromKeychain() }

        let listener = try NWListener(using: identity.listenerParameters(), on: 0)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16) { _, _, _, _ in
                connection.cancel()
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !finished else { return }
                    finished = true
                    continuation.resume()
                case .failed(let error):
                    guard !finished else { return }
                    finished = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }
        defer { listener.cancel() }

        guard let port = listener.port else {
            throw LANWebTLSIdentity.GenerationError.invalidCertificate
        }

        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
            complete(true)
        }, DispatchQueue.global())
        let connection = NWConnection(host: "127.0.0.1", port: port, using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var finished = false
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard !finished else { return }
                            finished = true
                            connection.cancel()
                            continuation.resume()
                        case .failed(let error):
                            guard !finished else { return }
                            finished = true
                            continuation.resume(throwing: error)
                        default:
                            break
                        }
                    }
                    connection.start(queue: .global())
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                throw LANWebTLSIdentity.GenerationError.invalidCertificate
            }
            try await group.next()
            group.cancelAll()
        }
    }
}
