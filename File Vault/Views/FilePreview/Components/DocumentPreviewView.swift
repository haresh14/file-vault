//
//  DocumentPreviewView.swift
//  File Vault
//
//  Document preview components for PDFs, text files, and other documents
//

import SwiftUI
import PDFKit

struct DocumentPreviewView: View {
    let vaultItem: VaultItem
    let fileData: Data?
    @Binding var showingQuickLook: Bool
    @Binding var temporaryFileURL: URL?
    
    var body: some View {
        Group {
            if vaultItem.fileType == "application/pdf", let fileData = fileData {
                PDFPreviewView(data: fileData)
            } else if vaultItem.fileType == "text/plain", let fileData = fileData {
                TextPreviewView(data: fileData, fileName: vaultItem.fileName)
            } else {
                // Use QuickLook for other document types
                DocumentQuickLookView(
                    fileData: fileData,
                    fileName: vaultItem.fileName,
                    fileType: vaultItem.fileType,
                    showingQuickLook: $showingQuickLook,
                    temporaryFileURL: $temporaryFileURL
                )
            }
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
    let data: Data
    @State private var pdfDocument: PDFDocument?
    
    var body: some View {
        Group {
            if let pdfDocument = pdfDocument {
                PDFKitView(document: pdfDocument)
            } else {
                Text("Failed to load PDF")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            pdfDocument = PDFDocument(data: data)
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.black
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // No updates needed
    }
}

// MARK: - Text Preview

struct TextPreviewView: View {
    let data: Data
    let fileName: String?
    @State private var textContent: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let fileName = fileName {
                    Text(fileName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Text(textContent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black)
        .onAppear {
            loadTextContent()
        }
    }
    
    private func loadTextContent() {
        if let content = String(data: data, encoding: .utf8) {
            textContent = content
        } else if let content = String(data: data, encoding: .ascii) {
            textContent = content
        } else {
            textContent = "Unable to decode text file"
        }
    }
}

// MARK: - QuickLook Integration

struct DocumentQuickLookView: View {
    let fileData: Data?
    let fileName: String?
    let fileType: String?
    @Binding var showingQuickLook: Bool
    @Binding var temporaryFileURL: URL?
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: documentIcon)
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                Text(fileName ?? "Document")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let fileType = fileType {
                    Text(fileType.uppercased())
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            
            Button("Open with QuickLook") {
                createTemporaryFile()
                showingQuickLook = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
    
    private var documentIcon: String {
        guard let fileType = fileType else { return "doc" }
        
        switch fileType {
        case "application/pdf":
            return "doc.richtext"
        case let type where type.contains("word"):
            return "doc.richtext"
        case let type where type.contains("excel") || type.contains("spreadsheet"):
            return "tablecells"
        case let type where type.contains("powerpoint") || type.contains("presentation"):
            return "rectangle.on.rectangle"
        case "text/plain":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }
    
    private func createTemporaryFile() {
        guard let fileData = fileData,
              let fileName = fileName else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try fileData.write(to: tempURL)
            temporaryFileURL = tempURL
        } catch {
            print("Failed to create temporary file: \(error)")
        }
    }
}

#Preview {
    DocumentQuickLookView(
        fileData: Data(),
        fileName: "sample.docx",
        fileType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        showingQuickLook: .constant(false),
        temporaryFileURL: .constant(nil)
    )
    .background(Color.black)
}