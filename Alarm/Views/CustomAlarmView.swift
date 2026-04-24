import SwiftUI

private enum TimeField: Hashable { case hour, minute }

struct CustomAlarmView: View {
    let existingAlarm: AlarmItem?
    let onSave: (AlarmItem) -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var hour: Int
    @State private var minute: Int
    @State private var daily: Bool
    @State private var days: [Bool]
    @State private var selectedMissions: [AlarmMission]
    @State private var toneID: String
    @State private var volume: Double
    @State private var vibration: Bool

    @State private var showMissionPicker = false
    @State private var showRingtonePicker = false
    @State private var showDeleteConfirm = false
    @State private var showPhotoTaskPicker = false
    @State private var photoTaskIDs: [String]?

    @FocusState private var focusedField: TimeField?
    @State private var hourInput: String = ""
    @State private var minuteInput: String = ""

    private let dayLabels = ["M","T","W","T","F","S","S"]

    init(existingAlarm: AlarmItem? = nil,
         onSave: @escaping (AlarmItem) -> Void,
         onCancel: @escaping () -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existingAlarm = existingAlarm
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        
        if let a = existingAlarm {
            _hour       = State(initialValue: a.hour)
            _minute     = State(initialValue: a.minute)
            _daily      = State(initialValue: a.days.allSatisfy { $0 })
            _days       = State(initialValue: a.days)
            _selectedMissions   = State(initialValue: a.selectedMissions)
            _toneID     = State(initialValue: a.toneID)
            _volume     = State(initialValue: a.volume)
            _vibration  = State(initialValue: a.vibration)
            _photoTaskIDs = State(initialValue: a.photoTaskIDs)
        } else {
            _hour       = State(initialValue: 7)
            _minute     = State(initialValue: 0)
            _daily      = State(initialValue: true)
            _days       = State(initialValue: [true, true, true, true, true, false, false])
            _selectedMissions   = State(initialValue: [AlarmMission(from: .off)])
            _toneID     = State(initialValue: UserDefaults.standard.string(forKey: .keyDefaultToneID) ?? defaultAlarmToneID)
            _volume     = State(initialValue: 70)
            _vibration  = State(initialValue: true)
            _photoTaskIDs = State(initialValue: nil)
        }
    }

    private var ringsInLabel: String {
        let now = Date()
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute; comps.second = 0
        guard let target = Calendar.current.nextDate(
            after: now, matching: comps,
            matchingPolicy: .nextTime
        ) else { return "" }
        let diff = Int(target.timeIntervalSince(now))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        if h == 0 { return "rings in \(m)m" }
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
                        if hasPhotoMission {
                            photoObjectsSection
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        soundSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        if onDelete != nil {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Text("Delete Alarm")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }

                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .confirmationDialog("Delete this alarm?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showMissionPicker) {
            MissionPickerView(
                missions: selectedMissions,
                onAdd: { mission in
                    let wasPhoto = mission.id == .photo
                    let alreadySelected = selectedMissions.contains(mission)
                    if !alreadySelected { selectedMissions.append(mission) }
                    showMissionPicker = false

                    // First time Photo is added → seed default 10 and take
                    // the user straight to the picker so they can tailor the
                    // list (or hit Test) before saving.
                    if wasPhoto, !alreadySelected, photoTaskIDs == nil {
                        photoTaskIDs = TaskCatalog.defaultIDs
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showPhotoTaskPicker = true
                        }
                    }
                },
                onBack: { showMissionPicker = false }
            )
            .presentationDetents([.large])
            .presentationBackground(OB.bg)
        }
        .sheet(isPresented: $showPhotoTaskPicker) {
            PhotoTaskPickerView(
                initial: photoTaskIDs,
                onDone: { ids in
                    photoTaskIDs = ids
                    showPhotoTaskPicker = false
                },
                onCancel: { showPhotoTaskPicker = false }
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
                var item = AlarmItem(
                    hour: hour,
                    minute: minute,
                    days: days,
                    selectedMissions: selectedMissions,
                    toneID: toneID,
                    volume: volume,
                    vibration: vibration
                )
                if let existing = existingAlarm {
                    item.id = existing.id
                    item.alarmKitID = existing.alarmKitID
                    item.isEnabled = existing.isEnabled
                }
                item.photoTaskIDs = hasPhotoMission ? photoTaskIDs : nil
                onSave(item)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(OB.accent)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Time card (onboarding-style picker)

    private var timeCard: some View {
        VStack(spacing: 12) {
            timePicker
            Text(ringsInLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.ink3)
        }
        .padding(20)
        .background(OB.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { focusedField = nil }
        .background(hiddenFields)
    }

    private var timePicker: some View {
        HStack(spacing: 10) {
            timeColumn(value: hour, display: displayHour, field: .hour, upper: 24)
            Text(":")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(OB.ink3)
                .padding(.bottom, 6)
            timeColumn(value: minute, display: displayMinute, field: .minute, upper: 60)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
    }

    private func timeColumn(value: Int, display: String, field: TimeField, upper: Int) -> some View {
        let isEditing = focusedField == field
        return VStack(spacing: 6) {
            Button {
                commitEditing()
                if field == .hour { hour = (hour + 1) % upper }
                else { minute = (minute + 1) % upper }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OB.ink3)
                    .padding(8)
            }

            ZStack(alignment: .bottom) {
                Text(display)
                    .font(.system(size: 48, weight: .bold))
                    .kerning(-3)
                    .foregroundStyle(isEditing ? OB.accent : OB.ink)
                    .monospacedDigit()
                    .frame(width: 100, alignment: .center)
                    .animation(.easeInOut(duration: 0.12), value: isEditing)

                if isEditing {
                    Rectangle()
                        .fill(OB.accent)
                        .frame(width: 60, height: 3)
                        .cornerRadius(2)
                        .offset(y: 6)
                        .transition(.opacity.animation(.easeIn(duration: 0.1)))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if field == .hour {
                    hourInput = ""
                    focusedField = .hour
                } else {
                    minuteInput = ""
                    focusedField = .minute
                }
            }

            Button {
                commitEditing()
                if field == .hour { hour = ((hour - 1) + upper) % upper }
                else { minute = ((minute - 1) + upper) % upper }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OB.ink3)
                    .padding(8)
            }
        }
    }

    private var displayHour: String {
        if focusedField == .hour {
            return hourInput.isEmpty ? "--" : hourInput.count == 1 ? "0\(hourInput)" : hourInput
        }
        return String(format: "%02d", hour)
    }

    private var displayMinute: String {
        if focusedField == .minute {
            return minuteInput.isEmpty ? "--" : minuteInput.count == 1 ? "0\(minuteInput)" : minuteInput
        }
        return String(format: "%02d", minute)
    }

    private func commitEditing() {
        focusedField = nil
        hourInput = ""
        minuteInput = ""
    }

    private func handleHourInput(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        let capped = String(digits.suffix(2))
        if hourInput != capped { hourInput = capped }
        if let val = Int(capped), val <= 23 {
            hour = val
        } else if capped.count == 2 {
            hourInput = String(capped.prefix(1))
        }
        if capped.count == 2, let val = Int(capped), val <= 23 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                minuteInput = ""
                focusedField = .minute
            }
        }
    }

    private func handleMinuteInput(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        let capped = String(digits.suffix(2))
        if minuteInput != capped { minuteInput = capped }
        if let val = Int(capped), val <= 59 {
            minute = val
        } else if capped.count == 2 {
            minuteInput = String(capped.prefix(1))
        }
        if capped.count == 2, let val = Int(capped), val <= 59 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = nil
            }
        }
    }

