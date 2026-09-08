import SwiftUI

struct FlightComparisonSection: View {
    let offers: [FlightOffer]
    let selectedIDs: Set<UUID>
    let bookings: [BookingRecord]
    let completingOfferID: UUID?
    let completionMessage: String?
    let onSelect: (UUID) -> Void

    @State private var focusedOfferID: UUID?
    @State private var comparisonIDs: Set<UUID> = []
    @State private var isDetailExpanded = false
    @State private var isComparisonPresented = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var presentations: [FlightOptionPresentation] {
        FlightPresentationBuilder.sortedOffers(
            offers,
            selectedIDs: selectedIDs
        )
    }

    private var focused: FlightOptionPresentation? {
        let id = focusedOfferID ?? presentations.first?.id
        return presentations.first { $0.id == id }
            ?? presentations.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader

            if let focused {
                FeaturedFlightCard(
                    flight: focused,
                    isSelected: selectedIDs.contains(focused.id),
                    isCompared: comparisonIDs.contains(focused.id),
                    isCompleting:
                        completingOfferID == focused.id,
                    isDetailExpanded: $isDetailExpanded,
                    onSelect: {
                        onSelect(focused.id)
                    },
                    onToggleComparison: {
                        toggleComparison(focused.id)
                    }
                )
            }

            if let completionMessage {
                Label(
                    completionMessage,
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.warningAccent)
                .fixedSize(horizontal: false, vertical: true)
            }

            if presentations.count > 1 {
                alternatives
            }

            if comparisonIDs.count >= 2 {
                Button {
                    isComparisonPresented = true
                } label: {
                    HStack {
                        Text("COMPARE \(comparisonIDs.count) OPTIONS")
                            .font(.caption.weight(.semibold))
                            .tracking(1.5)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(GIAColor.canvas)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background {
                        Capsule(style: .continuous)
                            .fill(GIAColor.primaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    "Opens a detailed side-by-side comparison"
                )
            }
        }
        .onAppear {
            focusedOfferID =
                selectedIDs.first ?? presentations.first?.id
            openDebugComparisonIfRequested()
        }
        .onChange(of: offers.map(\.id)) { _, availableIDs in
            comparisonIDs.formIntersection(availableIDs)
            if
                let focusedOfferID,
                !availableIDs.contains(focusedOfferID)
            {
                self.focusedOfferID = presentations.first?.id
            }
        }
        .sheet(isPresented: $isComparisonPresented) {
            FlightComparisonSheet(
                flights: presentations.filter {
                    comparisonIDs.contains($0.id)
                },
                selectedIDs: selectedIDs,
                onSelect: onSelect
            )
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FLIGHT OPTIONS")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.1)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.48)
                    )

                Text("\(offers.count) sourced options")
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            Text(bookingStatusLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(bookingStatusColor)
        }
    }

    private var selectedBooking: BookingRecord? {
        bookings.first {
            $0.category == .flight
                && selectedIDs.contains($0.itemIdentifier)
                && $0.status != .cancelled
        }
    }

    private var bookingStatusLabel: String {
        switch selectedBooking?.status {
        case .demoConfirmed:
            "DEMO CONFIRMED"
        case .confirmed:
            "PROVIDER CONFIRMED"
        case .externalCheckoutRequired, .processing:
            "CHECKOUT REQUIRED"
        default:
            "NO BOOKING MADE"
        }
    }

    private var bookingStatusColor: Color {
        switch selectedBooking?.status {
        case .confirmed:
            GIAColor.confirmedAccent
        case .demoConfirmed:
            GIAColor.intelligenceAccent
        case .externalCheckoutRequired, .processing:
            GIAColor.warningAccent
        default:
            GIAColor.secondaryText
        }
    }

    private var alternatives: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("ALTERNATIVES")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.38)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 11) {
                    ForEach(presentations) { flight in
                        CompactFlightCard(
                            flight: flight,
                            isFocused: flight.id == focused?.id,
                            isSelected:
                                selectedIDs.contains(flight.id),
                            isCompared:
                                comparisonIDs.contains(flight.id),
                            onFocus: {
                                withAnimation(
                                    reduceMotion
                                        ? .linear(duration: 0.01)
                                        : .easeOut(duration: 0.2)
                                ) {
                                    focusedOfferID = flight.id
                                    isDetailExpanded = false
                                }
                            },
                            onToggleComparison: {
                                toggleComparison(flight.id)
                            }
                        )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func toggleComparison(_ id: UUID) {
        if comparisonIDs.contains(id) {
            comparisonIDs.remove(id)
        } else if comparisonIDs.count < 3 {
            comparisonIDs.insert(id)
        }
    }

    private func openDebugComparisonIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_COMPARE_FLIGHTS"
            ] == "1"
        else {
            return
        }

        comparisonIDs = Set(
            presentations.prefix(3).map(\.id)
        )
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            isComparisonPresented = true
        }
        #endif
    }
}

