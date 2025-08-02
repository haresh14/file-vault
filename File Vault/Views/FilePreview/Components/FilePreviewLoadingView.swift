//
//  FilePreviewLoadingView.swift
//  File Vault
//
//  Loading view for file preview
//

import SwiftUI

struct FilePreviewLoadingView: View {
    let fileName: String?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Loading \(fileName ?? "file")...")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
}

#Preview {
    FilePreviewLoadingView(fileName: "sample.pdf")
        .background(Color.black)
}