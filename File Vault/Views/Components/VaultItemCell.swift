//
//  VaultItemCell.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import AVFoundation

/// Reusable cell component for displaying vault items in grid
struct VaultItemCell: View {
    let item: VaultItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                } else if isLoadingThumbnail {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    // Show appropriate icon based on file type
                    Image(systemName: getFileIcon(for: item))
                        .font(.largeTitle)
                        .foregroundColor(getFileIconColor(for: item))
                }
                
                // File type indicator
                if item.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(4)
                    }
                } else if item.isDocument || item.isAudio {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: item.isDocument ? "doc.fill" : "music.note")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(4)
                    }
                }
                
                // Selection indicator
                if isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundColor(isSelected ? .blue : .gray)
                            }
                            .padding(2)
                        }
                    }
                }
            }
            .cornerRadius(4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFileIcon(for item: VaultItem) -> String {
        if item.isImage {
            return "photo.fill"
        } else if item.isVideo {
            return "video.fill"
        } else if item.isAudio {
            return "music.note"
        } else if item.isDocument {
            // More specific document icons based on file type
            guard let fileType = item.fileType?.lowercased() else { return "doc.fill" }
            
            if fileType.contains("pdf") {
                return "doc.richtext.fill"
            } else if fileType.contains("word") || fileType.contains("doc") {
                return "doc.text.fill"
            } else if fileType.contains("excel") || fileType.contains("sheet") {
                return "tablecells.fill"
            } else if fileType.contains("powerpoint") || fileType.contains("presentation") {
                return "rectangle.on.rectangle.angled.fill"
            } else if fileType.contains("zip") || fileType.contains("rar") || fileType.contains("7z") {
                return "archivebox.fill"
            } else if fileType.contains("text") || fileType.contains("txt") {
                return "doc.plaintext.fill"
            } else {
                return "doc.fill"
            }
        } else {
            return "questionmark.circle.fill"
        }
    }
    
    private func getFileIconColor(for item: VaultItem) -> Color {
        if item.isImage {
            return .blue
        } else if item.isVideo {
            return .purple
        } else if item.isAudio {
            return .green
        } else if item.isDocument {
            return .orange
        } else {
            return .gray
        }
    }
    
    private func loadThumbnail() {
        // Loading thumbnail for item
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: item)
            
            DispatchQueue.main.async {
                if let data = loadedThumbnail {
                    self.thumbnail = UIImage(data: data)
                } else {
                    self.thumbnail = nil
                }
                self.isLoadingThumbnail = false
                
                if loadedThumbnail == nil {
                    // Try to regenerate thumbnail if it's missing
                    if item.thumbnailFileName == nil || item.thumbnailFileName?.isEmpty == true {
                        self.regenerateThumbnail()
                    }
                }
            }
        }
    }
    
    private func regenerateThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let fileData = try FileStorageManager.shared.loadFile(vaultItem: item)
                
                if item.isImage {
                    // Generate image thumbnail
                    if let image = UIImage(data: fileData) {
                        let thumbnailSize = CGSize(width: 200, height: 200)
                        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                        
                        let thumbnail = renderer.image { context in
                            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                        }
                        
                        DispatchQueue.main.async {
                            self.thumbnail = thumbnail
                        }
                    }
                } else if item.isVideo {
                    // Generate video thumbnail
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString + ".mov")
                    
                    try fileData.write(to: tempURL)
                    defer { try? FileManager.default.removeItem(at: tempURL) }
                    
                    let asset = AVURLAsset(url: tempURL)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    
                    let time = CMTime(seconds: 1, preferredTimescale: 60)
                    
                    if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                        let thumbnail = UIImage(cgImage: cgImage)
                        
                        DispatchQueue.main.async {
                            self.thumbnail = thumbnail
                        }
                    }
                }
            } catch {
                print("Error regenerating thumbnail: \(error)")
            }
        }
    }
}