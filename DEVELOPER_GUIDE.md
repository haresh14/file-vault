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
   - Navigate to your project folder: `/Users/mac/Flexteam/projects/flexteam/File Vault/`
   - Find the file named `File Vault.xcodeproj` (it has a blue icon)

2. **Open in Xcode**:
   - Double-click on `File Vault.xcodeproj`
   - OR right-click and select "Open With" → "Xcode"
   - OR open Xcode first, then File → Open → navigate to the project file

## Adding Privacy Permissions

Since iOS requires explicit user permission for accessing sensitive features, we need to add descriptions for why our app needs these permissions.

### Method 1: Using Xcode's Interface (Recommended for beginners)

1. **Open the project in Xcode**

2. **Select the project settings**:
   - In the left sidebar (Navigator), click on the blue project icon at the top (named "File Vault")
   - This opens the project settings in the main editor

3. **Navigate to Info tab**:
   - In the main editor, you'll see tabs like "General", "Signing & Capabilities", "Info", etc.
   - Click on the "Info" tab

4. **Add privacy permissions**:
   - Look for a section called "Custom iOS Target Properties"
   - Hover over any existing row and click the "+" button that appears
   - A dropdown will appear - start typing the permission key name
   
5. **Add Face ID permission**:
   - Click the "+" button
   - Type: `Privacy - Face ID Usage Description`
   - Press Enter
   - In the Value column, type: `File Vault uses Face ID to protect your private photos and videos`

6. **Add Photo Library permission**:
   - Click the "+" button again
   - Type: `Privacy - Photo Library Usage Description`
   - Press Enter
   - In the Value column, type: `File Vault needs access to your photo library to import photos and videos`

7. **Add Photo Library Add permission**:
   - Click the "+" button again
   - Type: `Privacy - Photo Library Additions Usage Description`
   - Press Enter
   - In the Value column, type: `File Vault needs permission to save photos and videos to your photo library`

### Method 2: Direct Info.plist Edit

1. **Create Info.plist file**:
   - Right-click on the "File Vault" folder in Xcode's navigator
   - Select "New File..."
   - Choose "Property List" under Resources
   - Name it "Info.plist"
   - Click "Create"

2. **Add the XML content**:
   - Right-click on Info.plist → "Open As" → "Source Code"
   - Replace content with:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>NSFaceIDUsageDescription</key>
       <string>File Vault uses Face ID to protect your private photos and videos</string>
       <key>NSPhotoLibraryUsageDescription</key>
       <string>File Vault needs access to your photo library to import photos and videos</string>
       <key>NSPhotoLibraryAddUsageDescription</key>
       <string>File Vault needs permission to save photos and videos to your photo library</string>
   </dict>
   </plist>
   ```

## Building and Running the App

### On iOS Simulator

1. **Select a simulator**:
   - At the top of Xcode, next to the "Play" button, you'll see a device selector
   - Click on it and choose a simulator (e.g., "iPhone 16 Pro")
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
├── Models/ - Data structures
├── Managers/ - Business logic handlers
├── Utilities/ - Helper classes
├── Views/ - UI components
├── Assets.xcassets - Images and colors
├── ContentView.swift - Main view
└── File_VaultApp.swift - App entry point

File Vault.xcodeproj - Project configuration
File VaultTests/ - Unit tests
File VaultUITests/ - UI tests
```

### Key Files for Beginners

1. **ContentView.swift**: The main screen of your app
2. **File_VaultApp.swift**: Where the app starts
3. **Assets.xcassets**: Where you add app icons and images

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
- Xcode → Preferences → Components → Download simulators

### App crashes on launch
- Check the console for error messages
- Ensure all required files are included in target

### Build fails
- Check Issue Navigator for specific errors
- Try cleaning build folder
- Ensure you're using correct Swift version

## Next Steps

Now that you understand the basics, you can:
1. Test the current authentication features
2. Proceed to implement file storage
3. Add the main vault UI

Remember: Don't hesitate to use Xcode's built-in help (Help menu) or hover over buttons to see tooltips! 