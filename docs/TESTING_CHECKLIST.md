# Testing Checklist - Core Features

Use this checklist against a simulator or device. Automated coverage lives in `KeepshireTests` (run serially) and `KeepshireUITests`.

Home screen shows **Keepshire**. Face ID and local-network prompts use that name. This bundle ID is a fresh vault.

## Pre-test

- [ ] Project opens in Xcode
- [ ] App builds (Cmd+B)
- [ ] App runs on simulator or device (Cmd+R)

Face ID, local network, and launch screen strings are already in `Keepshire/Info.plist`.

## First launch

1. [ ] Delete the app (or use DEBUG Settings → Simulate First Launch Cleanup)
2. [ ] Launch: **Security Setup** with 4-digit passcode, 6-digit passcode, and password
3. [ ] Continue into setup:
   - [ ] 4-digit: exact length, confirm match
   - [ ] 6-digit: exact length, confirm match
   - [ ] Password: minimum 6 characters, confirm match
4. [ ] After setup, the five tabs appear: Folder, Category, Gallery, Web Upload, Settings

## Main tabs

1. [ ] Folder: empty-state create folder / add files; nested folders; swipe delete
2. [ ] Category: Favorites, Photos, Videos, Audio, Documents, Other, All Files
3. [ ] Gallery: grid, search, add content (photos/videos, files, web upload)
4. [ ] Web Upload: start/stop server, URL, QR; fake login cannot start the server
5. [ ] Settings: Security, Advanced Security, Trash, disk usage, About version matches the built marketing version and build number

## Auto-lock

Default timeout is **30 seconds**. Options: Immediately, 5s, 10s, 15s, 30s, 1 min, 5 min, Never.

1. [ ] Immediately: return from background → credential (or biometrics)
2. [ ] 30 seconds: return before 30s → stay unlocked; after 30s → lock
3. [ ] Never: return after a long wait → stay unlocked

## Privacy overlay

- [ ] App Switcher preview does not show vault contents (lock cover)

## Biometrics

Simulator: Features → Face ID → Enrolled / Matching Face / Non-matching Face. Prefer a physical device.

1. [ ] Settings toggle matches hardware (Face ID or Touch ID)
2. [ ] After timeout, biometric prompt runs first
3. [ ] Cancel biometric → passcode/password UI
4. [ ] Success unlocks the real vault

## Unlock

1. [ ] Wrong credential → error, fields clear
2. [ ] Correct credential → tabs
3. [ ] Fake password (if set) → empty UI, no add, no web server, Settings About only

## Change authentication

- [ ] Change method in Settings re-encrypts files
- [ ] If re-encrypt cannot finish, the old credential still opens files
- [ ] Old credential cannot decrypt after a successful change
- [ ] Fake password is cleared

## Vault encryption

- [ ] New install: import a photo, lock, unlock — file still opens
- [ ] Settings → Change Authentication: files still open with the new credential; the old one does not
- [ ] Vault that existed before PBKDF2: first unlock after this build still shows files (may pause briefly while files are rewritten)
- [ ] Imported file keeps its name in Gallery; the file in `Documents/Vault/` is a UUID, not `vacation.jpg`
- [ ] Rename in the app changes the Gallery name; the UUID blob on disk stays the same
- [ ] Older vault files named after the display name still open after first unlock (they are moved to UUID)
- [ ] Import a photo: Gallery thumbnail shows; `Documents/Thumbnails/{uuid}.thumb` is not a JPEG on disk
- [ ] Vault that had plaintext thumbs: first unlock still shows thumbnails (files are rewritten under AES-GCM)
- [ ] After unlock, Gallery search still matches the original filename
- [ ] Lock the device, inspect `Keepshire.sqlite` (or a Core Data dump): `fileName` / folder `name` are empty; `sealedMetadata` is present
- [ ] Share a file, cancel the sheet, lock the app: no decrypted file remains under `tmp/keepshire-share/`
- [ ] Import a video from Photos; the app stays running (does not jetsam on a large clip under 2 GB)
- [ ] Files larger than 2 GB fail import with an error

