import SwiftUI

struct SpatialItineraryTimeline: View {
    let trip: Trip
    let onMove:
        (UUID, Date, Date) -> Bool
    let onToggleLock: (UUID) -> Void

    @State private var selectedDayID: UUID?
    @State private var expandedItemIDs: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var days: [TimelineDayPresentation] {
        ItineraryPresentationBuilder.days(for: trip)
    }

    private var selectedDay: TimelineDayPresentation? {
        let id = selectedDayID ?? days.first?.id
        return days.first { $0.id == id } ?? days.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            daySelector

            if let selectedDay {
                VStack(alignment: .leading, spacing: 0) {
                    dayHeader(selectedDay)

                    Rectangle()
                        .fill(GIAColor.subtleStroke)
                        .frame(height: 0.6)
                        .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        let items = selectedDay.items
                        ForEach(Array(items.enumerated()), id: \.element.id) {
                            index,
                            presentation in
                            TimelineItemRow(
                                presentation: presentation,
                                isExpanded:
                                    expandedItemIDs.contains(
                                        presentation.id
                                    ),
                                onToggleExpanded: {
                                    toggleExpanded(presentation.id)
                                },
                                onMove: onMove,
                                onToggleLock: {
                                    onToggleLock(presentation.id)
                                }
                            )

                            if index < items.count - 1 {
                                let route =
                                    ItineraryPresentationBuilder.route(
                                        from: presentation.item,
                                        to: items[index + 1].item,
                                        in: trip
                                    )
                                TimelineTransportConnector(route: route)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .planSurface(cornerRadius: 24)
            }
        }
        .onAppear {
            selectedDayID = days.first?.id
        }
        .onChange(of: days.map(\.id)) { _, availableIDs in
            if
                let selectedDayID,
                !availableIDs.contains(selectedDayID)
            {
                self.selectedDayID = availableIDs.first
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY PLAN")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.1)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.48)
                    )

                Text("\(days.count) itinerary days")
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            Text("15 MIN SNAP")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(GIAColor.secondaryText)
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    Button {
                        withAnimation(
                            reduceMotion
                                ? .linear(duration: 0.01)
                                : .easeOut(duration: 0.2)
                        ) {
                            selectedDayID = day.id
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.shortTitle.uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(1.1)

                            if let weather = day.weatherSummary {
                                Text(weather)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(
                            selectedDayID == day.id
                                ? GIAColor.canvas
                                : GIAColor.secondaryText
                        )
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    selectedDayID == day.id
                                        ? GIAColor.primaryText
                                        : GIAColor.primaryText.opacity(0.05)
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
                    .accessibilityLabel(day.fullTitle)
                    .accessibilityValue(
                        selectedDayID == day.id
                            ? "Selected"
                            : "Not selected"
                    )
                    .accessibilityAddTraits(
                        selectedDayID == day.id ? .isSelected : []
                    )
                }
            }
        }
    }

    private func dayHeader(
        _ day: TimelineDayPresentation
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(day.fullTitle)
                .font(.headline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)

            Spacer()

            if let weather = day.weatherSummary {
                Text(weather)
                    .font(.caption)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .lineLimit(1)
            }
        }
        .padding(18)
        .accessibilityElement(children: .combine)
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeInOut(duration: 0.22)
        ) {
            if expandedItemIDs.contains(id) {
                expandedItemIDs.remove(id)
            } else {
                expandedItemIDs.insert(id)
            }
        }
    }
}

private struct TimelineItemRow: View {
    let presentation: ItineraryItemPresentation
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onMove: (UUID, Date, Date) -> Bool
    let onToggleLock: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: nodeColor.opacity(0.7),
                        radius: 4
                    )

