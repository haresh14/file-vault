//
//  SheetView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import PhotosUI

/// Collection of reusable sheet components
struct SheetView {
    
    /// Standard sheet header with title and dismiss button
    struct Header: View {
        let title: String
        let onDismiss: () -> Void
        
        var body: some View {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    /// Action sheet for sorting options
    struct SortActionSheet: View {
        let currentSort: String
        let sortOptions: [(title: String, value: String)]
        let onSelection: (String) -> Void
        let onDismiss: () -> Void
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    Header(title: "Sort Options", onDismiss: onDismiss)
                    
                    Divider()
                    
                    LazyVStack(spacing: 0) {
                        ForEach(sortOptions, id: \.value) { option in
                            Button(action: {
                                onSelection(option.value)
                                onDismiss()
                            }) {
                                HStack {
                                    Text(option.title)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if option.value == currentSort {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if option.value != sortOptions.last?.value {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    /// Action sheet for adding files
    struct AddActionSheet: View {
        let onPhotoPicker: () -> Void
        let onDocumentPicker: () -> Void
        let onWebUpload: (() -> Void)?
        let onDismiss: () -> Void
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    Header(title: "Add Files", onDismiss: onDismiss)
                    
                    Divider()
                    
                    VStack(spacing: 16) {
                        ActionButton(
                            title: "Import Photos",
                            subtitle: "Select photos from your library",
                            icon: "photo.on.rectangle",
                            color: .blue,
                            action: {
                                onPhotoPicker()
                                onDismiss()
                            }
                        )
                        
                        ActionButton(
                            title: "Import Documents",
                            subtitle: "Choose files from Files app",
                            icon: "doc.badge.plus",
                            color: .green,
                            action: {
                                onDocumentPicker()
                                onDismiss()
                            }
                        )
                        
                        if let onWebUpload = onWebUpload {
                            ActionButton(
                                title: "Web Upload",
                                subtitle: "Upload via web interface",
                                icon: "globe",
                                color: .orange,
                                action: {
                                    onWebUpload()
                                    onDismiss()
                                }
                            )
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    /// Reusable action button for sheets
    struct ActionButton: View {
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    /// Generic container for custom sheet content
    struct Container<Content: View>: View {
        let title: String
        let onDismiss: () -> Void
        let content: Content
        
        init(title: String, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
            self.title = title
            self.onDismiss = onDismiss
            self.content = content()
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    Header(title: title, onDismiss: onDismiss)
                    
                    Divider()
                    
                    content
                }
            }
            .presentationDragIndicator(.visible)
        }
    }
    
    /// Instructions sheet
    struct InstructionsSheet: View {
        let instructions: [String]
        let onDismiss: () -> Void
        
        var body: some View {
            Container(title: "Instructions", onDismiss: onDismiss) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(width: 24, alignment: .leading)
                                
                                Text(instruction)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    /// QR Code display sheet
    struct QRCodeSheet: View {
        let qrCodeContent: String
        let title: String
        let onDismiss: () -> Void
        
        var body: some View {
            Container(title: title, onDismiss: onDismiss) {
                VStack(spacing: 24) {
                    Spacer()
                    
                    // QR Code would be generated here
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Text("QR")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text(qrCodeContent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Copy URL") {
                        UIPasteboard.general.string = qrCodeContent
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

/// Universal sheet router for handling different sheet types
struct UniversalSheetRouter: View {
    let sheetType: SheetType
    let onDismiss: () -> Void
    
    // Optional handlers - should be passed from parent view
    var onPhotoSelection: (([PHPickerResult]) -> Void)?
    var onDocumentSelection: (([(Data, String)]) -> Void)?
    var onSortSelection: ((String) -> Void)?
    var currentSortOption: String = ""
    var sortOptions: [(title: String, value: String)] = []
    
    var body: some View {
        Group {
            switch sheetType {
            case .photoPicker:
                PhotoPickerView { results in
                    onPhotoSelection?(results)
                    onDismiss()
                }
                
            case .documentPicker:
                DocumentPickerView { documents in
                    onDocumentSelection?(documents)
                    onDismiss()
                }
                
            case .sortActionSheet:
                SheetView.SortActionSheet(
                    currentSort: currentSortOption,
                    sortOptions: sortOptions,
                    onSelection: { selection in
                        onSortSelection?(selection)
                    },
                    onDismiss: onDismiss
                )
                
            case .addActionSheet:
                SheetView.AddActionSheet(
                    onPhotoPicker: {
                        onPhotoSelection?([])
                    },
                    onDocumentPicker: {
                        onDocumentSelection?([])
                    },
                    onWebUpload: nil,
                    onDismiss: onDismiss
                )
                
            case .instructions:
                SheetView.InstructionsSheet(
                    instructions: [
                        "Connect to the same Wi-Fi network",
                        "Open your web browser",
                        "Enter the URL shown below",
                        "Upload your files"
                    ],
                    onDismiss: onDismiss
                )
                
            case .qrCode:
                SheetView.QRCodeSheet(
                    qrCodeContent: "http://192.168.1.100:8080",
                    title: "Upload URL",
                    onDismiss: onDismiss
                )
                
            default:
                Text("Sheet not implemented")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}