# iOS Development Guide for File Vault

This guide provides detailed step-by-step instructions for common iOS development tasks.

## Table of Contents
1. [Opening the Project](#opening-the-project)
2. [Adding Privacy Permissions](#adding-privacy-permissions)
3. [App Store Compliance](#app-store-compliance)
4. [Building and Running the App](#building-and-running-the-app)
5. [Understanding the Project Structure](#understanding-the-project-structure)
6. [Common Xcode Tasks](#common-xcode-tasks)

## Opening the Project

1. **Locate the project file**:
   - Open the repository folder
   - Find `File Vault.xcodeproj`

2. **Open in Xcode**:
   - Double-click on `File Vault.xcodeproj`
   - OR right-click and select "Open With" → "Xcode"
   - OR open Xcode first, then File → Open → navigate to the project file

## Adding Privacy Permissions

Face ID usage is declared in `File Vault/Info.plist` as `NSFaceIDUsageDescription`: `Use Face ID to unlock your secure vault`.

Photo library access uses `PHPickerViewController`. Do not add `NSPhotoLibraryUsageDescription`.

LAN web upload uses `NSLocalNetworkUsageDescription` in the same Info.plist.

`File Vault/PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API with reason CA92.1. It declares no tracking and no collected data because the app has no account, analytics, or remote service. Re-audit the manifest whenever a dependency or required-reason API is added.

Notification authorization is requested when the user starts Web Upload. Do not move it back to app launch or unlock.

## App Store Compliance

### Export compliance

`ITSAppUsesNonExemptEncryption` is `YES`. App Store Connect answers and legal advice must agree with that declaration. App Review notes:

> The app encrypts user-selected files and metadata on device with AES-GCM. The encryption key is derived from the user's vault credential with PBKDF2-HMAC-SHA256; Keychain material is ThisDeviceOnly. The optional local-network transfer server uses HTTPS with a new self-signed ECDSA certificate per server session. The app has no account or cloud sync, and vault files are excluded from backup.

### Privacy and support URLs

Set `PRIVACY_POLICY_URL` and `SUPPORT_URL` in the app target's build settings to real hosted HTTPS pages. Empty or invalid values hide the corresponding About link. Configure the same URLs in App Store Connect.

The hosted privacy policy must state:

- No account, analytics, advertising, tracking, or sale of data.
- Vault files, encrypted metadata, credentials, biometric decisions, and security settings remain on the device.
- Face ID / Touch ID evaluation is performed by iOS; the app does not receive biometric data.
- Web Upload is optional and limited to the local network. Paired browsers can upload; downloads require an authenticated export session. The browser must verify the displayed self-signed certificate fingerprint to detect interception.
- Screenshot blanking and the decoy credential are UI protections, not protection against a compromised device or filesystem access.
- How users request support and how policy changes are published.

Support pages must provide a contact method, supported iOS version, troubleshooting for unlock and LAN certificate warnings, and the warning that forgotten vault credentials cannot be recovered.

## Building and Running the App

### On iOS Simulator

1. **Select a simulator**:
   - At the top of Xcode, next to the "Play" button, you'll see a device selector
   - Click on it and choose a simulator (for example iPhone 18 Pro)
   - If no simulators are listed, go to Window → Devices and Simulators to download one

2. **Build and run**:
   - Click the triangular "Play" button (or press Cmd+R)
   - The app will compile and launch in the simulator
   - First time may take a few minutes as it builds everything

3. **Stop the app**:
   - Click the square "Stop" button (or press Cmd+.)

### On Physical Device

1. **Connect your iPhone/iPad**:
   - Connect via USB cable
   - Trust the computer on your device if prompted

2. **Select your device**:
   - It should appear in the device selector at the top of Xcode

3. **Handle signing** (one-time setup):
   - Select the project in navigator
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Team (you may need to add your Apple ID)

4. **Run on device**:
   - Click the "Play" button
   - You may need to trust the developer certificate on your device:
     - On device: Settings → General → VPN & Device Management → Developer App → Trust

## Understanding the Project Structure

### In Xcode Navigator (Left Sidebar)

```
File Vault (Blue folder icon) - Main app folder
├── Coordinators/ - Authentication and lock orchestration
├── Dependencies/ - Dependency container
├── Models/ - Data structures and protocols
├── Managers/ - Storage, security, web, Core Data services
├── Services/ - Shared import workflow
├── Utilities/ - Helper classes
├── Views/ - UI components
├── Assets.xcassets - Images and colors
├── ContentView.swift - Main view
└── FileVaultApp.swift - App entry point

File Vault.xcodeproj - Project configuration
File VaultTests/ - Unit tests
File VaultUITests/ - Launch and navigation smoke tests
```

Component relationships (auth, tabs, storage, security, web server) are in [COMPONENT_GRAPH.md](COMPONENT_GRAPH.md).

### Key Files for Beginners

1. **ContentView.swift**: Auth gates and the unlocked tab root
2. **FileVaultApp.swift**: App entry
3. **Assets.xcassets**: App icons and images

## Common Xcode Tasks

### Adding a New Swift File

1. Right-click on the folder where you want to add the file
2. Select "New File..."
3. Choose "Swift File"
4. Name your file (e.g., "FileStorageManager")
5. Make sure "File Vault" target is checked
6. Click "Create"

### Adding Images/Icons

1. Click on "Assets.xcassets" in navigator
2. Drag and drop images into the main area
3. OR right-click → "New Image Set"
4. Name your image and drag files to 1x, 2x, 3x slots

### Viewing Build Errors

1. Look for red icons in the navigator
2. Click on the "Issue Navigator" (triangle with !) in left sidebar
3. Build errors will be listed with file and line numbers

### Using the Console

1. When app is running, bottom area shows console
2. Use it to see print() statements and errors
3. If hidden, View → Debug Area → Show Debug Area

### Running Tests

- In Xcode, press Cmd+U to run the selected scheme's tests.
- Keep unit tests serial when diagnosing shared-state failures:

  ```sh
  xcodebuild -project "File Vault.xcodeproj" -scheme "File Vault" \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    test -only-testing:"File VaultTests" -parallel-testing-enabled NO
  ```
- Run `File VaultUITests` on both an iPhone and iPad simulator for authentication, tab, fake-vault, and add-control smoke coverage.

### Keyboard Shortcuts

- **Build**: Cmd+B
- **Run**: Cmd+R
- **Stop**: Cmd+.
- **Clean Build**: Cmd+Shift+K
- **Find in Project**: Cmd+Shift+F
- **Open Quickly**: Cmd+Shift+O

## Troubleshooting

### "No such module" error
- Clean build folder: Product → Clean Build Folder
- Close and reopen Xcode

### Simulator not showing up
- Xcode → Settings → Components → Download simulators

### App crashes on launch
- Check the console for error messages
- Ensure all required files are included in target

### Build fails
- Check Issue Navigator for specific errors
- Try cleaning build folder
- Ensure you're using Swift 5.0 language mode as set in the project 