                Rectangle()
                    .fill(GIAColor.primaryText.opacity(0.12))
                    .frame(width: 0.7)
                    .frame(minHeight: isExpanded ? 108 : 69)
            }
            .padding(.top, 19)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: presentation.iconName)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(presentation.item.title)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(GIAColor.primaryText)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        Text(presentation.timeRange)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                GIAColor.intelligenceAccent
                            )

                        if let location = presentation.locationText {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(presentation.flexibilityLabel)
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(
                                presentation.canMove
                                    ? GIAColor.intelligenceAccent
                                    : GIAColor.secondaryText
                            )

                        if presentation.canMove {
                            Image(systemName: "line.3.horizontal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GIAColor.secondaryText)
                                .frame(width: 34, height: 30)
                                .contentShape(Rectangle())
                                .gesture(dragGesture)
                                .accessibilityHidden(true)
                        }
                    }
                }

                HStack {
                    if let cost = presentation.costText {
                        Label(cost, systemImage: "creditcard")
                    }

                    Spacer()

                    Button(action: onToggleExpanded) {
                        HStack(spacing: 5) {
                            Text(isExpanded ? "LESS" : "DETAILS")
                            Image(
                                systemName:
                                    isExpanded
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(GIAColor.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(.top, 13)

                if isExpanded {
                    expandedContent
                        .transition(
                            .opacity.combined(with: .move(edge: .top))
                        )
                }
            }
            .padding(16)
            .planSurface(cornerRadius: 18)
            .offset(y: dragOffset)
            .zIndex(dragOffset == 0 ? 0 : 1)
        }
        .padding(.horizontal, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilitySummary)
        .modifier(
            TimelineMoveAccessibilityModifier(
                isEnabled: presentation.canMove,
                moveEarlier: {
                    move(byMinutes: -15)
                },
                moveLater: {
                    move(byMinutes: 15)
                }
            )
        )
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let notes = presentation.item.notes {
                TranslatedPlanText(
                    originalText: notes,
                    contentKind: .travelMessage,
                    protectedTerms: [
                        presentation.item.title,
                        presentation.item.subtitle,
                        presentation.item.location?.name,
                        "GIA"
                    ].compactMap { $0 }
                )
            }

            HStack {
                Label(
                    statusLabel,
                    systemImage: "circle.fill"
                )

                Spacer()

                if presentation.canToggleLock {
                    Button(action: onToggleLock) {
                        Label(
                            presentation.item.flexibility == .lockedByUser
                                ? "Unlock"
                                : "Lock",
                            systemImage:
                                presentation.item.flexibility
                                == .lockedByUser
                                ? "lock.open"
                                : "lock"
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                }
            }
            .font(.caption)
            .foregroundStyle(GIAColor.secondaryText)
        }
        .padding(.top, 15)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragOffset = min(max(value.translation.height, -96), 96)
            }
            .onEnded { value in
                let increments = Int(
                    (value.translation.height / 16).rounded()
                )
                move(byMinutes: increments * 15)
                resetDragOffset()
            }
    }

    private var nodeColor: Color {
        switch presentation.item.flexibility {
        case .fixed:
            GIAColor.primaryText
        case .flexible:
            GIAColor.intelligenceAccent
        case .lockedByUser:
            GIAColor.secondaryText
        }
    }

    private var statusLabel: String {
        switch presentation.item.status {
        case .proposed:
            "Proposed"
        case .selected:
            "Selected"
        case .confirmed:
            "Confirmed"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        }
    }

    private func move(byMinutes minutes: Int) {
        guard presentation.canMove, minutes != 0 else {
            resetDragOffset()
            return
        }
        let offset = TimeInterval(minutes * 60)
        _ = onMove(
            presentation.id,
            presentation.item.start.addingTimeInterval(offset),
            presentation.item.end.addingTimeInterval(offset)
        )
    }

    private func resetDragOffset() {
        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeOut(duration: 0.2)
        ) {
            dragOffset = 0
        }
    }
}

private struct TimelineMoveAccessibilityModifier: ViewModifier {
    let isEnabled: Bool
    let moveEarlier: () -> Void
    let moveLater: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityAction(
                    named: Text("Move 15 minutes earlier"),
                    moveEarlier
                )
                .accessibilityAction(
                    named: Text("Move 15 minutes later"),
                    moveLater
                )
        } else {
            content
        }
    }
}

private struct TimelineTransportConnector: View {
    let route: TimelineTransportPresentation?

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Rectangle()
                    .fill(GIAColor.primaryText.opacity(0.13))
                    .frame(width: 0.7, height: 35)
            }
            .frame(width: 10)

            if let route {
                HStack(spacing: 7) {
                    Image(systemName: modeIcon(route.route.mode))
                        .font(.caption)

                    Text(route.modeText)
                    Text("·")
                    Text(route.durationText)
                    Text("·")
                    Text(route.confidenceText)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(GIAColor.secondaryText)
                .accessibilityElement(children: .combine)
            } else {
                Text("Route not connected")
                    .font(.caption2)
                    .foregroundStyle(
                        GIAColor.secondaryText.opacity(0.64)
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func modeIcon(_ mode: TransportationMode) -> String {
        switch mode {
        case .walking:
            "figure.walk"
        case .bicycle:
            "bicycle"
        case .car, .rideshare:
            "car"
        case .transit, .bus, .subway, .train:
            "tram"
        case .ferry:
            "ferry"
        case .airplane:
            "airplane"
        }
    }
}
