import AppIntents
import Foundation
import UIKit
import os

private let log = Logger(subsystem: "com.alarm", category: "intent")

/// Triggered when the user slides-to-stop on AlarmKit's system alert.
///
/// Behavior: AlarmKit *stops* the alarm before `perform()` runs. If we did
/// nothing here, the alarm would simply disappear — no mission, no wake-up.
/// Instead we immediately (a) persist the fired alarm as `pendingMission` so
/// the app routes into the mission flow on next foreground, and (b) schedule
/// a fresh backup alarm a few seconds out. If the screen is still locked (or
/// the user ignores the unlock prompt), the backup fires and we loop again
/// until the mission is solved, which cancels the backup.
struct SolveMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Solve to Dismiss"
    static let isDiscoverable: Bool = false
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    var alarmIDString: String

    init() { self.alarmIDString = "" }
    init(alarmIDString: String) { self.alarmIDString = alarmIDString }

    nonisolated func perform() async throws -> some IntentResult {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appState = await MainActor.run { UIApplication.shared.applicationState.rawValue }
        await log.info("▶ [intent] perform START pid=\(pid) appState=\(appState) alarmID='\(alarmIDString)'")

        guard let item = Self.resolveItem(alarmIDString: alarmIDString) else {
            await log.warning("▶ [intent] could not resolve item; items data empty? pendingMission? — opening app only")
            return .result()
        }
        await log.info("▶ [intent] resolved item id=\(item.id) tone='\(item.toneID)' vol=\(Int(item.volume)) missions=\(item.selectedMissions.map({$0.id}))")

        Self.persistPending(item)
        await log.info("▶ [intent] pendingMission persisted")

        await MainActor.run {
            log.info("▶ [intent] calling AudioService.play (on MainActor)")
            AudioService.shared.play(toneID: item.toneID, volume: item.volume, loops: -1)
            log.info("▶ [intent] AudioService.play returned — isPlaying=\(AudioService.shared.isPlaying)")
        }

        // Rescue scheduling is owned by the in-app rescue-loop (AlarmApp.rescueLoop).
        // It runs every 3s while pendingMission != nil — it'll pick up and
        // schedule rescues as needed once the app is alive.

        await log.info("▶ [intent] perform END")
        return .result()
    }

    // MARK: - Helpers (nonisolated, safe from intent process)

    private static func resolveItem(alarmIDString: String) -> AlarmItem? {
        let ud = UserDefaults.standard

        if !alarmIDString.isEmpty,
           let data = ud.data(forKey: "alarmItems"),
           let items = try? JSONDecoder().decode([AlarmItem].self, from: data),
           let match = items.first(where: { $0.alarmKitID == alarmIDString || $0.id.uuidString == alarmIDString }) {
            return match
        }

        // Fallback: backup alarm case, or app was killed — use the last persisted pending mission.
        if let data = ud.data(forKey: "pendingMission"),
           let item = try? JSONDecoder().decode(AlarmItem.self, from: data) {
            return item
        }
        return nil
    }

    private static func persistPending(_ item: AlarmItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        UserDefaults.standard.set(data, forKey: "pendingMission")
    }
}
