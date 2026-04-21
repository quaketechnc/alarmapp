import SwiftUI

enum OB {
    // MARK: Colors
    static let bg      = Color(red: 0.961, green: 0.945, blue: 0.918) // #f5f1ea
    static let card    = Color.white
    static let ink     = Color(red: 0.082, green: 0.075, blue: 0.075) // #151313
    static let ink2    = Color(red: 0.353, green: 0.325, blue: 0.298) // #5a534c
    static let ink3    = Color(red: 0.639, green: 0.604, blue: 0.561) // #a39a8f
    static let accent  = Color(red: 1.000, green: 0.353, blue: 0.122) // #ff5a1f
    static let accent2 = Color(red: 1.000, green: 0.902, blue: 0.851) // #ffe6d9
    static let ok      = Color(red: 0.180, green: 0.561, blue: 0.353) // #2e8f5a
    static let line    = Color.black.opacity(0.08)
    static let denied  = Color(red: 0.992, green: 0.910, blue: 0.894) // #fde8e4
    static let deniedText = Color(red: 0.769, green: 0.239, blue: 0.165) // #c43d2a

    // MARK: Radius
    static let cardRadius: CGFloat = 22
    static let buttonRadius: CGFloat = 16
}

// MARK: - Primary Button
struct OBButton: View {
    let label: String
    var variant: Variant = .primary
    var action: () -> Void

    enum Variant { case primary, accent, secondary, ghost }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: variant == .ghost ? 44 : 56)
                .foregroundStyle(fgColor)
                .background(bgColor, in: RoundedRectangle(cornerRadius: OB.buttonRadius, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var bgColor: Color {
        switch variant {
        case .primary:   return OB.ink
        case .accent:    return OB.accent
        case .secondary: return OB.ink.opacity(0.05)
        case .ghost:     return .clear
        }
    }
    private var fgColor: Color {
        switch variant {
        case .primary, .accent: return .white
        case .secondary:        return OB.ink
        case .ghost:            return OB.ink2
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Progress dots
struct ProgressDots: View {
    let total: Int
    let active: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == active ? OB.ink : OB.ink.opacity(0.15))
                    .frame(width: i == active ? 22 : 5, height: 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
            }
        }
    }
}

// MARK: - Screen shell
struct ScreenShell<Content: View>: View {
    let step: Int
    let totalSteps: Int
    var showBack: Bool = true
    var padding:CGFloat = 0
    var onBack: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            OB.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content()
            }
            .padding(padding)
        }
    }
    
    private var topBar: some View {
        ProgressDots(total: totalSteps, active: step)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .overlay(alignment: .leading) {
                if showBack, let back = onBack {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OB.ink2)
                            .frame(width: 36, height: 36)
                    }
                } else {
                    Spacer().frame(width: 36, height: 36)
                }
            }
    }
}
