import SwiftUI

struct PlanHeaderView: View {
    let request: TripRequest
    let phase: TripPlanningPhase
    let statusText: String?
    let isProcessing: Bool
    let canCancel: Bool
    let jumpAnchors: [PlanJumpAnchor]
    let showsAskGIA: Bool
    let isWaitingForAnswer: Bool
    let onSelectMetric: (PlanContextMetric.Kind) -> Void
    let onJump: (PlanJumpAnchor) -> Void
    let onNewRequest: () -> Void
    let onCancel: () -> Void
    let onAskGIA: () -> Void

    private var metrics: [PlanContextMetric] {
        PlanPresentationBuilder.contextMetrics(for: request)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            tripStrip

            if let statusText, showsStatus {
                statusRow(statusText)
            }

            if !jumpAnchors.isEmpty {
                jumpChips
            }

            if showsAskGIA {
                askGIAButton
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var showsStatus: Bool {
        guard statusText != nil else { return false }
        switch phase {
        case .ready, .cancelled, .idle:
            return isProcessing
        default:
            return true
        }
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Text("Plan")
                .font(.title2.weight(.semibold))
                .foregroundStyle(GIAColor.primaryText)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            PlanLanguageMenu()

            Menu {
                Button("New trip", action: onNewRequest)
                if canCancel {
                    Button(
                        "Cancel planning",
                        role: .destructive,
                        action: onCancel
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(GIAColor.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Plan actions")
            .accessibilityIdentifier("plan.actions")
        }
    }

    private var tripStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(metrics) { metric in
                    tripChip(metric)
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(metrics.prefix(2)) { metric in
                        tripChip(metric)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(metrics.suffix(2)) { metric in
                        tripChip(metric)
                    }
                }
            }
        }
    }

    private func tripChip(_ metric: PlanContextMetric) -> some View {
        Button {
            onSelectMetric(metric.kind)
        } label: {
            Text(metric.value)
                .font(.caption.weight(.medium))
                .foregroundStyle(
                    metric.isResolved
                        ? GIAColor.primaryText
                        : GIAColor.intelligenceAccent
                )
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .background {
                    Capsule(style: .continuous)
                        .fill(GIAColor.primaryText.opacity(0.055))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            metric.isResolved
                                ? GIAColor.subtleStroke
                                : GIAColor.intelligenceAccent.opacity(0.42),
                            lineWidth: 0.7
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.value)
        .accessibilityHint("Double tap to edit")
        .accessibilityIdentifier("plan.strip.\(metric.kind.rawValue)")
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .tint(GIAColor.intelligenceAccent)
            }

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .lineLimit(2)

            Spacer(minLength: 8)

            if canCancel {
                Button("Cancel", action: onCancel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel planning request")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var jumpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(jumpAnchors) { anchor in
                    Button {
                        onJump(anchor)
                    } label: {
                        Text(anchor.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GIAColor.primaryText)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(GIAColor.primaryText.opacity(0.08))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to \(anchor.title)")
                    .accessibilityIdentifier("plan.jump.\(anchor.rawValue)")
                }
            }
        }
    }

    private var askGIAButton: some View {
        Button(action: onAskGIA) {
            HStack(spacing: 10) {
                Image(
                    systemName: isWaitingForAnswer
                        ? "waveform"
                        : "plus.forwardslash.minus"
                )
                .font(.system(size: 14, weight: .semibold))

                Text(
                    isWaitingForAnswer
                        ? "Answer G.I.A."
                        : "Add or change"
                )
                .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
            }
            .foregroundStyle(GIAColor.intelligenceAccent)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                Capsule(style: .continuous)
                    .fill(GIAColor.intelligenceAccent.opacity(0.10))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        GIAColor.intelligenceAccent.opacity(0.28),
                        lineWidth: 0.8
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan.addOrChange")
        .accessibilityHint(
            isWaitingForAnswer
                ? "Returns to Map so you can answer G.I.A."
                : "Returns to Map to add or change this trip"
        )
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
                phase: .searching,
                statusText: "Finding travel options",
                isProcessing: true,
                canCancel: true,
                jumpAnchors: [.flights, .stay, .budget],
                showsAskGIA: true,
                isWaitingForAnswer: false,
                onSelectMetric: { _ in },
                onJump: { _ in },
                onNewRequest: { },
                onCancel: { },
                onAskGIA: { }
            )
            .padding(22)
        }
        .background(GIAColor.canvas)
        .environment(PlanTranslationCoordinator(service: nil))
        .preferredColorScheme(.dark)
    }
}
