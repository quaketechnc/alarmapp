# Alarm App — Session Context

iOS alarm app built with SwiftUI + AlarmKit (iOS 26.4). Single-module Xcode project. No third-party dependencies.

---

## Architecture

```
AlarmApp  →  ContentView  →  OnboardingView   (first launch)
                          →  AlarmListView    (main screen)
                               ├── QuickAlarmSheet   (sheet)
                               ├── CustomAlarmView   (fullScreenCover)
                               ├── SettingsView      (fullScreenCover)
                               └── RingingView       (fullScreenCover)
                                    └── MissionExecutionView (fullScreenCover)
```

**State management:** `@Observable` + `@Environment`. `AlarmStore` lives in `AlarmApp`, injected via `.environment(store)` down the whole tree.

**Persistence:** `AlarmStore` → `UserDefaults` (key `"alarmItems"`, JSON-encoded `[AlarmItem]`). Settings → `@AppStorage`.

**Scheduling:** `AlarmService.swift` wraps `AlarmManager.shared` (AlarmKit). `AlarmApp` monitors `alarmUpdates` AsyncSequence and sets `store.firingAlarmID` when an alarm enters `.alerting` state, which triggers `RingingView`.

---

## Key Files

| File | Role |
|------|------|
| `Alarm/AlarmApp.swift` | App entry; watches `AlarmManager.shared.alarmUpdates`; runs watchdog that refreshes the backup alarm every 10s while ringing |
| `Alarm/AlarmStore.swift` | Observable store; CRUD + UserDefaults persistence; `firingAlarmID`, `pendingMission`, `backupAlarmKitID`; `completeMission()` finalizer |
| `Alarm/ContentView.swift` | Routes onboarding ↔ main; saves onboarding alarm to store |
| `Alarm/Services/AlarmService.swift` | AlarmKit wrapper; `schedule(_:)`, `scheduleBackup(for:delay:)`, `cancel(alarmKitID:)`, `cancelBackup()`, `nextFireDate(for:)` |
| `Alarm/Views/AlarmListView.swift` | Main list; FAB, tap-to-edit, swipe-delete, next-ring label |
| `Alarm/Views/CustomAlarmView.swift` | New + Edit alarm form; accepts `existingAlarm: AlarmItem?` |
| `Alarm/Views/RingingView.swift` | Full-screen ringing; audio loop; hands off to `MissionExecutionView` |
| `Alarm/Views/MissionExecutionView.swift` | Mission runner (math, typing, tiles, shake, photo); progress bar; no cancel escape — task completion is required to stop the alarm |
| `Alarm/Views/SettingsView.swift` | Default tone/volume/vibration, permissions, legal |
| `Alarm/Onboarding/OnboardingCoordinator.swift` | Onboarding state + `allTones` / `allMissions` arrays (global lookup tables) |
| `Alarm/Onboarding/OnboardingTokens.swift` | **Design system**: `OB.*` colors, `OBButton`, `ScaleButtonStyle`, `ScreenShell` |
| `Alarm/Services/AlarmService.swift` | AlarmKit scheduling; `AlarmMeta: AlarmMetadata` struct |
| `Alarm/Services/RecognitionService.swift` | CoreML (ResNet50FP16) for photo mission |
| `Alarm/Services/TaskService.swift` | 14 photo mission tasks with keywords |

---

## Data Model

```swift
struct AlarmItem: Identifiable, Codable {
    var id: UUID
    var hour: Int; var minute: Int
    var days: [Bool]          // 7 elements: Mon(0)–Sun(6)
    var isEnabled: Bool       // default true
    var missionIDs: [String]  // ["math", "shake", ...]
    var toneID: String        // one of allTones: "radar" | "apex" | "beacon" | "chimes" | "cosmic" | "hillside" | "night-owl" | "ripples" | "sencha" | "slow-rise" | "uplift" | "waves"
    var volume: Double        // 0–100
    var vibration: Bool
    var alarmKitID: String?   // UUID from AlarmKit, nil if not yet scheduled
}
```

`AlarmStore` also holds:
- `firingAlarmID: String?` — alarmKitID of the currently alerting alarm
- `pendingMission: AlarmItem?` — persisted; survives app kill so the backup alarm can resume the mission on relaunch
- `backupAlarmKitID: String?` — persisted; the currently scheduled duplicate (fallback) alarm

---

## AppStorage Keys

```swift
"hasCompletedOnboarding"   Bool    — onboarding done flag
"defaultToneID"            String  — default "radar"
"defaultVolume"            Double  — default 70.0
"defaultVibration"         Bool    — default true
```

---

## Design System (`OnboardingTokens.swift`)

