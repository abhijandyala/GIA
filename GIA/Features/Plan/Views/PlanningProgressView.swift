import SwiftUI

struct PlanningProgressView: View {
    let progress: TripPlanningProgress
    let phase: TripPlanningPhase
    let failureMessage: String?
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GIA PROCESS")
                        .font(.caption2.weight(.semibold))
                        .tracking(2.1)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.48)
                        )

                    Text(currentStatus)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if canCancel {
                    Button(action: onCancel) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))

                            Text("CANCEL")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.2)
                        }
                        .foregroundStyle(GIAColor.secondaryText)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 44)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    GIAColor.primaryText.opacity(0.055)
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    GIAColor.subtleStroke,
                                    lineWidth: 0.7
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel planning request")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(
                        Array(progress.items.enumerated()),
                        id: \.element.id
                    ) { index, item in
                        PlanningProgressNode(item: item)
                            .equatable()

                        if index < progress.items.count - 1 {
                            Rectangle()
                                .fill(connectorColor(after: item))
                                .frame(width: 22, height: 0.7)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .planSurface(cornerRadius: 22)
        }
    }

    private var currentStatus: String {
        if phase == .failed, let failureMessage {
            return failureMessage
        }
        if let activeItem = progress.activeItem {
            return activeItem.statusMessage
                ?? "\(activeItem.workstream.title) in progress"
        }

        if phase == .needsClarification {
            return progress
                .item(for: .understanding)
                .statusMessage
                ?? "Waiting for a required detail"
        }

        if !progress.hasStartedProviderWork {
            return "No live provider search has started"
        }
        if
            phase == .partiallyAvailable,
            progress.items
                .filter(\.workstream.isProviderWork)
                .allSatisfy({ $0.status == .unavailable })
        {
            return "Live travel services are unavailable"
        }

        return PlanPhasePresentation.detail(for: phase)
    }

    private var canCancel: Bool {
        switch phase {
        case
            .validating,
            .needsClarification,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting:
            true
        default:
            false
        }
    }

    private func connectorColor(
        after item: PlanningWorkItem
    ) -> Color {
        item.status == .complete
            ? GIAColor.intelligenceAccent.opacity(0.48)
            : GIAColor.primaryText.opacity(0.10)
    }
}

private struct PlanningProgressNode: View, Equatable {
    let item: PlanningWorkItem

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(nodeFill)
                    .frame(width: 29, height: 29)

                nodeContent
            }

            Text(item.workstream.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .lineLimit(1)

            Text(statusText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .frame(width: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.workstream.title)
        .accessibilityValue(statusText)
    }

    @ViewBuilder
    private var nodeContent: some View {
        switch item.status {
        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(GIAColor.canvas)
        case .active:
            Circle()
                .fill(GIAColor.intelligenceAccent)
                .frame(width: 7, height: 7)
                .shadow(
                    color: GIAColor.intelligenceAccent,
                    radius: 5
                )
        case .waitingForInput:
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(GIAColor.intelligenceAccent)
        case .unavailable:
            Image(systemName: "exclamationmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(GIAColor.secondaryText)
        case .cancelled:
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(GIAColor.secondaryText)
        case .queued:
            Circle()
                .fill(GIAColor.primaryText.opacity(0.24))
                .frame(width: 4, height: 4)
        }
    }

    private var nodeFill: Color {
        return switch item.status {
        case .complete:
            GIAColor.intelligenceAccent
        case .active, .waitingForInput:
            GIAColor.intelligenceAccent.opacity(0.10)
        case .unavailable, .cancelled, .queued:
            GIAColor.primaryText.opacity(0.055)
        }
    }

    private var statusText: String {
        if let count = item.resultCount {
            return count == 1 ? "1 result" : "\(count) results"
        }

        return switch item.status {
        case .queued:
            "Queued"
        case .waitingForInput:
            "Needs input"
        case .active:
            "Active"
        case .complete:
            "Complete"
        case .unavailable:
            "Unavailable"
        case .cancelled:
            "Cancelled"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .active, .waitingForInput, .complete:
            GIAColor.intelligenceAccent
        case .queued, .unavailable, .cancelled:
            GIAColor.secondaryText
        }
    }
}

private extension PlanningWorkstream {
    var title: String {
        switch self {
        case .understanding:
            "Request"
        case .destination:
            "Place"
        case .flights:
            "Flights"
        case .stay:
            "Stay"
        case .experiences:
            "Explore"
        case .weather:
            "Weather"
        case .routes:
            "Routes"
        case .schedule:
            "Schedule"
        case .budget:
            "Budget"
        }
    }
}

struct PlanningProgressView_Previews: PreviewProvider {
    static var previews: some View {
        PlanningProgressView(
            progress: TripPlanningProgress(),
            phase: .validating,
            failureMessage: nil,
            onCancel: { }
        )
        .padding(22)
        .background(GIAColor.canvas)
        .preferredColorScheme(.dark)
    }
}
