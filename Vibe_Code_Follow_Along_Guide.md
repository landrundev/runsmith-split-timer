# Runsmith Multi-Coach Merge â Vibe Coder's Follow-Along Guide

**For**: Daniel (novice vibe coder)
**Tool**: VSCode + Claude Code (or Cursor/Copilot)
**Time estimate**: 3-4 weeks, one step per session
**Total steps**: 12 (Step 0 through Step 11)

---

## How to Use This Guide

Each step has a matching prompt file (`Step_00_Roster_Import.md`, `Step_01_Coach_Identity.md`, etc.) that you feed directly to Claude Code. This guide tells you:

1. **What you're building** (plain English)
2. **How to prompt Claude Code** (exactly what to do in VSCode)
3. **What to test** (specific things to tap/check on your device)
4. **What can go wrong** (common issues and how to fix them)
5. **When you're done** (the "green light" to move on)

---

## Before You Start

### One-time setup
- [ ] Open your Runsmith Split Timer Xcode project
- [ ] Make sure it builds and runs on your device/simulator as-is
- [ ] Put all the `Step_XX_*.md` files somewhere accessible (your Desktop, or in the project root)
- [ ] **Git commit** your current working code: `git add . && git commit -m "pre-merge-feature baseline"`

### Before each step
- [ ] Make sure the app builds cleanly (no red errors)
- [ ] **Git commit** so you can revert if a step goes sideways: `git add . && git commit -m "before step X"`

### If something breaks
- Don't panic. Run `git diff` to see what changed. If it's a mess, run `git checkout .` to revert to your last commit and try the step again.
- If Claude Code generates something that doesn't compile, paste the Xcode error back into Claude Code and say "Fix this build error: [paste error]"
- If you get stuck, take the error message and the step file and start a fresh Claude Code chat

---

## Step 0 â Roster Import (CSV)

### What you're building
A way to import athletes from a CSV spreadsheet file instead of adding them one by one. This is completely standalone â it doesn't depend on any other step.

### How to prompt Claude Code
1. Open Claude Code in VSCode
2. Say: "Read this file and implement everything in it" then paste the contents of `Step_00_Roster_Import.md`
3. Let it create the files and modify `AthleteRosterView.swift`

### What to test on your device
- [ ] Build and run the app
- [ ] Go to the **Athletes** screen (person.2 icon, top left of Home)
- [ ] Tap the **+** button â you should see a **menu** with "Add Athlete" and "Import from File"
- [ ] Tap **"Add Athlete"** â make sure the old add-athlete sheet still works exactly as before
- [ ] Tap **"Import from File"** â you should see the Import Athletes screen
- [ ] Check that the **format guide** is visible with the example table (Name, Gender, Team)
- [ ] Create a test CSV file on your phone or computer:
  ```
  Name,Gender,Team
  Test Runner,M,Oklahoma TC
  Jane Speed,F,Tulsa Track
  ```
- [ ] Save it as `test_roster.csv` and get it on your device (AirDrop, iCloud Drive, or email to yourself)
- [ ] Tap **"Choose File"** and select your CSV
- [ ] You should see a **preview** with green checkmarks next to both names
- [ ] Tap **"Import 2 Athletes"**
- [ ] Confirm the athletes appear in your roster
- [ ] **Import the same file again** â both should show as gray "duplicate, will skip"
- [ ] Try a CSV with a **missing gender** â should show an orange warning for that row

### What can go wrong
- **"No such module" error**: Make sure the new files are in the correct folders in Xcode's file navigator. You may need to drag them into the right group.
- **File picker doesn't show CSV files**: Check that the `allowedContentTypes` includes `.commaSeparatedText`
- **App crashes on import**: Paste the crash log into Claude Code

### Green light to move on
Athletes screen has a working import button. You can import a CSV, see the preview, and athletes appear in your roster. Duplicates are caught.

---

## Step 1 â Coach Identity

