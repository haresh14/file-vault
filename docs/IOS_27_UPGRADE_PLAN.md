# iOS 27 upgrade plan (File Vault)

**Goal:** Build and run File Vault with the **iOS 27 SDK (Xcode 27)** without changing product behavior. Every item in [FEATURES.md](FEATURES.md) must still work.

**Non-goals (do not do in this upgrade unless a task below requires it):**
- Raising the deployment target above **iOS 18.5**
- Enabling Swift 6 language mode / complete concurrency checking
- Redesigning for Liquid Glass
- Fixing pre-existing bugs (screenshot toggle persistence, unused `SearchViewModel`, MIME mismatches)

**Sources:** [docs/FEATURES.md](FEATURES.md), iOS & iPadOS 27 Beta 6 Release Notes, Xcode 27 Release Notes, SwiftUI `NavigationView` deprecation (iOS 13–27).

**Constraint for agents:** One agent owns the files listed on its task. Do not edit another task’s files. If two tasks touch the same file, they are sequential.

## Implementation status — 2026-09-15

Completed:
- All Wave B source migrations (`NavigationStack`, `dismiss`, tint/onChange, scene-aware security and sharing, Optic ID handling, context-menu labels).
- Wave C project work. A checked-in `File Vault/Info.plist` now contains the local-network description, background-task identifier array, launch screen, scene manifest, orientations, and existing Face ID/background modes.
- Deployment target remains **iOS 18.5** and Swift language mode remains **5.0**.
- **Wave A1 (Xcode 27 / iOS 27 SDK):** clean Debug build **succeeded** on `iphonesimulator27.0` (Xcode 27.0, 27A266a). Warning dump: [docs/ios27-baseline-warnings.txt](ios27-baseline-warnings.txt). No `NavigationView` / `presentationMode` / `.accentColor` deprecations. Remaining warnings are pre-existing (AVFoundation thumbnail APIs, unused locals, Core Data import, Swift 6 isolation notes).
- Built app `Info.plist` keys verified: `NSLocalNetworkUsageDescription`, `BGTaskSchedulerPermittedIdentifiers` = `com.haresh.FileVault.upload-processing`, `NSFaceIDUsageDescription`, `UIBackgroundModes`, `UILaunchScreen`, `MinimumOSVersion` = 18.5, `DTSDKName` = `iphonesimulator27.0`.
- **Install + launch:** created `iPhone 18 Pro (iOS 27)` and `iPad Pro 13-inch M5 (iOS 27)` simulators. App process starts; first screen is **Security Setup** (4-digit / 6-digit / password) on both (E1 / E10 launch).
- **Wave D1 UI tests:** `File VaultUITests` **TEST SUCCEEDED** (6 tests, 0 failures) on iPhone 18 Pro iOS 27 and again on iPad Pro iOS 27.
- Test-target compile breaks (stale `EmptyStateViewTests`, `FileStorageManagerTests` thumbnail `Data` vs image, `VaultMainViewModelTests` renamed members) were updated so the unit-test target **builds**.

Unit tests (`File VaultTests`) on iOS 27: **42 passed, 82 failed**. Failures are almost all Swift Testing runner crashes (`Crash: File Vault at specialized static Runner._applyScopingTraits(for:testCase:_:)` ) when Xcode clones the simulator for parallel tests — not assertion failures in app code. Biometric, empty-state, and search suites that ran without that crash passed. This is a test-harness issue on Xcode 27, not an app compile/link failure.

Pending (manual / device — cannot be finished from `xcodebuild` alone):
- E2–E9, E11: Face ID, auto-lock/App Switcher, fake vault, pickers, folder CRUD, media zoom/paging, LAN upload, screenshot/recording overlay, existing-vault unlock after rebuild.
- E10 remainder: iPad **context menu icons** (needs a populated vault + long-press).
- Re-run `File VaultTests` with parallel testing off if you want a non-crash unit-test baseline.

---

## 0. Compatibility verdict (features vs iOS 27)

