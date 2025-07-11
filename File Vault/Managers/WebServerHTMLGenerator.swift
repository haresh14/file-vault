//
//  WebServerHTMLGenerator.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation

extension WebServerManager {
    
    func generateUploadHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>File Vault - Upload Files</title>
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
                    max-width: 600px;
                    width: 100%;
                    text-align: center;
                }
                
                .logo {
                    font-size: 48px;
                    margin-bottom: 20px;
                }
                
                h1 {
                    color: #333;
                    margin-bottom: 10px;
                    font-size: 32px;
                    font-weight: 600;
                }
                
                .subtitle {
                    color: #666;
                    margin-bottom: 40px;
                    font-size: 18px;
                }
                
                .upload-area {
                    border: 3px dashed #ddd;
                    border-radius: 15px;
                    padding: 60px 20px;
                    margin: 30px 0;
                    transition: all 0.3s ease;
                    cursor: pointer;
                    position: relative;
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
                    font-size: 64px;
                    color: #ccc;
                    margin-bottom: 20px;
                }
                
                .upload-text {
                    font-size: 20px;
                    color: #666;
                    margin-bottom: 10px;
                }
                
                .upload-hint {
                    font-size: 14px;
                    color: #999;
                }
                
                #fileInput {
                    display: none;
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
                
                .file-list {
                    margin-top: 30px;
                    text-align: left;
                }
                
                .file-item {
                    background: #f8f9fa;
                    border-radius: 10px;
                    padding: 15px;
                    margin: 10px 0;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                }
                
                .file-info {
                    display: flex;
                    align-items: center;
                }
                
                .file-icon {
                    font-size: 24px;
                    margin-right: 15px;
                }
                
                .file-name {
                    font-weight: 500;
                    color: #333;
                }
                
                .file-size {
                    color: #666;
                    font-size: 14px;
                    margin-left: 10px;
                }
                
                .remove-file {
                    background: #dc3545;
                    color: white;
                    border: none;
                    border-radius: 50%;
                    width: 30px;
                    height: 30px;
                    cursor: pointer;
                    font-size: 16px;
                }
                
                .progress-bar {
                    width: 100%;
                    height: 6px;
                    background: #e9ecef;
                    border-radius: 3px;
                    margin: 20px 0;
                    overflow: hidden;
                }
                
                .progress-fill {
                    height: 100%;
                    background: linear-gradient(45deg, #667eea, #764ba2);
                    width: 0%;
                    transition: width 0.3s ease;
                }
                
                .status-message {
                    margin-top: 20px;
                    padding: 15px;
                    border-radius: 10px;
                    font-weight: 500;
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
                
                @media (max-width: 768px) {
                    .container {
                        padding: 20px;
                        margin: 10px;
                    }
                    
                    h1 {
                        font-size: 24px;
                    }
                    
                    .upload-area {
                        padding: 40px 15px;
                    }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="logo">🔐</div>
                <h1>File Vault</h1>
                <p class="subtitle">Securely upload your files</p>
                
                <form id="uploadForm" enctype="multipart/form-data">
                    <div class="upload-area" id="uploadArea">
                        <div class="upload-icon">📁</div>
                        <div class="upload-text">Drop files here or click to browse</div>
                        <div class="upload-hint">Supports images, videos, documents and more</div>
                        <input type="file" id="fileInput" name="files" multiple accept="*/*">
                    </div>
                    
                    <div class="file-list" id="fileList" style="display: none;"></div>
                    
                    <div class="progress-bar" id="progressBar" style="display: none;">
                        <div class="progress-fill" id="progressFill"></div>
                    </div>
                    
                    <div id="statusMessage"></div>
                    
                    <button type="submit" class="btn" id="uploadBtn" style="display: none;">
                        Upload Files
                    </button>
                    
                    <button type="button" class="btn btn-secondary" onclick="clearFiles()">
                        Clear All
                    </button>
                </form>
                
                <div style="margin-top: 30px;">
                    <a href="/status" class="btn btn-secondary">View Status</a>
                </div>
            </div>
            
            <script>
                const uploadArea = document.getElementById('uploadArea');
                const fileInput = document.getElementById('fileInput');
                const fileList = document.getElementById('fileList');
                const uploadBtn = document.getElementById('uploadBtn');
                const uploadForm = document.getElementById('uploadForm');
                const progressBar = document.getElementById('progressBar');
                const progressFill = document.getElementById('progressFill');
                const statusMessage = document.getElementById('statusMessage');
                
                let selectedFiles = [];
                
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
                    
                    const files = Array.from(e.dataTransfer.files);
                    addFiles(files);
                });
                
                // File input change
                fileInput.addEventListener('change', (e) => {
                    const files = Array.from(e.target.files);
                    addFiles(files);
                });
                
                function addFiles(files) {
                    selectedFiles = [...selectedFiles, ...files];
                    updateFileList();
                    updateUploadButton();
                }
                
                function updateFileList() {
                    if (selectedFiles.length === 0) {
                        fileList.style.display = 'none';
                        return;
                    }
                    
                    fileList.style.display = 'block';
                    fileList.innerHTML = selectedFiles.map((file, index) => {
                        const fileIcon = getFileIcon(file.type);
                        const fileSize = formatFileSize(file.size);
                        
                        return '<div class="file-item">' +
                            '<div class="file-info">' +
                                '<span class="file-icon">' + fileIcon + '</span>' +
                                '<span class="file-name">' + file.name + '</span>' +
                                '<span class="file-size">' + fileSize + '</span>' +
                            '</div>' +
                            '<button type="button" class="remove-file" onclick="removeFile(' + index + ')">×</button>' +
                        '</div>';
                    }).join('');
                }
                
                function updateUploadButton() {
                    uploadBtn.style.display = selectedFiles.length > 0 ? 'inline-block' : 'none';
                }
                
                function removeFile(index) {
                    selectedFiles.splice(index, 1);
                    updateFileList();
                    updateUploadButton();
                    if (selectedFiles.length === 0) {
                        resetUploadButton();
                    }
                }
                
                function clearFiles() {
                    selectedFiles = [];
                    fileInput.value = '';
                    updateFileList();
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
                    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
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
                
                // Form submission
                uploadForm.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    
                    if (selectedFiles.length === 0) {
                        showStatus('Please select files to upload', true);
                        return;
                    }
                    
                    const formData = new FormData();
                    selectedFiles.forEach((file, index) => {
                        formData.append('files', file);
                    });
                    
                    try {
                        uploadBtn.disabled = true;
                        uploadBtn.textContent = 'Uploading...';
                        showProgress(0);
                        hideStatus();
                        
                        const xhr = new XMLHttpRequest();
                        
                        xhr.upload.addEventListener('progress', (e) => {
                            if (e.lengthComputable) {
                                const percent = (e.loaded / e.total) * 100;
                                showProgress(percent);
                            }
                        });
                        
                        xhr.addEventListener('load', () => {
                            hideProgress();
                            resetUploadButton();
                            
                            if (xhr.status === 200) {
                                showStatus('Successfully uploaded ' + selectedFiles.length + ' file(s)!');
                                clearFiles();
                            } else {
                                showStatus('Upload failed. Please try again.', true);
                            }
                        });
                        
                        xhr.addEventListener('error', () => {
                            hideProgress();
                            resetUploadButton();
                            showStatus('Upload failed. Please check your connection.', true);
                        });
                        
                        xhr.open('POST', '/upload');
                        xhr.send(formData);
                        
                    } catch (error) {
                        hideProgress();
                        resetUploadButton();
                        showStatus('Upload failed: ' + error.message, true);
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