### What you're building
A simple way to store your coach name (like "Coach Davis") so it gets attached to any data you share. No login, no account â just a name saved on your phone.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_01_Coach_Identity.md`

### What to test on your device
- [ ] Build and run
- [ ] Go to **About** (tap the Runsmith logo at top of Home screen)
- [ ] You should see a new **"Coach Name"** section
- [ ] It should say "Not Set" or be empty initially
- [ ] Tap the **edit button** (pencil icon)
- [ ] Enter your name (e.g., "Coach Davis") and tap Save
- [ ] Your name should now display in the Coach Name row
- [ ] **Kill the app completely** (swipe up from app switcher)
- [ ] Reopen â your name should still be there

### What can go wrong
- **Section doesn't appear**: The new code might have been inserted in the wrong spot in AboutView. Check that it's between the Features section and "The Runsmith Platform" section.

### Green light to move on
About screen shows your coach name, it persists after app restart.

---

## Step 2 â Data Models

### What you're building
Two Swift structs that define the shape of data coaches will share. Think of them as templates â SharedRaceConfig (what the host sends before the race) and CoachSplitPayload (what assistants send back after).

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_02_Data_Models.md`

### What to test on your device
- [ ] Build succeeds â that's the main test
- [ ] No UI changes for this step, so just make sure nothing broke
- [ ] Run through the app quickly â Home, Athletes, start a quick race, stop it

### What can go wrong
- **"Cannot find type 'EventType'"**: Make sure the new files are in the `SplitDeck/Models/` group so they can see existing types
- **Build errors about Gender**: The SharedAthlete struct uses `Gender?` which already exists in your project

### Green light to move on
App builds cleanly. No visible changes (these are behind-the-scenes data structures).

---

## Step 3 â Payload Encoder

### What you're building
The "translator" that converts those data structs into QR code strings and back. Also handles JSON file export/import.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_03_Payload_Encoder.md`

### What to test on your device
- [ ] Build succeeds
- [ ] No UI changes â this is pure logic code
- [ ] Quick smoke test: run the app, make sure nothing broke

### What can go wrong
- **NSData compressed errors**: This uses Apple's built-in compression. Should work on iOS 16+, which you're already targeting.

### Green light to move on
App builds cleanly. No visible changes.

---

## Step 4 â Merge Algorithm

### What you're building
The math that takes multiple coaches' split times and produces one final time per split â using median (like World Athletics rules) or average.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_04_Merge_Algorithm.md`

### What to test on your device
- [ ] Build succeeds
- [ ] No UI changes â pure logic code
- [ ] Quick smoke test: run the app, make sure nothing broke

### Green light to move on
App builds cleanly. No visible changes.

---

## Step 5 â QR Scanner

### What you're building
A camera screen that reads QR codes. This gets reused everywhere â importing race configs, importing coach splits.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_05_QR_Scanner.md`

### What to test on your device
- [ ] Build succeeds
- [ ] No UI changes visible yet (the scanner view exists but isn't wired up to any button yet)
- [ ] **IMPORTANT**: Make sure your `Info.plist` has the camera permission string. Claude Code should add it, but if you get a crash on camera access, add `NSCameraUsageDescription` with value "Scan QR codes to import race data from other coaches" to your Info.plist.

### What can go wrong
- **Simulator**: The camera won't work in the iOS Simulator. You need a real device to test QR scanning. The scanner should show an error message instead of crashing on simulator.
- **Permission denied**: If you accidentally deny camera permission, go to Settings > Runsmith Split Timer > Camera and toggle it on

### Green light to move on
App builds cleanly. Camera permission is in Info.plist.

---

## Step 6 â Host Shares Race Config

### What you're building
A "Share with Coaches" button on the Race Setup screen. When the host taps it, a QR code appears that assistant coaches can scan to get the same race setup.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_06_Host_Shares_Config.md`

### What to test on your device
- [ ] Build and run
- [ ] Tap **Quick Race** on the Home screen
- [ ] Select a distance (e.g., 800m), select 2-3 athletes
- [ ] Scroll down â you should see a new **"Multi-Coach"** section
- [ ] Tap **"Share with Coaches"**
- [ ] A sheet should appear with:
  - Your coach name (from Step 1)
  - The race name and athlete count
  - A **QR code**
  - Share and Copy buttons
