# File Vault

A local, encrypted iOS vault for photos, videos, audio, documents, and other files. Access is protected by a 4-digit passcode, 6-digit passcode, or password, with optional Face ID / Touch ID.

There is no cloud sync. The only network feature is an optional LAN web server for uploads from other devices on the same Wi‑Fi.

The full technical inventory (for OS upgrades and regressions) is in [docs/FEATURES.md](docs/FEATURES.md). Component relationships are in [docs/COMPONENT_GRAPH.md](docs/COMPONENT_GRAPH.md).

## Requirements

| | |
|---|---|
| Deployment target | **iOS 18.5** |
| Devices | iPhone and iPad |
| Language | Swift 5.0 (Xcode project setting) |
| Dependencies | None (no SPM / CocoaPods) |
| Bundle ID | `com.haresh.FileVault` |
| Version | Marketing **1.0** (About screen shows **1.0.0**) |

## Quick start

1. Open `File Vault.xcodeproj` in Xcode.
2. Select a simulator or a signed device.
3. Run (**⌘R**).

Face ID usage text is already set on the target (`NSFaceIDUsageDescription`). Photo library access uses `PHPickerViewController` and does not need `NSPhotoLibraryUsageDescription`.

New to Xcode? See [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) for opening the project, signing, and troubleshooting.

## Features

### Authentication and lock
- First-launch choice: 4-digit passcode, 6-digit passcode, or password (minimum 6 characters)
- Optional Face ID / Touch ID (falls back to the vault credential)
- Auto-lock after backgrounding: immediately, 5s–5 min, or never (default **30 seconds**)
- App Switcher cover so vault contents are not visible when leaving the app
- Change authentication re-encrypts all vault files

### Decoy vault
- Optional fake passcode/password that unlocks an empty UI
- Add files, folders, web server, and most Settings are blocked in that mode

### Files and folders
- Nested folders (create, rename, move, delete, swipe-to-delete)
- Import photos/videos from the system picker (up to 50) and files from the Files app
- Gallery, category browser (Favorites, Photos, Videos, Audio, Documents, Other, All Files), search on Gallery and Categories
- Sort, multi-select, favorites, share, rename, move
- Optional trash with restore and empty

### Preview
- Photos: pinch, pan, double-tap zoom, swipe between items
- Videos: autoplay, play/pause, scrubber, ±15s, speed, pinch/double-tap zoom
- Audio playback; PDF (PDFKit); other documents via QuickLook

### Web upload
- Local HTTP server on port **8080**, URL copy, QR code
- Browser upload, folder management; optional downloads (off by default)

### Extra security (Settings)
- Screenshot notice and inactive-state overlay
- Screen recording overlay
- Optional shake-to-lock and flip-to-lock

Files in `Documents/Vault/` are encrypted with **AES-GCM**. The key is **PBKDF2-HMAC-SHA256** of the real credential (random salt in Keychain). Thumbnails are unencrypted JPEGs. Core Data metadata uses Data Protection `completeUntilFirstUserAuthentication`. Credentials and the derivation salt use Keychain `WhenUnlockedThisDeviceOnly`.

## App structure

```
File Vault/
├── FileVaultApp.swift          # App entry, first-launch cleanup, background session init
├── ContentView.swift           # Auth gates → MainTabView
├── Coordinators/               # Authentication and lock orchestration
├── Dependencies/               # DependencyContainer
├── Models/                     # Core Data (Folder, VaultItem), protocols
├── Managers/                   # Storage, security, web, Core Data
├── Services/                   # Shared vault import workflow
├── ViewModels/
├── Views/                      # Tabs: Folders, Category, Gallery, Web Upload, Settings
├── Utilities/                  # Keychain, sharing, notification names
docs/FEATURES.md                # Canonical feature catalog
File VaultTests/                # Unit tests
File VaultUITests/              # Launch and navigation smoke tests
```

Five tabs after unlock: **Folder**, **Category**, **Gallery**, **Web Upload**, **Settings**.

## Testing

Unit tests: **⌘U** in Xcode (`File VaultTests`). For deterministic command-line runs, disable parallel testing:

```sh
xcodebuild -project "File Vault.xcodeproj" -scheme "File Vault" \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test -only-testing:"File VaultTests" -parallel-testing-enabled NO
```

Auth smoke test:
1. Launch and choose 4-digit, 6-digit, or password.
2. Unlock; optionally enable biometrics in Settings.
3. Background the app longer than the auto-lock timeout and return — you should be locked.

A broader regression list is in [docs/FEATURES.md](docs/FEATURES.md#9-upgrade-verification-checklist).

## Current known gaps

- Screenshot and screen-recording Settings toggles are not written to UserDefaults; they default to on after relaunch.
- Screenshot detection always shows an alert; the Settings toggle only gates the inactive-state overlay.
- Folder tab has no search field.
- No in-app camera capture.

## Need help?

- Feature behavior and OS-upgrade baseline: [docs/FEATURES.md](docs/FEATURES.md)
- Component graph: [docs/COMPONENT_GRAPH.md](docs/COMPONENT_GRAPH.md)
- Xcode basics: [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)
- Testing checklist: [docs/TESTING_CHECKLIST.md](docs/TESTING_CHECKLIST.md)
- Troubleshooting: [docs/DEVELOPER_GUIDE.md#troubleshooting](docs/DEVELOPER_GUIDE.md#troubleshooting)
