import SwiftUI

struct MissionScreen: View {
    @Binding var selectedMissionID: String
    let onFinish: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScreenShell(step: 5, totalSteps: 6, onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Prove you're up.")
                    .font(.system(size: 28, weight: .bold))
                    .kerning(-0.8)
                    .foregroundStyle(OB.ink)
                    .padding(.top, 24)

                Text("Your alarm won't stop until you complete this.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.ink2)
                    .padding(.top, 6)

                // Mission list
                VStack(spacing: 0) {
                    ForEach(Array(allMissions.enumerated()), id: \.element.id) { index, mission in
                        missionRow(mission: mission, isLast: index == allMissions.count - 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 18)

                Spacer()

                OBButton(label: "Finish setup", variant: .accent, action: onFinish)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 22)
        }
    }

    private func missionRow(mission: AlarmMission, isLast: Bool) -> some View {
        let active = mission.id == selectedMissionID

        return HStack(spacing: 14) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? Color.white.opacity(0.12) : OB.ink.opacity(0.05))
                    .frame(width: 42, height: 42)
                MissionIconView(missionID: mission.id, active: active)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mission.name)
                        .font(.system(size: 16, weight: .semibold))
                    Text(mission.level)
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            active ? Color.white.opacity(0.15) : OB.ink.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        .foregroundStyle(active ? Color.white.opacity(0.85) : OB.ink2)
                        .textCase(.uppercase)
                }
                Text(mission.desc)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? Color.white.opacity(0.6) : OB.ink3)
            }
            .foregroundStyle(active ? Color.white : OB.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Check indicator
            ZStack {
                Circle()
                    .fill(active ? Color.white : .clear)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(active ? Color.clear : OB.ink.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(OB.ink)
                }
            }
        }
        .padding(14)
        .background(active ? OB.ink : OB.card)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedMissionID = mission.id } }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 70)
            }
        }
    }
}

// MARK: - Mission icons using SF Symbols
struct MissionIconView: View {
    let missionID: String
    let active: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(active ? .white : OB.ink)
    }

    private var symbolName: String {
        switch missionID {
        case "math":   return "function"
        case "type":   return "keyboard"
        case "tiles":  return "square.grid.2x2"
        case "shake":  return "iphone.gen3.radiowaves.left.and.right"
        default:       return "moon.zzz"
        }
    }
}

#Preview {
    MissionScreen(selectedMissionID: .constant("math"), onFinish: {}, onBack: {})
}
