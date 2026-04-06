# On-Air Indicator — Project Ideas

## Goal

Build an "On Air" light with an embedded Arduino that automatically turns on/off via Bluetooth LE whenever any registered device is actively on a call — regardless of app (Teams, Zoom, Google Meet, FaceTime, regular phone call) or device type (Mac, PC, iPhone, Android). The light currently has a manual switch and is powered via USB-C.

Detection is microphone-state based: if any registered device has the microphone open, the light turns on. This means app-specific detection logic is not required — any call on any app that holds the mic triggers the light.

---

## Architecture Overview

```
Work Mac  (Teams/Zoom/Meet/FaceTime) ──BLE──┐
Work PC   (Teams/Zoom/Meet)          ──BLE──┼──► Arduino ──► On Air light
iPhone    (Teams/Zoom/phone calls)   ──BLE──┘

Each device independently reports mic state.
Arduino turns light on if ANY device is on a call.
Light stays on until ALL devices report mic inactive.
```

---

## Hardware Design

### Light & Power
- The existing light is powered via a **USB-C jack (5V DC)**
- The Arduino will be powered directly from this 5V supply via the **VIN pin**
- No separate power supply or battery needed

### Arduino Board

#### POC: Arduino UNO R4 WiFi
- Larger form factor — easy to breadboard and prototype
- Built-in BLE via ESP32-S3 coprocessor
- Uses the `ArduinoBLE` library (same API as production target)
- Powered via USB during development

#### Production: Arduino Nano 33 IoT (or Nano 33 BLE)
- Small form factor: ~45mm x 18mm — fits inside most light cases
- Built-in BLE
- Runs on 5V via VIN pin
- No additional BLE module needed
- Same `ArduinoBLE` library as UNO R4 — code is directly portable

### Light Control Circuit
- The Arduino will control the light via a **logic-level MOSFET** (e.g. IRLZ44N or 2N7000)
  - Silent, no moving parts, tiny footprint
  - Suitable for LED loads (almost certain given USB-C power)
- A **relay** is an alternative if simplicity is preferred
- The MOSFET/relay sits between the Arduino output pin and the light circuit

```
USB-C 5V ──┬──► Arduino VIN
            └──► Light circuit (via MOSFET controlled by Arduino)
```

---

## Call Detection

Detection is microphone-state based — no app-specific logic needed. Any app holding the mic open (Teams, Zoom, Google Meet, FaceTime, regular phone/cellular call) triggers the light. This approach works across all platforms and call types.

### Desktop: macOS
Query `AVCaptureDevice` to check whether any app currently holds the microphone.

- Works when muted via in-app mute button (app keeps mic claimed at OS level)
- May give false negative if muted at hardware/OS level (uncommon in practice)
- Implementation varies by language: `pyobjc` (Python), `AVCaptureDevice` directly (Swift), `objc2` crate (Rust)

### Desktop: Windows
Query the Windows Audio Session API (WASAPI) to check for an active audio capture session.