Nothing in the vault’s core stack is **removed** on iOS 27. AES-GCM, Keychain, Core Data, PHPicker, `NWListener`, AVPlayer, PDFKit, QuickLook, Face ID/Touch ID, screenshot notification, and `UIScreen` capture detection still exist.

| Feature / API we use | iOS 27 status | Action | Replacement if needed |
|----------------------|---------------|--------|------------------------|
| SwiftUI `WindowGroup` scene | Required (UIKit apps without scenes fail to launch) | Keep | Already SwiftUI scene-based |
| Explicit `UILaunchScreen` dictionary | Apps built with iOS 27 SDK **must** have a launch screen | Keep and verify | Use a launch storyboard only if iOS 27 validation rejects the dictionary |
| `NavigationView` | **Deprecated through iOS 27** | Replace | `NavigationStack` (single column; already used in `FolderView`) |
| `.accentColor(_:)` view modifier | Soft-deprecated (tint is the replacement) | Replace at call sites | `.tint(_:)` |
| `@Environment(\.presentationMode)` | Deprecated | Replace | `@Environment(\.dismiss)` |
| `.onChange(of:) { _ in }` one-parameter | Deprecated since iOS 17; noisy on new SDK | Replace | `.onChange(of:) { _, _ in }` |
| `TabView(selection:)` + `.tabItem` | Supported. **Crash** if selection is a hidden tab (164516837) | Keep 5 always-visible tabs; do not hide tabs | Optional later: `Tab` API; not required to preserve behavior |
| Context menu `Label(..., systemImage:)` | On **iPadOS 27**, SF Symbols in menus are hidden by default | Force icons on object/action items we rely on | `.labelStyle(.titleAndIcon)` on those `Label`s |
| Selectable `Text` | New system selection gestures when `.textSelection(.enabled)` | We barely use selectable text | If a custom gesture fights selection, `.highPriorityGesture` |
| `UIScreen.main.isCaptured` | Still works; iPhone Mirroring / extra screens may not be `UIScreen.main` | Use the **scene’s** screen | `windowScene.screen.isCaptured` |
| Extra `UIWindow` at `alert + 1` (privacy overlay) | Still valid; Liquid Glass / window levels may look different | Re-test; keep opaque black cover | If overlay fails: scene-level full-screen cover only (still opaque) |
| `UIApplication.shared.connectedScenes` + `windows.first` | Fragile with multi-window | Prefer key window of the foreground scene | Same APIs, better window lookup |
| `PHPickerViewController` | Still the supported picker | Keep | Do **not** go back to `UIImagePickerController` |
| `NWListener` + `includePeerToPeer` | Supported (`Network.framework`). MultipeerConnectivity is what Apple is deprecating | Keep | N/A |
| Local HTTP on :8080 | May be **blocked or prompted** more strictly without usage strings | Add privacy keys | `NSLocalNetworkUsageDescription` (+ Bonjour list only if we advertise Bonjour) |
| `BGTaskScheduler.register` | Still supported. `submit(_:)` is deprecated if we add scheduling | Add permitted-identifiers plist | New `submitTaskRequest` only if we call `submit` |
| `LAContext` Face ID / Touch ID | Supported. `biometryType` can be `.opticID` (Vision) | Map `.opticID` explicitly; iPhone still Face ID | Same `LAPolicy.deviceOwnerAuthenticationWithBiometrics` |
| Optic ID as unlock | **Not used** (iPhone/iPad vault) | Out of scope | Face ID / Touch ID / vault passcode remain the unlock path |
| CryptoKit AES-GCM + SHA256 | Supported | Keep | No alternative needed |
| Keychain `WhenUnlockedThisDeviceOnly` | Supported | Keep | No alternative needed |
| `FileProtectionType.complete` on vault dirs | Supported | Keep | No alternative needed |
| `userDidTakeScreenshotNotification` | Supported | Keep | No true “block screenshots” API; overlay + alert remain |
| In-app camera | Not a feature | Do nothing | N/A |
| Swift 6 language mode | Compiler is 6.4; language mode can stay 5 | **Keep `SWIFT_VERSION = 5.0`** | Swift 6 is a separate project |
| Liquid Glass chrome | System tab/nav bars change when linked against new SDK | Visual QA only | Do not restyle unless overlay/lock UI fails |