private struct FeaturedFlightCard: View {
    let flight: FlightOptionPresentation
    let isSelected: Bool
    let isCompared: Bool
    let isCompleting: Bool
    @Binding var isDetailExpanded: Bool
    let onSelect: () -> Void
    let onToggleComparison: () -> Void
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let badge = flight.primaryBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(GIAColor.intelligenceAccent)
                } else {
                    Text("FLIGHT OPTION")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                SourcePill(label: flight.sourceLabel)
            }

            Text(flight.airlineName)
                .font(.title3.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .padding(.top, 14)

            Text(flight.departureDate)
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(.top, 3)

            FlightRouteLine(flight: flight)
                .padding(.top, 21)

            HStack(spacing: 0) {
                FlightMetric(
                    title: "DURATION",
                    value: flight.duration
                )

                FlightMetric(
                    title: "ROUTE",
                    value: flight.stopDescription
                )

                FlightMetric(
                    title: "TOTAL",
                    value: flight.totalPrice
                )
            }
            .padding(.top, 23)

            if
                let priceInsight = flight.priceInsightDescription
            {
                Label(
                    priceInsight,
                    systemImage: flight.priceInsightSymbol
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(GIAColor.intelligenceAccent)
                .padding(.top, 18)
            }

            if !flight.hasResolvedTimeZones {
                Label(
                    "One or more connection time zones need verification",
                    systemImage: "clock.badge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(.top, 13)
            }

            if let returnStatus = flight.returnStatus {
                Label(
                    returnStatus,
                    systemImage: "arrow.uturn.right"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(.top, 13)
            }

            Button {
                withAnimation(
                    reduceMotion
                        ? .linear(duration: 0.01)
                        : .easeInOut(duration: 0.22)
                ) {
                    isDetailExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(
                        isDetailExpanded
                            ? "HIDE DETAILS"
                            : "VIEW DETAILS"
                    )
                    .font(.caption2.weight(.semibold))
                    .tracking(1.3)

                    Spacer()

                    Image(
                        systemName:
                            isDetailExpanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(GIAColor.secondaryText)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isDetailExpanded
                    ? "Hide flight details"
                    : "View flight details"
            )
            .padding(.top, 5)

            if isDetailExpanded {
                FlightDetailView(flight: flight)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Rectangle()
                .fill(GIAColor.subtleStroke)
                .frame(height: 0.6)
                .padding(.bottom, 15)

            actions
        }
        .padding(20)
        .planSurface(cornerRadius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(flight.accessibilitySummary)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onSelect) {
                    Group {
                        if isCompleting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("LOADING RETURN OPTIONS")
                            }
                        } else {
                            Text(
                                isSelected
                                    ? "REVIEW SELECTION"
                                    : "SELECT FLIGHT"
                            )
                        }
                    }
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(
                            isSelected
                                ? GIAColor.intelligenceAccent
                                : GIAColor.canvas
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 43)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    isSelected
                                        ? GIAColor
                                            .intelligenceAccent
                                            .opacity(0.09)
                                        : GIAColor.primaryText
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    isSelected
                                        ? GIAColor
                                            .intelligenceAccent
                                            .opacity(0.42)
                                        : .clear,
                                    lineWidth: 0.8
                                )
                        }
                }
                .buttonStyle(.plain)
                .disabled(isCompleting)

                Button(action: onToggleComparison) {
                    Image(
                        systemName:
                            isCompared
                            ? "checkmark.circle.fill"
                            : "plus.circle"
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isCompared
                            ? GIAColor.intelligenceAccent
                            : GIAColor.secondaryText
                    )
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(GIAColor.primaryText.opacity(0.055))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isCompared
                        ? "Remove from comparison"
                        : "Add to comparison"
                )
            }

            if
                let bookingURL = flight.offer.bookingURL,
                flight.offer.continuationToken == nil
            {
                Link(destination: bookingURL) {
                    HStack {
                        Text("VIEW WITH PROVIDER")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.1)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(GIAColor.secondaryText)
                    .padding(.horizontal, 15)
                    .frame(minHeight: 41)
                    .background {
                        Capsule(style: .continuous)
                            .fill(GIAColor.primaryText.opacity(0.045))
                    }
                }
                .accessibilityHint(
                    "Opens an external provider. No booking has been made."
                )
            }
        }
    }
}

