import SwiftUI
import UserNotifications

struct PermNotifScreen: View {
    @Binding var state: PermState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(state == .denied ? OB.denied : OB.accent2)
                    .frame(width: 76, height: 76)
                Image(systemName: "bell.badge")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(state == .denied ? OB.deniedText : OB.accent)
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: state == .denied)

            Text("Let us reach you.")
                .font(.system(size: 28, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(OB.ink)
                .padding(.top, 20)

            Text("Notifications are how the alarm actually rings. Without them, iOS might kill us in the background. We'll never spam you - just your alarm.")
                .font(.system(size: 15))
                .foregroundStyle(OB.ink2)
                .lineSpacing(5)
                .padding(.top, 10)

            notifPreview
                .padding(.top, 22)

            if state == .denied {
                deniedBanner
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var notifPreview: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OB.ink)
                    .frame(width: 38, height: 38)
                Text("A")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("WAKEPAL")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(0.3)
                        .foregroundStyle(OB.ink)
                    Spacer()
                    Text("now")
                        .font(.system(size: 12))
                        .foregroundStyle(OB.ink3)
                }
                Text("Wake up. It's 7:00.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OB.ink)
                Text("No snooze. You've got this.")
                    .font(.system(size: 13))
                    .foregroundStyle(OB.ink2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.75))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OB.line, lineWidth: 0.5)
        )
    }

    private var deniedBanner: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Without notifications")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OB.deniedText)
            Text("Your alarm may not fire if the app gets suspended. Please enable in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.478, green: 0.176, blue: 0.122))
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OB.denied, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    PermNotifScreen(state: .constant(.prompt))
}
