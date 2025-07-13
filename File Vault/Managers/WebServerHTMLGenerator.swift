//
//  WebServerHTMLGenerator.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation

extension WebServerManager {
    
    func getFolderContents(folderId: String?) -> (folders: [Folder], files: [VaultItem]) {
        let targetFolder: Folder?
        
        if let folderId = folderId, let uuid = UUID(uuidString: folderId) {
            targetFolder = CoreDataManager.shared.fetchFolder(by: uuid)
        } else {
            targetFolder = nil
        }
        
        let folders: [Folder]
        let files: [VaultItem]
        
        if let targetFolder = targetFolder {
            folders = targetFolder.subfoldersArray
            files = targetFolder.itemsArray
        } else {
            folders = CoreDataManager.shared.fetchRootFolders()
            files = CoreDataManager.shared.fetchVaultItems(in: nil)
        }
        
        return (folders: folders, files: files)
    }
    
    func generateBreadcrumbs(folderId: String?) -> String {
        guard let folderId = folderId, 
              let uuid = UUID(uuidString: folderId),
              let folder = CoreDataManager.shared.fetchFolder(by: uuid) else {
            return "<a onclick=\"navigateToFolder('')\">📁 Root</a>"
        }
        
        let breadcrumbPath = folder.breadcrumbPath
        var breadcrumbs = "<a onclick=\"navigateToFolder('')\">📁 Root</a>"
        
        for (index, pathFolder) in breadcrumbPath.enumerated() {
            let folderIdString = pathFolder.id?.uuidString ?? ""
            breadcrumbs += " > <a onclick=\"navigateToFolder('\(folderIdString)')\">\(pathFolder.displayName)</a>"
        }
        
        return breadcrumbs
    }
    
    func getFileIcon(fileType: String) -> String {
        if fileType.hasPrefix("image/") { return "🖼️" }
        if fileType.hasPrefix("video/") { return "🎥" }
        if fileType.hasPrefix("audio/") { return "🎵" }
        if fileType.contains("pdf") { return "📄" }
        if fileType.contains("word") || fileType.contains("document") { return "📝" }
        if fileType.contains("spreadsheet") || fileType.contains("excel") { return "📊" }
        if fileType.contains("zip") || fileType.contains("rar") { return "📦" }
        return "📄"
    }
    
    func formatFileSize(size: Int64) -> String {
        if size == 0 { return "0 Bytes" }
        let k: Double = 1024
        let sizes = ["Bytes", "KB", "MB", "GB"]
        let i = Int(floor(log(Double(size)) / log(k)))
        let formattedSize = Double(size) / pow(k, Double(i))
        return String(format: "%.1f %@", formattedSize, sizes[i])
    }
    
    func generateUploadHTML(currentFolderId: String? = nil) -> String {
        let (folders, files) = getFolderContents(folderId: currentFolderId)
        let breadcrumbs = generateBreadcrumbs(folderId: currentFolderId)
        
        var folderItems = ""
        for folder in folders {
            let itemCount = folder.totalItemCount
            let folderIdString = folder.id?.uuidString ?? ""
            let escapedFolderName = folder.displayName.replacingOccurrences(of: "'", with: "\\'")
            folderItems += """
                <div class="file-item" data-type="folder" data-id="\(folderIdString)" data-name="\(escapedFolderName)">
                    <div class="item-checkbox">
                        <input type="checkbox" class="item-select" onchange="updateSelectionState()">
                    </div>
                    <div class="file-icon">📁</div>
                    <div class="file-info" onclick="navigateToFolder('\(folderIdString)')" style="cursor: pointer; flex: 1;">
                        <div class="file-name">\(folder.displayName)</div>
                        <div class="file-meta">\(itemCount) items</div>
                    </div>
                    <div class="file-actions">
                        <button class="action-btn rename-btn" onclick="event.stopPropagation(); showRenameDialog('\(folderIdString)', '\(escapedFolderName)')" title="Rename folder">
                            ✏️
                        </button>
                        <button class="action-btn delete-btn" onclick="event.stopPropagation(); showDeleteConfirmation('folder', '\(folderIdString)', '\(escapedFolderName)')" title="Delete folder">
                            🗑️
                        </button>
                    </div>
                </div>
            """
        }
        
        var fileItems = ""
        for file in files {
            let fileIcon = getFileIcon(fileType: file.fileType ?? "")
            let fileSize = formatFileSize(size: file.fileSize)
            let fileName = file.fileName ?? "Unknown"
            let fileIdString = file.id?.uuidString ?? ""
            let escapedFileName = fileName.replacingOccurrences(of: "'", with: "\\'")
            fileItems += """
                <div class="file-item" data-type="file" data-id="\(fileIdString)" data-name="\(escapedFileName)">
                    <div class="item-checkbox">
                        <input type="checkbox" class="item-select" onchange="updateSelectionState()">
                    </div>
                    <div class="file-icon">\(fileIcon)</div>
                    <div class="file-info" style="flex: 1;">
                        <div class="file-name">\(fileName)</div>
                        <div class="file-meta">\(fileSize)</div>
                    </div>
                    <div class="file-actions">
                        <button class="action-btn delete-btn" onclick="showDeleteConfirmation('file', '\(fileIdString)', '\(escapedFileName)')" title="Delete file">
                            🗑️
                        </button>
                    </div>
                </div>
            """
        }
        
        let emptyState = (folders.isEmpty && files.isEmpty) ? """
            <div class="empty-state">
                <div class="icon">📂</div>
                <div>This folder is empty</div>
                <div style="margin-top: 10px; font-size: 14px;">Click "Upload Files" to add content</div>
            </div>
        """ : ""
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>File Vault - File Explorer</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    padding: 20px;
                }
                
                .container {
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                    padding: 30px;
                    max-width: 1100px;
                    width: 100%;
                    margin: 0 auto;
                    max-height: 90vh;
                    display: flex;
                    flex-direction: column;
                }
                
                .header {
                    text-align: center;
                    margin-bottom: 30px;
                }
                
