# XCODE BUILD & INSTALL MANUAL

This document records the exact terminal commands and recommended developer steps used to build and install the BobCamAgent Debug binary (works with the project layout in this repo). Keep this as a reproducible reference for future debugging, CI, or by the next coding agent.

---

## Overview (where to run)

All commands below assume your current working directory is the repository root:

```
/Users/gunn.kim/study/BobCam
```

Primary project folder for the iOS agent:

```
BobCam-iOS/BobCamAgent
```

---

## 1) Prepare CocoaPods (one-time or when Podfile changes)

Make sure CocoaPods is installed on the machine (gem or Homebrew). Then run:

```bash
cd BobCam-iOS/BobCamAgent
pod install --repo-update
```

Notes:

- `--repo-update` refreshes the specs repo; omit if you want faster installs and know your specs are up-to-date.
- If Pod installation fails, check CocoaPods version and Ruby environment. Use Bundler if the project provides a Gemfile.

---

## 2) Find device identifier (for physical iPhone)

You can get device identifier from Xcode or CLI:

- Xcode: Window → Devices and Simulators → select the device → copy Identifier (UUID).
- CLI (simulator lists):
  - For simulators: `xcrun simctl list devices`
  - For attached physical devices, use `xcrun xctrace list devices` or `idevice_id -l` (libimobiledevice, not required; prefer Xcode GUI).

Replace `<DEVICE_ID>` below with that identifier.

---

## 3) Clean, build and install (Debug, physical device)

From the iOS agent directory:

```bash
cd BobCam-iOS/BobCamAgent

# Clean, build and install to a specific connected device:
xcodebuild -workspace BobCamAgent.xcworkspace \
  -scheme BobCamAgent \
  -configuration Debug \
  -destination "id=<DEVICE_ID>" \
  clean build install | tee build_install_debug.log
```

What this does:

- `clean` removes old build intermediates.
- `build` compiles the app for the device.
- `install` attempts to install the app to the device specified by `-destination`.
- `tee build_install_debug.log` saves the verbose combined output to a log file for inspection.

Common flags you may add:

- `-quiet` to reduce output (not recommended during debug).
- `CODE_SIGN_STYLE=Automatic` or explicit `CODE_SIGN_IDENTITY` if automation is required (but signing is best configured in Xcode project settings).

---

## 4) Faster local run (when working inside Xcode)

Open `BobCam-iOS/BobCamAgent/BobCamAgent.xcworkspace` in Xcode, select the BobCamAgent scheme and your connected device, then Run (Cmd+R). Use Breakpoints and the Debug console to inspect runtime behavior.

---

## 5) Useful log & diagnostics commands

- Watch build log:
  ```
  tail -n 200 build_install_debug.log
  ```
- Full build log path example:
  ```
  BobCam-iOS/BobCamAgent/build_install_debug.log
  ```
- View DerivedData build products (BUILT_PRODUCTS_DIR):
  ```
  xcodebuild -workspace BobCam-iOS/BobCamAgent/BobCamAgent.xcworkspace \
    -scheme BobCamAgent -configuration Debug -showBuildSettings | grep BUILT_PRODUCTS_DIR
  ```

---

## 6) Capture device crash report / runtime logs

If the app crashes while reproducing, gather the following:

(a) Device crash report (preferred)

- Xcode → Window → Devices and Simulators → Select device → View Device Logs → Filter by `BobCamAgent` or bundle id → Export Log… or select and copy text.
- Paste the entire `.crash` file contents when reporting.

(b) Xcode runtime console (live debug)

- Add Exception Breakpoint: Breakpoint navigator → + → Add Exception Breakpoint (All Exceptions).
- Run the app from Xcode (Cmd+R); reproduce the crash; copy the console output (right-click → Select All → Cmd+C).
- If paused at a breakpoint, capture the stack trace and the editor showing the crashed line.

(c) Device console (if not running via Xcode)

- Xcode Devices window → select device → Open Console (live). Reproduce and copy logs around the crash.

---

## 7) Recommended diagnostics to enable when tracking memory/threads

These slow down execution but provide powerful diagnostics:

- In Xcode → Product → Scheme → Edit Scheme → Diagnostics:
  - Enable: Thread Sanitizer (detect data races)
  - Enable: Address Sanitizer (detect memory corruption)
  - Enable: Zombies (NSZombies) — helps find use-after-free
    Note: Use these only for targeted testing (they may change behavior/performance).

---

## 8) Example commands used in the current debugging session

These were used successfully by the developer agent:

```bash
# 1) Install Pods
cd BobCam-iOS/BobCamAgent
pod install --repo-update

# 2) Build & install on device (replace with your device id)
xcodebuild -workspace BobCamAgent.xcworkspace \
  -scheme BobCamAgent \
  -configuration Debug \
  -destination 'id=00008110-0011714C2201801E' \
  clean build install | tee build_install_debug.log

# 3) Inspect build output quickly
tail -n 200 build_install_debug.log
```

---

## 9) Common issues & fixes

- `ld: framework 'Pods_BobCamAgent' not found`  
  → Run `pod install` in `BobCam-iOS/BobCamAgent` and re-open the workspace `.xcworkspace` (not the `.xcodeproj`).
- Code signing or provisioning errors  
  → Ensure the selected signing identity / provisioning profile is valid for the bundle id. Use Xcode GUI to set the Development Team and let Xcode manage the profile for Debug builds.
- Device not found or wrong destination id  
  → Verify device is connected and recognized by Xcode. Use the GUI to copy the device identifier.

---

## 10) Notes for next agent / dev

- Keep a copy of `build_install_debug.log`. If a crash occurs, attach that log plus the `.crash` report.
- For CI, consider moving Pod install and xcodebuild into a reproducible script or Fastlane lane.
- If you need me to run a build/install again or to create an IPA for TestFlight, I can do that with approval.

---

## 11) Quick checklist (copy into your workflow)

- [ ] Verify Xcode uses `.xcworkspace` (not `.xcodeproj`)
- [ ] Run `pod install --repo-update` if Pods are missing/changed
- [ ] Replace `<DEVICE_ID>` with the physical device identifier
- [ ] Run `xcodebuild` command above and save the `build_install_debug.log`
- [ ] If crash: export crash report and console output; include timings & which UI toggle was used