- [ ] Tap **Share** â should open the standard iOS share sheet with a JSON file
- [ ] Tap **Copy** â copies the QR string to clipboard
- [ ] Dismiss the sheet â the Start Race button should still work normally

### What can go wrong
- **QR code is blank or tiny**: The CIFilter code might need a scale transform. Claude Code should handle this.
- **"Coach Name" shows "Host"**: You haven't set your coach name yet (do Step 1 first)

### Green light to move on
Race Setup screen has "Share with Coaches" button. QR code generates. Share sheet works.

---

## Step 7 â Import Race (Assistant Side)

### What you're building
An "Import" button on the Home screen that lets another coach scan the host's QR code and get the same race ready to time on their device.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_07_Import_Race.md`

### What to test on your device (you need TWO devices for the full test)
- [ ] Build and run
- [ ] Home screen bottom bar should now show **three** buttons: Import, Relay Builder, Quick Race
- [ ] Tap **Import** â camera should open for QR scanning

**Full test with two devices:**
- [ ] **Device A (host)**: Quick Race â select athletes â Share with Coaches â show QR code
- [ ] **Device B (assistant)**: Home â Import â scan Device A's QR code
- [ ] Device B should show a success screen with the race name and athlete count
- [ ] Check Device B's **Athletes** screen â the imported athletes should appear
- [ ] On Device B, the imported race should be ready to start timing

**One-device test (if you only have one phone):**
- [ ] Generate a QR code (Step 6), take a screenshot
- [ ] Display the screenshot on your computer screen
- [ ] On your phone, tap Import and scan the QR code from your computer screen

### What can go wrong
- **"Race not found" after scan**: The QR might be a CoachSplitPayload instead of a SharedRaceConfig. The decoder should detect this and show an appropriate message.
- **Athletes not appearing**: Check that `importRace(from:)` was added to `SplitDeckStore.swift` correctly

### Green light to move on
Import button works on Home. Scanning a host's QR creates athletes and a race on the assistant's device. The race is ready to time.

---

## Step 8 â Export Splits (Assistant Side)

### What you're building
After an assistant coach finishes timing a race, they can tap "Export for Merge" to show a QR code with their split data that the host can scan.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_08_Export_Splits.md`

### What to test on your device
- [ ] Build and run
- [ ] Complete a race (Quick Race â start â tap splits â finish)
- [ ] On the **Results** screen, the toolbar should now show a **"..."** menu instead of the old Share button
- [ ] Tap the menu â you should see three options:
  1. **Share Results** (old functionality, still works)
  2. **Export for Merge** (new)
  3. **Merge Coach Data** (shows "Coming soon" for now)
- [ ] Tap **"Export for Merge"**
- [ ] You should see your coach name (editable), a QR code, and Share/Copy buttons
- [ ] The QR code should be scannable (test with your phone's camera app â it'll show base64 text, that's expected)

### What can go wrong
- **"Share Results" stopped working**: Make sure the existing share logic was preserved inside the Menu
- **No coach name prompt**: If you already set your name in Step 1, it should auto-fill. If not, you'll see a prompt.

### Green light to move on
Results menu has three options. "Export for Merge" shows a QR code with your splits. "Share Results" still works.

---

## Step 9 â Store: replaceSplits

### What you're building
A behind-the-scenes method that lets the app replace an athlete's splits with the merged values. Small change â adds one method to the data store.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_09_Store_ReplaceSplits.md`

### What to test on your device
- [ ] Build succeeds
- [ ] No UI changes
- [ ] Quick smoke test: complete a race, check Results still display correctly

### Green light to move on
App builds cleanly. Results still work.

---

## Step 10 â Merge ViewModel

