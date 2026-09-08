import SwiftUI

struct PlanSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(
                    GIAColor.planSurface.opacity(
                        reduceTransparency ? 1 : 0.78
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                GIAColor.primaryText.opacity(
                                    reduceTransparency ? 0 : 0.045
                                ),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(
                    GIAColor.primaryText.opacity(
                        colorSchemeContrast == .increased
                            ? 0.32
                            : 0.12
                    ),
                    lineWidth:
                        colorSchemeContrast == .increased ? 1 : 0.7
                )
            }
    }
}

extension View {
    func planSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(
            PlanSurfaceModifier(cornerRadius: cornerRadius)
        )
    }
}
