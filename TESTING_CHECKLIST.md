# Testing Checklist - Phase 1 (Updated)

Use this checklist to verify that the authentication features are working correctly before proceeding to the next phase.

## Pre-Test Setup ✅

- [ ] Project opens successfully in Xcode
- [ ] Privacy permissions added to Info.plist (see [Developer Guide](DEVELOPER_GUIDE.md#adding-privacy-permissions))
- [ ] App builds without errors (Cmd+B)
- [ ] App runs on simulator/device (Cmd+R)

## First Launch Test 🚀

1. [ ] **Delete app** from simulator/device (to test fresh install)
   - Long press app icon → Remove App → Delete App
   - OR Long press lock icon for 3 seconds on login screen (debug only)

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
   - [ ] Check "Auto-Lock" picker with options: Immediately, 30 Seconds, 1 Minute, 5 Minutes, Never
   - [ ] Change lock timeout and verify it saves
   - [ ] Check biometric toggle (see Biometric section below)
   - [ ] Tap "Done" to close settings

## Lock Timeout Test ⏰ (NEW!)

Test each timeout option:

1. [ ] **Set to "Immediately"**
   - Background app → Return immediately → Should require passcode
   
2. [ ] **Set to "30 Seconds"** (default)
   - Background app → Return within 20 seconds → Should NOT require passcode
   - Background app → Wait 35+ seconds → Return → Should require passcode
   
3. [ ] **Set to "1 Minute"**
   - Background app → Return within 50 seconds → Should NOT require passcode
   - Background app → Wait 65+ seconds → Return → Should require passcode
   
4. [ ] **Set to "Never"**
   - Background app → Wait any amount of time → Return → Should NOT require passcode
   - ⚠️ Not recommended for security

## Privacy Overlay Test 🛡️ (NEW!)

1. [ ] **App Switcher Privacy**
   - From main screen, swipe up (or double-tap home) to see app switcher
   - File Vault preview should show black screen with lock icon
   - No sensitive content should be visible

## Biometric Authentication Test 🔍

**For Simulator:**
1. [ ] Enable Face ID in simulator: **Features → Face ID → Enrolled**
2. [ ] In Settings, biometric toggle should show warning if not available
3. [ ] If available, toggle ON and test authentication

**For Physical Device:**
1. [ ] If device has Face ID/Touch ID, toggle should work
2. [ ] Background app → Wait for timeout → Return
3. [ ] Should prompt for biometric automatically
4. [ ] Cancel biometric → Should show passcode screen

**Console Messages to Check:**
- Look for: `"DEBUG: Biometrics available"` or `"DEBUG: Biometrics not available"`
- If not available, check error message in console

## Background/Foreground Test 🔄

1. [ ] **Test immediate background**
   - With timeout set to "30 Seconds" or longer
   - Press Home button (or swipe up)
   - Immediately return to app
   - Should NOT require authentication

2. [ ] **Test timeout**
   - Press Home button (or swipe up)
   - Wait for your configured timeout period
   - Return to app
   - Should show passcode screen

3. [ ] **Console monitoring**
   - Watch for: `"DEBUG: App going to background, showing privacy overlay"`
   - And: `"DEBUG: App coming to foreground, within timeout period - no auth needed"`

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

## Developer Options Test 🛠️

1. [ ] **Settings Reset**
   - In Settings → Developer Options → Reset App
   - Confirm → App closes
   - Relaunch → Should show setup screen

2. [ ] **Quick Reset** (Debug only)
   - On login screen, long press lock icon for 3 seconds
   - App closes → Relaunch → Should show setup screen

## Known Limitations 📝

These are expected behaviors in Phase 1:
- Main screen only shows placeholder content
- No actual photo/video storage yet
- No ability to change passcode after initial setup
- Biometric may not work on all simulators

## Troubleshooting 🔧

### Biometric not working
- Check console for: `"DEBUG: Biometrics not available. Error:"`
- On simulator: Features → Face ID → Enrolled
- Try on physical device for full functionality

### Lock timeout not working as expected
- Check Settings → Auto-Lock setting
- Verify console shows correct timeout messages
- Make sure to wait full timeout period + a few seconds

### Privacy overlay not showing
- Should appear immediately when backgrounding
- Check console for: `"DEBUG: App going to background, showing privacy overlay"`

## Ready for Phase 2? ✨

If all tests pass, you're ready to proceed to the next phase:
- [ ] All authentication flows work correctly
- [ ] Lock timeout works as configured
- [ ] Privacy overlay protects content in app switcher
- [ ] No crashes or major bugs
- [ ] Understand the current code structure

Congratulations! The security foundation is solid and ready for file storage implementation. 🎉 