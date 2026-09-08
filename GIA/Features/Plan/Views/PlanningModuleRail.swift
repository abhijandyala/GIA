import SwiftUI

struct PlanningModuleRail: View {
    let phase: TripPlanningPhase
    let progress: TripPlanningProgress
    let trip: Trip?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PLANNING SYSTEMS")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.1)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.48)
                    )

                Spacer()

                Text(moduleSummary)
                    .font(.caption2)
                    .foregroundStyle(
                        GIAColor.secondaryText.opacity(0.72)
                    )
                    .lineLimit(1)
            }

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                LazyHStack(spacing: 11) {
                    ForEach(PlanModuleKind.allCases) { kind in
                        PlanningModuleCard(
                            kind: kind,
                            status:
                                PlanPresentationBuilder.moduleStatus(
                                    for: kind,
                                    progress: progress,
                                    trip: trip
                                )
                        )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private var moduleSummary: String {
        switch phase {
        case .searching:
            "Live lookup active"
        case .comparing:
            "Comparing sourced options"
        case .buildingItinerary:
            "Connecting the plan"
        case .presenting:
            "Preparing results"
        case .ready:
            "Systems complete"
        case .partiallyAvailable:
            "Limited provider access"
        case .failed:
            "Planning paused"
        default:
            "5 systems queued"
        }
    }
}

private struct PlanningModuleCard: View {
    let kind: PlanModuleKind
    let status: PlanModuleStatus

    @ScaledMetric(relativeTo: .body)
    private var cardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .body)
    private var minimumCardHeight: CGFloat = 138

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(iconColor)

                Spacer()

                statusIndicator
            }

            Spacer(minLength: 16)

            Text(kind.title)
                .font(.headline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)

            Text(status.label)
                .font(.caption)
                .foregroundStyle(statusColor)
                .padding(.top, 4)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(progressColor(for: index))
                        .frame(
                            width: index == 1 ? 19 : 9,
                            height: 1
                        )
                }
            }
            .padding(.top, 15)
        }
        .padding(16)
        .frame(width: max(150, cardWidth))
        .frame(minHeight: max(138, minimumCardHeight))
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(status.label)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if status.isActive {
            Circle()
                .fill(GIAColor.intelligenceAccent)
                .frame(width: 6, height: 6)
                .shadow(
                    color: GIAColor.intelligenceAccent.opacity(0.8),
                    radius: 5
                )
        } else if status.isReady {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(GIAColor.primaryText)
        } else {
            Circle()
                .stroke(
                    GIAColor.primaryText.opacity(0.28),
                    lineWidth: 0.8
                )
                .frame(width: 6, height: 6)
        }
    }

    private var iconColor: Color {
        status.isActive
            ? GIAColor.intelligenceAccent
            : GIAColor.primaryText.opacity(0.72)
    }

    private var statusColor: Color {
        status.isActive
            ? GIAColor.intelligenceAccent
            : GIAColor.secondaryText
    }

    private func progressColor(for index: Int) -> Color {
        if status.isReady {
            return GIAColor.primaryText.opacity(
                0.74 - (Double(index) * 0.16)
            )
        }
        if status.isActive, index == 0 {
            return GIAColor.intelligenceAccent
        }
        return GIAColor.primaryText.opacity(0.14)
    }
}

struct PlanningModuleRail_Previews: PreviewProvider {
    static var previews: some View {
        PlanningModuleRail(
            phase: .validating,
            progress: TripPlanningProgress(),
            trip: nil
        )
        .padding(22)
        .background(GIAColor.canvas)
        .preferredColorScheme(.dark)
    }
}
