# File Vault - Secure Photo & Video Storage iOS App

A secure vault iOS application to store and manage photos and videos with biometric and passcode protection.

## Features Implemented

### Phase 1 - Foundation & Security (✅ Complete)
- **Core Data Setup**: Created data models for VaultItem and Folder with proper relationships
- **Keychain Integration**: Secure password storage using iOS Keychain Services
- **Biometric Authentication**: Face ID/Touch ID support using LocalAuthentication framework
- **Passcode Protection**: Custom passcode entry UI with secure text fields
- **Authentication Flow**: Combined biometric and passcode authentication with automatic lock on app backgrounding

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

1. Open `File Vault.xcodeproj` in Xcode
2. Add the following privacy permissions to the project's Info settings:
   - `NSFaceIDUsageDescription`: "File Vault uses Face ID to protect your private photos and videos"
   - `NSPhotoLibraryUsageDescription`: "File Vault needs access to your photo library to import photos and videos"
   - `NSPhotoLibraryAddUsageDescription`: "File Vault needs permission to save photos and videos to your photo library"
3. Build and run on a physical device or simulator

## Security Features

- **Keychain Storage**: Passwords are securely stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Biometric Authentication**: Optional Face ID/Touch ID support
- **Auto-lock**: App automatically locks after 30 seconds in background
- **Core Data Encryption**: Data protection enabled with `FileProtectionType.complete`

## Next Steps

- [ ] File storage implementation with encryption
- [ ] Main vault UI with grid/list view
- [ ] Photo import from gallery
- [ ] File operations (delete, rename, organize)
- [ ] Photo viewer with zoom/pan
- [ ] Video player with advanced controls
- [ ] Web server for browser-based uploads
- [ ] Unit tests

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