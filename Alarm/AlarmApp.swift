import SwiftUI
import AlarmKit

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { await watchAlarms() }
        }
    }

    private func watchAlarms() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            if let alerting = alarms.first(where: { $0.state == .alerting }) {
                store.firingAlarmID = alerting.id.uuidString
            } else if alarms.allSatisfy({ $0.state != .alerting }) {
                // clear if no alarm is alerting (e.g. dismissed via system UI)
                if store.firingAlarmID != nil && !alarms.contains(where: { $0.id.uuidString == store.firingAlarmID && $0.state == .alerting }) {
                    store.firingAlarmID = nil
                }
            }
        }
    }
}
