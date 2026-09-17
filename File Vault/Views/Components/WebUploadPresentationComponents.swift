import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct WebUploadHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("Web Upload")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Upload files from any device on your network")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
}

struct WebUploadStatusCard: View {
    let isRunning: Bool
    let serverURL: String
    let copyURL: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(isRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)
                    .foregroundColor(isRunning ? .green : .red)
                    .accessibilityIdentifier("webUpload.status")
                Spacer()
            }

            if isRunning {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Server URL:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(serverURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityIdentifier("webUpload.serverURL")
                            .accessibilityLabel("Server URL")
                        Button(action: copyURL) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                        .accessibilityIdentifier("webUpload.copyURL")
                        .accessibilityLabel("Copy server URL")
                    }
                    Text("Share this URL with devices on your network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WebUploadServerControls: View {
    let isRunning: Bool
    let isFakeLogin: Bool
    let toggleServer: () -> Void
    let showQRCode: () -> Void
    let showInstructions: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isFakeLogin {
                VStack(spacing: 8) {
                    Button(action: {}) {
                        Label("Server Disabled", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(true)
                    .accessibilityIdentifier("webUpload.serverDisabled")
                    .accessibilityLabel("Server disabled")
                    Text("Web server is not available in this mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button(action: toggleServer) {
                    Label(
                        isRunning ? "Stop Server" : "Start Server",
                        systemImage: isRunning ? "stop.circle" : "play.circle"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.red : Color.green)
                    .cornerRadius(12)
                }
                .accessibilityIdentifier("webUpload.toggleServer")
                .accessibilityLabel(isRunning ? "Stop Server" : "Start Server")
            }

            if isRunning {
                HStack(spacing: 12) {
                    secondaryButton("QR Code", icon: "qrcode", identifier: "webUpload.qrCode", action: showQRCode)
                    secondaryButton("Help", icon: "questionmark.circle", identifier: "webUpload.help", action: showInstructions)
                }
            }
        }
    }

    private func secondaryButton(
        _ title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .accessibilityIdentifier(identifier)
    }
}

/// Confirms the person holding the phone before downloads are allowed, using Face ID or the
/// vault's own passcode. The device passcode is never accepted here.
struct WebExportUnlockSheet: View {
    let onUnlocked: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var credential = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("Allow downloads for 10 minutes")
                    .font(.headline)
                Text("Confirm it's you before the browser can pull files out of the vault.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if BiometricAuthManager.shared.canUseBiometrics() {
                    Button(action: authenticateWithBiometrics) {
                        Label(biometricButtonTitle, systemImage: biometricButtonIcon)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .accessibilityIdentifier("webUpload.exportFaceID")
                }

                SecureField("Vault passcode or password", text: $credential)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(verifyCredential)
                    .accessibilityIdentifier("webUpload.exportCredential")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button("Allow Downloads", action: verifyCredential)
                    .disabled(credential.isEmpty)
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if BiometricAuthManager.shared.canUseBiometrics() {
                    authenticateWithBiometrics()
                } else {
                    isFocused = true
                }
            }
        }
    }

    private var biometricButtonTitle: String {
        BiometricAuthManager.shared.biometricType() == .touchID ? "Use Touch ID" : "Use Face ID"
    }

    private var biometricButtonIcon: String {
        BiometricAuthManager.shared.biometricType() == .touchID ? "touchid" : "faceid"
    }

    private func authenticateWithBiometrics() {
        BiometricAuthManager.shared.authenticateWithBiometrics(
            reason: "Allow downloads from the web browser"
        ) { success, _ in
            if success {
                onUnlocked()
                dismiss()
            } else {
                isFocused = true
            }
        }
    }

    private func verifyCredential() {
        let result = KeychainManager.shared.validatePassword(credential)
        // The duress credential must never open a download window.
        guard result.isValid, !result.isFakeLogin else {
            credential = ""
            errorMessage = "That passcode is not right."
            return
        }
        onUnlocked()
        dismiss()
    }
}

