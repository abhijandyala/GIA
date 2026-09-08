import SwiftUI

struct GroupCommunicationSummary: View {
    let trip: Trip
    let viewerID: UUID
    let onOpen: () -> Void

    private var messages: [TripMessagePresentation] {
        (trip.communication?.messages ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(2)
            .map {
                TripMessagePresentation(
                    message: $0,
                    trip: trip,
                    viewerID: viewerID
                )
            }
    }

    private var unreadCount: Int {
        (trip.communication?.messages ?? []).count { message in
            !message.readReceipts.contains {
                $0.travelerID == viewerID
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TRIP CHAT")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.42)
                        )

                    Text(
                        unreadCount == 0
                            ? "Everyone stays in context"
                            : "\(unreadCount) unread updates"
                    )
                    .font(.caption2)
                    .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                ShareLink(item: TripShareSummaryBuilder.text(for: trip)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GIAColor.secondaryText)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(
                                GIAColor.primaryText.opacity(0.05)
                            )
                        }
                }
                .accessibilityLabel("Share trip summary")

                Button(action: onOpen) {
                    Text("OPEN")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(GIAColor.intelligenceAccent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    GIAColor.intelligenceAccent.opacity(
                                        0.08
                                    )
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open trip chat")
            }

            if messages.isEmpty {
                Label(
                    "Start the trip conversation.",
                    systemImage: "bubble.left"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .planSurface(cornerRadius: 18)
            } else {
                ForEach(messages) { message in
                    HStack(alignment: .top, spacing: 10) {
                        Text(message.authorInitials)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(
                                message.message.authorKind == .gia
                                    ? GIAColor.intelligenceAccent
                                    : GIAColor.primaryText
                            )
                            .frame(width: 29, height: 29)
                            .background {
                                Circle().fill(
                                    GIAColor.primaryText.opacity(0.055)
                                )
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.authorLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(
                                        GIAColor.primaryText
                                    )
                                if message.isUnread {
                                    Circle()
                                        .fill(
                                            GIAColor.intelligenceAccent
                                        )
                                        .frame(width: 5, height: 5)
                                }
                            }

                            Text(message.message.body)
                                .font(.caption)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )
                                .lineLimit(2)
                        }

                        Spacer(minLength: 4)
                    }
                    .padding(14)
                    .planSurface(cornerRadius: 18)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(message.authorLabel): "
                        + message.message.body
                    )
                }
            }
        }
        .id("group-chat")
    }
}

struct GroupChatSheet: View {
    let trip: Trip
    let viewerID: UUID
    let onSend:
        (String, TripMessageContext, Set<UUID>) -> String?
    let onReaction:
        (UUID, MessageReactionKind) -> String?
    let onMarkRead: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var filterContext: TripMessageContext?
    @State private var composerContext: TripMessageContext = .trip
    @State private var mentionedTravelerIDs: Set<UUID> = []
    @State private var draft = ""
    @State private var errorMessage: String?

    private var messages: [TripMessagePresentation] {
        (trip.communication?.messages ?? [])
            .filter {
                filterContext == nil || $0.context == filterContext
            }
            .sorted { $0.createdAt < $1.createdAt }
            .map {
                TripMessagePresentation(
                    message: $0,
                    trip: trip,
                    viewerID: viewerID
                )
            }
    }

