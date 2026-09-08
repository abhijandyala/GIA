import SwiftUI

struct GIAPlanningIndicator: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var rotation = Angle.degrees(24)

    var body: some View {
        indicator(rotation: rotation)
        .onChange(
            of: shouldAnimate,
            initial: true
        ) { _, shouldAnimate in
            updateAnimation(shouldAnimate)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("G.I.A. is preparing the trip")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var shouldAnimate: Bool {
        isActive && !reduceMotion
    }

    private func updateAnimation(_ shouldAnimate: Bool) {
        if shouldAnimate {
            rotation = .degrees(24)
            withAnimation(
                .linear(duration: 10.6)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = .degrees(384)
            }
        } else {
            withAnimation(.linear(duration: 0.01)) {
                rotation = .degrees(24)
            }
        }
    }

    private func indicator(rotation: Angle) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.82))

            Circle()
                .stroke(
                    GIAColor.primaryText.opacity(0.18),
                    lineWidth: 1
                )

            Circle()
                .trim(from: 0.08, to: 0.64)
                .stroke(
                    GIAColor.primaryText.opacity(0.92),
                    style: StrokeStyle(
                        lineWidth: 1.35,
                        lineCap: .round
                    )
                )
                .rotationEffect(rotation)
                .shadow(
                    color: .white.opacity(0.28),
                    radius: 5
                )

            Circle()
                .trim(from: 0.74, to: 0.91)
                .stroke(
                    GIAColor.primaryText.opacity(0.44),
                    style: StrokeStyle(
                        lineWidth: 0.8,
                        lineCap: .round
                    )
                )
                .rotationEffect(
                    .degrees(-rotation.degrees * 0.72)
                )

            Text("GIΛ")
                .font(
                    .system(
                        size: 12,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .tracking(1.6)
                .foregroundStyle(GIAColor.primaryText)
        }
        .compositingGroup()
    }
}

struct GIAPlanningIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            GIAPlanningIndicator(isActive: true)
                .frame(width: 72, height: 72)
        }
        .preferredColorScheme(.dark)
    }
}