private struct FlightRouteLine: View {
    let flight: FlightOptionPresentation

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(flight.departureTime)
                    .font(.title2.weight(.medium))
                Text(flight.originCode)
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(GIAColor.primaryText)
                    .frame(width: 5, height: 5)

                Rectangle()
                    .fill(GIAColor.primaryText.opacity(0.24))
                    .frame(height: 0.8)

                Image(systemName: "airplane")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GIAColor.intelligenceAccent)

                Rectangle()
                    .fill(GIAColor.primaryText.opacity(0.24))
                    .frame(height: 0.8)

                Circle()
                    .stroke(GIAColor.primaryText, lineWidth: 1)
                    .frame(width: 5, height: 5)
            }
            .accessibilityHidden(true)

            VStack(alignment: .trailing, spacing: 5) {
                Text(flight.arrivalTime)
                    .font(.title2.weight(.medium))
                Text(flight.destinationCode)
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(GIAColor.secondaryText)
            }
        }
        .foregroundStyle(GIAColor.primaryText)
    }
}

private struct FlightMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(GIAColor.primaryText.opacity(0.38))

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct FlightDetailView: View {
    let flight: FlightOptionPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            segmentGroup(
                title: "OUTBOUND",
                segments: flight.offer.outboundSegments
            )

            if !flight.offer.returnSegments.isEmpty {
                Divider()
                    .overlay(GIAColor.subtleStroke)

                segmentGroup(
                    title: "RETURN",
                    segments: flight.offer.returnSegments
                )
            }

            Label(
                flight.baggageDescription,
                systemImage: "suitcase"
            )
            Label(
                flight.emissionsDescription,
                systemImage: "leaf"
            )
        }
        .font(.caption)
        .foregroundStyle(GIAColor.secondaryText)
        .padding(.bottom, 15)
    }

    @ViewBuilder
    private func segmentGroup(
        title: String,
        segments: [FlightSegment]
    ) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(GIAColor.primaryText.opacity(0.45))

        ForEach(segments) { segment in
            HStack(alignment: .top, spacing: 11) {
                Circle()
                    .fill(GIAColor.intelligenceAccent)
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        "\(segment.origin.iataCode ?? "—")"
                        + " → "
                        + "\(segment.destination.iataCode ?? "—")"
                    )
                    .font(.subheadline.weight(.medium))

                    Text(
                        "\(segment.airlineName) "
                        + "\(segment.flightNumber)"
                    )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                }
            }
        }
    }
}