    private var hiddenFields: some View {
        ZStack {
            TextField("", text: $hourInput)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .hour)
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .onChange(of: hourInput) { _, newValue in handleHourInput(newValue) }

            TextField("", text: $minuteInput)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .minute)
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .onChange(of: minuteInput) { _, newValue in handleMinuteInput(newValue) }
        }
        .allowsHitTesting(false)
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
                Text("\(selectedMissions.count)/5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OB.ink3)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                // Always render 5 slots. Filled slots show the selected mission
                // with a remove (×) badge; empty slots show a dashed "+" button
                // that opens the picker.
                ForEach(0..<5, id: \.self) { slot in
                    if slot < selectedMissions.count {
                        let id = selectedMissions[slot].id
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(OB.card)
                                .frame(width: 58, height: 58)
                            MissionIconView(missionID: id.rawValue, active: false)
                                .frame(width: 58, height: 58)
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedMissions.removeAll { $0.id == id }
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
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            showMissionPicker = true
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
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Photo-objects section

    private var hasPhotoMission: Bool {
        selectedMissions.contains(where: { $0.id == .photo })
    }

    private var photoObjectsSummary: String {
        if let ids = photoTaskIDs {
            if ids.isEmpty { return "None selected" }
            return "\(ids.count) object\(ids.count == 1 ? "" : "s") selected"
        }
        return "All \(TaskCatalog.totalCount) objects"
    }

    private var photoObjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTO OBJECTS")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(OB.ink3)
                .padding(.horizontal, 4)

            Button { showPhotoTaskPicker = true } label: {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 15))
                        .foregroundStyle(OB.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Objects to photograph")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OB.ink)
                        Text("Tap to customize & test")
                            .font(.system(size: 12))
                            .foregroundStyle(OB.ink3)
                    }
                    Spacer()
                    Text(photoObjectsSummary)
                        .font(.system(size: 14))
                        .foregroundStyle(OB.ink3)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OB.ink3.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sound section

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOUND")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(OB.ink3)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                Button { showRingtonePicker = true } label: {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 15))
                            .foregroundStyle(OB.accent)
                            .frame(width: 28)
                        Text("Ringtone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OB.ink)
                        Spacer()
                        Text(allTones.first { $0.id == toneID }?.name ?? "Default")
                            .font(.system(size: 16))
                            .foregroundStyle(OB.ink3)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OB.ink3.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 44)

                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.1")
                        .font(.system(size: 14))
                        .foregroundStyle(OB.ink3)
                        .frame(width: 28)
                    Slider(value: $volume, in: 0...100)
                        .tint(OB.accent)
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 14))
                        .foregroundStyle(OB.ink2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 44)

                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 15))
                        .foregroundStyle(OB.ink2)
                        .frame(width: 28)
                    Text("Vibration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(OB.ink)
                    Spacer()
                    Toggle("", isOn: $vibration)
                        .tint(OB.accent)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

#Preview {
    CustomAlarmView(onSave: { _ in }, onCancel: {})
}