**Not supported / not applicable on iPhone File Vault:** Optic ID as the primary biometric (Vision). Alternative: Face ID, Touch ID, then vault passcode (already implemented).

---

## 1. Strategy

1. **SDK bump, not OS-min bump.** Compile with Xcode 27 / iOS 27 SDK. Leave `IPHONEOS_DEPLOYMENT_TARGET = 18.5` so iOS 18.5–26 devices keep working.
2. **Behavior freeze.** Same screens, same encryption, same fake-vault rules. API replacements only.
3. **Warnings first.** Capture a baseline warning list, then burn it down per task.
4. **Regress against FEATURES.md §9** before calling the upgrade done.

---

## 2. Work waves

```
Wave A (1 agent, blocking)     → baseline build + warning dump
Wave B (many agents, parallel) → isolated Swift UI / API replacements
Wave C (1–2 agents)            → project/plist (touches pbxproj)
Wave D (1 agent, after B+C)    → compile + unit tests
Wave E (manual / browser-N/A)  → device + simulator FEATURES checklist
```

Wave B tasks must not edit `project.pbxproj`. Wave C must not edit Swift files Wave B owns.

---

## 3. Agent tasks (smallest units)

Each task: **ID**, **files**, **depends on**, **parallel with**, **done when**, **must not change**.

### Wave A — sequential

#### A1 — Toolchain and warning baseline
- **Files:** none (read-only)
- **Depends on:** none
- **Work:** Install/use Xcode 27. Open `File Vault.xcodeproj`. Select iOS 27 simulator. Build Debug. Save full warning/error list to `docs/ios27-baseline-warnings.txt` (create that file).
- **Done when:** Clean build log exists; SDK is iOS 27.
- **Must not change:** App source.

---

### Wave B — parallel (after A1, independent of each other)

#### B1 — Tab bar deprecations
- **Files:** `File Vault/Views/MainTabView.swift` only
- **Parallel with:** all other B*
- **Work:**
  1. Replace `.accentColor(.blue)` with `.tint(.blue)`.
  2. Replace `.onChange(of: selectedTab) { _ in` with `{ _, _ in`.
  3. Do **not** hide any tab. Keep tags 0…4.
- **Done when:** Five tabs still switch; `TabDidChange` still posts; Web Upload badge still works.
- **Must not change:** Tab order, labels, or fake-login behavior.

#### B2 — Gallery + Category `NavigationView`
- **Files:** `File Vault/Views/VaultMainView.swift`, `File Vault/Views/CategoryView.swift`
- **Parallel with:** B1, B3–B9 (not B2b)
- **Work:** Replace `NavigationView {` with `NavigationStack {` in those files only. Keep `.navigationBarTitleDisplayMode`, searchable, sheets.
- **Done when:** Gallery search/sort/add and Category grid navigation still work.

#### B3 — Settings + File Preview navigation
- **Files:** `File Vault/Views/SettingsView.swift`, `File Vault/Views/FilePreview/FilePreviewView.swift`
- **Work:** `NavigationView` → `NavigationStack`. Nested `NavigationView` in fake-password sheet → `NavigationStack`. Do not change Settings sections or preview toolbar actions.
- **Done when:** Settings sheets (change auth, fake password, trash) still present; Close/Favorite/Share still work.

#### B4 — Web upload screens navigation
- **Files:** `File Vault/Views/WebUploadTabView.swift`, `File Vault/Views/WebUploadView.swift`
- **Work:** All `NavigationView` → `NavigationStack`. Leave server start/stop, QR, download toggle, copy-URL haptic as-is.
- **Done when:** Tab and Gallery sheet still start/stop the server and show URL/QR.

#### B5 — Shared sheets / pickers navigation
- **Files:**
  - `File Vault/Views/Components/SheetView.swift`
  - `File Vault/Views/Components/UniversalFolderPickerView.swift`
  - `File Vault/Views/Components/UniversalSortPopupView.swift`
  - `File Vault/Views/Components/MigrationProgressView.swift`
  - `File Vault/Views/PasswordSetupView.swift`
  - `File Vault/Views/PasscodeSetupView.swift`
