import SwiftUI

struct PermAlarmScreen: View {
    @Binding var state: PermState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(state == .denied ? OB.denied : OB.accent2)
                    .frame(width: 76, height: 76)
                Image(systemName: "alarm")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(state == .denied ? OB.deniedText : OB.accent)
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: state == .denied)

            Text("We need alarm access.")
                .font(.system(size: 28, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(OB.ink)
                .padding(.top, 20)

            Text("iOS requires explicit permission to wake you even when your phone is silent, on Do Not Disturb, or during Focus. We only use it for your one alarm.")
                .font(.system(size: 15))
                .foregroundStyle(OB.ink2)
                .lineSpacing(5)
                .padding(.top, 10)

            VStack(spacing: 0) {
                reassuranceRow(label: "Silent mode",  value: "Rings through", isLast: false)
                reassuranceRow(label: "Focus & DND",  value: "Rings through", isLast: false)
                reassuranceRow(label: "Locked phone", value: "Rings through", isLast: true)
            }
            .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 20)

            if state == .denied {
                deniedBanner
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private func reassuranceRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OB.ink)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(OB.ok)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }

    private var deniedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(OB.deniedText)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Permission denied")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OB.deniedText)
                Text("Tap \"Open Settings\", go to Alarmy and enable Alarms. Then return here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.478, green: 0.176, blue: 0.122))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OB.denied, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    PermAlarmScreen(state: .constant(.prompt))
}