private struct CompactFlightCard: View {
    let flight: FlightOptionPresentation
    let isFocused: Bool
    let isSelected: Bool
    let isCompared: Bool
    let onFocus: () -> Void
    let onToggleComparison: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onFocus) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(flight.sourceLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(
                                GIAColor.primaryText.opacity(0.42)
                            )

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(
                                    GIAColor.intelligenceAccent
                                )
                        }
                    }

                    Text("\(flight.originCode) → \(flight.destinationCode)")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .padding(.top, 16)

                    Text(
                        "\(flight.departureTime) · \(flight.duration)"
                    )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                    .padding(.top, 5)

                    Spacer(minLength: 16)

                    HStack(alignment: .bottom) {
                        Text(flight.totalPrice)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(GIAColor.primaryText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(GIAColor.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(flight.accessibilitySummary)
            .accessibilityHint("Focuses this flight option")

            Button(action: onToggleComparison) {
                HStack {
                    Image(
                        systemName:
                            isCompared
                            ? "checkmark.circle.fill"
                            : "plus.circle"
                    )
                    Text(isCompared ? "COMPARING" : "COMPARE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.1)
                }
                .foregroundStyle(
                    isCompared
                        ? GIAColor.intelligenceAccent
                        : GIAColor.secondaryText
                )
                .padding(.top, 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isCompared
                    ? "Remove flight from comparison"
                    : "Add flight to comparison"
            )
        }
        .padding(16)
        .frame(width: 218, height: 176)
        .planSurface(cornerRadius: 20)
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                isFocused
                    ? GIAColor.intelligenceAccent.opacity(0.62)
                    : .clear,
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SourcePill: View {
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(
                    label == "LIVE"
                        ? GIAColor.intelligenceAccent
                        : GIAColor.secondaryText
                )
                .frame(width: 4, height: 4)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
        }
        .foregroundStyle(
            label == "LIVE"
                ? GIAColor.intelligenceAccent
                : GIAColor.secondaryText
        )
        .padding(.horizontal, 9)
        .frame(minHeight: 25)
        .background {
            Capsule(style: .continuous)
                .fill(GIAColor.primaryText.opacity(0.05))
        }
    }
}

private struct FlightComparisonSheet: View {
    let flights: [FlightOptionPresentation]
    let selectedIDs: Set<UUID>
    let onSelect: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas
                    .ignoresSafeArea()

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(flights) { flight in
                            comparisonCard(flight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Compare Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(GIAColor.primaryText)
                }
            }
            .toolbarBackground(GIAColor.canvas, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationBackground(GIAColor.canvas)
    }

    private func comparisonCard(
        _ flight: FlightOptionPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(flight.airlineName)
                    .font(.headline)
                Text("\(flight.originCode) → \(flight.destinationCode)")
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            comparisonRow("Total", flight.totalPrice)
            comparisonRow("Duration", flight.duration)
            comparisonRow("Stops", flight.stopDescription)
            comparisonRow("Baggage", flight.baggageDescription)
            comparisonRow("Emissions", flight.emissionsDescription)
            comparisonRow(
                "Price",
                flight.priceInsightDescription ?? "No insight"
            )
            comparisonRow("Source", flight.sourceLabel)

            Spacer(minLength: 0)

            Button {
                onSelect(flight.id)
            } label: {
                Text(
                    selectedIDs.contains(flight.id)
                        ? "REVIEW"
                        : "SELECT"
                )
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(
                    selectedIDs.contains(flight.id)
                        ? GIAColor.intelligenceAccent
                        : GIAColor.canvas
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            selectedIDs.contains(flight.id)
                                ? GIAColor
                                    .intelligenceAccent
                                    .opacity(0.10)
                                : GIAColor.primaryText
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(width: 260)
        .frame(minHeight: 520)
        .foregroundStyle(GIAColor.primaryText)
        .planSurface(cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }

    private func comparisonRow(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(GIAColor.primaryText.opacity(0.38))

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