```swift
OB.bg        // #f5f1ea — warm beige background
OB.card      // #ffffff — card surfaces
OB.ink       // #151313 — primary text
OB.ink2      // #5a534c — secondary text
OB.ink3      // #a39a8f — tertiary / placeholders
OB.accent    // #ff5a1f — orange brand color
OB.accent2   // #ffe6d9 — light orange tint
OB.ok        // green — success states
OB.line      // separator color

OBButton(label:variant:action:)  // .primary | .accent | .secondary | .ghost
ScaleButtonStyle()                // 0.97 scale on press
```

All new screens must use `OB.*` tokens. No hard-coded colors.

---

## Missions

| ID | Name | Mechanic |
|----|------|----------|
| `math` | Math | Multiply two numbers; numpad input |
| `type` | Typing | Retype a fixed phrase character by character |
| `tiles` | Find color tiles | Tap 6 colored tiles in memorized order |
| `shake` | Shake | Accelerometer → 100% progress bar |
| `off` | Off | Dismisses immediately (no mission) |

**Photo mission** (`photo` ID doesn't exist in allMissions) — `default` branch in `MissionExecutionView.missionContent` calls `PhotoMissionView` → `CameraView(onComplete: onSolve)`. Powered by ResNet50 + `TaskService` (14 tasks).

---

## AlarmKit Notes

- Requires `NSAlarmKitUsageDescription` in Info.plist ✓
- Requires `NSCameraUsageDescription` for photo mission ✓
- `AlarmManager.shared.cancel(id:)` is **synchronous** (throws)
- `AlarmManager.shared.schedule(id:configuration:)` is **async throws**
- Alarm fires → `alarm.state == .alerting` in `alarmUpdates` stream
- `AlarmMeta: AlarmMetadata` is an empty struct defined in `AlarmService.swift`

---

## Common Patterns

**Add a new view:**
```swift
// In parent:
@State private var showFoo = false
// ...
.fullScreenCover(isPresented: $showFoo) { FooView(onBack: { showFoo = false }) }

// FooView follows the ZStack { OB.bg / VStack { navBar / ScrollView } } template
```

**Read @Environment store:**
```swift
@Environment(AlarmStore.self) private var store
```

**Schedule an alarm:**
```swift
let uuid = try? await AlarmService.shared.schedule(item)
store.items[idx].alarmKitID = uuid?.uuidString
store.update(store.items[idx])
```

**Section card layout:**
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("SECTION HEADER")
        .font(.system(size: 11, weight: .bold)).kerning(0.6).foregroundStyle(OB.ink3)
        .padding(.horizontal, 22)
    VStack(spacing: 0) { /* rows */ }
        .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
}
```

---

## Reliability / fallback design

AlarmKit is the source of truth for when an alarm should fire — the OS reliably
alerts even if the app is not running. When it does:

1. **Primary fire path:** `AlarmManager.alarmUpdates` yields `.alerting` →
   `AlarmApp.watchAlarms` sets `store.firingAlarmID` and `store.pendingMission`
   (persisted) → `RingingView` appears → `AudioService` plays the tone in-app.
2. **Intent:** both `stopIntent` and `secondaryIntent` on the alarm are
   `SolveMissionIntent` (`openAppWhenRun = true`). Tapping either system button
   launches the app and routes to the mission screen without stopping the sound
   perceptibly (in-app `AudioService` takes over).
3. **Duplicate / fallback:** while the user is mid-mission,
   `AlarmApp.watchdog` runs every 10s and refreshes a single duplicate alarm
   scheduled `AlarmService.backupDelaySeconds` (20s, inside 10–30s window)
   ahead. This duplicate uses the fixed `AlarmService.backupSlotID` so we can
   always cancel it. If the process is killed, the duplicate fires and iOS
   re-launches us into the ringing/mission flow with the persisted
   `pendingMission`.
4. **Termination:** task completion calls `AlarmStore.completeMission()` which
   cancels the primary alarm, cancels the duplicate, clears transient state
   (unlocks the UI), and reschedules recurring alarms for their next
   occurrence. There is no way to dismiss the alarm without completing the
   task.

No snooze.

## Known Gaps (future work)

- `QuickAlarmSheet` sound picker button removed — sound inherits from Settings defaults
- No alarm reordering (drag-and-drop)
- Audio plays in silent mode (ignores mute switch) — intentional for an alarm app
- AlarmKit permission not checked/re-requested at app launch if previously denied
- Typing mission phrase is hardcoded (`"The early bird catches the worm"`)
- No unit tests

---

## Build

Target: **iOS 26.4**, Swift 6, Xcode (latest beta).  
File sync: `PBXFileSystemSynchronizedRootGroup` — new `.swift` files anywhere under `Alarm/` are auto-included, no project.pbxproj edits needed.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Alarm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
