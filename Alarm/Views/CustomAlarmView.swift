import SwiftUI

struct CustomAlarmView: View {
    let existingAlarm: AlarmItem?
    let onSave: (AlarmItem) -> Void
    let onCancel: () -> Void

    @State private var alarmDate: Date
    @State private var daily: Bool
    @State private var days: [Bool]
    @State private var missionIDs: [String]
    @State private var toneID: String
    @State private var volume: Double
    @State private var vibration: Bool

    @State private var showMissionPicker = false
    @State private var showRingtonePicker = false

    private let dayLabels = ["M","T","W","T","F","S","S"]

    init(existingAlarm: AlarmItem? = nil,
         onSave: @escaping (AlarmItem) -> Void,
         onCancel: @escaping () -> Void) {
        self.existingAlarm = existingAlarm
        self.onSave = onSave
        self.onCancel = onCancel
        if let a = existingAlarm {
            _alarmDate  = State(initialValue: Calendar.current.date(bySettingHour: a.hour, minute: a.minute, second: 0, of: Date()) ?? Date())
            _daily      = State(initialValue: a.days.allSatisfy { $0 })
            _days       = State(initialValue: a.days)
            _missionIDs = State(initialValue: a.missionIDs)
            _toneID     = State(initialValue: a.toneID)
            _volume     = State(initialValue: a.volume)
            _vibration  = State(initialValue: a.vibration)
        } else {
            _alarmDate  = State(initialValue: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date())
            _daily      = State(initialValue: true)
            _days       = State(initialValue: [true, true, true, true, true, false, false])
            _missionIDs = State(initialValue: ["math"])
            _toneID     = State(initialValue: "sunrise")
            _volume     = State(initialValue: 70)
            _vibration  = State(initialValue: true)
        }
    }

    private var hour: Int { Calendar.current.component(.hour, from: alarmDate) }
    private var minute: Int { Calendar.current.component(.minute, from: alarmDate) }

    private var timeString: String { String(format: "%d:%02d", hour, minute) }

    private var ringsInLabel: String {
        let now = Date()
        var comps = Calendar.current.dateComponents([.hour, .minute], from: alarmDate)
        comps.second = 0
        guard let target = Calendar.current.nextDate(
            after: now, matching: comps,
            matchingPolicy: .nextTime
        ) else { return "" }
        let diff = Int(target.timeIntervalSince(now))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        return "rings in \(h)h \(m)m"
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView {
                    VStack(spacing: 0) {
                        timeCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        repeatSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        missionSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        soundSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showMissionPicker) {
            MissionPickerView(
                currentIDs: missionIDs,
                onAdd: { id in
                    if !missionIDs.contains(id) { missionIDs.append(id) }
                    showMissionPicker = false
                },
                onBack: { showMissionPicker = false }
            )
            .presentationDetents([.large])
            .presentationBackground(OB.bg)
        }
        .sheet(isPresented: $showRingtonePicker) {
            RingtonePickerView(
                selectedID: toneID,
                onDone: { id in
                    toneID = id
                    showRingtonePicker = false
                },
                onBack: { showRingtonePicker = false }
            )
            .presentationDetents([.large])
            .presentationBackground(OB.bg)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OB.ink2)
            Spacer()
            Text(existingAlarm == nil ? "New Alarm" : "Edit Alarm")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
            Button("Save") {
                let cal = Calendar.current
                var item = AlarmItem(
                    hour: cal.component(.hour, from: alarmDate),
                    minute: cal.component(.minute, from: alarmDate),
                    days: days,
                    missionIDs: missionIDs,
                    toneID: toneID,
                    volume: volume,
                    vibration: vibration
                )
                if let existing = existingAlarm {
                    item.id = existing.id
                    item.alarmKitID = existing.alarmKitID
                    item.isEnabled = existing.isEnabled
                }
                onSave(item)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(OB.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 10)
    }

    // MARK: - Time card

    private var timeCard: some View {
        VStack(spacing: 14) {
            Text(timeString)
                .font(.system(size: 64, weight: .bold))
                .kerning(-3)
                .monospacedDigit()
                .foregroundStyle(OB.ink)
            Text(ringsInLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.ink3)
            DatePicker("", selection: $alarmDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 100)
                .clipped()
        }
        .padding(20)
        .background(OB.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Repeat section

    private var repeatSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("REPEAT")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(OB.ink3)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25)) { daily.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(daily ? OB.ink : OB.ink.opacity(0.08))
                                .frame(width: 16, height: 16)
                            if daily {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text("Daily")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OB.ink2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        daily ? OB.ink : Color.clear,
                        in: Capsule()
                    )
                    .foregroundStyle(daily ? .white : OB.ink2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let on = daily || days[i]
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            daily = false
                            days[i].toggle()
                        }
                    } label: {
                        Text(dayLabels[i])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(on ? .white : OB.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                on ? OB.ink : OB.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Mission section

    private var missionSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("MISSION")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(OB.ink3)
                Spacer()
                Text("\(missionIDs.count)/5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OB.ink3)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ForEach(missionIDs, id: \.self) { id in
                    let mission = allMissions.first { $0.id == id }
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(OB.card)
                            .frame(width: 58, height: 58)
                        MissionIconView(missionID: id, active: false)
                            .frame(width: 58, height: 58)
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                missionIDs.removeAll { $0 == id }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(OB.accent, in: Circle())
                        }
                        .offset(x: -6, y: -6)
                    }
                }

                ForEach(0..<max(0, min(3, 5 - missionIDs.count)), id: \.self) { i in
                    Button {
                        if i == 0 { showMissionPicker = true }
                    } label: {
                        Text("+")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(OB.ink3)
                            .frame(width: 58, height: 58)
                            .background(
                                Color.clear,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(OB.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Sound section

    private var soundSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SOUND")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(OB.ink3)
                Spacer()
                Button { showRingtonePicker = true } label: {
                    HStack(spacing: 3) {
                        Text(allTones.first { $0.id == toneID }?.name ?? "Sunrise")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OB.ink2)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink2)
                Slider(value: $volume, in: 0...100)
                    .tint(OB.accent)
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(vibration ? OB.ink2 : OB.ink3)
                Toggle("", isOn: $vibration)
                    .tint(OB.accent)
                    .labelsHidden()
                    .fixedSize()
            }
            .padding(14)
            .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    CustomAlarmView(onSave: { _ in }, onCancel: {})
}
