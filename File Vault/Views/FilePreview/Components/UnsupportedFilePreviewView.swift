//
//  UnsupportedFilePreviewView.swift
//  File Vault
//
//  Preview view for unsupported file types with QuickLook fallback
//

import SwiftUI

struct UnsupportedFilePreviewView: View {
    let vaultItem: VaultItem
    let canShareFile: Bool
    let onShareFile: () -> Void
    let onShowQuickLook: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 10) {
                Text("Preview Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("This file type cannot be previewed")
                    .font(.body)
                    .foregroundColor(.gray)
                
                if let fileName = vaultItem.fileName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            
            VStack(spacing: 15) {
                Button("Open with QuickLook") {
                    onShowQuickLook()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                if canShareFile {
                    Button(action: onShareFile) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share File")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    UnsupportedFilePreviewView(
        vaultItem: {
            let context = CoreDataManager.shared.context
            let item = VaultItem(context: context)
            item.fileName = "archive.zip"
            item.fileType = "application/zip"
            return item
        }(),
        canShareFile: true,
        onShareFile: { },
        onShowQuickLook: { }
    )
    .background(Color.black)
}