import SwiftUI

struct PlanHeaderView: View {
    let request: TripRequest
    let phase: TripPlanningPhase
    let isProcessing: Bool
    var phaseTitleOverride: String? = nil
    let onSelectMetric: (PlanContextMetric.Kind) -> Void

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 20) {
            headerLayout
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            TripRequestPanel(
                request: request,
                onSelectMetric: onSelectMetric
            )
        }
    }

    @ViewBuilder
    private var headerLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 14) {
                    planningIndicator
                    planLabel

                    Spacer(minLength: 8)

                    phaseGlyph
                }

                phaseTitle
            }
        } else {
            HStack(spacing: 14) {
                planningIndicator

                VStack(alignment: .leading, spacing: 5) {
                    planLabel
                    phaseTitle
                }

                Spacer(minLength: 10)

                phaseGlyph
            }
        }
    }

    private var planningIndicator: some View {
        GIAPlanningIndicator(
            isActive:
                isProcessing
                && PlanPhasePresentation.isActive(phase)
        )
        .frame(width: 54, height: 54)
    }

    private var planLabel: some View {
        Text("PLAN SYNTHESIS")
            .font(.caption2.weight(.semibold))
            .tracking(2.4)
            .foregroundStyle(
                GIAColor.primaryText.opacity(0.58)
            )
    }

    private var phaseTitle: some View {
        Text(
            phaseTitleOverride
            ?? PlanPhasePresentation.title(for: phase)
        )
            .font(
                dynamicTypeSize.isAccessibilitySize
                    ? .title2.weight(.medium)
                    : .headline.weight(.medium)
            )
            .foregroundStyle(GIAColor.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var phaseGlyph: some View {
        if
            isProcessing,
            PlanPhasePresentation.isActive(phase)
        {
            HStack(spacing: 6) {
                Circle()
                    .fill(GIAColor.intelligenceAccent)
                    .frame(width: 5, height: 5)
                    .shadow(
                        color: GIAColor.intelligenceAccent.opacity(0.8),
                        radius: 4
                    )

                Text("ACTIVE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
            }
            .foregroundStyle(GIAColor.intelligenceAccent)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        GIAColor.intelligenceAccent.opacity(0.08)
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        GIAColor.intelligenceAccent.opacity(0.24),
                        lineWidth: 0.7
                    )
            }
            .accessibilityLabel("Planning active")
        }
    }
}

private struct TripRequestPanel: View {
    let request: TripRequest
    let onSelectMetric: (PlanContextMetric.Kind) -> Void

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("REQUEST")
                .font(.caption2.weight(.semibold))
                .tracking(2.2)
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.48)
                )

            if let transcript = request.rawTranscript {
                Text(transcript)
                    .font(
                        .system(
                            .title3,
                            design: .rounded,
                            weight: .light
                        )
                    )
                    .lineSpacing(3)
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(GIAColor.subtleStroke)
                .frame(height: 0.6)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(
                    PlanPresentationBuilder.contextMetrics(for: request)
                ) { metric in
                    PlanContextMetricView(
                        metric: metric,
                        action: {
                            onSelectMetric(metric.kind)
                        }
                    )
                }
            }

        }
        .padding(20)
        .planSurface(cornerRadius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trip request")
    }
}

private struct PlanContextMetricView: View {
    let metric: PlanContextMetric
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(metric.title.uppercased())
                    .font(.caption2.weight(.medium))
                    .tracking(1.3)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.42)
                    )

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            GIAColor.intelligenceAccent.opacity(
                                metric.isResolved ? 0.72 : 1
                            )
                        )
                        .frame(width: 4, height: 4)
                        .shadow(
                            color:
                                metric.isResolved
                                ? .clear
                                : GIAColor.intelligenceAccent,
                            radius: 3
                        )

                    Text(metric.value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(
                            metric.isResolved
                                ? GIAColor.primaryText
                                : GIAColor.intelligenceAccent
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(metric.title), \(metric.value)"
        )
        .accessibilityHint("Double tap to edit")
    }
}

struct PlanHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            PlanHeaderView(
                request: TripRequest(
                    rawTranscript:
                        "Plan seven days in Lisbon for four travelers "
                        + "under six thousand dollars."
                ),
                phase: .validating,
                isProcessing: true,
                onSelectMetric: { _ in }
            )
            .padding(22)
        }
        .background(GIAColor.canvas)
        .preferredColorScheme(.dark)
    }
}