struct WebUploadPairingCard: View {
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pairing Code:")
                .font(.headline)
            Text(code.isEmpty ? "------" : code)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .kerning(6)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("webUpload.pairingCode")
            Text("The browser asks for this code the first time it connects. It changes every time you start the server.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WebUploadExportSessionCard: View {
    let expiresAt: Date?
    let startSession: () -> Void
    let endSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloads:")
                .font(.headline)
            if let expiresAt {
                Text("Allowed until \(expiresAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Button("Stop Downloads", action: endSession)
                    .accessibilityIdentifier("webUpload.endExportSession")
            } else {
                Button("Allow Downloads for 10 Minutes", action: startSession)
                    .accessibilityIdentifier("webUpload.startExportSession")
            }
            Text("Downloads stay off until you allow them. Each file gets a single-use link, and the window closes when it expires or you leave the app.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WebUploadInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Upload Files:")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                InstructionStep(number: "1", text: "Make sure your device is on the same WiFi network")
                InstructionStep(number: "2", text: "Open a web browser on any device")
                InstructionStep(number: "3", text: "Navigate to the server URL above")
                InstructionStep(number: "4", text: "Drag and drop files or click to browse")
                InstructionStep(number: "5", text: "Click 'Upload Files' to transfer securely")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WebUploadSecurityNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Security Notice", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundColor(.orange)
            Text("• Files are uploaded securely to your device only\n• Server only runs on your local network\n• No files are sent to external servers\n• Stop the server when not in use")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct WebUploadQRCodeView: View {
    private enum QRCodeLayout {
        static let displaySize: CGFloat = 200
        static let renderScale: CGFloat = 10
    }

    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Scan QR Code").font(.title).fontWeight(.bold)
                Text("Scan this code with your phone's camera to quickly access the upload page")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                qrCode
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                Button("Copy URL") {
                    UIPasteboard.general.string = url
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var qrCode: some View {
        if let image = generateQRCode(from: url) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: QRCodeLayout.displaySize, height: QRCodeLayout.displaySize)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: QRCodeLayout.displaySize, height: QRCodeLayout.displaySize)
                .overlay {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                        Text("Failed to generate QR code")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "H"
        guard let image = filter.outputImage else { return nil }
        let scaledImage = image.transformed(
            by: CGAffineTransform(scaleX: QRCodeLayout.renderScale, y: QRCodeLayout.renderScale)
        )
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started").font(.title2).fontWeight(.bold)
                        Text("Follow these steps to upload files from any device:")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        DetailedInstructionStep(number: "1", title: "Network Connection", description: "Ensure both your iPhone and the device you want to upload from are connected to the same WiFi network.")
                        DetailedInstructionStep(number: "2", title: "Start the Server", description: "Tap 'Start Server' to begin accepting file uploads. The server will only run while this app is active.")
                        DetailedInstructionStep(number: "3", title: "Access Upload Page", description: "On any device, open a web browser and navigate to the server URL. You can also scan the QR code for quick access.")
                        DetailedInstructionStep(number: "4", title: "Upload Files", description: "Drag and drop files onto the upload area, or click to browse and select files. Multiple files can be uploaded at once.")
                        DetailedInstructionStep(number: "5", title: "Secure Transfer", description: "Files are encrypted and stored securely in your vault. They never leave your local network during the upload process.")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supported File Types").font(.title2).fontWeight(.bold)
                        Text("• Images: JPEG, PNG, HEIC, GIF\n• Videos: MP4, MOV, M4V\n• Documents: PDF, DOC, DOCX, TXT\n• And many more...")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Troubleshooting").font(.title2).fontWeight(.bold)
                        Text("• Make sure both devices are on the same WiFi network\n• Check that your firewall isn't blocking connections\n• Try restarting the server if connections fail\n• Ensure the app stays active during uploads")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailedInstructionStep: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
