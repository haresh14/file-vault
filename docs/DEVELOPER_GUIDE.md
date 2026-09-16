# iOS Development Guide for File Vault

This guide provides detailed step-by-step instructions for common iOS development tasks.

## Table of Contents
1. [Opening the Project](#opening-the-project)
2. [Adding Privacy Permissions](#adding-privacy-permissions)
3. [Building and Running the App](#building-and-running-the-app)
4. [Understanding the Project Structure](#understanding-the-project-structure)
5. [Common Xcode Tasks](#common-xcode-tasks)

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