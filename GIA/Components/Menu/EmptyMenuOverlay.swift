import SwiftUI

struct EmptyMenuOverlay: View {
    let onDismiss: () -> Void
    let isJudgeDemoActive: Bool
    let onStartJudgeDemo: () -> Void
    let onResetJudgeDemo: () -> Void

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast
    @ScaledMetric(relativeTo: .caption)
    private var topChromeHeight = GIASpacing.topChromeHeight

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = GIASpacing.screenEdge(
                for: proxy.size.width
            )
            let menuWidth = min(
                176,
                proxy.size.width - (horizontalInset * 2)
            )
            let menuHeight: CGFloat =
                isJudgeDemoActive ? 172 : 132
            let menuTop =
                GIASpacing.topChromeInset
                + topChromeHeight
                + 8

            ZStack(alignment: .topLeading) {
                Button(action: onDismiss) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss menu")

                VStack(alignment: .leading, spacing: 0) {
                    Text("PRESENTATION")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(GIAColor.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.top, 13)
                        .padding(.bottom, 8)

                    Button(action: onStartJudgeDemo) {
                        Label(
                            isJudgeDemoActive
                                ? "Restart Offline Demo"
                                : "Start Offline Demo",
                            systemImage: "play.circle"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)

                    if isJudgeDemoActive {
                        Button(action: onResetJudgeDemo) {
                            Label(
                                "Reset Demo",
                                systemImage: "arrow.counterclockwise"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(GIAColor.warningAccent)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Text("NO NETWORK REQUIRED")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
                    .background {
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(
                            GIAColor.menuSurface.opacity(
                                reduceTransparency ? 1 : 0.96
                            )
                        )
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .stroke(
                            GIAColor.subtleStroke.opacity(
                                colorSchemeContrast == .increased ? 1 : 0.72
                            ),
                            lineWidth:
                                colorSchemeContrast == .increased ? 1 : 0.75
                        )
                    }
                    .frame(width: menuWidth, height: menuHeight)
                    .shadow(
                        color: .black.opacity(0.38),
                        radius: 24,
                        x: 0,
                        y: 12
                    )
                    .position(
                        x: proxy.size.width
                            - horizontalInset
                            - (menuWidth / 2),
                        y: menuTop + (menuHeight / 2)
                    )
            }
        }
        .accessibilityAction(.escape, onDismiss)
    }
}
