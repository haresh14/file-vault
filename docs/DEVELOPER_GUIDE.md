# iOS Development Guide for Keepshire

This guide provides detailed step-by-step instructions for common iOS development tasks.

## Table of Contents
1. [Opening the Project](#opening-the-project)
2. [Adding Privacy Permissions](#adding-privacy-permissions)
3. [App Store Compliance](#app-store-compliance)
4. [Building and Running the App](#building-and-running-the-app)
5. [Understanding the Project Structure](#understanding-the-project-structure)
6. [Common Xcode Tasks](#common-xcode-tasks)

The home-screen name is Keepshire (`CFBundleDisplayName`). The Xcode project is `Keepshire.xcodeproj` and the app source folder is `Keepshire`. Bundle ID is `com.haresh.keepshire`. That identifier is a new app: vault files and Keychain items from `com.haresh.FileVault` do not migrate.

## Opening the Project

1. **Locate the project file**:
   - Open the repository folder
   - Find `Keepshire.xcodeproj`

2. **Open in Xcode**:
   - Double-click on `Keepshire.xcodeproj`
   - OR right-click and select "Open With" → "Xcode"
   - OR open Xcode first, then File → Open → navigate to the project file

## Adding Privacy Permissions

Face ID usage is declared in `Keepshire/Info.plist` as `NSFaceIDUsageDescription`: `Use Face ID to unlock Keepshire`.

Photo library access uses `PHPickerViewController`. Do not add `NSPhotoLibraryUsageDescription`.

LAN web upload uses `NSLocalNetworkUsageDescription` in the same Info.plist.

`Keepshire/PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API with reason CA92.1. It declares no tracking and no collected data because the app has no account, analytics, or remote service. Re-audit the manifest whenever a dependency or required-reason API is added.

Notification authorization is requested when the user starts Web Upload. Do not move it back to app launch or unlock.

`CoreDataManager.save()` throws. A failed SQLite load does not `fatalError`; the root view shows a database error overlay. Share plaintext lives under `tmp/keepshire-share/` and is swept on lock and unlock. Vault files at or above 16 MB use chunked AES-GCM (`KSHC`); imports above 2 GB are rejected. Passcode change stages `.migrating` copies and only commits the new key after every blob succeeds.

## App Store Compliance

### Export compliance

`ITSAppUsesNonExemptEncryption` is `YES`. App Store Connect answers and legal advice must agree with that declaration. App Review notes:

> The app encrypts user-selected files and metadata on device with AES-GCM. The encryption key is derived from the user's vault credential with PBKDF2-HMAC-SHA256; Keychain material is ThisDeviceOnly. The optional local-network transfer server uses HTTPS with a new self-signed ECDSA certificate per server session. The app has no account or cloud sync, and vault files are excluded from backup.

### Privacy and support URLs

`PRIVACY_POLICY_URL` is `https://keepshire.haresh.dev/privacy`. `SUPPORT_URL` is `https://keepshire.haresh.dev/support`. Settings → About opens those pages. Put the same URLs in App Store Connect. Source files live in `web/`. Vercel Root Directory is `web`; the domain is `https://keepshire.haresh.dev`.

Listing fields that are not in the binary:

| Field | Value |
|--------|--------|
| Name (30) | Keepshire: Private Photo Vault |
| Subtitle (30) | Hide photos, videos & files |
| Keywords | `gallery,locker,album,encrypted,passcode,secure,folder,document,audio,secret,lock` |
| Privacy | `https://keepshire.haresh.dev/privacy` |
| Support | `https://keepshire.haresh.dev/support` |
| Bundle ID | `com.haresh.keepshire` |
| SKU (your choice) | `keepshire` |
| Primary language | English (US) |

### Apple Developer Program and App Store Connect

These steps require your Apple ID and cannot be finished from this repo. They are not legal advice.

**1. Enroll**

1. Open [developer.apple.com/programs](https://developer.apple.com/programs/).
2. Enroll as an **Individual** (personal project) with the Apple ID you will use for the App Store.
3. Pay the annual fee and wait until the account shows **Active**.
4. Sign the contracts in [App Store Connect](https://appstoreconnect.apple.com/) → Agreements, Tax, and Banking. Add a bank account and tax form or you cannot sell (even a free app needs Paid Apps / Free Apps agreements accepted).

**2. Register the bundle ID**

1. Open [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list).
2. Click **+** → **App IDs** → **App**.
3. Description: `Keepshire`.
4. Bundle ID: **Explicit** `com.haresh.keepshire`.
5. Enable **App Groups**. Leave Push, Associated Domains, and iCloud off.
6. Register.
7. Return to Identifiers and create another explicit App ID: `com.haresh.keepshire.share`, description `Keepshire Share`. Enable **App Groups**.
8. Identifiers → **App Groups** → **+**. Register `group.com.haresh.keepshire`.
9. Open both App IDs, configure App Groups, and select `group.com.haresh.keepshire`.
10. In Xcode, select both the **Keepshire** and **KeepshireShare** targets → **Signing & Capabilities** → Team = your team → **Automatically manage signing**. Confirm the App Groups capability lists `group.com.haresh.keepshire`. The first device build may ask you to allow certificates.

**3. Create the app record (listing)**

1. [App Store Connect](https://appstoreconnect.apple.com/) → **Apps** → **+** → **New App**.
2. Platforms: iOS.
3. Name: `Keepshire: Private Photo Vault`.
4. Primary language: English (U.S.).
5. Bundle ID: `com.haresh.keepshire` (the ID from step 2).
6. SKU: `keepshire` (internal; users never see it).
7. User access: Full Access.

Then open the app → **App Information** / **App Store** tab and paste:

- Subtitle: `Hide photos, videos & files`
- Privacy Policy URL: `https://keepshire.haresh.dev/privacy`
- Category: something like **Utilities** (primary) and **Photo & Video** (secondary) if offered.
- Support URL: `https://keepshire.haresh.dev/support` (on the version page, under General App Information).
- Marketing URL (optional): `https://keepshire.haresh.dev`
- Description (draft you can paste):

```
Keepshire is a private vault for photos, videos, audio, and files on your iPhone and iPad. There is no account and no cloud.

Unlock with a 4-digit passcode, 6-digit passcode, or password. Face ID or Touch ID is optional. Files stay encrypted on the device.

Import from Photos or the Files app, or send from a browser on the same Wi-Fi. Optional screenshot blanking and a decoy credential that opens an empty screen.

If you forget your vault passcode or password, the files cannot be recovered.
```

- Keywords: `gallery,locker,album,encrypted,passcode,secure,folder,document,audio,secret,lock`
- Screenshots: iPhone 6.7" (required) plus iPad 12.9" if you ship iPad. No vault contents that look like someone else’s photos.
- Review notes (paste):

```
The app encrypts user-selected files and metadata on device with AES-GCM. The encryption key is derived from the user's vault credential with PBKDF2-HMAC-SHA256; Keychain material is ThisDeviceOnly. The optional local-network transfer server uses HTTPS with a new self-signed ECDSA certificate per server session. The app has no account or cloud sync, and vault files are excluded from backup.

Demo: create a 6-digit passcode, import one photo, optional Face ID. Web Upload: start the server, accept the browser certificate warning, enter the pairing code shown in the app. There is no test account.
```

**4. App Privacy (nutrition label)**

App Store Connect → App Privacy → **Get Started**.

- Data collected: **No**. Keepshire has no account, analytics, or tracking. Do not declare Name, Email, Photos, or Product Interaction as collected-by-you; imported photos stay on device.
- Tracking: **No**.

**5. Export compliance (encryption)**

The Info.plist key `ITSAppUsesNonExemptEncryption` is **YES** because Keepshire uses AES-GCM at rest (not “HTTPS only”). Answers in Connect must not contradict that.

Typical path (wording varies; read the screen):

1. First TestFlight / App Store upload, or **App Store Connect** → the app → **Distribution** / compliance questions.
2. “Does your app use encryption?” → **Yes**.
3. Questions about exemption (HTTPS only, authentication only, etc.) → **No, not exempt** for this product. Custom file encryption is why the plist is YES.
4. If Apple then asks for an ERN or annual self-classification, follow the link they show. That paperwork is yours (or a lawyer’s). Do not flip the plist to `NO` to skip it.

A lawyer who does software export can confirm this. This repo does not replace that.

**6. Name / trademark (counsel)**

Nobody in this project can be your lawyer. Practical checks before you spend on ads:

- Search [Apple Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html) — Keepshire is not Apple FileVault; do not use “FileVault” in the listing.
- Search the App Store for “Keepshire” and similar spellings.
- Search USPTO TESS / your country’s trademark office.

If you want the name protected, hire a trademark attorney. Shipping as an Individual under Keepshire is a business choice you make; the code already uses that name.

**7. Age rating**

Complete the age-rating questionnaire. Keepshire does not include unrestricted web browsing, gambling, or its own UGC feed. User-imported photos can include anything the user owns — answer the “user-generated content” / “mature themes” questions as Apple phrases them that year; do not claim the app filters photos.

**8. First build (TestFlight)**

1. In Xcode: Product → Archive (Any iOS Device, Release).
2. Distribute App → App Store Connect → Upload.
3. Wait for processing, then add the build to a TestFlight internal group and install it on your iPhone.
4. Confirm Settings → About opens the live privacy and support URLs.


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
Keepshire (Blue folder icon) - Main app folder
├── Coordinators/ - Authentication and lock orchestration
├── Dependencies/ - Dependency container
├── Models/ - Data structures and protocols
├── Managers/ - Storage, security, web, Core Data services
├── Services/ - Shared import workflow
├── Utilities/ - Helper classes
├── Views/ - UI components
├── Assets.xcassets - Images and colors
├── ContentView.swift - Main view
└── KeepshireApp.swift - App entry point

Keepshire.xcodeproj - Project configuration
KeepshireTests/ - Unit tests
KeepshireUITests/ - Launch and navigation smoke tests
```

Component relationships (auth, tabs, storage, security, web server) are in [COMPONENT_GRAPH.md](COMPONENT_GRAPH.md).

### Key Files for Beginners

1. **ContentView.swift**: Auth gates and the unlocked tab root
2. **KeepshireApp.swift**: App entry
3. **Assets.xcassets**: App icons and images

## Common Xcode Tasks

### Adding a New Swift File

1. Right-click on the folder where you want to add the file
2. Select "New File..."
3. Choose "Swift File"
4. Name your file (e.g., "FileStorageManager")
5. Make sure "Keepshire" target is checked
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
  xcodebuild -project "Keepshire.xcodeproj" -scheme "Keepshire" \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    test -only-testing:"KeepshireTests" -parallel-testing-enabled NO
  ```
- Run `KeepshireUITests` on both an iPhone and iPad simulator for authentication, tab, fake-vault, and add-control smoke coverage.

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