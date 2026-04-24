import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(AlarmStore.self) private var store
    
    var body: some View {
        if hasCompletedOnboarding {
            AlarmListView()
        } else {
            OnboardingView { item in
                hasCompletedOnboarding = true
                guard let item else { return }
                store.add(item)
                let idx = store.items.count - 1
                Task {
                    if let uuid = try? await AlarmService.shared.schedule(item) {
                        store.items[idx].alarmKitID = uuid.uuidString
                        store.update(store.items[idx])
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AlarmStore())
}
