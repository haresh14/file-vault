# Testing Checklist - Phase 1

Use this checklist to verify that the authentication features are working correctly before proceeding to the next phase.

## Pre-Test Setup ✅

- [ ] Project opens successfully in Xcode
- [ ] Privacy permissions added to Info.plist (see [Developer Guide](DEVELOPER_GUIDE.md#adding-privacy-permissions))
- [ ] App builds without errors (Cmd+B)
- [ ] App runs on simulator/device (Cmd+R)

## First Launch Test 🚀

1. [ ] **Delete app** from simulator/device (to test fresh install)
   - Long press app icon → Remove App → Delete App

2. [ ] **Launch app**
   - Should see "Set Your Passcode" screen
   - Lock icon should be visible
   - Two password fields should be present

3. [ ] **Test passcode validation**
   - [ ] Try passcode with less than 4 characters → Should show error
   - [ ] Try different passcodes in both fields → Should show "Passcodes don't match"
   - [ ] Enter matching passcodes (4+ characters) → Should proceed to main screen

## Main Screen Test 📱

1. [ ] **Verify main screen appears**
   - Green shield icon
   - "Welcome to Your Vault" text
   - Settings gear icon in top right

2. [ ] **Test Settings**
   - [ ] Tap gear icon → Settings should open
   - [ ] If device has Face ID/Touch ID, toggle should be visible
   - [ ] Toggle biometric authentication ON
   - [ ] Tap "Done" to close settings

## Background/Foreground Test 🔄

1. [ ] **Test immediate background**
   - Press Home button (or swipe up)
   - Immediately return to app
   - Should NOT require authentication

2. [ ] **Test timeout (30+ seconds)**
   - Press Home button (or swipe up)
   - Wait at least 35 seconds
   - Return to app
   - Should show passcode screen

3. [ ] **Test biometric authentication** (if enabled)
   - [ ] Face ID/Touch ID prompt should appear automatically
   - [ ] Cancel biometric → Should show passcode field
   - [ ] Approve biometric → Should unlock app

## Passcode Entry Test 🔐

1. [ ] **Test wrong passcode**
   - Enter incorrect passcode
   - Should show "Incorrect passcode" error
   - Field should clear

2. [ ] **Test correct passcode**
   - Enter correct passcode
   - Should unlock and show main screen

## Edge Cases Test 🧪

1. [ ] **Force quit test**
   - Double tap home (or swipe up and hold)
   - Swipe up on app to force quit
   - Relaunch app
   - Should require authentication

2. [ ] **Rotation test** (if iPad or iPhone with rotation)
   - Rotate device while on passcode screen
   - UI should adapt properly

## Known Limitations 📝

These are expected behaviors in Phase 1:
- Main screen only shows placeholder content
- No actual photo/video storage yet
- Settings only has biometric toggle
- No ability to change passcode yet

## Troubleshooting 🔧

### App crashes on launch
- Check console for errors (View → Debug Area → Activate Console)
- Ensure Core Data model is properly configured

### Biometric not working
- Check if device has Face ID/Touch ID
- Ensure privacy permissions are set
- Try on physical device (simulator has limited biometric support)

### Passcode not saving
- Delete app and reinstall
- Check Keychain access in console for errors

## Ready for Phase 2? ✨

If all tests pass, you're ready to proceed to the next phase:
- [ ] All authentication flows work correctly
- [ ] No crashes or major bugs
- [ ] Understand the current code structure

Congratulations! The security foundation is solid and ready for file storage implementation. 🎉 