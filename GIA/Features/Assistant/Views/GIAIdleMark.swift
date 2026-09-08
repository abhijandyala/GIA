import SwiftUI

struct GIAIdleMark: View {
    let isActive: Bool
    let isAssistantActive: Bool
    let onActivate: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var animationStart = Date()

    var body: some View {
        Button(action: onActivate) {
            animatedContent
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isAssistantActive
                ? "Return G.I.A. to world view"
                : "Activate G.I.A."
        )
        .accessibilityValue(
            isAssistantActive ? "Active" : "World"
        )
        .accessibilitySortPriority(2)
        .accessibilityIdentifier("map.giaIdentity")
    }

    @ViewBuilder
    private var animatedContent: some View {
        Group {
            if reduceMotion || !isActive {
                responsiveIdentity(scale: 1)
            } else {
                TimelineView(
                    .animation(minimumInterval: 1.0 / 30.0)
                ) { context in
                    animatedIdentity(at: context.date)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .compositingGroup()
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func animatedIdentity(at date: Date) -> some View {
        let elapsed = max(
            0,
            date.timeIntervalSince(animationStart)
        )
        let breath = CGFloat(
            (sin((elapsed / 4.8) * .pi * 2) + 1) / 2
        )

        responsiveIdentity(
            scale: 1 + (breath * 0.012)
        )
    }

    private func responsiveIdentity(
        scale: CGFloat
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            identity(scale: scale, fontSize: 205)
                .frame(width: 420)

            identity(scale: scale, fontSize: 165)
                .frame(width: 350)

            identity(scale: scale, fontSize: 140)
                .frame(width: 300)
        }
    }

    private func identity(
        scale: CGFloat,
        fontSize: CGFloat
    ) -> some View {
        Text("GIΛ")
            .font(
                .system(
                    size: fontSize,
                    weight: .ultraLight,
                    design: .rounded
                )
            )
            .tracking(16)
            .foregroundStyle(GIAColor.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .scaleEffect(scale)
            .shadow(
                color: .black.opacity(isAssistantActive ? 0.22 : 0.72),
                radius: isAssistantActive ? 2 : 3,
                x: 0,
                y: isAssistantActive ? 0 : 2
            )
    }
}

struct GIAIdleMark_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            GIAIdleMark(
                isActive: true,
                isAssistantActive: false,
                onActivate: { }
            )
        }
        .preferredColorScheme(.dark)
    }
}
