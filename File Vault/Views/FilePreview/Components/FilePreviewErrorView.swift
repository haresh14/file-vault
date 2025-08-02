//
//  FilePreviewErrorView.swift
//  File Vault
//
//  Error view for file preview
//

import SwiftUI

struct FilePreviewErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Failed to Load File")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                onRetry()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    FilePreviewErrorView(
        message: "Network connection failed",
        onRetry: { }
    )
    .background(Color.black)
}