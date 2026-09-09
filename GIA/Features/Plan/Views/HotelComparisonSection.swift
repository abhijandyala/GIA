import SwiftUI

struct HotelComparisonSection: View {
    let offers: [HotelOffer]
    let selectedIDs: Set<UUID>
    let bookings: [BookingRecord]
    let onSelect: (UUID) -> Void

    @State private var focusedOfferID: UUID?
    @State private var comparisonIDs: Set<UUID> = []
    @State private var isDetailExpanded = false
    @State private var isComparisonPresented = false
    @State private var showsMoreOptions = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var presentations: [HotelOptionPresentation] {
        HotelPresentationBuilder.sortedOffers(
            offers,
            selectedIDs: selectedIDs
        )
    }

    private var focused: HotelOptionPresentation? {
        let id = focusedOfferID ?? presentations.first?.id
        return presentations.first { $0.id == id }
            ?? presentations.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader

            if let focused {
                FeaturedHotelCard(
                    hotel: focused,
                    isSelected: selectedIDs.contains(focused.id),
                    isCompared: comparisonIDs.contains(focused.id),
                    isDetailExpanded: $isDetailExpanded,
                    onSelect: {
                        onSelect(focused.id)
                    },
                    onToggleComparison: {
                        toggleComparison(focused.id)
                    }
                )
            }

            if presentations.count > 1 {
                Button {
                    withAnimation(
                        reduceMotion
                            ? .linear(duration: 0.01)
                            : .easeOut(duration: 0.2)
                    ) {
                        showsMoreOptions.toggle()
                    }
                } label: {
                    Text(
                        showsMoreOptions
                            ? "Hide other stays"
                            : moreStayOptionsTitle
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            if showsMoreOptions, presentations.count > 1 {
                alternatives
            }

            if comparisonIDs.count >= 2 {
                Button {
                    isComparisonPresented = true
                } label: {
                    HStack {
                        Text("Compare \(comparisonIDs.count) stays")
                            .font(.subheadline.weight(.semibold))

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
                    "Opens a detailed side-by-side hotel comparison"
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
            HotelComparisonSheet(
                hotels: presentations.filter {
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
                Text("Stay")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(
                    offers.count == 1
                        ? "1 option"
                        : "\(offers.count) options"
                )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            Text(bookingStatusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bookingStatusColor)
        }
    }

    private var selectedBooking: BookingRecord? {
        bookings.first {
            $0.category == .hotel
                && selectedIDs.contains($0.itemIdentifier)
                && $0.status != .cancelled
        }
    }

    private var moreStayOptionsTitle: String {
        let extras = max(offers.count - 1, 0)
        return extras == 1
            ? "More options"
            : "More options (\(extras))"
    }

    private var bookingStatusLabel: String {
        switch selectedBooking?.status {
        case .demoConfirmed:
            "Demo confirmed"
        case .confirmed:
            "Booked"
        case .externalCheckoutRequired, .processing:
            "Checkout needed"
        default:
            "No booking yet"
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
            Text("Other stays")
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.55)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 11) {
                    ForEach(presentations) { hotel in
                        CompactHotelCard(
                            hotel: hotel,
                            isFocused: hotel.id == focused?.id,
                            isSelected:
                                selectedIDs.contains(hotel.id),
                            isCompared:
                                comparisonIDs.contains(hotel.id),
                            onFocus: {
                                withAnimation(
                                    reduceMotion
                                        ? .linear(duration: 0.01)
                                        : .easeOut(duration: 0.2)
                                ) {
                                    focusedOfferID = hotel.id
                                    isDetailExpanded = false
                                }
                            },
                            onToggleComparison: {
                                toggleComparison(hotel.id)
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
                "GIA_DEBUG_COMPARE_HOTELS"
            ] == "1"
        else {
            return
        }

        comparisonIDs = Set(
            presentations.prefix(3).map(\.id)
        )
        showsMoreOptions = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            isComparisonPresented = true
        }
        #endif
    }
}

private struct FeaturedHotelCard: View {
    let hotel: HotelOptionPresentation
    let isSelected: Bool
    let isCompared: Bool
    @Binding var isDetailExpanded: Bool
    let onSelect: () -> Void
    let onToggleComparison: () -> Void
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HotelHeroImage(hotel: hotel)
                    .frame(width: 72, height: 72)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(hotel.offer.name)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(hotel.locationLabel)
                        .font(.caption)
                        .foregroundStyle(GIAColor.secondaryText)
                        .lineLimit(1)

                    Text(
                        "\(hotel.ratingText)  ·  \(hotel.totalPrice)"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                }

                Spacer(minLength: 0)
            }

            if isDetailExpanded {
                extraDetails
                    .transition(
                        .opacity.combined(with: .move(edge: .top))
                    )
            }

            actions
        }
        .padding(16)
        .planSurface(cornerRadius: 22)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(hotel.accessibilitySummary)
    }

    @ViewBuilder
    private var extraDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let badge = hotel.primaryBadge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.intelligenceAccent)
            }

            Text("\(hotel.nightlyPrice) per night")
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)

            Text(hotel.reviewText)
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)

            Label(
                hotel.cancellationDescription,
                systemImage:
                    hotel.offer.cancellationPolicy == nil
                    ? "questionmark.circle"
                    : "checkmark.circle"
            )
            .font(.caption)
            .foregroundStyle(
                hotel.offer.cancellationPolicy == nil
                    ? GIAColor.secondaryText
                    : GIAColor.intelligenceAccent
            )

            Text(hotel.taxDescription)
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)

            HotelDetailView(hotel: hotel)