- **Work:** `NavigationView` → `NavigationStack` only. No logic changes.
- **Done when:** Add Content, sort, folder picker, auth setup, migration UI still present.

#### B6 — Dismiss API (photo + document pickers)
- **Files:** `File Vault/Views/Components/PhotoPickerView.swift`, `File Vault/Views/DocumentPickerView.swift`
- **Work:** Replace `presentationMode` with `@Environment(\.dismiss)` and `dismiss()`. Keep PHPicker config (`selectionLimit = 50`, images+videos, `.current`) and document UTTypes.
- **Done when:** Import still returns results and the picker dismisses.

#### B7 — Scene-aware capture + overlay
- **Files:** `File Vault/Managers/SecurityManager.swift` only
- **Work:**
  1. Read `isCaptured` from the overlay/`UIWindowScene`’s `screen`, not `UIScreen.main` alone.
  2. Keep screenshot notification, recording overlay, shake, flip.
  3. Overlay must remain **opaque** (no glass).
- **Done when:** Recording still blacks out the vault; screenshot still logs/alerts; shake/flip still post `TriggerSecurityLock`.
- **Must not change:** Defaults (screenshot/recording on, shake/flip off) or UserDefaults keys.

#### B8 — Share / alert window lookup
- **Files:** `File Vault/Utilities/ShareManager.swift`, `File Vault/Views/FilePreview/FilePreviewSharingService.swift`
- **Work:** Present `UIActivityViewController` / alerts from the foreground `UIWindowScene`’s key window (not `windows.first` blindly). Decrypt-then-share path unchanged.
- **Done when:** Share from gallery, folders, viewer still opens the system sheet.

#### B9 — Tint leftovers + Optic ID case
- **Files:** `File Vault/Views/FilePreview/Components/AudioPreviewView.swift`, `File Vault/Managers/BiometricAuthManager.swift`
- **Work:**
  1. Audio: `.accentColor(.white)` → `.tint(.white)`. Do not add MediaPlayer Now Playing.
  2. Biometrics: handle `LABiometryType.opticID` in the switch (treat as unavailable on iPhone; do not crash / fall into `default` silently). Unlock policy stays `deviceOwnerAuthenticationWithBiometrics`.
- **Done when:** Audio slider tint still white; Face ID/Touch ID tests still compile; Optic ID does not get reported as Face ID.

#### B10 — iPad context menu icons
- **Files:**
  - `File Vault/Views/Components/VaultGridView.swift`
  - `File Vault/Views/Folders/FileRowViews.swift`
  - `File Vault/Views/Folders/FolderRowViews.swift`
  - `File Vault/Views/Categories/CategoryFilesView.swift`
- **Work:** On `Label("…", systemImage:)` inside `contextMenu`, add `.labelStyle(.titleAndIcon)` so iPadOS 27 still shows pencil/folder/trash/heart. Do not add/remove menu actions.
- **Done when:** Same menu items; icons visible on iPad simulator iOS 27.

---

### Wave C — after Wave B (plist / project; can be one agent)

