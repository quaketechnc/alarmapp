import SwiftUI

struct MissionPickerView: View {
    let currentIDs: [String]
    let onAdd: (String) -> Void
    let onBack: () -> Void

    @State private var selected: String? = nil

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(allMissions) { mission in
                            let inUse = currentIDs.contains(mission.id)
                            let isSelected = selected == mission.id
                            missionRow(mission: mission, selected: isSelected, inUse: inUse)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OB.ink2)
            }
            Spacer()
            Text("Mission")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
            Button("Add") {
                if let sel = selected { onAdd(sel) }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(selected != nil ? OB.accent : OB.ink3)
            .disabled(selected == nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func missionRow(mission: AlarmMission, selected: Bool, inUse: Bool) -> some View {
        Button {
            guard !inUse else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                self.selected = mission.id
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? OB.card.opacity(0.12) : OB.accent2)
                        .frame(width: 44, height: 44)
                    MissionIconView(missionID: mission.id, active: selected)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mission.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? .white : OB.ink)
                    Text(mission.desc)
                        .font(.system(size: 12))
                        .foregroundStyle(selected ? .white.opacity(0.6) : OB.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(selected ? .white : Color.clear)
                        .frame(width: 22, height: 22)
                    Circle()
                        .stroke(selected ? Color.clear : OB.ink.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(OB.ink)
                            .frame(width: 10, height: 10)
                    }
                    if inUse {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(OB.ink3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                selected ? OB.ink : OB.card,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .opacity(inUse ? 0.45 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(inUse)
    }
}

#Preview {
    MissionPickerView(currentIDs: ["math"], onAdd: { _ in }, onBack: {})
}