    private var contexts: [(TripMessageContext, String)] {
        CommunicationContextResolver.availableContexts(in: trip)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    threadFilter

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    TripMessageBubble(
                                        presentation: message,
                                        onReaction: {
                                            errorMessage = onReaction(
                                                message.id,
                                                $0
                                            )
                                        }
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(
                            of: messages.map(\.id),
                            initial: true
                        ) { _, ids in
                            guard let last = ids.last else { return }
                            withAnimation(
                                reduceMotion
                                    ? .linear(duration: 0.01)
                                    : .easeOut(duration: 0.2)
                            ) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }

                    composer
                }
            }
            .navigationTitle("Trip Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(
                        item: TripShareSummaryBuilder.text(for: trip)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(GIAColor.primaryText)
                    .accessibilityLabel("Share trip summary")
                }

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
        .presentationBackground(GIAColor.canvas)
        .task(id: trip.communication?.messages.count ?? 0) {
            onMarkRead()
        }
    }

    private var threadFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                contextFilterButton(nil, label: "ALL")
                ForEach(Array(contexts.enumerated()), id: \.offset) {
                    _, context in
                    contextFilterButton(
                        context.0,
                        label: context.1.uppercased()
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GIAColor.subtleStroke)
                .frame(height: 0.6)
        }
    }

    private func contextFilterButton(
        _ context: TripMessageContext?,
        label: String
    ) -> some View {
        Button {
            filterContext = context
        } label: {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.9)
                .lineLimit(1)
                .foregroundStyle(
                    filterContext == context
                        ? GIAColor.canvas
                        : GIAColor.secondaryText
                )
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            filterContext == context
                                ? GIAColor.primaryText
                                : GIAColor.primaryText.opacity(0.045)
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) messages")
        .accessibilityValue(
            filterContext == context ? "Selected" : "Not selected"
        )
        .accessibilityAddTraits(
            filterContext == context ? .isSelected : []
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !mentionedTravelerIDs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(
                        trip.travelers.filter {
                            mentionedTravelerIDs.contains($0.id)
                        }
                    ) { traveler in
                        Text("@\(traveler.displayName)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(
                                GIAColor.intelligenceAccent
                            )
                    }
                }
            }

            HStack(spacing: 9) {
                Menu {
                    ForEach(Array(contexts.enumerated()), id: \.offset) {
                        _, context in
                        Button(context.1) {
                            composerContext = context.0
                        }
                    }
                } label: {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(GIAColor.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Link message to plan item")

                Menu {
                    ForEach(
                        trip.travelers.filter { $0.id != viewerID }
                    ) { traveler in
                        Button {
                            if mentionedTravelerIDs.contains(
                                traveler.id
                            ) {
                                mentionedTravelerIDs.remove(
                                    traveler.id
                                )
                            } else {
                                mentionedTravelerIDs.insert(
                                    traveler.id
                                )
                            }
                        } label: {
                            Label(
                                traveler.displayName,
                                systemImage:
                                    mentionedTravelerIDs.contains(
                                        traveler.id
                                    )
                                    ? "checkmark"
                                    : "at"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "at")
                        .font(.caption)
                        .foregroundStyle(
                            mentionedTravelerIDs.isEmpty
                                ? GIAColor.secondaryText
                                : GIAColor.intelligenceAccent
                        )
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mention trip members")

                TextField(
                    "Message the group",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundStyle(GIAColor.primaryText)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GIAColor.canvas)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(GIAColor.primaryText)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(GIAColor.planSurface)
            }

            HStack {
                Text(
                    "LINKED TO · "
                    + CommunicationContextResolver.label(
                        for: composerContext,
                        in: trip
                    ).uppercased()
                )
                Spacer()
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(GIAColor.warningAccent)
                }
            }
            .font(.system(size: 7, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(GIAColor.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(GIAColor.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GIAColor.subtleStroke)
                .frame(height: 0.6)
        }
    }

    private func send() {
        if
            let error = onSend(
                draft,
                composerContext,
                mentionedTravelerIDs
            )
        {
            errorMessage = error
        } else {
            draft = ""
            mentionedTravelerIDs = []
            errorMessage = nil
        }
    }
}

private struct TripMessageBubble: View {
    let presentation: TripMessagePresentation
    let onReaction: (MessageReactionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(presentation.authorInitials)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(
                    presentation.message.authorKind == .gia
                        ? GIAColor.intelligenceAccent
                        : GIAColor.primaryText
                )
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(
                        presentation.message.authorKind == .gia
                            ? GIAColor.intelligenceAccent.opacity(0.10)
                            : GIAColor.primaryText.opacity(0.055)
                    )
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(presentation.authorLabel)
                        .font(.caption2.weight(.semibold))
                        .tracking(
                            presentation.message.authorKind == .member
                                ? 0
                                : 0.8
                        )
                        .foregroundStyle(
                            presentation.message.authorKind == .gia
                                ? GIAColor.intelligenceAccent
                                : GIAColor.primaryText
                        )

                    Spacer()

                    Text(presentation.timestamp)
                        .font(.caption2)
                        .foregroundStyle(GIAColor.secondaryText)
                }

                if presentation.message.context != .trip {
                    Label(
                        presentation.contextLabel,
                        systemImage: "link"
                    )
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(GIAColor.intelligenceAccent)
                }

                Text(presentation.message.body)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !presentation.mentionLabels.isEmpty {
                    Text(
                        presentation.mentionLabels.joined(separator: " ")
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(GIAColor.intelligenceAccent)
                }

                if presentation.message.authorKind != .system {
                    reactionBar
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        presentation.isOwnMessage
                            ? GIAColor.intelligenceAccent.opacity(0.075)
                            : GIAColor.planSurface
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        presentation.message.authorKind == .gia
                            ? GIAColor.intelligenceAccent.opacity(0.22)
                            : GIAColor.subtleStroke,
                        lineWidth: 0.7
                    )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var reactionBar: some View {
        HStack(spacing: 7) {
            reaction(.approve, symbol: "hand.thumbsup")
            reaction(.heart, symbol: "heart")
            reaction(.celebrate, symbol: "party.popper")
            reaction(.question, symbol: "questionmark")

            Spacer()

            Text(
                "\(presentation.message.readReceipts.count) read"
            )
            .font(.system(size: 8))
            .foregroundStyle(GIAColor.secondaryText)
        }
    }

    private func reaction(
        _ kind: MessageReactionKind,
        symbol: String
    ) -> some View {
        let count = presentation.reactionCount(kind)
        let isSelected = presentation.viewerReacted(kind)
        return Button {
            onReaction(kind)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                if count > 0 {
                    Text("\(count)")
                        .monospacedDigit()
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(
                isSelected
                    ? GIAColor.intelligenceAccent
                    : GIAColor.secondaryText
            )
            .padding(.horizontal, 7)
            .frame(minWidth: 36, minHeight: 36)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? GIAColor.intelligenceAccent.opacity(0.09)
                            : GIAColor.primaryText.opacity(0.035)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(kind.rawValue) reaction, \(count)"
        )
    }
}
