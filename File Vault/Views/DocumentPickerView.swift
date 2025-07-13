//
//  DocumentPickerView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: ([(Data, String)]) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.image,
            UTType.movie,
            UTType.video,
            UTType.pdf,
            UTType.text,
            UTType.data
        ], asCopy: false)
        
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            // Process URLs and immediately read their data to avoid security-scoped resource issues
            DispatchQueue.global(qos: .userInitiated).async {
                var processedData: [(Data, String)] = []
                
                for url in urls {
                    // Start accessing security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        print("Error: Could not access security-scoped resource for \(url)")
                        continue
                    }
                    
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    do {
                        // Immediately read the file data while we have access
                        let data = try Data(contentsOf: url)
                        let fileName = url.lastPathComponent
                        
                        processedData.append((data, fileName))
                        print("Successfully read file data: \(fileName), size: \(data.count) bytes")
                        
                    } catch {
                        print("Error reading file \(url.lastPathComponent): \(error)")
                    }
                }
                
                // Call completion on main thread with the processed data
                DispatchQueue.main.async {
                    self.parent.completion(processedData)
                }
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 