## Files and folders

- [ ] Import up to 50 photos/videos; document picker
- [ ] Nested folders: create, rename, move, delete
- [ ] Gallery and category search; folder tab has no search
- [ ] Sort, multi-select, favorite, share, rename, move
- [ ] Trash restore / empty / disable with contents
- [ ] Trash off: delete a file and confirm its `Documents/Vault/` blob and `Documents/Thumbnails/` thumb are gone
- [ ] Unlock clears vault files and thumbnails that belong to no item

## Preview

- [ ] Photo pinch, pan, double-tap zoom, swipe between items
- [ ] Video play/pause, scrubber, ±15s, speed, pinch/double-tap zoom
- [ ] Audio; PDF; other documents via QuickLook

## Web upload

- [ ] Fresh install: launch and unlock do not request notification permission; starting Web Upload requests it once
- [ ] Upload with the app on screen: in-app completion banner appears, no duplicate system banner
- [ ] Upload while the app is in the App Switcher: a system notification arrives, as long as the transfer finishes within the short window iOS allows a backgrounded app
- [ ] Lock the device, then upload from the browser: the page says the iPhone is locked instead of a file-permission error, and any export session has ended
- [ ] Unlock the device and retry the same upload: it succeeds without restarting the server
- [ ] With notifications refused in Settings: starting the server shows a banner that opens this app's Settings page when tapped
- [ ] Banners without an action still let taps reach the screen underneath
- [ ] Start server on port 8080; open the **https** URL from another device on the same Wi‑Fi
- [ ] Browser warns about the certificate; accept it, then enter the 6-digit pairing code; uploads work after pairing
- [ ] Downloads stay hidden until Allow Downloads is confirmed with Face ID or the vault credential
- [ ] After that, per-file/folder download icons and Download Selected appear; they vanish when the session ends
- [ ] Download Selected with several files and folders picked returns one ZIP named Keepshire Selection.zip containing every pick
- [ ] Upload small and large files

## Device security

- [ ] Screenshot protection on: vault stays visible; the image in Photos is blank; one alert says the shot is blank, and one entry lands in the security log
- [ ] Lock screen, sheets (Settings, Web Upload, pickers), and full-screen previews look normal on the device and are blank in the screenshot
- [ ] Screenshot protection off: no blanking alert; screenshot can include the vault
- [ ] Screenshot and recording toggles still match after relaunch
- [ ] Screen recording overlay when that toggle is on; it stays up after switching apps and back, and when a recording is already running at launch
- [ ] Shake to lock / flip to lock when enabled

## Developer (DEBUG)

- [ ] Complete App Reset → Security Setup on relaunch; `Documents/Vault/` and `Documents/Thumbnails/` are empty
- [ ] Delete All Files & Folders keeps the credential and empties both storage directories, with trash on and off

## App Store compliance

- [ ] Home screen icon is labeled Keepshire
- [ ] Face ID prompt says “unlock Keepshire”
- [ ] Local-network prompt names Keepshire
- [ ] iPad does not offer a second app window
- [ ] Archive contains `PrivacyInfo.xcprivacy` with UserDefaults reason CA92.1 and no tracking declaration
- [ ] Archive Info.plist has `ITSAppUsesNonExemptEncryption = YES`
- [ ] Release run emits no verbose vault request, path, filename, or security-state diagnostics
- [ ] Settings → About: Privacy Policy opens https://keepshire.haresh.dev/privacy and Support opens https://keepshire.haresh.dev/support
- [ ] App Store Connect export answers, privacy answers, review notes, and URLs match the app and developer guide

## Automated tests

```sh
xcodebuild -project "Keepshire.xcodeproj" -scheme "Keepshire" \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test -only-testing:"KeepshireTests" -parallel-testing-enabled NO
```

- [ ] Unit tests pass serially
- [ ] UI tests on iPhone and iPad: first-launch auth, tabs, fake vault, add controls

The full OS-upgrade checklist is in [FEATURES.md](FEATURES.md#9-upgrade-verification-checklist).
