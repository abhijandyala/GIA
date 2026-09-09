import SwiftUI

struct GIAActiveVoiceDisc: View, Animatable {
    var microphoneLevel: CGFloat
    var revealProgress: CGFloat
    var transcript: String
    var statusText: String
    var presentationState: GIAAssistantPresentationState
    var isSpeechPlaybackActive: Bool = false
    var isAnimationActive: Bool = true
    var isAssistantTranscript: Bool = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var animatableData: CGFloat {
        get { revealProgress }
        set { revealProgress = newValue }
    }

    var body: some View {
        let reveal = smootherStepProgress(
            min(max(revealProgress, 0), 1)
        )

        ZStack {
            Circle()
                .fill(Color.clear)
                .padding(60)

            Circle()
                .stroke(
                    stateAccent.opacity(
                        colorSchemeContrast == .increased ? 1 : 0.84
                    ),
                    lineWidth:
                        colorSchemeContrast == .increased ? 1.6 : 1.2
                )
                .padding(60)
                .shadow(
                    color: stateAccent.opacity(0.46),
                    radius: 7
                )
                .shadow(
                    color: stateAccent.opacity(0.20),
                    radius: 18
                )

            if
                GIAQualityPolicy.shouldRunContinuousAnimation(
                    isVisible: isAnimationActive,
                    reduceMotion: reduceMotion
                ),
                reveal > 0.38
            {
                TimelineView(
                    .animation(minimumInterval: 1.0 / 60.0)
                ) { timeline in
                    voiceRipples(at: timeline.date)
                }
            }

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                Text(statusText.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(
                        stateAccent.opacity(0.72)
                    )

                if !transcript.isEmpty {
                    Text(transcript)
                        .font(
                            .system(
                                size: 21,
                                weight: .light,
                                design: .rounded
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(5)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: 248)
                        .foregroundStyle(transcriptColor)
                }

                Spacer(minLength: 0)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(78)
                .opacity(
                    Double(
                        smoothStep(
                            edge0: 0.28,
                            edge1: 0.72,
                            value: reveal
                        )
                    )
                )
                .scaleEffect(
                    0.92
                        + (
                            0.08
                            * smoothStep(
                                edge0: 0.28,
                                edge1: 0.82,
                                value: reveal
                            )
                        )
                )
                .shadow(
                    color: .white.opacity(0.18),
                    radius: 10
                )
        }
        .mask {
            DiagonalActivationMask(progress: reveal)
                .blur(radius: 2.5)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusText)
        .accessibilityValue(
            transcript.isEmpty
                ? presentationState.accessibilityValue
                : transcript
        )
        .accessibilityHidden(isSpeechPlaybackActive)
    }

    private var transcriptColor: Color {
        if isAssistantTranscript {
            return GIAColor.intelligenceAccent
        }
        switch presentationState {
        case .speaking, .processing:
            return GIAColor.intelligenceAccent
        case .idle, .wakeDetected, .listening, .returning, .error:
            return GIAColor.primaryText
        }
    }

    private var stateAccent: Color {
        switch presentationState {
        case .error:
            return GIAColor.warningAccent
        case .wakeDetected, .listening, .processing, .speaking:
            return GIAColor.intelligenceAccent
        case .idle, .returning:
            return GIAColor.primaryText
        }
    }

    private func voiceRipples(at date: Date) -> some View {
        let accent = stateAccent
        let time = date.timeIntervalSinceReferenceDate
        let reveal = smootherStepProgress(
            min(max(revealProgress, 0), 1)
        )
        let rippleReveal = smoothStep(
            edge0: 0.38,
            edge1: 0.84,
            value: reveal
        )
        let microphoneEnergy =
            min(max(microphoneLevel, 0), 1)
            * rippleReveal
        let activationProgress = min(
            max((reveal - 0.34) / 0.66, 0),
            1
        )
        let activationCurve = max(
            sin(Double(activationProgress) * .pi),
            0
        )
        let activationEnergy =
            CGFloat(pow(activationCurve, 0.88)) * 0.34
        let rawEnergy = max(microphoneEnergy, activationEnergy)
        let gatedEnergy = max((rawEnergy - 0.04) / 0.96, 0)
        let reactiveLevel =
            CGFloat(pow(Double(gatedEnergy), 0.82))
        let listeningLevel: CGFloat = reveal > 0.98 ? 0.055 : 0
        let motionLevel = max(reactiveLevel, listeningLevel)

        return Canvas { context, size in
            let center = CGPoint(
                x: size.width / 2,
                y: size.height / 2
            )
            let baseRadius =
                (min(size.width, size.height) / 2) - 60
            let travelPhase =
                time * (1.25 + (Double(motionLevel) * 1.35))

            guard motionLevel > 0.01 else { return }

            let livePerimeter = verticalRipplePath(
                center: center,
                radius: baseRadius,
                amplitude: 0.35 + (motionLevel * 18),
                phase: travelPhase
            )
            context.stroke(
                livePerimeter,
                with: .color(
                    accent.opacity(
                        0.06 + (Double(motionLevel) * 0.34)
                    )
                ),
                lineWidth: 5 + (motionLevel * 3)
            )
            context.stroke(
                livePerimeter,
                with: .color(
                    accent.opacity(
                        0.22 + (Double(motionLevel) * 0.78)
                    )
                ),
                lineWidth: 1.1 + (motionLevel * 1.4)
            )

            guard reactiveLevel > 0.04 else { return }

            for index in 0..<2 {
                let layer = CGFloat(index)
                let radius =
                    baseRadius
                    + 10
                    + (layer * 13)
                    + (reactiveLevel * 4)
                let amplitude =
                    reactiveLevel
                    * max(7, 13 - (layer * 4))
                let path = verticalRipplePath(
                    center: center,
                    radius: radius,
                    amplitude: amplitude,
                    phase: travelPhase - (Double(index) * 0.58)
                )
                let opacity =
                    Double(reactiveLevel)
                    * (0.52 - (Double(index) * 0.12))

                context.stroke(
                    path,
                    with: .color(
                        accent.opacity(opacity * 0.22)
                    ),
                    lineWidth: 4
                )
                context.stroke(
                    path,
                    with: .color(
                        accent.opacity(opacity)
                    ),
                    lineWidth: 1.25
                )
            }
        }
    }

    private func verticalRipplePath(
        center: CGPoint,
        radius: CGFloat,
        amplitude: CGFloat,
        phase: Double
    ) -> Path {
        var path = Path()
        let pointCount = 320

        for index in 0...pointCount {
            let angle =
                (Double(index) / Double(pointCount))
                * .pi
                * 2
            let verticalPosition = sin(angle)
            let sideEmphasis =
                0.20 + (0.80 * abs(cos(angle)))
            let sidePhase =
                phase + (cos(angle) >= 0 ? 0.22 : -0.34)
            let variation =
                (
                    sin(
                        (verticalPosition * 5.6) - sidePhase
                    ) * 0.70
                    + sin(
                        (verticalPosition * 9.2)
                        - (sidePhase * 1.12)
                        + 0.8
                    ) * 0.20
                    + sin(
                        (verticalPosition * 3.2)
                        - (sidePhase * 0.54)
                    ) * 0.10
                )
                * sideEmphasis
            let currentRadius =
                radius + (amplitude * CGFloat(variation))
            let point = CGPoint(
                x: center.x + (CGFloat(cos(angle)) * currentRadius),
                y: center.y + (CGFloat(sin(angle)) * currentRadius)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func smoothStep(
        edge0: CGFloat,
        edge1: CGFloat,
        value: CGFloat
    ) -> CGFloat {
        guard edge1 > edge0 else {
            return value >= edge1 ? 1 : 0
        }

        let normalized = min(
            max((value - edge0) / (edge1 - edge0), 0),
            1
        )
        return normalized
            * normalized
            * (3 - (2 * normalized))
    }

    private func smootherStepProgress(
        _ value: CGFloat
    ) -> CGFloat {
        value
            * value
            * value
            * (
                value
                    * ((value * 6) - 15)
                    + 10
            )
    }
}

private struct DiagonalActivationMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let progress = min(max(progress, 0), 1)
        let totalDistance = rect.width + rect.height
        let frontDistance =
            (-0.12 + (progress * 1.24)) * totalDistance
        let sampleCount = 180

        path.move(
            to: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(
            to: CGPoint(x: rect.maxX, y: rect.minY)
        )

        for index in stride(
            from: sampleCount,
            through: 0,
            by: -1
        ) {
            let normalizedX =
                CGFloat(index) / CGFloat(sampleCount)
            let localX = normalizedX * rect.width
            let organicOffset =
                sin((normalizedX * 14.2) + (progress * 1.1))
                    * rect.height
                    * 0.009
                + sin((normalizedX * 31.4) - (progress * 0.7))
                    * rect.height
                    * 0.003
            let boundary = min(
                max(
                    frontDistance - localX + organicOffset,
                    0
                ),
                rect.height
            )

            path.addLine(
                to: CGPoint(
                    x: rect.minX + localX,
                    y: rect.minY + boundary
                )
            )
        }

        path.closeSubpath()
        return path
    }
}

struct GIAActiveVoiceDisc_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            GIAActiveVoiceDisc(
                microphoneLevel: 0.58,
                revealProgress: 1,
                transcript:
                    "Plan seven days in Lisbon for four travelers.",
                statusText: "Listening",
                presentationState: .listening,
                isSpeechPlaybackActive: false,
                isAnimationActive: true
            )
                .frame(width: 410, height: 410)
        }
        .preferredColorScheme(.dark)
    }
}