                .title {
                    font-size: 28px;
                    font-weight: 700;
                    color: #333;
                    margin-bottom: 10px;
                }
                
                .breadcrumbs {
                    background: #f8f9fa;
                    padding: 12px 16px;
                    border-radius: 8px;
                    margin-bottom: 20px;
                    font-size: 14px;
                    color: #666;
                    border: 1px solid #e1e5e9;
                }
                
                .breadcrumbs a {
                    color: #667eea;
                    text-decoration: none;
                    cursor: pointer;
                }
                
                .breadcrumbs a:hover {
                    text-decoration: underline;
                }
                
                .explorer-container {
                    flex: 1;
                    display: flex;
                    flex-direction: column;
                    min-height: 0;
                }
                
                .explorer-header {
                    margin-bottom: 15px;
                }
                
                .header-buttons {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    width: 100%;
                }
                
                .action-buttons {
                    display: flex;
                    gap: 10px;
                }
                
                .selection-controls {
                    display: flex;
                    align-items: center;
                    gap: 15px;
                }
                
                .select-all-container {
                    display: flex;
                    align-items: center;
                    gap: 5px;
                    font-size: 14px;
                    cursor: pointer;
                    font-weight: 500;
                }
                
                .item-checkbox {
                    display: block;
                    margin-right: 10px;
                }
                
                .item-checkbox input[type="checkbox"] {
                    margin: 0;
                    cursor: pointer;
                    transform: scale(1.2);
                    accent-color: #667eea;
                    width: 18px;
                    height: 18px;
                }
                
                .select-all-container input[type="checkbox"] {
                    margin: 0 8px 0 0;
                    cursor: pointer;
                    transform: scale(1.3);
                    accent-color: #667eea;
                    width: 16px;
                    height: 16px;
                }
                
                .delete-selected-btn {
                    background: #dc3545;
                    color: white;
                }
                
                .delete-selected-btn:hover {
                    background: #c82333;
                }
                

                
                .action-button {
                    border: none;
                    padding: 10px 16px;
                    border-radius: 8px;
                    font-size: 14px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                }
                
                .upload-button {
                    background: #667eea;
                    color: white;
                }
                
                .upload-button:hover {
                    background: #5a6fd8;
                }
                
                .new-folder-btn {
                    background: #28a745;
                    color: white;
                }
                
                .new-folder-btn:hover {
                    background: #218838;
                }
                
                .file-actions {
                    display: flex;
                    gap: 5px;
                    align-items: center;
                }
                
                .action-btn {
                    background: none;
                    border: none;
                    font-size: 16px;
                    cursor: pointer;
                    padding: 5px;
                    border-radius: 4px;
                    transition: background 0.2s ease;
                }
                
                .action-btn:hover {
                    background: rgba(0, 0, 0, 0.1);
                }
                
                .rename-btn:hover {
                    background: rgba(255, 193, 7, 0.2);
                }
                
                .delete-btn:hover {
                    background: rgba(220, 53, 69, 0.2);
                }
                
                .file-list {
                    flex: 1;
                    overflow-y: auto;
                    border: 1px solid #e1e5e9;
                    border-radius: 8px;
                    background: #fafbfc;
                    min-height: 300px;
                }
                
                .file-item {
                    display: flex;
                    align-items: center;
                    padding: 12px 16px;
                    border-bottom: 1px solid #e1e5e9;
                    cursor: pointer;
                    transition: background 0.2s ease;
                }
                
                .file-item:hover {
                    background: #f0f2f5;
                }
                
                .file-item[onclick]:hover {
                    background: #e3f2fd;
                    transform: translateY(-1px);
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                
                .file-item:last-child {
                    border-bottom: none;
                }
                
                .file-icon {
                    font-size: 20px;
                    margin-right: 12px;
                    width: 24px;
                    text-align: center;
                }
                
                .file-info {
                    flex: 1;
                }
                
                .file-name {
                    font-weight: 500;
                    color: #333;
                    margin-bottom: 2px;
                }
                
                .file-meta {
                    font-size: 12px;
                    color: #666;
                }
                
                .empty-state {
                    text-align: center;
                    padding: 40px;
                    color: #666;
                }
                
                .empty-state .icon {
                    font-size: 48px;
                    margin-bottom: 16px;
                }
                
                .upload-dialog {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.5);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 1000;
                }
                
