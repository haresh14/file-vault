//
//  FolderView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct FolderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                
                Text("No Folders Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create folders to organize your files")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    // TODO: Implement add folder functionality
                }) {
                    Text("Create Folder")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    FolderView()
} 