            if let bookingURL = hotel.offer.bookingURL {
                Link(destination: bookingURL) {
                    HStack {
                        Text("Open booking site")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(GIAColor.secondaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background {
                        Capsule(style: .continuous)
                            .fill(GIAColor.primaryText.opacity(0.045))
                    }
                }
                .accessibilityHint(
                    "Opens an external provider. No reservation has been made."
                )
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(
                    reduceMotion
                        ? .linear(duration: 0.01)
                        : .easeInOut(duration: 0.22)
                ) {
                    isDetailExpanded.toggle()
                }
            } label: {
                Text(isDetailExpanded ? "Less" : "Details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isDetailExpanded
                    ? "Hide hotel details"
                    : "View hotel details"
            )

            Spacer()

            Button(action: onToggleComparison) {
                Image(
                    systemName:
                        isCompared
                        ? "checkmark.circle.fill"
                        : "plus.circle"
                )
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    isCompared
                        ? GIAColor.intelligenceAccent
                        : GIAColor.secondaryText
                )
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isCompared
                    ? "Remove hotel from comparison"
                    : "Add hotel to comparison"
            )

            Button(action: onSelect) {
                Text(isSelected ? "Selected" : "Select")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        isSelected
                            ? GIAColor.intelligenceAccent
                            : GIAColor.canvas
                    )
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                isSelected
                                    ? GIAColor.intelligenceAccent
                                        .opacity(0.10)
                                    : GIAColor.primaryText
                            )
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HotelHeroImage: View {
    let hotel: HotelOptionPresentation

    var body: some View {
        ZStack {
            if let imageURL = hotel.offer.imageURLs.first {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        spatialPlaceholder
                    }
                }
            } else {
                spatialPlaceholder
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var spatialPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    GIAColor.intelligenceAccent.opacity(0.15),
                    GIAColor.planSurface,
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 19) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(
                        cornerRadius: 2,
                        style: .continuous
                    )
                    .stroke(
                        GIAColor.primaryText.opacity(
                            0.08 + (Double(index) * 0.025)
                        ),
                        lineWidth: 0.8
                    )
                    .frame(
                        width: 22,
                        height: CGFloat(38 + (index * 11))
                    )
                }
            }
            .offset(y: 18)

            Image(systemName: "building.2")
                .font(.system(size: 25, weight: .ultraLight))
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.60)
                )
        }
    }
}

private struct HotelMetric: View {
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
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HotelDetailView: View {
    let hotel: HotelOptionPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(hotel.starDescription, systemImage: "star")
            Label(hotel.lodgingType, systemImage: "building.2")
            Label(hotel.checkTimeDescription, systemImage: "clock")

            if let roomDescription = hotel.offer.roomDescription {
                TranslatedPlanText(
                    originalText: roomDescription,
                    contentKind: .placeDescription,
                    protectedTerms: [
                        hotel.offer.name,
                        hotel.offer.location.name,
                        hotel.offer.location.city,
                        hotel.offer.location.region,
                        hotel.offer.location.country
                    ].compactMap { $0 }
                )
            }

            if hotel.offer.location.coordinate != nil {
                Label(
                    "Location ready for route analysis",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            } else {
                Label(
                    "Route analysis needs coordinates",
                    systemImage: "location.slash"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(GIAColor.secondaryText)
        .padding(.bottom, 15)
    }
}

private struct CompactHotelCard: View {
    let hotel: HotelOptionPresentation
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
                        Text(hotel.sourceLabel)
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

                    Text(hotel.offer.name)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .lineLimit(2)
                        .padding(.top, 14)

                    Text("\(hotel.ratingText) · \(hotel.reviewText)")
                        .font(.caption)
                        .foregroundStyle(GIAColor.secondaryText)
                        .lineLimit(1)
                        .padding(.top, 5)

                    Spacer(minLength: 14)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hotel.totalPrice)
                                .font(.title3.weight(.semibold))
                            Text("total")
                                .font(.caption2)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )
                        }
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
            .accessibilityLabel(hotel.accessibilitySummary)
            .accessibilityHint("Focuses this hotel option")

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
                .padding(.top, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isCompared
                    ? "Remove hotel from comparison"
                    : "Add hotel to comparison"
            )
        }
        .padding(16)
        .frame(width: 226, height: 190)
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

private struct HotelSourcePill: View {
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

private struct HotelComparisonSheet: View {
    let hotels: [HotelOptionPresentation]
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
                        ForEach(hotels) { hotel in
                            comparisonCard(hotel)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Compare Stays")
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
        _ hotel: HotelOptionPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hotel.offer.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(hotel.locationLabel)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            comparisonRow("Total", hotel.totalPrice)
            comparisonRow("Nightly", hotel.nightlyPrice)
            comparisonRow("Rating", hotel.ratingText)
            comparisonRow("Reviews", hotel.reviewText)
            comparisonRow("Class", hotel.starDescription)
            comparisonRow("Cancellation", hotel.cancellationDescription)
            comparisonRow("Taxes", hotel.taxDescription)
            comparisonRow(
                "Amenities",
                hotel.amenityTitles.prefix(4).joined(separator: ", ")
            )
            comparisonRow("Source", hotel.sourceLabel)

            Spacer(minLength: 0)

            Button {
                onSelect(hotel.id)
            } label: {
                Text(
                    selectedIDs.contains(hotel.id)
                        ? "REVIEW"
                        : "SELECT"
                )
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(
                    selectedIDs.contains(hotel.id)
                        ? GIAColor.intelligenceAccent
                        : GIAColor.canvas
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            selectedIDs.contains(hotel.id)
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
        .frame(width: 270)
        .frame(minHeight: 590)
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

            Text(value.isEmpty ? "Not supplied" : value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
