import SwiftUI

struct PlanTimelineFoundation: View {
    let phase: TripPlanningPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ITINERARY")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.1)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.48)
                    )

                Spacer()

                Text("SPATIAL TIMELINE")
                    .font(.caption2.weight(.medium))
                    .tracking(1.2)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.28)
                    )
            }

            VStack(spacing: 0) {
                TimelineFoundationRow(
                    title: "Request captured",
                    detail: "Your original intent remains the source",
                    state: .complete,
                    drawsConnector: true
                )

                TimelineFoundationRow(
                    title: "Travel options",
                    detail: optionsDetail,
                    state: optionsState,
                    drawsConnector: true
                )

                TimelineFoundationRow(
                    title: "Shared itinerary",
                    detail: itineraryDetail,
                    state: itineraryState,
                    drawsConnector: false
                )
            }
            .padding(.vertical, 13)
            .planSurface(cornerRadius: 24)
        }
    }

    private var optionsState: TimelineFoundationState {
        switch phase {
        case .searching, .comparing:
            .active
        case
            .buildingItinerary,
            .presenting,
            .ready:
            .complete
        default:
            .waiting
        }
    }

    private var itineraryState: TimelineFoundationState {
        switch phase {
        case .buildingItinerary, .presenting:
            .active
        case .ready:
            .complete
        default:
            .waiting
        }
    }

    private var optionsDetail: String {
        optionsState == .waiting
            ? "Flights, stays, places, routes, and weather"
            : "Organizing sourced recommendations"
    }

    private var itineraryDetail: String {
        itineraryState == .waiting
            ? "A time-aware day plan will assemble here"
            : "Connecting time, location, cost, and people"
    }
}

private enum TimelineFoundationState: Equatable {
    case waiting
    case active
    case complete
}

private struct TimelineFoundationRow: View {
    let title: String
    let detail: String
    let state: TimelineFoundationState
    let drawsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(nodeFill)
                        .frame(width: 22, height: 22)

                    nodeContent
                }

                if drawsConnector {
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 0.7, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 19)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState)
    }

    @ViewBuilder
    private var nodeContent: some View {
        switch state {
        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(GIAColor.canvas)
        case .active:
            Circle()
                .fill(GIAColor.intelligenceAccent)
                .frame(width: 6, height: 6)
                .shadow(
                    color: GIAColor.intelligenceAccent,
                    radius: 4
                )
        case .waiting:
            Circle()
                .fill(GIAColor.primaryText.opacity(0.24))
                .frame(width: 4, height: 4)
        }
    }

    private var nodeFill: Color {
        switch state {
        case .complete:
            GIAColor.primaryText
        case .active:
            GIAColor.intelligenceAccent.opacity(0.12)
        case .waiting:
            GIAColor.primaryText.opacity(0.055)
        }
    }

    private var connectorColor: Color {
        state == .complete
            ? GIAColor.primaryText.opacity(0.32)
            : GIAColor.primaryText.opacity(0.10)
    }

    private var accessibilityState: String {
        switch state {
        case .waiting:
            "Waiting"
        case .active:
            "Active"
        case .complete:
            "Complete"
        }
    }
}

struct PlanTimelineFoundation_Previews: PreviewProvider {
    static var previews: some View {
        PlanTimelineFoundation(phase: .validating)
            .padding(22)
            .background(GIAColor.canvas)
            .preferredColorScheme(.dark)
    }
}