### What you're building
The brain of the merge screen â handles importing coach data, computing the averaged/median times, and committing the final result. No UI yet, just the logic.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_10_Merge_ViewModel.md`

### What to test on your device
- [ ] Build succeeds
- [ ] No UI changes yet
- [ ] Quick smoke test

### Green light to move on
App builds cleanly. No visible changes.

---

## Step 11 â Merge UI (The Big One)

### What you're building
The actual Merge Coach Data screen â where the host scans QR codes from assistant coaches, sees a side-by-side comparison of everyone's splits, and saves the merged result.

### How to prompt Claude Code
1. Say: "Read this file and implement everything in it" then paste `Step_11_Merge_UI.md`

### What to test on your device

**Basic test (one device):**
- [ ] Build and run
- [ ] Complete a race, go to Results
- [ ] Tap "..." menu â "Merge Coach Data"
- [ ] The merge screen should appear with:
  - "Scan QR Code" and "Import File" buttons
  - Strategy picker (Median / Average)
  - "Save Merged Results" button (disabled â no data yet)

**Full end-to-end test (two devices):**
- [ ] **Device A (host)**: Set up race â Share with Coaches â show QR
- [ ] **Device B (assistant)**: Import race â time the race â finish â Export for Merge â show QR
- [ ] **Device A**: Also time the race â finish â Results â Merge Coach Data â Scan QR Code â scan Device B's QR
- [ ] You should see:
  - Coach B's name in the "Imported Coaches" list
  - A side-by-side table for each athlete: "You" (host's splits), Coach B's name (their splits), "Merged" (the calculated result)
  - Toggle between Median and Average to see different calculations
  - Any outliers flagged with an orange warning
- [ ] Tap **"Save Merged Results"**
- [ ] Results screen should refresh with the merged times
- [ ] Check an athlete's profile â their PB should reflect the merged time

### What can go wrong
- **Times display as raw milliseconds**: The formatter should convert elapsedMs to m:ss.xx format. If it shows numbers like "58410", the formatter isn't hooked up.
- **Merge doesn't save**: Check that `store` is available as an EnvironmentObject. You may need to add `@EnvironmentObject var store: SplitDeckStore` to ResultsView.
- **QR scan doesn't import**: Make sure the scanned string is being decoded as a CoachSplitPayload (not a SharedRaceConfig)

### Green light to move on
Full merge flow works end-to-end. Host can scan assistant QR codes, preview merged splits, and save the result.

---

## You're Done!

After completing all 12 steps, you have:

- **CSV Roster Import** â bulk add athletes from spreadsheets
- **Coach Identity** â your name travels with your data
- **Multi-Coach Timing** â host shares race setup, assistants import it
- **Split Merging** â collect everyone's times, merge with median/average
- **Outlier Detection** â flags bad splits automatically

### Final checklist
- [ ] Git commit: `git add . && git commit -m "multi-coach merge feature complete"`
- [ ] Test the full flow with real coaches at your next practice
- [ ] Celebrate â you just vibe-coded a feature that competitors charge $30-80/year for

---

## Quick Reference

| Step | File | What it adds | UI visible? |
|------|------|-------------|-------------|
| 0 | Step_00 | CSV roster import | Yes â Athletes screen |
| 1 | Step_01 | Coach name in About | Yes â About screen |
| 2 | Step_02 | Data model structs | No |
| 3 | Step_03 | Encoder/decoder | No |
| 4 | Step_04 | Merge math | No |
| 5 | Step_05 | QR camera scanner | No (created but not wired) |
| 6 | Step_06 | "Share with Coaches" | Yes â Race Setup screen |
| 7 | Step_07 | "Import Race" | Yes â Home screen |
| 8 | Step_08 | "Export for Merge" | Yes â Results screen |
| 9 | Step_09 | replaceSplits method | No |
| 10 | Step_10 | Merge logic | No |
| 11 | Step_11 | Merge UI screen | Yes â Results screen |

### Tips for vibe coding with Claude Code
- **One step at a time.** Don't try to do multiple steps in one session.
- **Commit before each step.** Git is your safety net.
- **Paste the whole step file.** Don't summarize â Claude Code needs the exact code.
- **If it breaks, paste the error.** Say "Fix this build error:" and paste the Xcode error. Claude Code is good at this.
- **Test on a real device** for Steps 5-11 (QR scanning needs a camera).
- **Two devices** make the full test way easier. Borrow a friend's iPhone for 10 minutes.
