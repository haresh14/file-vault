//
//  WebUploadView.swift
//  File Vault
//
//  Created on 11/07/25.
//

import SwiftUI
import Network

struct WebUploadView: View {
    @StateObject private var webServer = WebServerManager.shared
    @State private var showQRCode = false
    @State private var showInstructions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
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
                    
                    // Server Status Card
                    VStack(spacing: 16) {
                        HStack {
                            Circle()
                                .fill(webServer.isServerRunning ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text(webServer.isServerRunning ? "Server Running" : "Server Stopped")
                                .font(.headline)
                                .foregroundColor(webServer.isServerRunning ? .green : .red)
                            
                            Spacer()
                        }
                        
                        if webServer.isServerRunning {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Server URL:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(webServer.serverURL)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    
                                    Button(action: copyURL) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
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
                    
                    // Control Buttons
                    VStack(spacing: 12) {
                        Button(action: toggleServer) {
                            HStack {
                                Image(systemName: webServer.isServerRunning ? "stop.circle" : "play.circle")
                                Text(webServer.isServerRunning ? "Stop Server" : "Start Server")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(webServer.isServerRunning ? Color.red : Color.green)
                            .cornerRadius(12)
                        }
                        
                        if webServer.isServerRunning {
                            HStack(spacing: 12) {
                                Button(action: { showQRCode = true }) {
                                    HStack {
                                        Image(systemName: "qrcode")
                                        Text("QR Code")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { showInstructions = true }) {
                                    HStack {
                                        Image(systemName: "questionmark.circle")
                                        Text("Help")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Instructions
                    if webServer.isServerRunning {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Upload Files:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
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
                    
                    // Security Notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.orange)
                            Text("Security Notice")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("• Files are uploaded securely to your device only\n• Server only runs on your local network\n• No files are sent to external servers\n• Stop the server when not in use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Web Upload")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeView(url: webServer.serverURL)
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
    }
    
    private func toggleServer() {
        if webServer.isServerRunning {
            webServer.stopServer()
        } else {
            webServer.startServer()
        }
    }
    
    private func copyURL() {
        UIPasteboard.general.string = webServer.serverURL
        
        // Show feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
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
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct QRCodeView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Scan QR Code")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Scan this code with your phone's camera to quickly access the upload page")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // QR Code placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("QR Code")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Follow these steps to upload files from any device:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        DetailedInstructionStep(
                            number: "1",
                            title: "Network Connection",
                            description: "Ensure both your iPhone and the device you want to upload from are connected to the same WiFi network."
                        )
                        
                        DetailedInstructionStep(
                            number: "2",
                            title: "Start the Server",
                            description: "Tap 'Start Server' to begin accepting file uploads. The server will only run while this app is active."
                        )
                        
                        DetailedInstructionStep(
                            number: "3",
                            title: "Access Upload Page",
                            description: "On any device, open a web browser and navigate to the server URL. You can also scan the QR code for quick access."
                        )
                        
                        DetailedInstructionStep(
                            number: "4",
                            title: "Upload Files",
                            description: "Drag and drop files onto the upload area, or click to browse and select files. Multiple files can be uploaded at once."
                        )
                        
                        DetailedInstructionStep(
                            number: "5",
                            title: "Secure Transfer",
                            description: "Files are encrypted and stored securely in your vault. They never leave your local network during the upload process."
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supported File Types")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("• Images: JPEG, PNG, HEIC, GIF\n• Videos: MP4, MOV, M4V\n• Documents: PDF, DOC, DOCX, TXT\n• And many more...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Troubleshooting")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("• Make sure both devices are on the same WiFi network\n• Check that your firewall isn't blocking connections\n• Try restarting the server if connections fail\n• Ensure the app stays active during uploads")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WebUploadView()
} 