- Same behaviour as macOS re: in-app vs hardware mute
- Implementation varies by language: `pycaw` (Python), `NAudio` (C#), `windows` crate (Rust)

### Mobile: iOS / iPhone
Use `AVAudioSession` to monitor microphone state. Covers:
- Teams, Zoom, Google Meet, FaceTime (all hold mic via `AVAudioSession`)
- Regular cellular and VoIP calls
- A thin Swift wrapper with Rust core logic, or a native Swift app

### Mobile: Android
Use `AudioManager` and `AudioRecord` APIs to detect active audio capture sessions. Covers:
- Teams, Zoom, Google Meet (all request mic via Android audio APIs)
- Regular phone calls (detectable via `TelephonyManager` call state)
- Implemented in Kotlin/Java shell with Rust core via JNI, or natively in Kotlin

### Previously considered: Calendar-based detection
- **Microsoft Graph API:** Ruled out — requires Azure app registration
- **Published ICS Feed:** Viable fallback — detects *scheduled* meeting times (not actual mic state); kept in reserve for edge cases where mic detection isn't available

---

## Bluetooth LE Communication

### Python: `bleak` library (Recommended)
- Fully cross-platform (macOS and Windows)
- Well-maintained
- Works natively with both the UNO R4 WiFi (POC) and Nano 33 IoT (production)

### JavaScript: `@abandonware/noble` (Node.js / Electron)
- Cross-platform (macOS and Windows)
- Maintained fork of the original `noble` package
- Works in both plain Node.js and Electron
- Historically less stable than `bleak` on Windows

### .NET: `Windows.Devices.Bluetooth` (WinRT)
- Excellent on Windows only
- macOS BLE from .NET requires complex P/Invoke into CoreBluetooth
- Not recommended for cross-platform use

---

## Security — Restricting Access to One Device

BLE is open by default — any device could try to connect. The challenge without a screen or buttons on the Arduino is that standard BLE bonding was designed with the assumption that at least one device has some UI. Several approaches are available:

### Option A: Physical Pairing Button (Recommended for production)
Add a small tactile button to the Arduino circuit. Pairing flow:
1. Hold button for 3 seconds → Arduino enters pairing mode for 30 seconds
2. Host script detects pairing mode and initiates bonding
3. Arduino stores bonded device's MAC address in EEPROM/flash
4. All subsequent connection attempts from unknown MACs are rejected

- This is how most consumer BLE devices (headphones, speakers) work
- Simple, reliable, user-friendly — no tooling needed
- A small button fits easily alongside the MOSFET in the light case
- Supports multiple devices by entering pairing mode multiple times
- **Verdict:** Best option for the production build

### Option B: BLE-managed Allowlist
Expose a protected "admin" BLE characteristic for managing allowed devices programmatically:
1. Pairing mode triggered by reset or button press
2. In pairing mode, Arduino accepts a write to the admin characteristic containing a MAC address to allowlist
3. Outside pairing mode, admin characteristic is locked
4. Allowlisted MACs stored in EEPROM — persist across reboots
5. Multiple devices can be allowlisted (e.g. work Mac + work PC)

- Most flexible option — no need to open the case to manage devices
- Pairs well with a host-side CLI tool or UI for managing the allowlist
- **Verdict:** Best if you want to support multiple devices without re-flashing

### Option C: Shared Secret (Out-of-band)
Skip BLE bonding — implement application-level authentication instead:
- A shared secret (UUID or passphrase) is hardcoded into the Arduino sketch
- Host script presents the secret as the first BLE characteristic write
- Arduino disconnects immediately if the secret doesn't match
- "Re-pairing" just means deploying the host script with the correct secret

- Simple to implement, no hardware changes needed
- Secret is visible in sketch source and doesn't rotate
- Fine for a personal device; weaker in a shared environment
- **Verdict:** Good for POC; not recommended for production

### Option D: Hardcoded MAC Address (Simplest)
Allowed MAC address(es) hardcoded directly in the Arduino sketch. To change, re-flash via USB.

- Zero complexity — no pairing mechanism needed
- Completely impractical if the device changes hands or you switch computers
- **Verdict:** Fine for early POC only

### Multi-device OR logic
With multiple devices potentially connected, the Arduino needs to handle simultaneous signals correctly:
- Each device independently reports its mic state (`0x01` = on call, `0x00` = not on call)
- Arduino maintains a state flag per connected device
- Light turns **on** if **any** device reports active
- Light turns **off** only when **all** devices report inactive
- If a device disconnects unexpectedly, its state should be treated as inactive after a timeout

### Recommended progression
- **POC:** Option D (hardcoded MAC) — just get it working with one device
- **Production:** Option A (physical button) as primary; Option B (BLE allowlist) preferred once multi-device support is needed

---

## Language Options

### Python (Recommended for cross-platform)

| Component | Library |
|---|---|
| Calendar (ICS fallback) | `icalevents` |
| Mic detection (macOS) | `pyobjc` |
| Mic detection (Windows) | `pycaw` |
| Bluetooth LE | `bleak` |
| Polling loop | `schedule` |

Cross-platform abstraction pattern:
```python
import platform

def is_in_teams_call():
    if platform.system() == "Darwin":  # macOS
        return check_macos_mic()
    elif platform.system() == "Windows":
        return check_windows_audio_session()
```

### .NET / C#
- **Windows:** Good native support via `NAudio` (WASAPI) and `Windows.Devices.Bluetooth`
- **macOS:** Significantly more complex — BLE and mic APIs require P/Invoke into native frameworks
- **Verdict:** Viable for Windows-only; Python is the better cross-platform choice

### Hybrid approach
Keep core logic and BLE in Python; expose detection state over a local socket or named pipe if integration with a larger .NET project is needed.

### Native Swift / SwiftUI (macOS only)
A native macOS menu bar app — the most natural fit for the macOS side of this project.

- **Mic detection:** `AVCaptureDevice` / `AVAudioSession` — first-class Swift APIs, reliable and well-documented
- **BLE:** `CoreBluetooth` — the gold standard on macOS/iOS, excellent developer experience
- **UI:** SwiftUI menu bar app — native, small footprint, idiomatic macOS
- **Pros:** Best possible macOS integration; clean, modern Swift APIs for exactly what's needed
- **Cons:** macOS only — requires a separate Windows implementation
- **Verdict:** Ideal if macOS is the primary platform or you want a best-in-class macOS experience

### Native C# / WinRT (Windows only)
The most natural fit for the Windows side — deep OS API access with less friction than raw C++.

- **Mic detection:** `NAudio` wrapping WASAPI — excellent Windows audio session access
- **BLE:** `Windows.Devices.Bluetooth` (WinRT) — first-class Windows BLE API
- **UI:** WinForms or WPF system tray app
- **Pros:** Best possible Windows integration; well-documented APIs
- **Cons:** Windows only — requires a separate macOS implementation
- **Verdict:** Ideal Windows counterpart to the Swift macOS app

### Split Native Architecture (Recommended for native route)
Build two separate native apps sharing a single Arduino sketch:

```
macOS:   Swift menu bar app  (AVCaptureDevice + CoreBluetooth)
Windows: C# tray app         (NAudio/WASAPI + Windows.Devices.Bluetooth)
Arduino: Shared sketch        (ArduinoBLE — identical on both platforms)
```

The Arduino doesn't care what connects to it over BLE, so you get fully native, idiomatic code on each platform without compromise. Trade-off is maintaining two codebases.

### .NET MAUI (Cross-platform — not recommended)
Designed for iOS/Android/Windows/macOS from a single codebase, but not a good fit here.

- macOS support via Mac Catalyst is still considered second-class
- Primarily a UI framework — doesn't provide easy access to low-level audio session APIs
- Still requires platform-specific native interop for mic detection on each platform, negating the cross-platform benefit
- **Verdict:** Ruled out — the cross-platform promise breaks down when deep OS API access is needed

### Rust (Cross-platform native — worth exploring)
A single cross-platform native codebase that calls OS APIs directly on both macOS and Windows.

#### BLE: `btleplug`
The strongest part of the Rust story. `btleplug` abstracts over `CoreBluetooth` on macOS and `WinRT` on Windows — actively maintained, widely used, and cross-platform BLE in Rust is essentially a solved problem.

#### Mic detection (Windows)
Microsoft publishes an official `windows` crate providing idiomatic Rust bindings to all of WinRT and Win32, including WASAPI. Querying audio sessions from Rust on Windows is actually quite clean.

#### Mic detection (macOS)
Use the `objc2` crate (modern, well-maintained successor to `objc`) to call `AVCaptureDevice` via Objective-C FFI. More boilerplate than Swift but functional and well-documented in the community.

#### UI options
- **`tray-icon` crate** — cross-platform system tray icon, lightweight
- **Tauri** — a mature Rust-based app framework, essentially a lighter-weight Electron alternative. Uses the OS's native webview instead of bundling Chromium, so binaries are typically under 10MB. Worth serious consideration if a UI is needed.

#### iOS and Android
- Rust compiles to iOS and Android targets
- iOS: thin Swift shell calling Rust core via FFI — `btleplug` supports iOS via `CoreBluetooth`
- Android: thin Kotlin shell calling Rust core via JNI — `btleplug` supports Android BLE APIs
- Google officially supports Rust in the Android platform; this is a well-trodden path
- Real-world examples: Dropbox, Firefox, and others use this Rust-core + native-shell pattern in production mobile apps

#### Summary
- **Pros:** Single core codebase across macOS, Windows, iOS, and Android; tiny binaries with no runtime dependency; memory safe; excellent performance for a constantly-running background process; active community around embedded Rust + BLE
- **Cons:** Steeper learning curve; macOS/iOS Objective-C interop is verbose (though functional); each platform still needs a thin native shell for OS integration and app store distribution
- **Verdict:** The most architecturally elegant option for the full multi-device vision — one Rust core shared across all four platforms, with thin native wrappers only where the OS requires it

### Native Swift (iOS)
A native iOS app running in the background, monitoring mic state and signalling the Arduino via BLE.

- **Mic detection:** `AVAudioSession` — covers all call types including cellular
- **BLE:** `CoreBluetooth` — same framework as macOS Swift app; code is largely shared
- **Background execution:** iOS background modes (`audio`, `bluetooth-central`) allow the app to run while backgrounded
- **Shared code with macOS:** Core logic (mic detection + BLE) can be shared between a macOS and iOS Swift target in the same Xcode project
- **Verdict:** Natural companion to the macOS Swift app; significant code reuse possible

### Native Kotlin (Android)
A native Android app monitoring mic/call state and signalling the Arduino via BLE.

- **Mic detection:** `AudioManager` + `AudioRecord` for app-level mic activity; `TelephonyManager` for cellular calls
- **BLE:** Android BLE APIs (`BluetoothLeScanner`, `BluetoothGatt`) — well-documented, widely used
- **Background execution:** Android foreground service with a persistent notification
- **Rust core via JNI:** Core logic can be written in Rust and called from a thin Kotlin shell
- **Verdict:** Solid option for Android support; more complex background execution model than iOS

### Rust (Cross-platform native — worth exploring)
A full Electron app wrapping Node.js, providing a system tray UI for status, manual override, and BLE device configuration.

- **BLE:** `@abandonware/noble` npm package (maintained fork of `noble`) — cross-platform, works on both macOS and Windows
- **Mic detection:** Requires native Node addons (C++ compiled `.node` files) on both platforms — not simpler than Python, just different
- **Pros:** Can ship a proper system tray UI (call status indicator, manual override, settings); familiar if you already work in JavaScript
- **Cons:** 100–200MB bundle (ships full Chromium + Node runtime); `noble` BLE has historically been less stable than Python's `bleak`; native addon complexity still required for mic detection
- **Verdict:** Good choice if a polished UI is a priority; overkill for a pure background service

### Plain Node.js (JavaScript — no UI)
Run a Node.js script as a background process — gets the JavaScript ecosystem without the Chromium overhead of Electron.

- **BLE:** Same `@abandonware/noble` as Electron
- **Mic detection:** Same native addon requirement as Electron
- **Background service:** `launchd` plist on macOS, NSSM or scheduled task on Windows
- **Pros:** Leaner than Electron; good if you prefer JS over Python
- **Cons:** Native addon complexity for mic detection; `noble` less battle-tested than `bleak` cross-platform
- **Verdict:** A reasonable middle ground if JavaScript is preferred but a UI isn't needed

---

## Options Comparison

| Option | macOS | Windows | iOS | Android | BLE library | Complexity | Notes |
|---|---|---|---|---|---|---|---|
| Python | ✅ | ✅ | ❌ | ❌ | `bleak` | Low | Easiest desktop path; no mobile |
| .NET / C# | ❌ | ✅ | ❌ | ❌ | `Windows.Devices.Bluetooth` | Medium | Windows desktop only |
| Electron | ✅ | ✅ | ❌ | ❌ | `@abandonware/noble` | Medium | Desktop UI; no mobile |
| Plain Node.js | ✅ | ✅ | ❌ | ❌ | `@abandonware/noble` | Medium | Desktop only; no UI |
| Swift (macOS + iOS) | ✅ | ❌ | ✅ | ❌ | `CoreBluetooth` | Medium | Best Apple experience; no Windows/Android |
| Kotlin (Android) | ❌ | ❌ | ❌ | ✅ | Android BLE APIs | Medium | Android only |
| Split Native (Swift + C# + Kotlin) | ✅ | ✅ | ✅ | ✅ | Platform native | Very High | Best quality; 3 codebases |
| .NET MAUI | ❌ (ruled out) | — | — | — | — | High | Cross-platform promise breaks down |
| Rust (shared core + thin shells) | ✅ | ✅ | ✅ | ✅ | `btleplug` | High | Single core codebase for all 4 platforms |

---

## Open Questions

- How big is the interior of the light case — is there room for a Nano 33 IoT (~45mm x 18mm) plus MOSFET circuit?
- Is the light a simple LED load, or does it have its own internal driver board?
- How quickly does the trigger need to respond to joining/leaving a call?
