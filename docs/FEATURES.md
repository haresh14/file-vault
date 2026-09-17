# File Vault — Feature Catalog

**Purpose:** This is the canonical technical inventory of every product and system feature in File Vault. Use it as the baseline for **any** iOS/Xcode upgrade (iOS 27, 28, 29, …). Do not treat README marketing bullets as complete.

**How to use this document for an OS upgrade**

1. Treat every row in [Feature inventory](#feature-inventory) as a regression requirement. If it exists here, it must still work after the upgrade.
2. For each feature, check the listed **Apple APIs / frameworks** against Apple’s latest release notes, deprecations, and Human Interface Guidelines.
3. If an API is deprecated or removed, record the replacement in an upgrade plan (separate document). Do not change behavior unless the OS forces it.
4. After implementation, run the [Upgrade verification checklist](#upgrade-verification-checklist).
5. When a feature is added or removed in the app, **update this file in the same change**.

**Document status**

| Field | Value |
|--------|--------|
| Last inventoried from source | 2026-09-16 |
| Last verified against source | 2026-09-16 |
| App version (About UI) | 1.0.0 |
| Marketing version (Xcode) | 1.0 |
| Bundle ID | `com.haresh.FileVault` |
| Deployment target | **iOS 18.5** |
| Swift language version (project) | 5.0 |
| Devices | iPhone and iPad (`TARGETED_DEVICE_FAMILY` 1,2) |
| Third-party dependencies | None (no SPM / CocoaPods) |

---

## 1. Product overview

File Vault is a **local, encrypted file vault** for iOS. Users store photos, videos, audio, documents, and other files on-device. Access is gated by a passcode or password, optionally Face ID / Touch ID. Files are encrypted at rest with a key derived from the vault credential.

There is **no cloud sync, no App Groups, no widgets, no Share Extension, and no App Intents**. The only network feature is an optional **LAN HTTP server** for browser upload/download on the same Wi‑Fi.

Architecture: SwiftUI app (`FileVaultApp` → `ContentView` → `AuthenticationCoordinator` → `MainTabView`), MVVM view models, protocol-based `DependencyContainer`, Core Data for metadata, encrypted files on disk.

---

## 2. Platform baseline (what an OS upgrade must preserve)

### 2.1 Targets and project settings

| Setting | Current value | Notes |
|---------|---------------|--------|
| `IPHONEOS_DEPLOYMENT_TARGET` | 18.5 | Set on the project, app target, and unit-test target. The UI-test target does not set its own value (inherits the project 18.5). |
| `SWIFT_VERSION` | 5.0 | Project setting (not “Swift 5.9+”) |
| `GENERATE_INFOPLIST_FILE` | NO | Checked-in `File Vault/Info.plist` |
| `NSFaceIDUsageDescription` | `Use Face ID to unlock your secure vault` | Face ID unlock |
| `NSLocalNetworkUsageDescription` | `File Vault uses the local network so you can upload files from a browser on the same Wi-Fi.` | LAN web upload |
| `UIBackgroundModes` | `background-fetch`, `background-processing` | Used with `BackgroundTasks` |
| `BGTaskSchedulerPermittedIdentifiers` | `com.haresh.FileVault.upload-processing` | Matches registration in `WebServerManager` |
| Scene manifest | Explicit in Info.plist | SwiftUI `WindowGroup` |
| Launch screen | Explicit empty `UILaunchScreen` dictionary | Required when linking with iOS 27 SDK |
| Signing | Automatic | Team `AYL8H487NP` |
| Entitlements file | **None** | No App Groups, iCloud, associated domains, or push entitlement |

No Bonjour services are advertised, so `NSBonjourServices` is not declared.

### 2.2 Apple frameworks in use

| Framework | Used for |
|-----------|----------|
| SwiftUI | Entire UI, scene lifecycle (`scenePhase`) |
| UIKit | Window overlay, alerts, `UIActivityViewController`, `UIDocumentPicker`, `PHPicker`, graphics renderers, screenshot / capture notifications |
| Core Data | `Folder`, `VaultItem` metadata |
| CryptoKit | AES-GCM encrypt/decrypt |
| CommonCrypto | PBKDF2-HMAC-SHA256 key derivation |
| Security (Keychain) | Real and fake credentials; `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| LocalAuthentication | Face ID / Touch ID |
| PhotosUI | `PHPickerViewController` (images + videos, limit 50) |
| Photos | `PHAsset` import path on `FileStorageManager` / `PhotoImportService` (primary UI path is `PHPicker` + `VaultImportService`) |
| UniformTypeIdentifiers | MIME/UTI mapping; document picker types |
| AVFoundation / AVKit | Video/audio playback, video thumbnails, player controls, `AVAudioSession` playback category for audio |
| MediaPlayer | Imported in `AudioPreviewView` but unused (no Now Playing / remote commands) |
| QuickLook | Document / unsupported file preview |
| PDFKit | Document preview |
| Network | `NWListener` local HTTP server on port **8080** |
| BackgroundTasks | `BGProcessingTask` `com.haresh.FileVault.upload-processing` |
| UserNotifications | Upload completion (alert, badge, sound) |
| CoreMotion | Shake-to-lock accelerometer |
| Core Image | QR code generation (`CIQRCodeGenerator`) |
| Combine | ViewModels |

### 2.3 Storage locations and protection

| Path / store | Protection | Encrypted by app? |
|--------------|------------|-------------------|
| `Documents/Vault/` | `FileProtectionType.complete` | Yes — AES-GCM combined sealed boxes. Filenames on disk are the item UUID, not the display name. |
| `Documents/Thumbnails/` | `FileProtectionType.complete` | Yes — AES-GCM combined sealed boxes named `{uuid}.thumb` (200×200 JPEG @ 0.7 before encryption) |
| `Documents/FileVault.sqlite` (+ WAL/SHM) | `completeUntilFirstUserAuthentication` | Display names, MIME types, and sizes are AES-GCM sealed JSON on each row (`sealedMetadata`). Search uses the decrypted copies in RAM after unlock. The store, `Documents/Vault/`, and `Documents/Thumbnails/` are excluded from iCloud/computer backup. |
| Keychain items `com.filevault.app` | `WhenUnlockedThisDeviceOnly` | System Keychain (credential + PBKDF2 salt/parameters) |
| UserDefaults | Standard suite | Settings, auth type, lock timeout, trash flag, security logs, biometric enabled |

**Encryption details**

- Key = PBKDF2-HMAC-SHA256 of the real credential (210,000 iterations, 16-byte random salt, 32-byte key). Salt and parameters live in Keychain account `vaultKeyDerivation` (`WhenUnlockedThisDeviceOnly`).
- Cipher: `AES.GCM.seal` / `AES.GCM.open` (combined nonce + ciphertext + tag) for vault files, thumbnails, and Core Data `sealedMetadata` JSON.
- Changing authentication generates a new salt and **re-encrypts every vault file** (`migrateFilesToNewEncryptionKey`) with a progress UI (`MigrationProgressView`). Failed files are skipped. Item and folder metadata blobs are re-sealed with the new key.
- If ciphertext exists but no derivation record is in Keychain, unlock derives a SHA-256 key long enough to open those files, then re-encrypts them with PBKDF2 and stores a salt.
- Duplicate display names in a folder get a suffix (`name (n).ext`). Each item has its own UUID blob on disk. Display name, MIME type, and size live in sealed JSON; gallery search filters decrypted `fileName` values in memory.
- Permanent delete removes the item's ciphertext and thumbnail from disk. Unlock also deletes vault files and thumbnails that no item claims; the sweep is skipped when the vault has no items.
- Unlock encrypts leftover plaintext JPEG thumbnails in place with the vault key, and seals leftover plaintext Core Data names into `sealedMetadata`.

---

## 3. User flows

### 3.1 First launch

1. `AppDataManager.isFirstLaunch` is true.
2. `performFirstLaunchCleanup()` wipes vault files and thumbnails, Keychain, UserDefaults (except launch flag), and Core Data.
3. Sets **`trashEnabled = true`**.
4. User must choose an authentication type, then set the credential.

DEBUG Settings can simulate this cleanup.

### 3.2 Unlock

Order of gates in `ContentView`:

1. Auth type set?
2. Password/passcode set?
3. Authenticated?

If biometrics are enabled and available, Face ID / Touch ID runs first (0.3s delay). Cancel / failure falls back to `PasscodeView` (numeric OTP UI or alphanumeric password field, depending on auth type). The loading screen `BiometricCheckView` always shows the **Face ID** SF Symbol, even on Touch ID devices. Users with a stored password but no auth type are treated as `.password`.

On **every** successful unlock (biometric, real passcode, or fake passcode), `FileStorageManager.setupEncryptionKey(from:)` is called with the **real** Keychain password. Fake login does not derive a different key; it only hides data in the UI.

### 3.3 Background / lock

- On resign active / background: `ContentView` shows `EnhancedPrivacyOverlay` (dark lock-shield cover). Separately, if screenshot protection is on, `SecurityManager` presents a full-screen black `UIWindow` overlay. Both can appear together. `setLastBackgroundTime()` is recorded.
- On foreground: if `shouldRequireAuthentication()` → lock, reset fake-login state, re-prompt.
- Immediate (0s): always re-auth.
- Never (−1): no auto re-auth.
- Default if never configured: **30 seconds**.
- Shake / flip / manual security events post `TriggerSecurityLock` and force lock.

---

## 4. Feature inventory

Every item below is a **must-keep** behavior unless product explicitly drops it.

### 4.1 Authentication and credentials

| ID | Feature | User-visible behavior | Implementation | Apple APIs |
|----|---------|----------------------|----------------|------------|
| A1 | Choose auth type | First launch: 4-digit passcode, 6-digit passcode, or alphanumeric password | `AuthTypeSelectionView`, stored in UserDefaults `authenticationType` | SwiftUI |
| A2 | 4-digit passcode setup | Numeric only, exact length 4, confirm step, OTP-style fields + custom number pad | `PasscodeSetupView`, `OTPStylePasscodeView`, `CustomNumberPadView` | SwiftUI |
| A3 | 6-digit passcode setup | Same as A2, length 6 | same | SwiftUI |
| A4 | Password setup | Minimum **6** characters, confirmation, strength UI | `PasswordSetupView` | SwiftUI |
| A5 | Store credential | Saved in Keychain, this-device-only, not iCloud Keychain sync | `KeychainManager.savePassword`, service `com.filevault.app`, account `userPassword` | Security.framework |
| A6 | Unlock with passcode/password | Custom UI, not system passcode sheet | `PasscodeView` | SwiftUI |
| A7 | Enable Face ID / Touch ID | Settings toggle; disabled if hardware/enrollment unavailable. `LABiometryType` only maps `.faceID` and `.touchID`; any other type (including Optic ID if present) is treated as `.none` | `BiometricAuthManager`, UserDefaults `biometricEnabled` | LocalAuthentication (`LAContext`) |
| A8 | Biometric unlock | Prompt on foreground if enabled; cancel title **"Use Password"**; `localizedFallbackTitle = ""` (no Enter Password / device-passcode fallback on the biometric policy). Success always sets **real** login | `AuthenticationCoordinator` | `LAPolicy.deviceOwnerAuthenticationWithBiometrics` |
| A9 | Biometric lockout | After **3** failures, blocked for **30 seconds** | `maxFailureAttempts`, `failureResetInterval` | LocalAuthentication |
| A10 | Change authentication | Verify current credential → pick new type → set new credential → re-encrypt all files | `ChangeAuthenticationView`, `MigrationProgressView` | CryptoKit + Core Data |
| A11 | Auto-lock timeout | Picker: Immediately, 5s, 10s, 15s, 30s, 1 min, 5 min, Never | `KeychainManager.LockTimeout` | Scene phase / UIApplication notifications |
| A12 | Privacy overlay when leaving app | Blur/cover so app switcher does not show vault contents | `EnhancedPrivacyOverlay` in `ContentView` | `scenePhase`, `willResignActive` |

**Not wired in the main unlock UI:** `authenticateWithDevicePasscode` exists on `BiometricAuthManager` but is unused.

### 4.2 Decoy (fake) vault

| ID | Feature | User-visible behavior | Implementation | Apple APIs |
|----|---------|----------------------|----------------|------------|
| D1 | Set fake password/passcode | Must differ from the real credential; same format as current auth type | Keychain account `fakePassword` | Security |
| D2 | Change / remove fake credential | Settings: set, change, remove; status Set / Not Set | `SettingsView` | — |
| D3 | Fake login | Entering the fake credential unlocks an **empty** vault | `validatePassword` → `(isValid, isFakeLogin)`; `LoginStateManager` | — |
| D4 | Fake-login restrictions | No add files, no create folders, no web server, Settings shows **About only** | `canAddFiles`, `canCreateFolders`, `canAccessFullSettings`, server HTTP 403 | — |
| D5 | Fake credential cleared on auth change | Changing real auth method deletes fake password and prompts to set a new one | `SettingsView` change-auth callback | — |

Fake login does **not** use a second encrypted store. ViewModels return empty lists (folders, gallery, categories, trash). Mutations and the web server are blocked. The real encryption key is still loaded.

### 4.3 Device security protections

| ID | Feature | Default | Behavior | Apple APIs |
|----|---------|---------|----------|------------|
| S1 | Screenshot detection | On | Alert: “Screenshot detected…”, security log. Detection is **always** registered; the alert is not gated on the Settings toggle | `UIApplication.userDidTakeScreenshotNotification` |
| S2 | Screenshot / app-switcher cover | On | Extra black overlay window while inactive **if** screenshot protection is enabled | `willResignActive` / `didBecomeActive`, extra `UIWindow` at `alert + 1` |
| S3 | Screen recording protection | On | When `UIScreen.main.isCaptured` **and** recording protection is enabled, show the same black overlay | `UIScreen.capturedDidChangeNotification` |
| S4 | Shake to lock | Off | Accelerometer magnitude > **2.5** → lock | CoreMotion `CMMotionManager`, interval 0.1s |
| S5 | Flip to lock | Off | Transition into `UIDeviceOrientation.faceDown` → lock | `UIDevice.orientationDidChangeNotification` |
| S6 | Security logs | — | Last **100** strings in UserDefaults `SecurityLogs` (debug-oriented, not shown in Settings UI) | UserDefaults |

Toggles live in Settings → Advanced Security. Shake and flip write UserDefaults in `enableShakeToLock` / `enableFlipToLock`. Screenshot and recording toggles update in-memory/`@Published` state via `enableScreenshotProtection` / `enableRecordingProtection` and do not write UserDefaults; `saveSettings()` is unused by Settings. After relaunch, screenshot/recording default to **on**.

### 4.4 Main navigation

Five tabs (`MainTabView`):

| Tab | Label | Root view | Role |
|-----|--------|-----------|------|
| 0 | Folder | `FolderView` → `FolderContentView` | Nested folder browser |
| 1 | Category | `CategoryView` → `CategoryFilesView` | Type-based groups |
| 2 | Gallery | `VaultMainView` | Flat grid of all non-trashed files |
| 3 | Web Upload | `WebUploadTabView` | LAN server; badge `●` when running; globe icon changes |
| 4 | Settings | `SettingsView` | Embedded tab (not a sheet) |

Changing tabs posts `TabDidChange`, which **clears multi-select** in list/grid screens.

### 4.5 Folders

| ID | Feature | Behavior | APIs |
|----|---------|----------|------|
| F1 | Nested folders | `parent` / `subfolders`; breadcrumbs; `NavigationStack` path | Core Data |
| F2 | Create folder | Alert / empty state / Add Content sheet | Core Data |
| F3 | Rename folder | Context menu (also Select / Move / Delete on selectable rows) | Core Data |
| F4 | Delete folder | If trash on: nested **files** go to trash at **root** (`folder = nil`); folder records are deleted. If trash off: permanent cascade (`deleteFolderCompletely`) | Core Data + FileStorage |
| F5 | Move folder | Folder picker; cannot move into self or descendants | `CoreDataManager.moveFolder` |
| F6 | Sort folders and files | User Default, Name, Date, Size, Kind, Favorites + ascending/descending toggle | `FolderSortOption` |
| F7 | Empty state | Create folder / add files CTAs | `EmptyStateView` |
| F8 | Swipe to delete | Trailing swipe on folder and file rows; full-swipe allowed only when trash is **off** | SwiftUI `swipeActions` |
| F9 | Folder multi-select | Select All, Move, Delete on folders in selection mode | `FolderViewModel` |

### 4.6 Files — import

| ID | Feature | Behavior | Apple APIs |
|----|---------|----------|------------|
| I1 | Import photos & videos | System photo picker; images **and** videos; **max 50**; `preferredAssetRepresentationMode = .current` | PhotosUI `PHPickerViewController` via `VaultImportService` — **no** `NSPhotoLibraryUsageDescription` (picker is out-of-process) |
| I2 | Import files | Files app / document picker; multi-select; security-scoped read | `UIDocumentPickerViewController` for `image`, `movie`, `video`, `pdf`, `text`, `data` |
| I3 | Web import | Browser upload into current/root folder (see 4.11) | Network.framework HTTP |
| I4 | Duplicate detection | Same `fileSize` + `fileType` in **target folder** → `FileStorageError.duplicateFile` | — |
| I5 | Name collision | Auto-rename `name (n).ext` | — |
| I6 | Import progress overlay | Progress UI during gallery/folder imports | `ImportProgressView` |
| I7 | Thumbnails | Images and videos: 200×200 JPEG @ 0.7, AES-GCM encrypted as `{uuid}.thumb`; videos get a play overlay | `ThumbnailGenerationService`, `EncryptedFileStore`, `UIGraphicsImageRenderer`, AVFoundation image generator |

**Not implemented:** in-app camera / microphone capture (`UIImagePickerController` / `AVCaptureSession` are not used). Import is library + Files + web only.

MIME detection: `FileStorageManager.determineFileType(from:)` by extension; UTI conversion for Photos.

### 4.7 Files — organize, search, share

| ID | Feature | Behavior | APIs |
|----|---------|----------|------|
| O1 | Rename file | Alert; updates the display `fileName` in Core Data. The encrypted blob and encrypted thumbnail stay `{uuid}` / `{uuid}.thumb` on disk | `FileStorageManager.renameFile` |
| O2 | Move file | Universal / gallery folder pickers | Core Data relationship |
| O3 | Favorite | Toggle `isFavorite`; heart in viewer and lists | Core Data |
| O4 | Share / export | Decrypt to temp file → share sheet | `UIActivityViewController`, `ShareManager`, `prepareForSharing` |
| O5 | Delete | Trash if enabled; else permanent delete of the Core Data row, the UUID blob, and the thumbnail | Core Data + FileStorage |
| O6 | Search | **Gallery** and **Category files** use SwiftUI `.searchable` and filter `fileName` immediately (no debounce). Folder browser has **no** search field. | SwiftUI searchable |
| O7 | Sort files | User Default, Name, Size, Date, Kind, Favorites | `SortOption` / `FolderSortOption` |
| O8 | Multi-select | Long-press or “Select”; Select All; Favorite, Share, Move, Delete | Selection toolbars / floating bar |
| O9 | Context menu (file) | Select, Favorite/Unfavorite, Rename, Move, Share, Delete | SwiftUI contextMenu |
| O10 | Grid / list presentation | Gallery grid (`VaultGridView` / `VaultItemCell`); folder rows | SwiftUI |

Add Content sheet (Gallery and Folders, hidden on fake login): Photos & Videos, Files, Web Upload (Gallery also presents `WebUploadView` as a sheet), Create Folder (folders only). **Category files screens do not offer import/add.**

### 4.8 Categories

`CategoryType` (counts exclude trashed items):

| Category | Matching rule |
|----------|----------------|
| Favorites | `isFavorite` |
| Photos | `isImage` (`fileType` prefix `image/`) |
| Videos | Explicit video MIME list (mp4, quicktime, m4v, mpeg, mkv, avi, webm, flv, wmv, 3gpp) |
| Audio | mp3, wav, m4a, aac, ogg, flac MIME list |
| Documents | pdf, Office, text, rtf, zip/rar/7z MIME list |
| Other | Not image/video/audio/document |
| All Files | All non-trashed |

Category files screens reuse search, sort, selection, context menu, and preview. They do **not** add or import files. Counts use `fetchVaultItemsFromAllFolders()` (non-trashed). Photos = `isImage` (any `image/*`); Videos = `isVideo` (fixed MIME list, **not** every `video/*` type).

### 4.9 Trash

| ID | Feature | Behavior |
|----|---------|----------|
| T1 | Enable trash | UserDefaults `trashEnabled`; default **on** after first launch |
| T2 | Soft delete | Sets `isTrashed`, `trashedAt`; folder relationship kept when possible |
| T3 | View trash | Settings → View Trash (`TrashView`) with count |
| T4 | Restore | Clears trash flags (single or multi-select) |
| T5 | Permanent delete | From trash |
| T6 | Empty trash | Bulk permanent delete |
| T7 | Disable trash with items | Alert **Empty Trash & Disable**; cannot disable while keeping trash contents |
| T8 | Delete with trash off | Deletes the item and its on-disk ciphertext and thumbnail immediately |

### 4.10 Preview and media playback

| ID | Feature | Behavior | Apple APIs |
|----|---------|----------|------------|
| P1 | Unified media viewer | Horizontal paging through the current list of photos/videos (gallery/folder pass the filtered media set; File Preview passes a **single** item) | SwiftUI `scrollTargetBehavior(.paging)` |
| P2 | Photo zoom / pan | Pinch, pan, bounds clamping, **double-tap** toggles 1×/2×; zoom disables horizontal paging | `ZoomablePhotoView` (gestures, not `UIScrollView`) |
| P3 | Video autoplay | Page plays when it becomes current (`isActive`) | `AutoPlayVideoView`, `AVPlayer` |
| P4 | Custom video controls | Play/pause, ±15s, scrubber, rates 0.25–2.0×, auto-hide; **pinch/pan and double-tap zoom** on the video surface | `PlayerControlsView`, `AutoPlayVideoView` |
| P5 | File info panel | Name, MIME, size, folder path, created, modified (if another day), favorite | `FileInfoPanel` |
| P6 | Viewer actions | Favorite, Share, dismiss | SwiftUI |
| P7 | Image/video from File Preview | Single-item `UnifiedMediaViewerView` (no sibling paging) | same |
| P8 | Document preview | PDF via PDFKit; plain text in-app; other documents QuickLook | PDFKit, QuickLook |
| P9 | Audio preview | Decrypt to temp file; play/pause/seek; `AVAudioSession` category `.playback` | AVKit, AVFoundation |
| P10 | Unsupported types | Placeholder + QuickLook fallback | QuickLook |
| P11 | Preview loading / error | Dedicated loading and error views | SwiftUI |

Playback decrypts to a temporary file; original vault file stays encrypted.

### 4.11 Web upload (LAN HTTP server)

| ID | Feature | Behavior | Apple APIs |
|----|---------|----------|------------|
| W1 | Start / stop server | Toggle; shows URL `http://<LAN-IP>:8080` | `NWListener`, port **8080**, `includePeerToPeer = true` |
| W2 | Copy URL | Clipboard + light haptic | UIPasteboard |
| W3 | QR code | QR of server URL | Core Image `CIQRCodeGenerator` |
| W4 | Help / instructions | Same-WiFi upload steps | SwiftUI sheet |
| W5 | Pairing | 6-digit code shown in the app; browser posts it to `/pair` (5 attempts) for a session cookie | `WebAccessControl` |
| W5b | Export session | Downloads stay off until Face ID / Touch ID or the vault credential unlocks a 10-minute window; ends on background or Stop Downloads | LocalAuthentication, Keychain |
| W6 | Browser UI | Folder browse, breadcrumbs, upload, manage when not fake login | `WebServerHTMLGenerator`, `WebServerHTMLComponents` |
| W7 | Block fake login | UI disabled; HTTP 403 | — |
| W8 | Background keep-alive | `UIBackgroundTask` named `WebServerUpload` while uploads in flight | UIKit background task |
| W9 | BG processing stub | Registers `com.haresh.FileVault.upload-processing` | BackgroundTasks |
| W10 | Background URLSession | Session id `com.haresh.FileVault.background-upload`; POST `/upload` | `URLSessionConfiguration.background` |
| W11 | Large uploads | `POST /upload` with Content-Length **> 100MB** (`100 * 1024 * 1024`) switches to `handleLargeFileUpload`. Browser can also `POST /upload/stream` | custom HTTP |
| W12 | Gallery web-upload sheet | Same server controls as the tab, presented from Gallery Add Content | `WebUploadView` |

HTTP routes. Every route except `POST /pair` requires the session token (header `X-Vault-Token`, session cookie on GET, or `?token=` on GET). Fake login returns 403 on every route.

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/pair` | Exchange pairing code for session cookie (public; attempt-capped) |
| GET | `/`, `/upload` | Upload HTML |
| GET | `/test`, `/status` | Diagnostics |
| GET | `/api/session` | Whether an export session is active |
| POST | `/upload` | Multipart upload |
| POST | `/upload/stream` | Streaming upload |
| POST | `/api/folder/create` | Create folder |
| POST | `/api/folder/rename` | Rename folder |
| POST | `/api/folder/delete` | Delete folder |
| POST | `/api/file/delete` | Delete file |
| POST | `/api/bulk/delete` | Bulk delete |
| POST | `/api/download/ticket` | Issue a one-shot download ticket for one file, one folder, or a selection (export session required) |
| GET | `/download/t/{ticket}` | Redeem ticket (single use, client-bound, 60s) |

Security notice in UI: local network only; files encrypted after arrival. Downloads use single-use tickets while an export session is open. Download Selected sends the whole selection on one ticket and returns a single `File Vault Selection.zip`. Folder and selection ZIPs stage files with complete file protection and delete the staging directory afterward.

### 4.12 Notifications and haptics

| ID | Feature | Behavior | APIs |
|----|---------|----------|------|
| N1 | Notification permission | Requested on `NotificationManager` init: alert, badge, sound | UserNotifications |
| N2 | In-app toasts | Upload start, 25/50/75/100% milestones, completion | `NotificationOverlayView` |
| N3 | System notification | Fired on **every** upload completion (not only when backgrounded) | `UNUserNotificationCenter` |
| N4 | Upload progress cards | Bottom overlay from `uploadProgress` dictionary | `UploadProgressOverlayView` |
| N5 | Haptics | First Gallery selection: **medium**; security lock: **heavy**; copy URL: **light** | `UIImpactFeedbackGenerator` |

### 4.13 Settings (real login)

| Section | Controls |
|---------|----------|
| Security | Current method; Change Authentication; Fake password set/change/remove; Auto-Lock picker; Biometric toggle + availability (Face ID vs Touch ID) |
| Advanced Security | Screenshot, recording, shake, flip toggles + help text |
| Trash | Enable; View Trash + count |
| Lock Behavior | Read-only restatement of current timeout |
| Disk | Total files; total size (encrypted files + thumbnails) |
| About | Version `1.0.0` |
| Developer (DEBUG only) | Complete App Reset (`exit(0)` after wipe); Simulate First Launch Cleanup; Delete All Files & Folders (keeps passcode/settings) |

All three delete vault files and thumbnails from disk before clearing metadata. Delete All Files & Folders ignores the trash setting and keeps the encryption key loaded, so imports work without unlocking again.

Fake login: **About only**.

### 4.14 Cross-cutting UX

| ID | Feature | Behavior |
|----|---------|----------|
| X1 | Alerts | SwiftUI `.alert` on folder, gallery, category, trash, and settings screens; `FolderViewModel` implements `AlertManageable` |
| X2 | Sheets | SwiftUI `.sheet` / `.fullScreenCover` for pickers, add content, web upload, trash, and auth change |
| X3 | Dark mode | System SwiftUI colors (`Color(.systemGray6)`, etc.); no custom theme engine |
| X4 | Orientations | iPhone: portrait + landscape; iPad: all four |
| X5 | Localization | **English hardcoded strings only** — no `Localizable.strings` |
| X6 | Accessibility | Standard SwiftUI controls; no dedicated VoiceOver audit artifacts |
| X7 | Dynamic Type | Relies on SwiftUI text styles in places; not systematically audited |
| X8 | iPad | Same targets/layouts; no split-view / multiple windows / document browser scene |

---

## 5. Data model

### Folder

| Attribute | Type |
|-----------|------|
| id | UUID |
| name | String (empty at rest; decrypted into RAM after unlock) |
| sealedMetadata | Binary (AES-GCM JSON `{name}`) |
| createdAt, updatedAt | Date |
| items | to-many VaultItem, **cascade** delete |
| parent | to-one Folder, **nullify** |
| subfolders | to-many Folder, **cascade** delete |

### VaultItem

| Attribute | Type |
|-----------|------|
| id | UUID |
| fileName, fileType, thumbnailFileName | String (empty at rest; decrypted into RAM after unlock) |
| fileSize | Int64 (0 at rest; decrypted into RAM after unlock) |
| sealedMetadata | Binary (AES-GCM JSON of name, MIME, size, thumbnail filename) |
| isFavorite, isTrashed | Bool (default false) |
| createdAt, updatedAt, trashedAt | Date |
| folder | to-one Folder, **nullify** |

Store name: `FileVault`. Class codegen: manual (`Folder+CoreData*`, `VaultItem+CoreData*`).

---

## 6. Constants (do not change accidentally in an OS upgrade)

```
Keychain service:                 com.filevault.app
Keychain accessibility:           kSecAttrAccessibleWhenUnlockedThisDeviceOnly
Encryption:                       AES-GCM; key = PBKDF2-HMAC-SHA256 (210k, 16-byte salt)
Keychain derivation account:      vaultKeyDerivation
Auto-lock default:                30 seconds
Auto-lock options (seconds):      0, 5, 10, 15, 30, 60, 300, -1
Biometric max failures:           3 (reset after 30s)
Shake threshold:                  2.5
Password min length:              6
Passcode length:                  exactly 4 or 6 digits
Web server port:                  8080
PHPicker selection limit:         50
Thumbnail size / JPEG quality:    200×200 / 0.7, AES-GCM as `{uuid}.thumb`
BG task id:                       com.haresh.FileVault.upload-processing
Background URLSession id:         com.haresh.FileVault.background-upload
Streaming upload threshold:       100 MB
Security log cap:                 100 entries
```

---

## 7. What this app does **not** include

These are confirmed absences. Do not treat them as regressions unless product adds them later.

- Camera capture, scanning, or microphone recording
- iCloud Drive / CloudKit / iCloud Keychain sync of vault files
- Share Extension, Action Extension, Widgets, Live Activities, App Intents / Siri
- Multiple windows / document-based `DocumentGroup`
- Optic ID (visionOS) — Face ID / Touch ID only
- PIN from system `LAPolicy.deviceOwnerAuthentication` as the primary unlock UI
- Per-file passwords, hidden albums beyond fake-login, or dual encrypted stores
- Contacts, calendar, location, Bluetooth peripherals
- Analytics / crash SDKs
- On-device ML / Vision / Photos intelligence features
- Localization beyond English source strings

---

## 8. Tests that must keep passing

| Target | Coverage (current files) |
|--------|---------------------------|
| File VaultTests | Keychain (including derivation record), Core Data, storage/crypto/thumbnails/trash, VaultCryptoService PBKDF2, Security, Biometric, authentication coordination, shared imports, Folder and VaultMain view models, WebServer HTML/HTTP helpers, DI, EmptyState, video lifecycle |
| File VaultUITests | First-launch authentication, tab/navigation, fake-vault restrictions, add controls, and launch smoke tests |

Upgrade work should run unit tests on the new SDK simulator and a smoke pass of UI tests. Tests are not a substitute for the checklist below.

---

## 9. Upgrade verification checklist

Use this for iOS 27, 28, 29, or any Xcode bump. Check every box against a **device and simulator** of the new OS.

**Auth & lock**

- [ ] First-launch auth type + 4-digit, 6-digit, and password setup
- [ ] Unlock with credential; Face ID; Touch ID (if hardware exists)
- [ ] Biometric cancel → passcode; 3 failures → 30s block
- [ ] Auto-lock: immediate, 30s, never
- [ ] App Switcher does not reveal vault contents
- [ ] Change auth re-encrypts files; old credential cannot decrypt
- [ ] Fake password: empty UI, no add, no web server, About-only settings
- [ ] Shake to lock / flip to lock when enabled

**Files**

- [ ] PHPicker import up to 50 photos/videos; HEIC/JPEG/PNG/GIF/WebP; MOV/MP4
- [ ] Document picker: PDF, text, Office-like, zip, audio
- [ ] Duplicate and rename-collision behavior unchanged
- [ ] Nested folders: create, rename, move (no cycle), delete + trash rules, swipe-to-delete
- [ ] Gallery search (filename, live filter); Category search; folders have no search
- [ ] Sort, multi-select, share, favorite (Gallery, Folders, Categories)
- [ ] Categories counts and filters
- [ ] Trash restore / empty / disable-with-contents alert

**Preview**

- [ ] Photo pinch/pan/double-tap zoom and paging
- [ ] Video play, scrub, ±15s, speed menu, autoplay next, pinch/double-tap zoom
- [ ] Audio play/seek
- [ ] PDF/QuickLook
- [ ] Share decrypts a usable temp file

**Web & background**

- [ ] Start server; URL + QR open from another device on Wi‑Fi
- [ ] Upload small and >100MB files; folder CRUD from browser
- [ ] Downloads remain off by default; work when enabled
- [ ] Fake login cannot start server
- [ ] Backgrounding during upload: in-app + system notifications
- [ ] Local network permission prompt (if the new OS requires it) does not break start/stop

**Data integrity**

- [ ] Existing vault from previous OS still unlocks with same credential (PBKDF2 salt in Keychain, or SHA-256 ciphertext rewritten on first unlock)
- [ ] Thumbnails still load; Core Data store migrates without loss
- [ ] Keychain items survive the upgrade (same bundle ID), including `vaultKeyDerivation`

**Build**

- [ ] Warn-as-known: deprecations listed in [IOS_27_UPGRADE_PLAN.md](IOS_27_UPGRADE_PLAN.md) only
- [ ] No new unprotected network endpoints (LAN server is opt-in; `POST /pair` is the only public route and is attempt-capped)

---

## 10. Known source/docs mismatches (not upgrade work)

Recorded so upgrades do not “fix” the wrong thing:

1. Keychain service `com.filevault.app` ≠ bundle id `com.haresh.FileVault`.
2. `FileVaultApp` notes that background URLSession events are not handled via `AppDelegate`.
3. About UI version `1.0.0` vs `MARKETING_VERSION` `1.0`.
4. MIME mismatches: `isAudio` includes `audio/x-m4a` / ogg / flac, but `determineFileType` maps `.m4a` → `audio/mp4` and has **no** ogg/flac/zip/rtf/Office cases (those become `application/octet-stream` → **Other** unless another importer supplies a MIME).
5. Screenshot/recording Settings toggles are not persisted (see §4.3).
6. `LoginStateManager.visibleSettingSections` omits Trash and does not drive `SettingsView` (the view uses `canAccessFullSettings` instead).
7. Screenshot detection shows an alert even when screenshot protection is off; only the inactive-state overlay is gated.

---

## 11. Open questions (need product confirmation)

If any of these are wrong, say so and this catalog will be corrected:

1. **Fake vault:** Confirm it is intentionally a *UI disguise* (empty lists), not a second encrypted dataset.
2. **Camera:** Confirm there is no in-app camera and we should not add one during OS upgrades.
3. **Optic ID / visionOS / Mac Catalyst:** In or out of scope for upcoming upgrades?
4. **Minimum OS after upgrade:** Keep supporting iOS 18.5, or raise the deployment target to the new OS only?

---

## 12. Maintenance rule

Any PR that adds, removes, or changes a user-visible behavior must update:

- This file (`docs/FEATURES.md`)
- The upgrade verification checklist if a new testable behavior appears
- README only for marketing-level changes (keep this file as the source of truth)
