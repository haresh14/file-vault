//
//  WebUploadTabView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct WebUploadTabView: View {
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
                                .fill(webServer.isRunning ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text(webServer.isRunning ? "Server Running" : "Server Stopped")
                                .font(.headline)
                                .foregroundColor(webServer.isRunning ? .green : .red)
                            
                            Spacer()
                        }
                        
                        if webServer.isRunning {
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
                                Image(systemName: webServer.isRunning ? "stop.circle" : "play.circle")
                                Text(webServer.isRunning ? "Stop Server" : "Start Server")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(webServer.isRunning ? Color.red : Color.green)
                            .cornerRadius(12)
                        }
                        
                        if webServer.isRunning {
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
                    if webServer.isRunning {
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
        if webServer.isRunning {
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

#Preview {
    WebUploadTabView()
} 