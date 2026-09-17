import SwiftUI
import UIKit

/// Main-tab variant of Web Upload.
struct WebUploadTabView: View {
    @StateObject private var webServer = WebServerManager.shared
    @StateObject private var loginStateManager = LoginStateManager.shared
    @State private var showQRCode = false
    @State private var showInstructions = false
    @State private var showExportUnlock = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    WebUploadHeaderView()
                    WebUploadStatusCard(
                        isRunning: webServer.isRunning,
                        serverURL: webServer.serverURL,
                        certificateFingerprint: webServer.certificateFingerprint,
                        copyURL: copyURL
                    )
                    WebUploadServerControls(
                        isRunning: webServer.isRunning,
                        isFakeLogin: loginStateManager.isFakeLogin,
                        toggleServer: toggleServer,
                        showQRCode: { showQRCode = true },
                        showInstructions: { showInstructions = true }
                    )
                    if webServer.isRunning {
                        WebUploadPairingCard(code: webServer.pairingCode)
                        WebUploadExportSessionCard(
                            expiresAt: webServer.exportSessionExpiresAt,
                            startSession: { showExportUnlock = true },
                            endSession: webServer.endExportSession
                        )
                        WebUploadInstructionsCard()
                    }
                    WebUploadSecurityNotice()
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Web Upload")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showQRCode) {
            WebUploadQRCodeView(url: webServer.serverURL)
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
        .sheet(isPresented: $showExportUnlock) {
            WebExportUnlockSheet { webServer.beginExportSession() }
        }
    }

    private func toggleServer() {
        webServer.isRunning ? webServer.stopServer() : webServer.startServer()
    }

    private func copyURL() {
        UIPasteboard.general.string = webServer.serverURL
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    WebUploadTabView()
}
