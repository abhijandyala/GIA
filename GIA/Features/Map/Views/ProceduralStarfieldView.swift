import SwiftUI

struct ProceduralStarfieldView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let stars = StarCatalog.stars

    var body: some View {
        Group {
            if reduceMotion || !isActive {
                starCanvas(time: 0)
            } else {
                TimelineView(
                    .animation(minimumInterval: 1.0 / 30.0)
                ) { timeline in
                    starCanvas(
                        time:
                            timeline.date
                            .timeIntervalSinceReferenceDate
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func starCanvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            for star in stars {
                let twinkle =
                    sin((time * star.twinkleSpeed) + star.phase)
                    * star.twinkleAmount
                let opacity = min(
                    max(star.brightness + twinkle, 0.08),
                    0.82
                )
                let overlapsTopChrome =
                    star.y < 0.17
                    && (star.x < 0.28 || star.x > 0.72)
                let chromeAttenuation =
                    overlapsTopChrome ? 0.14 : 1.0
                let resolvedOpacity =
                    opacity * chromeAttenuation
                let center = CGPoint(
                    x: star.x * size.width,
                    y: star.y * size.height
                )
                let diameter = star.radius * 2
                let starRect = CGRect(
                    x: center.x - star.radius,
                    y: center.y - star.radius,
                    width: diameter,
                    height: diameter
                )

                if star.radius > 1.15 {
                    let glowRadius = star.radius * 3.2
                    let glowRect = CGRect(
                        x: center.x - glowRadius,
                        y: center.y - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(
                            star.color.opacity(
                                resolvedOpacity * 0.09
                            )
                        )
                    )
                }

                context.fill(
                    Path(ellipseIn: starRect),
                    with: .color(
                        star.color.opacity(resolvedOpacity)
                    )
                )
            }
        }
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let brightness: Double
    let twinkleAmount: Double
    let twinkleSpeed: Double
    let phase: Double
    let color: Color
}

private enum StarCatalog {
    static let stars: [Star] = {
        var generator = SeededGenerator(seed: 0x4749_4153_5041_4345)

        return (0..<148).map { _ in
            let magnitudeSample = generator.next()
            let luminosity = pow(magnitudeSample, 4.2)
            let radius =
                0.34 + (pow(magnitudeSample, 7.5) * 1.28)
            let brightness = 0.14 + (luminosity * 0.62)
            let temperature = generator.next()
            let color: Color

            if temperature < 0.13 {
                color = Color(
                    red: 1,
                    green: 0.92,
                    blue: 0.82
                )
            } else if temperature > 0.86 {
                color = Color(
                    red: 0.82,
                    green: 0.90,
                    blue: 1
                )
            } else {
                color = Color(
                    red: 0.94,
                    green: 0.96,
                    blue: 1
                )
            }

            return Star(
                x: CGFloat(generator.next()),
                y: CGFloat(generator.next()),
                radius: CGFloat(radius),
                brightness: brightness,
                twinkleAmount:
                    luminosity > 0.08
                    ? 0.025 + (generator.next() * 0.055)
                    : 0,
                twinkleSpeed:
                    0.32 + (generator.next() * 0.58),
                phase: generator.next() * .pi * 2,
                color: color
            )
        }
    }()
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> Double {
        state = state
            &* 6_364_136_223_846_793_005
            &+ 1_442_695_040_888_963_407
        let upperBits = state >> 11
        let unitValue =
            Double(upperBits)
            / Double(UInt64.max >> 11)
        return unitValue
    }
}

struct ProceduralStarfieldView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            ProceduralStarfieldView(isActive: true)
        }
        .preferredColorScheme(.dark)
    }
}
