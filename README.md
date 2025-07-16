# File Vault - Secure Photo & Video Storage iOS App

A secure vault iOS application to store and manage photos and videos with biometric and passcode protection.

## 🚀 Quick Start for Beginners

**New to iOS development?** Check out our [Developer Guide](DEVELOPER_GUIDE.md) for detailed step-by-step instructions!

### Prerequisites
- Mac computer with macOS
- Xcode installed (free from Mac App Store)
- iOS device or simulator

### Getting Started
1. Open `File Vault.xcodeproj` in Xcode
2. Follow the [Developer Guide](DEVELOPER_GUIDE.md#adding-privacy-permissions) to add privacy permissions
3. Press the ▶️ Play button to run the app

## Features Implemented

### ✅ Complete Features
- **Core Data Setup**: Created data models for VaultItem and Folder with proper relationships
- **Keychain Integration**: Secure password storage using iOS Keychain Services
- **Biometric Authentication**: Face ID/Touch ID support using LocalAuthentication framework
- **Passcode Protection**: Custom passcode entry UI with secure text fields
- **Authentication Flow**: Combined biometric and passcode authentication with automatic lock on app backgrounding
- **File Storage**: Secure encrypted file storage with AES-GCM encryption
- **Photo/Video Import**: Import from photo library with thumbnail generation
- **Media Viewer**: Unified photo and video viewer with zoom, pan, and auto-play
- **Web Upload**: Local web server for browser-based file uploads
- **Security Features**: Screenshot protection, screen recording detection, app backgrounding protection

## Project Structure

```
File Vault/
├── Models/
│   ├── FileVault.xcdatamodeld/      # Core Data model
│   ├── VaultItem+CoreDataClass.swift
│   ├── VaultItem+CoreDataProperties.swift
│   ├── Folder+CoreDataClass.swift
│   └── Folder+CoreDataProperties.swift
├── Managers/
│   ├── CoreDataManager.swift         # Core Data operations
│   └── BiometricAuthManager.swift    # Biometric authentication
├── Utilities/
│   └── KeychainManager.swift         # Keychain wrapper
├── Views/
│   └── PasscodeView.swift           # Passcode entry UI
├── ContentView.swift                 # Main app view with auth flow
└── File_VaultApp.swift              # App entry point
```

## Setup Instructions

### For Beginners
Please refer to our comprehensive [Developer Guide](DEVELOPER_GUIDE.md) which includes:
- How to open the project in Xcode
- Step-by-step instructions for adding privacy permissions
- How to build and run the app
- Common Xcode tasks and troubleshooting

### Quick Setup (Experienced Developers)
1. Open `File Vault.xcodeproj` in Xcode
2. Add Face ID privacy key to Info.plist:
   - `NSFaceIDUsageDescription`
3. Build and run (Cmd+R)

## Security Features

- **Keychain Storage**: Passwords are securely stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Biometric Authentication**: Optional Face ID/Touch ID support
- **Auto-lock**: App automatically locks after 30 seconds in background
- **Core Data Encryption**: Data protection enabled with `FileProtectionType.complete`
- **Privacy-First Photo Access**: Uses Apple's secure PHPickerViewController which runs out-of-process, ensuring the app never has direct access to your photo library

## Current Issues (TODO)

- [ ] Fix thumbnail stretching/squeezing in gallery view
- [ ] Fix swipe navigation on images in photo viewer
- [ ] Fix video player white screen on first load
- [ ] Fix video brightness/color rendering issues
- [ ] Add missing video player controls (seek bar, volume)
- [ ] Fix video pinch zoom functionality
- [ ] Fix video double-tap zoom functionality

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Testing

To test the authentication flow:
1. Launch the app - you'll be prompted to create a passcode
2. Enter a passcode (minimum 4 characters)
3. Enable biometric authentication in Settings
4. Background the app and return after 30 seconds to test auto-lock

## Need Help?

- **New to iOS?** Start with our [Developer Guide](DEVELOPER_GUIDE.md)
- **Xcode Issues?** Check the [Troubleshooting section](DEVELOPER_GUIDE.md#troubleshooting)
- **Understanding the code?** Each file has comments explaining its purpose 