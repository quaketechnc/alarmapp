import SwiftUI

private enum TimeField: Hashable { case hour, minute }

struct SetAlarmScreen: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var selectedDays: [Bool]
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayFull   = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    @FocusState private var focusedField: TimeField?
    @State private var hourInput: String = ""
    @State private var minuteInput: String = ""

    var body: some View {
        ScreenShell(step: 1, totalSteps: 6, onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text("When should we\ndrag you out of bed?")
                    .font(.system(size: 28, weight: .bold))
                    .kerning(-0.8)
                    .lineSpacing(2)
                    .foregroundStyle(OB.ink)
                    .padding(.top, 24)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pick a time. You only get one — make it count.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.ink2)
                    .padding(.top, 8)

                // Card
                VStack(spacing: 24) {
                    timePicker
                    dayChips
                }
                .padding(20)
                .background(OB.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.top, 24)
                // Dismiss keyboard on tap outside spinner
                .onTapGesture { focusedField = nil }

                Spacer()

                OBButton(label: "Set Alarm", variant: .accent, action: {
                    commitEditing()
                    onNext()
                })
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 22)
            // Hidden text fields for keyboard input
            .background(hiddenFields)
        }
    }

    // MARK: - Hidden keyboard fields
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

    // MARK: - Time picker
    private var timePicker: some View {
        HStack(spacing: 10) {
            timeColumn(
                value: hour,
                display: displayHour,
                field: .hour,
                range: 0..<24
            )
            Text(":")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(OB.ink3)
                .padding(.bottom, 6)
            timeColumn(
                value: minute,
                display: displayMinute,
                field: .minute,
                range: 0..<60
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        // Dismiss on background tap
        .contentShape(Rectangle())
    }

    private func timeColumn(value: Int, display: String, field: TimeField, range: Range<Int>) -> some View {
        let isEditing = focusedField == field
        return VStack(spacing: 6) {
            Button {
                commitEditing()
                if field == .hour { hour = (hour + 1) % range.upperBound }
                else { minute = (minute + 1) % range.upperBound }
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

                // Underline caret when editing
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
                if field == .hour { hour = ((hour - 1) + range.upperBound) % range.upperBound }
                else { minute = ((minute - 1) + range.upperBound) % range.upperBound }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OB.ink3)
                    .padding(8)
            }
        }
    }

    // MARK: - Input handling
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

    private func handleHourInput(_ raw: String) {
        // Keep only digits, max 2
        let digits = raw.filter(\.isNumber)
        let capped = String(digits.suffix(2))
        if hourInput != capped { hourInput = capped }

        // Live update display
        if let val = Int(capped), val <= 23 {
            hour = val
        } else if capped.count == 2 {
            // Invalid (e.g. "25") — clamp to first digit
            hourInput = String(capped.prefix(1))
        }

        // Auto-advance to minute after 2 valid digits
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

        // Dismiss keyboard after 2 valid minute digits
        if capped.count == 2, let val = Int(capped), val <= 59 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = nil
            }
        }
    }

    private func commitEditing() {
        focusedField = nil
        hourInput = ""
        minuteInput = ""
    }

    // MARK: - Day chips
    private var dayChips: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let on = selectedDays[i]
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selectedDays[i].toggle()
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(dayLabels[i])
                            .font(.system(size: 14, weight: .bold))
                        Text(dayFull[i])
                            .font(.system(size: 9, weight: .medium))
                            .opacity(0.75)
                    }
                    .foregroundStyle(on ? .white : OB.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        on ? OB.accent : Color.white.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .shadow(color: on ? OB.accent.opacity(0.35) : .clear, radius: 6, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(OB.accent2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    SetAlarmScreen(
        hour: .constant(7),
        minute: .constant(0),
        selectedDays: .constant([true, true, true, true, true, false, false]),
        onNext: {}, onSkip: {}, onBack: {}
    )
}