                .upload-dialog-content {
                    background: white;
                    border-radius: 16px;
                    width: 90%;
                    max-width: 500px;
                    max-height: 90vh;
                    overflow-y: auto;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.2);
                }
                
                .upload-dialog-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 20px;
                    border-bottom: 1px solid #e1e5e9;
                }
                
                .upload-dialog-header h3 {
                    margin: 0;
                    color: #333;
                }
                
                .close-button {
                    background: none;
                    border: none;
                    font-size: 24px;
                    cursor: pointer;
                    color: #666;
                    padding: 0;
                    width: 30px;
                    height: 30px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                
                .close-button:hover {
                    color: #333;
                }
                
                .upload-dialog-footer {
                    display: flex;
                    justify-content: flex-end;
                    gap: 10px;
                    padding: 20px;
                    border-top: 1px solid #e1e5e9;
                }
                
                .upload-area {
                    border: 3px dashed #ddd;
                    border-radius: 12px;
                    padding: 40px 20px;
                    margin: 20px;
                    transition: all 0.3s ease;
                    cursor: pointer;
                    text-align: center;
                    background: #fafafa;
                }
                
                .upload-area:hover {
                    border-color: #667eea;
                    background: #f0f4ff;
                }
                
                .upload-area.dragover {
                    border-color: #667eea;
                    background: #e6f0ff;
                    transform: scale(1.02);
                }
                
                .upload-icon {
                    font-size: 48px;
                    color: #ccc;
                    margin-bottom: 16px;
                }
                
                .upload-text {
                    font-size: 18px;
                    color: #666;
                    margin-bottom: 8px;
                }
                
                .upload-hint {
                    font-size: 14px;
                    color: #999;
                }
                
                #fileInput {
                    display: none;
                }
                
                .btn {
                    background: #667eea;
                    color: white;
                    border: none;
                    padding: 10px 20px;
                    border-radius: 8px;
                    font-size: 14px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                }
                
                .btn:hover {
                    background: #5a6fd8;
                }
                
                .btn-secondary {
                    background: #f8f9fa;
                    color: #495057;
                    border: 1px solid #dee2e6;
                }
                
                .btn-secondary:hover {
                    background: #e9ecef;
                }
                
                .selected-files {
                    margin: 20px;
                    max-height: 200px;
                    overflow-y: auto;
                }
                
                .selected-file-item {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 10px;
                    background: #f8f9fa;
                    border-radius: 8px;
                    margin-bottom: 8px;
                }
                
                .selected-file-info {
                    display: flex;
                    align-items: center;
                    flex: 1;
                }
                
                .selected-file-icon {
                    font-size: 18px;
                    margin-right: 10px;
                }
                
                .selected-file-name {
                    font-weight: 500;
                    color: #333;
                    margin-right: 10px;
                }
                
                .selected-file-size {
                    color: #666;
                    font-size: 12px;
                }
                
                .remove-file {
                    background: #dc3545;
                    color: white;
                    border: none;
                    border-radius: 50%;
                    width: 24px;
                    height: 24px;
                    cursor: pointer;
                    font-size: 14px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                
                .progress-bar {
                    width: calc(100% - 40px);
                    height: 6px;
                    background: #e9ecef;
                    border-radius: 3px;
                    margin: 20px;
                    overflow: hidden;
                }
                
                .progress-fill {
                    height: 100%;
                    background: #667eea;
                    width: 0%;
                    transition: width 0.3s ease;
                }
                
                .status-message {
                    margin: 20px;
                    padding: 12px;
                    border-radius: 8px;
                    font-weight: 500;
                    font-size: 14px;
                }
                
                .status-success {
                    background: #d4edda;
                    color: #155724;
                    border: 1px solid #c3e6cb;
                }
                
                .status-error {
                    background: #f8d7da;
                    color: #721c24;
                    border: 1px solid #f5c6cb;
                }
                
                .upload-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.7);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 2000;
                }
                
                .upload-progress-card {
                    background: white;
                    border-radius: 16px;
                    padding: 30px;
                    text-align: center;
                    min-width: 300px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.3);
                }
                
                .spinner {
                    width: 50px;
                    height: 50px;
                    border: 4px solid #f3f3f3;
                    border-top: 4px solid #667eea;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                    margin: 0 auto 20px;
                }
                
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
                
                .success-icon-large {
                    font-size: 60px;
                    color: #28a745;
                    margin-bottom: 20px;
                }
                
                .upload-progress-text {
                    font-size: 18px;
                    font-weight: 600;
                    color: #333;
                    margin-bottom: 10px;
                }
                
                .upload-progress-detail {
                    font-size: 14px;
                    color: #666;
                    margin-bottom: 20px;
                }
                
                .progress-percentage {
                    font-size: 24px;
                    font-weight: 700;
                    color: #667eea;
                    margin-bottom: 15px;
                }
                
                @media (max-width: 768px) {
                    .container {
                        padding: 20px;
                        margin: 10px;
                    }
                    
                    .title {
                        font-size: 24px;
                    }
                    
                    .upload-area {
                        padding: 30px 15px;
                        margin: 15px;
                    }
                    
                    .header-buttons {
                        flex-direction: column;
                        gap: 15px;
                        align-items: stretch;
                    }
                    
                    .action-buttons {
                        justify-content: center;
                    }
                    
                    .selection-controls {
                        flex-wrap: wrap;
                        gap: 10px;
                        justify-content: center;
                    }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 class="title">🔐 File Vault</h1>
                </div>
                
                <div class="explorer-container">
                    <div class="explorer-header">
                        <div class="header-buttons">
                            <div class="selection-controls">
                                <label class="select-all-container">
                                    <input type="checkbox" id="selectAllCheckbox" onchange="toggleSelectAll()">
                                    <span>Select All</span>
                                </label>
                                <button class="action-button delete-selected-btn" onclick="deleteSelectedItems()" id="deleteSelectedBtn" style="display: none;">🗑️ Delete Selected</button>
                            </div>
                            <div class="action-buttons">
                                <button class="action-button new-folder-btn" onclick="showNewFolderDialog()">📁 New Folder</button>
                                <button class="action-button upload-button" onclick="showUploadDialog()">📤 Upload Files</button>
                            </div>
                        </div>
                    </div>
                    
                    <div class="breadcrumbs">
                        \(breadcrumbs)
                    </div>
                    
                    <div class="file-list">
                        \(folderItems)
                        \(fileItems)
                        \(emptyState)
                    </div>
                </div>
            </div>
            
            <!-- Upload Dialog -->
            <div id="uploadDialog" class="upload-dialog" style="display: none;">
                <div class="upload-dialog-content">
                    <div class="upload-dialog-header">
                        <h3>Upload Files</h3>
                        <button class="close-button" onclick="hideUploadDialog()">×</button>
                    </div>
                    
                    <form id="uploadForm" enctype="multipart/form-data">
                        <div class="upload-area" id="uploadArea">
                            <div class="upload-icon">📁</div>
                            <div class="upload-text">Drop files here or click to browse</div>
                            <div class="upload-hint">Supports images, videos, documents and more</div>
                            <input type="file" id="fileInput" name="files" multiple accept="*/*">
                        </div>
                        
                        <div class="selected-files" id="selectedFiles" style="display: none;"></div>
                        
                        <div class="progress-bar" id="progressBar" style="display: none;">
                            <div class="progress-fill" id="progressFill"></div>
                        </div>
                        
                        <div id="statusMessage"></div>
                        
                        <div class="upload-dialog-footer">
                            <button type="button" class="btn btn-secondary" onclick="clearFiles()">Clear All</button>
                            <button type="submit" class="btn" id="uploadBtn" style="display: none;">Upload Files</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Upload Progress Overlay -->
            <div id="uploadOverlay" class="upload-overlay" style="display: none;">
                <div class="upload-progress-card">
                    <div id="uploadSpinner" class="spinner"></div>
                    <div id="uploadSuccessIcon" class="success-icon-large" style="display: none;">✅</div>
                    <div id="uploadProgressText" class="upload-progress-text">Uploading files...</div>
                    <div id="uploadProgressDetail" class="upload-progress-detail">Preparing upload...</div>
                    <div id="uploadProgressPercentage" class="progress-percentage" style="display: none;">0%</div>
                </div>
            </div>
            
            <!-- New Folder Dialog -->
            <div id="newFolderDialog" class="upload-dialog" style="display: none;">
                <div class="upload-dialog-content" style="max-width: 400px;">
                    <div class="upload-dialog-header">
                        <h3>Create New Folder</h3>
                        <button class="close-button" onclick="hideNewFolderDialog()">×</button>
                    </div>
                    <div style="padding: 20px;">
                        <input type="text" id="folderNameInput" placeholder="Enter folder name" style="width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px;">
                        <div style="margin-top: 15px; text-align: right;">
                            <button onclick="hideNewFolderDialog()" style="margin-right: 10px; padding: 8px 16px; border: 1px solid #ddd; background: white; border-radius: 4px; cursor: pointer;">Cancel</button>
                            <button onclick="createFolder()" style="padding: 8px 16px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer;">Create</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Rename Folder Dialog -->
            <div id="renameFolderDialog" class="upload-dialog" style="display: none;">
                <div class="upload-dialog-content" style="max-width: 400px;">
                    <div class="upload-dialog-header">
                        <h3>Rename Folder</h3>
                        <button class="close-button" onclick="hideRenameDialog()">×</button>
                    </div>
                    <div style="padding: 20px;">
                        <input type="text" id="renameFolderInput" placeholder="Enter new name" style="width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px;">
                        <div style="margin-top: 15px; text-align: right;">
                            <button onclick="hideRenameDialog()" style="margin-right: 10px; padding: 8px 16px; border: 1px solid #ddd; background: white; border-radius: 4px; cursor: pointer;">Cancel</button>
                            <button onclick="renameFolder()" style="padding: 8px 16px; background: #667eea; color: white; border: none; border-radius: 4px; cursor: pointer;">Rename</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Delete Confirmation Dialog -->
            <div id="deleteConfirmationDialog" class="upload-dialog" style="display: none;">
                <div class="upload-dialog-content" style="max-width: 500px;">
                    <div class="upload-dialog-header">
                        <h3>Confirm Deletion</h3>
                        <button class="close-button" onclick="hideDeleteConfirmation()">×</button>
                    </div>
                    <div style="padding: 20px;">
                        <div id="deleteMessage" style="margin-bottom: 20px; line-height: 1.5;"></div>
                        <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; padding: 10px; margin-bottom: 20px;">
                            <strong>⚠️ Warning:</strong> This action cannot be undone.
                        </div>
                        <div style="text-align: right;">
                            <button onclick="hideDeleteConfirmation()" style="margin-right: 10px; padding: 8px 16px; border: 1px solid #ddd; background: white; border-radius: 4px; cursor: pointer;">Cancel</button>
                            <button onclick="confirmDelete()" style="padding: 8px 16px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <script>
                const uploadArea = document.getElementById('uploadArea');
                const fileInput = document.getElementById('fileInput');
                const selectedFiles = document.getElementById('selectedFiles');
                const uploadBtn = document.getElementById('uploadBtn');
                const uploadForm = document.getElementById('uploadForm');
                const progressBar = document.getElementById('progressBar');
                const progressFill = document.getElementById('progressFill');
                const statusMessage = document.getElementById('statusMessage');
                const uploadDialog = document.getElementById('uploadDialog');
                const uploadOverlay = document.getElementById('uploadOverlay');
                const uploadSpinner = document.getElementById('uploadSpinner');
                const uploadSuccessIcon = document.getElementById('uploadSuccessIcon');
                const uploadProgressText = document.getElementById('uploadProgressText');
                const uploadProgressDetail = document.getElementById('uploadProgressDetail');
                const uploadProgressPercentage = document.getElementById('uploadProgressPercentage');
                
                let files = [];
                let currentFolderId = '\(currentFolderId?.replacingOccurrences(of: "'", with: "\\'") ?? "")';
                
                console.log('DEBUG: currentFolderId set to:', currentFolderId);
                console.log('DEBUG: currentFolderId type:', typeof currentFolderId);
                console.log('DEBUG: currentFolderId length:', currentFolderId.length);
                console.log('DEBUG: Raw folder ID from server: "\\(currentFolderId ?? "nil")"');
                console.log('DEBUG: currentFolderId === "":', currentFolderId === '');
                console.log('DEBUG: currentFolderId truthy check:', !!currentFolderId);
                
                // Test the folder ID immediately
                if (currentFolderId) {
                    console.log('DEBUG: Folder ID is truthy, value:', currentFolderId);
                } else {
                    console.log('DEBUG: Folder ID is falsy, value:', currentFolderId);
                }
                
                // Navigation functions
                function navigateToFolder(folderId) {
                    const url = folderId ? `/upload?folder=${folderId}` : '/upload';
                    window.location.href = url;
                }
                
                // Upload dialog functions
                function showUploadDialog() {
                    uploadDialog.style.display = 'flex';
                    resetUploadState();
                }
                
                function hideUploadDialog() {
                    uploadDialog.style.display = 'none';
                    resetUploadState();
                }
                
                function resetUploadState() {
                    files = [];
                    fileInput.value = '';
                    updateSelectedFiles();
                    updateUploadButton();
                    hideStatus();
                    hideProgress();
                    resetUploadButton();
                }
                
                // Click to browse files
                uploadArea.addEventListener('click', () => {
                    fileInput.click();
                });
                
                // Drag and drop functionality
                uploadArea.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    uploadArea.classList.add('dragover');
                });
                
                uploadArea.addEventListener('dragleave', () => {
                    uploadArea.classList.remove('dragover');
                });
                
                uploadArea.addEventListener('drop', (e) => {
                    e.preventDefault();
                    uploadArea.classList.remove('dragover');
                    
                    const droppedFiles = Array.from(e.dataTransfer.files);
                    addFiles(droppedFiles);
                });
                
                // File input change
                fileInput.addEventListener('change', (e) => {
                    const inputFiles = Array.from(e.target.files);
                    addFiles(inputFiles);
                });
                
                function addFiles(newFiles) {
                    files = [...files, ...newFiles];
                    updateSelectedFiles();
                    updateUploadButton();
                }
                
                function updateSelectedFiles() {
                    if (files.length === 0) {
                        selectedFiles.style.display = 'none';
                        return;
                    }
                    
                    selectedFiles.style.display = 'block';
                    selectedFiles.innerHTML = files.map((file, index) => {
                        const fileIcon = getFileIcon(file.type);
                        const fileSize = formatFileSize(file.size);
                        
                        return '<div class="selected-file-item">' +
                            '<div class="selected-file-info">' +
                                '<span class="selected-file-icon">' + fileIcon + '</span>' +
                                '<span class="selected-file-name">' + file.name + '</span>' +
                                '<span class="selected-file-size">' + fileSize + '</span>' +
                            '</div>' +
                            '<button type="button" class="remove-file" onclick="removeFile(' + index + ')">×</button>' +
                        '</div>';
                    }).join('');
                }
                
                function updateUploadButton() {
                    uploadBtn.style.display = files.length > 0 ? 'inline-block' : 'none';
                }
                
                function removeFile(index) {
                    files.splice(index, 1);
                    updateSelectedFiles();
                    updateUploadButton();
                    if (files.length === 0) {
                        resetUploadButton();
                    }
                }
                
                function clearFiles() {
                    files = [];
                    fileInput.value = '';
                    updateSelectedFiles();
                    updateUploadButton();
                    hideStatus();
                    resetUploadButton();
                }
                
                function resetUploadButton() {
                    uploadBtn.disabled = false;
                    uploadBtn.textContent = 'Upload Files';
                    hideProgress();
                }
                
                function getFileIcon(mimeType) {
                    if (mimeType.startsWith('image/')) return '🖼️';
                    if (mimeType.startsWith('video/')) return '🎥';
                    if (mimeType.startsWith('audio/')) return '🎵';
                    if (mimeType.includes('pdf')) return '📄';
                    if (mimeType.includes('word') || mimeType.includes('document')) return '📝';
                    if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return '📊';
                    if (mimeType.includes('zip') || mimeType.includes('rar')) return '📦';
                    return '📄';
                }
                
                function formatFileSize(bytes) {
                    if (bytes === 0) return '0 Bytes';
                    const k = 1024;
                    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
                    const i = Math.floor(Math.log(bytes) / Math.log(k));
                    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
                }
                
                function showStatus(message, isError = false) {
                    statusMessage.innerHTML = '<div class="status-message ' + (isError ? 'status-error' : 'status-success') + '">' + message + '</div>';
                }
                
                function hideStatus() {
                    statusMessage.innerHTML = '';
                }
                
                function showProgress(percent) {
                    progressBar.style.display = 'block';
                    progressFill.style.width = percent + '%';
                }
                
                function hideProgress() {
                    progressBar.style.display = 'none';
                    progressFill.style.width = '0%';
                }
                
                function showUploadOverlay() {
                    uploadOverlay.style.display = 'flex';
                    uploadSpinner.style.display = 'block';
                    uploadSuccessIcon.style.display = 'none';
                    uploadProgressText.textContent = 'Uploading files...';
                    uploadProgressDetail.textContent = 'Preparing upload...';
                    uploadProgressPercentage.style.display = 'none';
                }
                
                function updateUploadProgress(percent, uploadedCount, totalCount) {
                    uploadProgressPercentage.style.display = 'block';
                    uploadProgressPercentage.textContent = Math.round(percent) + '%';
                    uploadProgressDetail.textContent = `Uploading ${uploadedCount} of ${totalCount} files...`;
                }
                
                function showUploadSuccess(count) {
                    uploadSpinner.style.display = 'none';
                    uploadSuccessIcon.style.display = 'block';
                    uploadProgressText.textContent = 'Upload Complete!';
                    uploadProgressDetail.textContent = `Successfully uploaded ${count} file(s)`;
                    uploadProgressPercentage.style.display = 'none';
                }
                
                function hideUploadOverlay() {
                    uploadOverlay.style.display = 'none';
                }
                
                // Form submission
                uploadForm.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    
                    if (files.length === 0) {
                        showStatus('Please select files to upload', true);
                        return;
                    }
                    
                    const formData = new FormData();
                    
                    // Add current folder ID FIRST
                    console.log('DEBUG: About to check folder ID for form submission');
                    console.log('DEBUG: currentFolderId value:', currentFolderId);
                    console.log('DEBUG: currentFolderId !== "":', currentFolderId !== '');
                    console.log('DEBUG: Boolean check result:', currentFolderId && currentFolderId !== '');
                    
                    if (currentFolderId && currentFolderId !== '') {
                        console.log('DEBUG: Adding folder ID to form data:', currentFolderId);
                        formData.append('folderId', currentFolderId);
                        console.log('DEBUG: Folder ID added to form data');
                    } else {
                        console.log('DEBUG: No folder ID specified, uploading to root');
                        console.log('DEBUG: currentFolderId was empty or falsy:', currentFolderId);
                    }
                    
                    // Add files AFTER folder ID
                    files.forEach((file, index) => {
                        formData.append('files', file);
                        console.log('DEBUG: Added file to form data:', file.name);
                    });
                    
                    // Debug: Show all form data entries
                    console.log('DEBUG: Final form data contents:');
                    for (let pair of formData.entries()) {
                        console.log('DEBUG: Form field:', pair[0], '=', typeof pair[1] === 'object' ? pair[1].name : pair[1]);
                    }
                    
                    try {
                        uploadBtn.disabled = true;
                        uploadBtn.textContent = 'Uploading...';
                        showProgress(0);
                        hideStatus();
                        showUploadOverlay();
                        
                        const xhr = new XMLHttpRequest();
                        
                        xhr.upload.addEventListener('progress', (e) => {
                            if (e.lengthComputable) {
                                const percent = (e.loaded / e.total) * 100;
                                showProgress(percent);
                                updateUploadProgress(percent, 0, files.length);
                            }
                        });
                        
                        xhr.addEventListener('load', () => {
                            hideProgress();
                            resetUploadButton();
                            
                            try {
                                const response = JSON.parse(xhr.responseText);
                                if (response.success) {
                                    showUploadSuccess(files.length);
                                    clearFiles();
                                    
                                    // Hide overlay and refresh after showing success
                                    setTimeout(() => {
                                        hideUploadOverlay();
                                        hideUploadDialog();
                                        window.location.reload();
                                    }, 2000);
                                } else {
                                    hideUploadOverlay();
                                    showStatus(response.message || 'Upload failed', true);
                                }
                            } catch (e) {
                                console.error('Error parsing response:', e);
                                if (xhr.status === 200) {
                                    showUploadSuccess(files.length);
                                    clearFiles();
                                    setTimeout(() => {
                                        hideUploadOverlay();
                                        hideUploadDialog();
                                        window.location.reload();
                                    }, 2000);
                                } else {
                                    hideUploadOverlay();
                                    showStatus('Upload failed: ' + xhr.status, true);
                                }
                            }
                        });
                        
                        xhr.addEventListener('error', () => {
                            hideProgress();
                            resetUploadButton();
                            hideUploadOverlay();
                            showStatus('Upload failed: Network error', true);
                        });
                        
                        xhr.open('POST', '/upload', true);
                        
                        // Also send folder ID in header as backup
                        if (currentFolderId && currentFolderId !== '') {
                            xhr.setRequestHeader('X-Folder-ID', currentFolderId);
                            console.log('DEBUG: Added folder ID to header:', currentFolderId);
                        }
                        
                        xhr.send(formData);
                        
                    } catch (error) {
                        hideProgress();
                        resetUploadButton();
                        hideUploadOverlay();
                        showStatus('Upload failed: ' + error.message, true);
                    }
                });
                
                // Close dialog when clicking outside
                uploadDialog.addEventListener('click', (e) => {
                    if (e.target === uploadDialog) {
                        hideUploadDialog();
                    }
                });
                
                // Handle escape key
                document.addEventListener('keydown', (e) => {
                    if (e.key === 'Escape') {
                        if (uploadDialog.style.display === 'flex') {
                            hideUploadDialog();
                        } else if (newFolderDialog.style.display === 'flex') {
                            hideNewFolderDialog();
                        } else if (renameFolderDialog.style.display === 'flex') {
                            hideRenameDialog();
                        } else if (deleteConfirmationDialog.style.display === 'flex') {
                            hideDeleteConfirmation();
                        }
                    }
                });
                
                // Folder management variables
                const newFolderDialog = document.getElementById('newFolderDialog');
                const renameFolderDialog = document.getElementById('renameFolderDialog');
                const folderNameInput = document.getElementById('folderNameInput');
                const renameFolderInput = document.getElementById('renameFolderInput');
                let currentRenameFolderId = null;
                
                // New Folder Dialog Functions
                function showNewFolderDialog() {
                    newFolderDialog.style.display = 'flex';
                    folderNameInput.value = '';
                    folderNameInput.focus();
                }
                
                function hideNewFolderDialog() {
                    newFolderDialog.style.display = 'none';
                    folderNameInput.value = '';
                }
                
                function createFolder() {
                    const folderName = folderNameInput.value.trim();
                    if (!folderName) {
                        alert('Please enter a folder name');
                        return;
                    }
                    
                    const data = {
                        name: folderName,
                        parentId: currentFolderId || ''
                    };
                    
                    fetch('/api/folder/create', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    })
                    .then(response => response.json())
                    .then(result => {
                        if (result.success) {
                            hideNewFolderDialog();
                            window.location.reload();
                        } else {
                            alert('Error creating folder: ' + result.message);
                        }
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        alert('Error creating folder');
                    });
                }
                
                // Rename Folder Dialog Functions
                function showRenameDialog(folderId, currentName) {
                    currentRenameFolderId = folderId;
                    renameFolderInput.value = currentName;
                    renameFolderDialog.style.display = 'flex';
                    renameFolderInput.focus();
                    renameFolderInput.select();
                }
                
                function hideRenameDialog() {
                    renameFolderDialog.style.display = 'none';
                    renameFolderInput.value = '';
                    currentRenameFolderId = null;
                }
                
                function renameFolder() {
                    const newName = renameFolderInput.value.trim();
                    if (!newName) {
                        alert('Please enter a folder name');
                        return;
                    }
                    
                    if (!currentRenameFolderId) {
                        alert('No folder selected');
                        return;
                    }
                    
                    const data = {
                        folderId: currentRenameFolderId,
                        newName: newName
                    };
                    
                    fetch('/api/folder/rename', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    })
                    .then(response => response.json())
                    .then(result => {
                        if (result.success) {
                            // Update the folder name in the UI immediately
                            const folderItem = document.querySelector(`[data-id="${currentRenameFolderId}"]`);
                            if (folderItem) {
                                const folderNameElement = folderItem.querySelector('.file-name');
                                if (folderNameElement) {
                                    folderNameElement.textContent = newName;
                                }
                                // Update data attribute for future operations
                                folderItem.dataset.name = newName.replace(/'/g, "\\'");
                            }
                            hideRenameDialog();
                        } else {
                            alert('Error renaming folder: ' + result.message);
                        }
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        alert('Error renaming folder');
                    });
                }
                
                // Selection Management
                let pendingDeletion = null;
                
                function updateSelectionState() {
                    const checkboxes = document.querySelectorAll('.item-select');
                    const selectedCheckboxes = document.querySelectorAll('.item-select:checked');
                    const deleteSelectedBtn = document.getElementById('deleteSelectedBtn');
                    const selectAllCheckbox = document.getElementById('selectAllCheckbox');
                    
                    // Update delete button visibility
                    const hasSelections = selectedCheckboxes.length > 0;
                    deleteSelectedBtn.style.display = hasSelections ? 'inline-block' : 'none';
                    
                    // Update select all checkbox
                    if (selectedCheckboxes.length === checkboxes.length && checkboxes.length > 0) {
                        selectAllCheckbox.checked = true;
                        selectAllCheckbox.indeterminate = false;
                    } else if (selectedCheckboxes.length > 0) {
                        selectAllCheckbox.checked = false;
                        selectAllCheckbox.indeterminate = true;
                    } else {
                        selectAllCheckbox.checked = false;
                        selectAllCheckbox.indeterminate = false;
                    }
                    
                    console.log(`Selection updated: ${selectedCheckboxes.length} items selected`);
                }
                
                function toggleSelectAll() {
                    const selectAllCheckbox = document.getElementById('selectAllCheckbox');
                    const checkboxes = document.querySelectorAll('.item-select');
                    
                    checkboxes.forEach(checkbox => {
                        checkbox.checked = selectAllCheckbox.checked;
                    });
                    
                    updateSelectionState();
                }
                
                function getSelectedItems() {
                    const selectedCheckboxes = document.querySelectorAll('.item-select:checked');
                    const items = [];
                    
                    selectedCheckboxes.forEach(checkbox => {
                        const fileItem = checkbox.closest('.file-item');
                        items.push({
                            type: fileItem.dataset.type,
                            id: fileItem.dataset.id,
                            name: fileItem.dataset.name
                        });
                    });
                    
                    return items;
                }
                
                function clearAllSelections() {
                    const checkboxes = document.querySelectorAll('.item-select');
                    checkboxes.forEach(checkbox => {
                        checkbox.checked = false;
                    });
                    updateSelectionState();
                }
                
                // Delete Functions
                function showDeleteConfirmation(type, id, name) {
                    const items = [{type, id, name}];
                    showDeleteDialog(items);
                }
                
                function deleteSelectedItems() {
                    const items = getSelectedItems();
                    if (items.length === 0) return;
                    showDeleteDialog(items);
                }
                
                function showDeleteDialog(items) {
                    const deleteDialog = document.getElementById('deleteConfirmationDialog');
                    const deleteMessage = document.getElementById('deleteMessage');
                    
                    pendingDeletion = items;
                    
                    let message = '';
                    const folderCount = items.filter(item => item.type === 'folder').length;
                    const fileCount = items.filter(item => item.type === 'file').length;
                    
                    if (items.length === 1) {
                        const item = items[0];
                        message = `Are you sure you want to delete the ${item.type} "<strong>${item.name}</strong>"?`;
                        if (item.type === 'folder') {
                            message += ' This will also delete all files and subfolders inside it.';
                        }
                    } else {
                        message = `Are you sure you want to delete the following items?<br><br>`;
                        if (folderCount > 0) {
                            message += `• <strong>${folderCount}</strong> folder${folderCount > 1 ? 's' : ''} (including all contents)<br>`;
                        }
                        if (fileCount > 0) {
                            message += `• <strong>${fileCount}</strong> file${fileCount > 1 ? 's' : ''}`;
                        }
                    }
                    
                    deleteMessage.innerHTML = message;
                    deleteDialog.style.display = 'flex';
                }
                
                function hideDeleteConfirmation() {
                    const deleteDialog = document.getElementById('deleteConfirmationDialog');
                    deleteDialog.style.display = 'none';
                    pendingDeletion = null;
                }
                
                function confirmDelete() {
                    if (!pendingDeletion) return;
                    
                    const items = pendingDeletion;
                    hideDeleteConfirmation();
                    
                    if (items.length === 1) {
                        // Single item deletion
                        const item = items[0];
                        const deletePromise = item.type === 'folder' ? deleteFolder(item.id) : deleteFile(item.id);
                        
                        deletePromise
                            .then(result => {
                                if (result.success) {
                                    window.location.reload();
                                } else {
                                    alert('Error deleting item: ' + result.message);
                                }
                            })
                            .catch(error => {
                                console.error('Error deleting item:', error);
                                alert('Error deleting item');
                            });
                    } else {
                        // Bulk deletion
                        bulkDeleteItems(items)
                            .then(result => {
                                if (result.success) {
                                    // Clear selections before reload
                                    clearAllSelections();
                                    window.location.reload();
                                } else {
                                    alert('Error during bulk delete: ' + result.message);
                                }
                            })
                            .catch(error => {
                                console.error('Error during bulk delete:', error);
                                alert('Error during bulk delete');
                            });
                    }
                }
                
                function deleteFolder(folderId) {
                    const data = {
                        folderId: folderId
                    };
                    
                    return fetch('/api/folder/delete', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    })
                    .then(response => response.json());
                }
                
                function deleteFile(fileId) {
                    const data = {
                        fileId: fileId
                    };
                    
                    return fetch('/api/file/delete', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    })
                    .then(response => response.json());
                }
                
                function bulkDeleteItems(items) {
                    const data = {
                        items: items
                    };
                    
                    return fetch('/api/bulk/delete', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    })
                    .then(response => response.json());
                }
                
                // Handle Enter key for dialogs
                folderNameInput.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                        createFolder();
                    }
                });
                
                renameFolderInput.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                        renameFolder();
                    }
                });
                
                // Handle dialog click outside to close
                newFolderDialog.addEventListener('click', (e) => {
                    if (e.target === newFolderDialog) {
                        hideNewFolderDialog();
                    }
                });
                
                renameFolderDialog.addEventListener('click', (e) => {
                    if (e.target === renameFolderDialog) {
                        hideRenameDialog();
                    }
                });
                
                const deleteConfirmationDialog = document.getElementById('deleteConfirmationDialog');
                deleteConfirmationDialog.addEventListener('click', (e) => {
                    if (e.target === deleteConfirmationDialog) {
                        hideDeleteConfirmation();
                    }
                });
                
                // Add row click functionality
                document.addEventListener('click', (e) => {
                    const fileItem = e.target.closest('.file-item');
                    const folderItem = e.target.closest('.folder-item');
                    
                    if (fileItem || folderItem) {
                        // Don't trigger selection if clicking on delete button, rename button, or checkbox
                        if (e.target.closest('.delete-btn') || 
                            e.target.closest('.rename-btn') || 
                            e.target.type === 'checkbox' ||
                            e.target.closest('a[href]')) {
                            return;
                        }
                        
                        // Find the checkbox in this row
                        const checkbox = (fileItem || folderItem).querySelector('input[type="checkbox"]');
                        if (checkbox) {
                            checkbox.checked = !checkbox.checked;
                            updateSelectionState();
                        }
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    func generateStatusHTML() -> String {
        let storageInfo = FileStorageManager.shared.getStorageInfo()
        let formattedSize = ByteCountFormatter.string(fromByteCount: storageInfo.usedSpace, countStyle: .file)
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>File Vault - Status</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                
                .container {
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                    padding: 40px;
                    max-width: 500px;
                    width: 100%;
                    text-align: center;
                }
                
                .logo {
                    font-size: 48px;
                    margin-bottom: 20px;
                }
                
                h1 {
                    color: #333;
                    margin-bottom: 30px;
                    font-size: 32px;
                    font-weight: 600;
                }
                
                .stats {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 20px;
                    margin: 30px 0;
                }
                
                .stat-card {
                    background: #f8f9fa;
                    border-radius: 15px;
                    padding: 25px;
                    text-align: center;
                }
                
                .stat-number {
                    font-size: 32px;
                    font-weight: 700;
                    color: #667eea;
                    margin-bottom: 5px;
                }
                
                .stat-label {
                    color: #666;
                    font-size: 14px;
                    font-weight: 500;
                }
                
                .btn {
                    background: linear-gradient(45deg, #667eea, #764ba2);
                    color: white;
                    border: none;
                    padding: 15px 30px;
                    border-radius: 25px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    margin: 10px;
                    text-decoration: none;
                    display: inline-block;
                }
                
                .btn:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(0,0,0,0.2);
                }
                
                .btn-secondary {
                    background: #f8f9fa;
                    color: #495057;
                    border: 2px solid #dee2e6;
                }
                
                .server-info {
                    background: #e8f4fd;
                    border-radius: 15px;
                    padding: 20px;
                    margin: 20px 0;
                    border-left: 4px solid #667eea;
                }
                
                .server-info h3 {
                    color: #333;
                    margin-bottom: 10px;
                }
                
                .server-url {
                    font-family: 'Monaco', 'Menlo', monospace;
                    background: white;
                    padding: 10px;
                    border-radius: 8px;
                    font-size: 14px;
                    color: #667eea;
                    word-break: break-all;
                }
                
                @media (max-width: 768px) {
                    .container {
                        padding: 20px;
                        margin: 10px;
                    }
                    
                    .stats {
                        grid-template-columns: 1fr;
                    }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="logo">📊</div>
                <h1>Vault Status</h1>
                
                <div class="stats">
                    <div class="stat-card">
                        <div class="stat-number">\(storageInfo.fileCount)</div>
                        <div class="stat-label">Files Stored</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">\(formattedSize)</div>
                        <div class="stat-label">Storage Used</div>
                    </div>
                </div>
                
                <div class="server-info">
                    <h3>🌐 Server Address</h3>
                    <div class="server-url">\(serverURL)</div>
                </div>
                
                <div style="margin-top: 30px;">
                    <a href="/" class="btn">Upload Files</a>
                    <button class="btn btn-secondary" onclick="window.location.reload()">Refresh</button>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    func generateSuccessHTML(uploadedFiles: [String]) -> String {
        let filesList = uploadedFiles.map { "• \($0)" }.joined(separator: "<br>")
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Upload Successful - File Vault</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                
                .container {
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                    padding: 40px;
                    max-width: 500px;
                    width: 100%;
                    text-align: center;
                }
                
                .success-icon {
                    font-size: 80px;
                    margin-bottom: 20px;
                }
                
                h1 {
                    color: #28a745;
                    margin-bottom: 20px;
                    font-size: 32px;
                    font-weight: 600;
                }
                
                .message {
                    color: #666;
                    margin-bottom: 30px;
                    font-size: 18px;
                }
                
                .file-list {
                    background: #f8f9fa;
                    border-radius: 15px;
                    padding: 20px;
                    margin: 20px 0;
                    text-align: left;
                }
                
                .file-list h3 {
                    color: #333;
                    margin-bottom: 15px;
                    text-align: center;
                }
                
                .files {
                    color: #666;
                    line-height: 1.6;
                }
                
                .btn {
                    background: linear-gradient(45deg, #667eea, #764ba2);
                    color: white;
                    border: none;
                    padding: 15px 30px;
                    border-radius: 25px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    margin: 10px;
                    text-decoration: none;
                    display: inline-block;
                }
                
                .btn:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(0,0,0,0.2);
                }
                
                .btn-secondary {
                    background: #f8f9fa;
                    color: #495057;
                    border: 2px solid #dee2e6;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="success-icon">✅</div>
                <h1>Upload Successful!</h1>
                <p class="message">Your files have been securely stored in the vault.</p>
                
                <div class="file-list">
                    <h3>📁 Uploaded Files (\(uploadedFiles.count))</h3>
                    <div class="files">\(filesList)</div>
                </div>
                
                <div style="margin-top: 30px;">
                    <a href="/" class="btn">Upload More Files</a>
                    <a href="/status" class="btn btn-secondary">View Status</a>
                </div>
            </div>
            
            <script>
                // Auto redirect after 5 seconds
                setTimeout(() => {
                    window.location.href = '/';
                }, 5000);
            </script>
        </body>
        </html>
        """
    }
} 