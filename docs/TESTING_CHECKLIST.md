# Testing Checklist - Core Features

Use this checklist against a simulator or device. Automated coverage lives in `File VaultTests` (run serially) and `File VaultUITests`.

## Pre-test

- [ ] Project opens in Xcode
- [ ] App builds (Cmd+B)
- [ ] App runs on simulator or device (Cmd+R)

Face ID, local network, and launch screen strings are already in `File Vault/Info.plist`.

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
5. [ ] Settings: Security, Advanced Security, Trash, disk usage, About `1.0.0`

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
- [ ] Old credential cannot decrypt
- [ ] Fake password is cleared

## Vault encryption

- [ ] New install: import a photo, lock, unlock — file still opens
- [ ] Settings → Change Authentication: files still open with the new credential; the old one does not
- [ ] Vault that existed before PBKDF2: first unlock after this build still shows files (may pause briefly while files are rewritten)
- [ ] Imported file keeps its name in Gallery; the file in `Documents/Vault/` is a UUID, not `vacation.jpg`
- [ ] Rename in the app changes the Gallery name; the UUID blob on disk stays the same
- [ ] Older vault files named after the display name still open after first unlock (they are moved to UUID)

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

- [ ] Start server on port 8080; open URL from another device on the same Wi‑Fi
- [ ] Upload small and large files; optional downloads default off

## Device security

- [ ] Screenshot: alert appears even if the Settings toggle is off; overlay follows the toggle
- [ ] Screen recording overlay when that toggle is on
- [ ] Shake to lock / flip to lock when enabled

## Developer (DEBUG)

- [ ] Complete App Reset → Security Setup on relaunch
- [ ] Delete All Files & Folders keeps the credential

## Automated tests

```sh
xcodebuild -project "File Vault.xcodeproj" -scheme "File Vault" \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test -only-testing:"File VaultTests" -parallel-testing-enabled NO
```

- [ ] Unit tests pass serially
- [ ] UI tests on iPhone and iPad: first-launch auth, tabs, fake vault, add controls

The full OS-upgrade checklist is in [FEATURES.md](FEATURES.md#9-upgrade-verification-checklist).