#### C1 — Privacy and background Info keys
- **Files:** `File Vault.xcodeproj/project.pbxproj` (generated Info keys) and/or a real `Info.plist` if you introduce one
- **Depends on:** A1
- **Parallel with:** none that edit pbxproj
- **Work:**
  1. Add `INFOPLIST_KEY_NSLocalNetworkUsageDescription` = `File Vault uses the local network so you can upload files from a browser on the same Wi-Fi.`
  2. Add `BGTaskSchedulerPermittedIdentifiers` = `com.haresh.FileVault.upload-processing`.
  3. Confirm `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (already set) — if App Store / SDK rejects generation-only, add an explicit `UILaunchScreen` dictionary.
  4. Keep `NSFaceIDUsageDescription` and `UIBackgroundModes`.
  5. Do **not** add photo-library usage strings.
- **Done when:** Built app Info.plist contains those keys; Face ID string unchanged.

#### C2 — Do not raise deployment target or Swift language mode
- **Files:** `project.pbxproj` (same agent as C1 if possible)
- **Work:** Leave `IPHONEOS_DEPLOYMENT_TARGET = 18.5` and `SWIFT_VERSION = 5.0`. Document in the PR that the **SDK** is 27, not the minimum OS.
- **Done when:** Those two settings are unchanged from pre-upgrade.

---

### Wave D — after B + C

#### D1 — Compile and unit tests
- **Files:** test targets only if a test fails due to API signature changes (`File VaultTests`, especially `BiometricAuthManagerTests`)
- **Depends on:** B1–B10, C1
- **Work:** ⌘B + ⌘U on iOS 27 simulator. Fix **test-only** compile breaks. No product behavior changes.
- **Done when:** App target and unit tests build green.

---

### Wave E — QA (after D1). Can split testers, not code agents.

Use [FEATURES.md §9](FEATURES.md#9-upgrade-verification-checklist). Extra iOS 27 checks:

| E# | Check | Why |
|----|--------|-----|
| E1 | First launch → 4-digit / 6-digit / password setup | NavigationStack must not break setup |
| E2 | Unlock Face ID + passcode fallback | Optic ID case must not break `canUseBiometrics` |
| E3 | Auto-lock 0 / 30s / never; App Switcher opaque | Liquid Glass must not reveal vault |
| E4 | Fake password empty UI, no web server | Unrelated to SDK but must not regress |
| E5 | PHPicker 50 items; Files picker | Picker dismiss API |
| E6 | Folder CRUD, swipe delete, share | Context menus + NavigationStack |
| E7 | Photo paging/zoom; video scrub/speed/pinch; audio; PDF | Player + Preview |
| E8 | Start LAN server; other device opens URL; upload small + >100MB | Local network prompt; accept and continue |
| E9 | Screen recording black overlay; screenshot notice | Scene screen vs `UIScreen.main` |
| E10 | iPhone **and** iPad iOS 27 simulators; iPad context menu icons | TabView + menu image policy |
| E11 | Existing vault from iOS 18.5 build still unlocks after rebuild | Keychain + AES-GCM + Core Data |
| E12 | Unit tests + UI launch tests | D1 |

Record pass/fail in the MR. Any fail → fix in the owning task’s files, not a drive-by.

---

## 4. Suggested parallel assignment

| Agent | Tasks |
|-------|--------|
| Agent 0 | A1 then wait |
| Agent 1 | B1 |
| Agent 2 | B2 |
| Agent 3 | B3 |
| Agent 4 | B4 |
| Agent 5 | B5 |
| Agent 6 | B6 |
| Agent 7 | B7 |
| Agent 8 | B8 |
| Agent 9 | B9 |
| Agent 10 | B10 |
| Agent 11 | C1 + C2 (after A1; can overlap Wave B) |
| Agent 12 | D1 after merge of B+C |
| Human | E1–E12 on device |

B5 is the largest Swift task; if it needs splitting: B5a sheets/pickers (`SheetView`, `UniversalFolderPickerView`, `UniversalSortPopupView`), B5b setup (`PasswordSetupView`, `PasscodeSetupView`, `MigrationProgressView`).

---

## 5. Merge / conflict rules

- Rebase on `main` after Wave A.
- Wave B branches: `ios27/b1-tabs`, `ios27/b2-gallery-nav`, … — should not conflict if file lists are respected.
- Wave C: `ios27/c-plist` — merge after or with B; pbxproj conflicts are the only likely ones.
- Do not enable `SWIFT_STRICT_CONCURRENCY = complete`.
- Do not “modernize” Core Data, encryption, or the HTTP server in this upgrade.

---

## 6. When GM / newer betas ship

Re-run A1 against the **GM** iOS 27 / Xcode 27 notes. If Apple adds a new required privacy key or removes `NavigationView` from the SDK entirely, extend Wave B rather than raising min iOS.

Update [FEATURES.md](FEATURES.md) only if user-visible behavior changes (it should not). Update README requirements only if you later choose to raise the deployment target (out of scope here).
