# iOS 27 compatibility (Keepshire)

Keep Keepshire building with the **iOS 27 SDK (Xcode 27)** without changing product behavior. Every item in [FEATURES.md](FEATURES.md) must still work.

**Out of scope unless a new OS release forces it:**

- Raising the deployment target above **iOS 18.5**
- Enabling Swift 6 language mode / complete concurrency checking
- Redesigning for Liquid Glass
- Product bug fixes (MIME mismatches)

**Sources:** [docs/FEATURES.md](FEATURES.md), iOS & iPadOS 27 release notes, Xcode 27 release notes.

## Current baseline

| Field | Value |
|--------|--------|
| Deployment target | **iOS 18.5** |
| Swift language mode | **5.0** |
| Info.plist | Checked-in `Keepshire/Info.plist` |
| Face ID | `NSFaceIDUsageDescription` = `Use Face ID to unlock Keepshire` |
| Local network | `NSLocalNetworkUsageDescription` for LAN web upload |
| Background modes | None declared; LAN uploads use finite foreground-app background time |
| Launch screen | Explicit `UILaunchScreen` dictionary |
| Scene manifest | Explicit in Info.plist |
| Warning dump | [docs/ios27-baseline-warnings.txt](ios27-baseline-warnings.txt) |

UI uses `NavigationStack`, `.tint`, `@Environment(\.dismiss)`, and two-parameter `.onChange`. Five tabs stay visible. Share and security overlays use the foreground scene’s window/screen where possible. `LABiometryType.opticID` is treated as unavailable on iPhone/iPad.

Run unit tests **serially** (`-parallel-testing-enabled NO`) on Xcode 27. Parallel clone runners can crash the Swift Testing harness.

Device/simulator checks that need a person: Face ID, App Switcher, fake vault, pickers, folder CRUD, media zoom/paging, LAN upload, screenshot/recording overlay, existing-vault unlock, iPad context-menu icons. Use [FEATURES.md §9](FEATURES.md#9-upgrade-verification-checklist).

## Compatibility vs iOS 27

AES-GCM, Keychain, Core Data, PHPicker, `NWListener`, AVPlayer, PDFKit, QuickLook, Face ID/Touch ID, screenshot notification, and capture detection remain available.

| Feature / API | iOS 27 status | App approach |
|-----------------|---------------|--------------|
| SwiftUI `WindowGroup` scene | Required | Keep |
| Explicit `UILaunchScreen` | Required when linking the iOS 27 SDK | Keep the Info.plist dictionary |
| `NavigationView` | Deprecated | `NavigationStack` |
| `.accentColor(_:)` | Soft-deprecated | `.tint(_:)` |
| `@Environment(\.presentationMode)` | Deprecated | `@Environment(\.dismiss)` |
| `.onChange(of:) { _ in }` | Deprecated | `.onChange(of:) { _, _ in }` |
| `TabView(selection:)` + `.tabItem` | Supported; crash if a selected tab is hidden | Five always-visible tabs |
| Context menu `Label(..., systemImage:)` | iPadOS 27 hides SF Symbols by default | `.labelStyle(.titleAndIcon)` on those labels |
| `UIScreen.main.isCaptured` | Extra screens may not be `UIScreen.main` | Scene’s `screen.isCaptured` |
| Extra `UIWindow` at `alert + 1` | Valid; appearance may differ under Liquid Glass | Opaque black cover |
| `PHPickerViewController` | Supported | Keep (no `UIImagePickerController`) |
| `NWListener` + `includePeerToPeer` | Supported | Keep |
| Local HTTPS on :8080 | May prompt for local network; browser warns on the self-signed cert | `NSLocalNetworkUsageDescription` |
| `LAContext` Face ID / Touch ID | `biometryType` can be `.opticID` | Map Optic ID as unavailable; Face ID / Touch ID / vault credential |
| CryptoKit AES-GCM + CommonCrypto PBKDF2 | Supported | Keep |
| Keychain `WhenUnlockedThisDeviceOnly` | Supported | Keep |
| `FileProtectionType.complete` | Supported | Keep |
| `userDidTakeScreenshotNotification` | Supported | Alert when screenshot protection is on; blanking uses a secure text-entry layer |
| Swift 6 language mode | Optional | Keep `SWIFT_VERSION = 5.0` |

Optic ID is not an unlock path on this iPhone/iPad app.

## Strategy for a later SDK

1. Compile with the new SDK. Leave `IPHONEOS_DEPLOYMENT_TARGET = 18.5` unless product raises the minimum OS.
2. Freeze behavior: same screens, encryption, and fake-vault rules. Replace APIs only when the SDK requires it.
3. Capture warnings, compare to [ios27-baseline-warnings.txt](ios27-baseline-warnings.txt).
4. Re-run [FEATURES.md §9](FEATURES.md#9-upgrade-verification-checklist).

Do not enable `SWIFT_STRICT_CONCURRENCY = complete`. Do not change Core Data, encryption, or the HTTPS server as part of an SDK bump.

## Verification extras on iOS 27

| Check | Why |
|--------|-----|
| First launch → 4-digit / 6-digit / password setup | NavigationStack setup |
| Unlock Face ID + passcode fallback | Optic ID must not break `canUseBiometrics` |
| Auto-lock 0 / 30s / never; App Switcher opaque | System chrome must not reveal vault |
| Fake password empty UI, no web server | Must not regress |
| PHPicker 50 items; Files picker | Picker dismiss |
| Folder CRUD, swipe delete, share | Context menus + NavigationStack |
| Photo paging/zoom; video scrub/speed/pinch; audio; PDF | Player + preview |
| LAN HTTPS server; other device uploads small + >100MB | Local network prompt; self-signed cert warning |
| Screen recording overlay; screenshot notice | Scene screen vs `UIScreen.main` |
| iPhone and iPad; iPad context menu icons | TabView + menu image policy |
| Existing vault from an iOS 18.5 build still unlocks | Keychain + AES-GCM + Core Data |
| Serial unit tests + UI smoke tests | Harness stability on Xcode 27 |
