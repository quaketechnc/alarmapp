import SwiftUI

struct IntroScreen: View {

    private let others: [(String, Bool)] = [
        ("6:00", true), ("6:15", true), ("6:30", true),
        ("7:00", true), ("7:15", true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardsRow
                .padding(.top, 28)
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("No more snoozing.")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-1.2)
                Text("Own your day.")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(OB.accent)
            }
            Text("One alarm. No escape button. A morning that actually starts when you said it would.")
                .font(.system(size: 15))
                .foregroundStyle(OB.ink2)
                .lineSpacing(5)
                .padding(.top, 10)
        }
        .foregroundStyle(OB.ink)
    }

    
    private var cardsRow: some View {
        // Comparison cards
        HStack(spacing: 10) {
            othersCard
            alarmyCard
        }
        .frame(maxHeight: 250)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    private var othersCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: OB.cardRadius, style: .continuous)
                .fill(OB.ink.opacity(0.04))

            VStack(alignment: .leading, spacing: 6) {
                Text("OTHERS")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(OB.ink3)

                ForEach(Array(others.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(OB.ink)
                        Spacer()
                        MiniToggle(on: item.1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .opacity(0.65)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(14)
            .padding(.bottom, 28)

            
            Text("8 alarms. still late.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OB.ink3)
                .padding(14)
        }
    }

    private var alarmyCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: OB.cardRadius, style: .continuous)
                .fill(OB.ink)

            VStack(alignment: .leading, spacing: 0) {
                Text("ALARMY")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Text("7:00")
                    .font(.system(size: 44, weight: .bold))
                    .kerning(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("Mon–Fri")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)

                Text("NO SNOOZE")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OB.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 14)
                Spacer()
            }
            .padding(14)
            .padding(.bottom, 28)

            Text("1 alarm. always on time.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(14)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: OB.cardRadius, style: .continuous))
    }
}

private struct MiniToggle: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? OB.accent : Color(white: 0.85))
                .frame(width: 20, height: 11)
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .padding(.horizontal, 1)
        }
    }
}

#Preview {
    IntroScreen()
}
