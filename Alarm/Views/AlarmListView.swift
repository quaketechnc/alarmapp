import os
import SwiftUI

private let log = Logger(subsystem: "com.alarm", category: "list")

struct AlarmListView: View {
    @Environment(AlarmStore.self) private var store
    @State private var showAddMenu = false
    @State private var showQuick = false
    @State private var showCustom = false
    @State private var showRinging = false
    @State private var showSettings = false
    @State private var editingAlarm: AlarmItem? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OB.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                listHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 58)
                    .padding(.bottom, 8)

                List {
                    ForEach(store.items) { alarm in
                        AlarmCard(alarm: alarm) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.toggle(alarm.id)
                            }
                        }
                        .onTapGesture { editingAlarm = alarm }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 22, bottom: 5, trailing: 22))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteAlarm(alarm)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Color.clear.frame(height: 70)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            if showAddMenu {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { showAddMenu = false }
                    }
            }

            if showAddMenu {
                addMenu
                    .padding(.trailing, 22)
                    .padding(.bottom, 92)
                    .transition(.scale(scale: 0.88, anchor: .bottomTrailing).combined(with: .opacity))
            }

            fabButton
                .padding(.trailing, 22)
                .padding(.bottom, 28)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showAddMenu)
        .onChange(of: store.firingAlarmID) { _, id in
            if let id {
                log.info("→ showRinging (firingAlarmID=\(id))")
                showRinging = true
            }
        }
        .onChange(of: store.pendingMission) { _, mission in
            if let mission {
                log.info("→ showRinging (pendingMission id=\(mission.id) time=\(mission.timeString))")
                showRinging = true
            }
        }
        .onAppear {
            if let mission = store.pendingMission {
                log.info("→ showRinging on appear (pendingMission id=\(mission.id) time=\(mission.timeString))")
                showRinging = true
            }
        }
        .sheet(isPresented: $showQuick) {
            QuickAlarmSheet { showQuick = false }
                .presentationDetents([.height(540)])
                .presentationCornerRadius(28)
                .presentationBackground(OB.bg)
        }
        .fullScreenCover(isPresented: $showCustom) {
            CustomAlarmView(
                onSave: { item in
                    store.add(item)
                    Task { await scheduleAndStore(item) }
                    showCustom = false
                },
                onCancel: { showCustom = false }
            )
        }
        .fullScreenCover(isPresented: $showRinging, onDismiss: {
            store.firingAlarmID = nil
        }) {
            let firingItem = store.items.first { $0.alarmKitID == store.firingAlarmID }
                ?? store.pendingSnooze
                ?? store.pendingMission
            RingingView(
                missions: firingItem?.missionIDs ?? ["math"],
                toneID: firingItem?.toneID ?? "sunrise",
                volume: firingItem?.volume ?? 70,
                onDismiss: {
                    completeMission()
                    showRinging = false
                }
            )
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(onBack: { showSettings = false })
        }
        .fullScreenCover(item: $editingAlarm) { alarm in
            CustomAlarmView(
                existingAlarm: alarm,
                onSave: { updatedItem in
                    if let oldID = updatedItem.alarmKitID {
                        try? AlarmService.shared.cancel(alarmKitID: oldID)
                    }
                    store.update(updatedItem)
                    Task {
                        if let uuid = try? await AlarmService.shared.schedule(updatedItem) {
                            var item = updatedItem
                            item.alarmKitID = uuid.uuidString
                            store.update(item)
                        }
                    }
                    editingAlarm = nil
                },
                onCancel: { editingAlarm = nil },
                onDelete: {
                    deleteAlarm(alarm)
                    editingAlarm = nil
                }
            )
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Alarms")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(OB.ink)
                let on = store.items.filter(\.isEnabled).count
                Text("\(on) on · \(nextRingLabel)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OB.ink3)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(OB.ink2)
                    .frame(width: 40, height: 40)
                    .background(OB.card, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var nextRingLabel: String {
        let dates = store.items.filter(\.isEnabled).map { AlarmService.shared.nextFireDate(for: $0) }
        guard let soonest = dates.min() else { return "no alarms set" }
        let diff = max(0, Int(soonest.timeIntervalSinceNow))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        return h > 0 ? "next in \(h)h \(m)m" : "next in \(m)m"
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAddMenu.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                .frame(width: 58, height: 58)
                .background(OB.ink, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAddMenu)
    }

    // MARK: - Add menu

    private var addMenu: some View {
        VStack(spacing: 0) {
            menuRow(icon: "⏱", title: "Quick alarm", sub: "in a few minutes") {
                showAddMenu = false
                showQuick = true
            }
            Divider()
                .padding(.horizontal, 8)
            menuRow(icon: "✦", title: "Custom alarm", sub: "with missions") {
                showAddMenu = false
                showCustom = true
            }
        }
        .background(OB.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
        .frame(width: 224)
    }

    private func menuRow(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 16))
                    .frame(width: 34, height: 34)
                    .background(OB.accent2, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OB.ink)
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(OB.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Actions

    private func completeMission() {
        log.info("✓ completeMission start")

        // Cancel the original firing alarm so AlarmKit doesn't re-trigger it.
        if let firingID = store.firingAlarmID {
            log.info("✗ cancel original alarm alarmKitID=\(firingID)")
            try? AlarmService.shared.cancel(alarmKitID: firingID)
        }

        if let backupID = store.backupAlarmKitID {
            log.info("✗ cancel backup alarmKitID=\(backupID)")
            try? AlarmService.shared.cancel(alarmKitID: backupID)
            store.backupAlarmKitID = nil
        }

        if let mission = store.pendingMission,
           let idx = store.items.firstIndex(where: { $0.id == mission.id }) {
            let isOneTime = store.items[idx].days.allSatisfy({ !$0 })
            if isOneTime {
                log.info("~ one-time alarm id=\(mission.id) → disabled")
                store.items[idx].isEnabled = false
                store.items[idx].alarmKitID = nil
                store.update(store.items[idx])
            } else {
                // Recurring alarm: reschedule so it fires again on the next occurrence.
                let item = store.items[idx]
                log.info("~ recurring alarm id=\(mission.id) → rescheduling")
                Task { await scheduleAndStore(item) }
            }
        }

        store.firingAlarmID = nil
        store.pendingSnooze = nil
        store.pendingMission = nil
        log.info("✓ completeMission done")
    }

    private func deleteAlarm(_ alarm: AlarmItem) {
        log.info("− deleteAlarm id=\(alarm.id) alarmKitID=\(alarm.alarmKitID ?? "nil")")
        if let id = alarm.alarmKitID {
            try? AlarmService.shared.cancel(alarmKitID: id)
        }
        if let idx = store.items.firstIndex(where: { $0.id == alarm.id }) {
            store.delete(at: IndexSet(integer: idx))
        }
    }

    private func scheduleAndStore(_ item: AlarmItem) async {
        guard let idx = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        log.info("+ scheduleAndStore id=\(item.id) time=\(item.timeString)")
        do {
            let uuid = try await AlarmService.shared.schedule(item)
            store.items[idx].alarmKitID = uuid.uuidString
            store.update(store.items[idx])
            log.info("✓ scheduleAndStore → alarmKitID=\(uuid.uuidString)")
        } catch {
            log.error("✗ scheduleAndStore failed: \(error)")
        }
    }

}

// MARK: - Alarm Card

struct AlarmCard: View {
    let alarm: AlarmItem
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(alarm.timeString)
                    .font(.system(size: 46, weight: .bold))
                    .kerning(-2)
                    .monospacedDigit()
                    .foregroundStyle(alarm.isEnabled ? OB.ink : OB.ink.opacity(0.35))
                Spacer()
                Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in onToggle() }))
                    .tint(OB.accent)
                    .labelsHidden()
                    .padding(.top, 8)
            }

            Text(alarm.daysLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(alarm.isEnabled ? OB.ink2 : OB.ink3)
                .padding(.top, 5)

            HStack(spacing: 6) {
                if !alarm.missionIDs.isEmpty {
                    alarmChip(
                        icon: "bolt.fill",
                        label: alarm.primaryMissionName,
                        fg: alarm.isEnabled ? OB.accent : OB.ink3,
                        bg: alarm.isEnabled ? OB.accent2 : OB.ink.opacity(0.05)
                    )
                }
                alarmChip(
                    icon: "music.note",
                    label: alarm.toneName,
                    fg: OB.ink2,
                    bg: OB.ink.opacity(0.05)
                )
            }
            .padding(.top, 12)
        }
        .padding(18)
        .background(
            alarm.isEnabled ? OB.card : OB.card.opacity(0.55),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .opacity(alarm.isEnabled ? 1 : 0.65)
        .animation(.easeInOut(duration: 0.2), value: alarm.isEnabled)
    }

    private func alarmChip(icon: String, label: String, fg: Color, bg: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(bg, in: Capsule())
    }
}

#Preview {
    AlarmListView()
        .environment(AlarmStore())
}
