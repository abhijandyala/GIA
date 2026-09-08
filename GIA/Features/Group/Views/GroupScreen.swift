import SwiftUI

struct GroupScreen: View {
    @Environment(TripPlanningSession.self)
    private var tripPlanningSession
    @State private var selectedTravelerID: UUID?
    @State private var isInvitePresented = false
    @State private var isDecisionProposalPresented = false
    @State private var isChatPresented = false

    var body: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    GIAColor.intelligenceAccent.opacity(0.055),
                    .clear
                ],
                center: UnitPoint(x: 0.1, y: 0),
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            ContentUnavailableView {
                Label("Group planning", systemImage: "person.2")
            } description: {
                Text(
                    "Group tools are temporarily hidden while "
                    + "the Map and Plan experience is refined."
                )
            }
            .foregroundStyle(GIAColor.secondaryText)
        }
        .accessibilityIdentifier("group.screen")
    }

    @ViewBuilder
    private var content: some View {
        if
            let trip = tripPlanningSession.currentTrip,
            let viewerID = tripPlanningSession.activeTravelerID,
            tripPlanningSession.canAccessGroupWorkspace
        {
            GroupWorkspaceView(
                presentation: GroupWorkspacePresentation(
                    trip: trip,
                    viewerID: viewerID
                ),
                onInvite: {
                    isInvitePresented = true
                },
                onSelectMember: {
                    selectedTravelerID = $0
                },
                onRevokeInvitation: revokeInvitation,
                onOpenChat: {
                    isChatPresented = true
                },
                onProposeDecision: {
                    isDecisionProposalPresented = true
                },
                onVote: castVote,
                onRevise: reviseDecision
            )
        } else if tripPlanningSession.currentTrip != nil {
            GroupAccessDeniedView()
        } else {
            GroupEmptyState()
        }
    }

    private func inviteTraveler(
        name: String,
        emailAddress: String
    ) -> String? {
        do {
            try tripPlanningSession.inviteTraveler(
                name: name,
                emailAddress: emailAddress
            )
            return nil
        } catch let error as GroupWorkspaceError {
            return error.userMessage
        } catch {
            return "The invitation could not be created."
        }
    }

    private func revokeInvitation(_ id: UUID) {
        try? tripPlanningSession.revokeInvitation(id)
    }

    private func proposeDecision(
        title: String,
        subject: DecisionSubject,
        rule: DecisionRule
    ) -> String? {
        do {
            try tripPlanningSession.proposeDecision(
                title: title,
                subject: subject,
                rule: rule
            )
            return nil
        } catch let error as DecisionVotingError {
            return error.userMessage
        } catch {
            return "The decision could not be proposed."
        }
    }

    private func castVote(
        decisionID: UUID,
        choice: VoteChoice
    ) -> String? {
        do {
            try tripPlanningSession.castVote(
                on: decisionID,
                choice: choice
            )
            return nil
        } catch let error as DecisionVotingError {
            return error.userMessage
        } catch {
            return "The vote could not be recorded."
        }
    }

    private func reviseDecision(_ id: UUID) -> String? {
        do {
            try tripPlanningSession.reviseDecision(id)
            return nil
        } catch let error as DecisionVotingError {
            return error.userMessage
        } catch {
            return "The revision could not be created."
        }
    }

    private func sendMessage(
        body: String,
        context: TripMessageContext,
        mentions: Set<UUID>
    ) -> String? {
        do {
            try tripPlanningSession.sendMessage(
                body,
                context: context,
                mentionedTravelerIDs: mentions
            )
            return nil
        } catch let error as TripCommunicationError {
            return error.userMessage
        } catch {
            return "The message could not be sent."
        }
    }

    private func toggleReaction(
        messageID: UUID,
        kind: MessageReactionKind
    ) -> String? {
        do {
            try tripPlanningSession.toggleReaction(
                on: messageID,
                kind: kind
            )
            return nil
        } catch let error as TripCommunicationError {
            return error.userMessage
        } catch {
            return "The reaction could not be updated."
        }
    }

    private func markMessagesRead() {
        try? tripPlanningSession.markMessagesRead()
    }

    private func updateVisibility(_ visibility: PreferenceVisibility) {
        guard var traveler = tripPlanningSession.activeTraveler else {
            return
        }
        traveler.preferences.visibility = visibility
        try? tripPlanningSession.updateActiveTravelerProfile(
            preferences: traveler.preferences,
            availability: traveler.availability,
            personalBudgetLimit: traveler.personalBudgetLimit
        )
    }

    private func removeTraveler(_ id: UUID) -> String? {
        do {
            try tripPlanningSession.removeTraveler(id)
            selectedTravelerID = nil
            return nil
        } catch let error as GroupWorkspaceError {
            return error.userMessage
        } catch {
            return "The member could not be removed."
        }
    }

    private func configureDebugGroupIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_GROUP_WORKSPACE"
            ] == "1",
            tripPlanningSession.currentTrip == nil,
            tripPlanningSession.phase == .idle
        else {
            return
        }

        let trip = GroupDebugFixtures.collaborationTrip()
        try? tripPlanningSession.beginListening(source: .debug)
        try? tripPlanningSession.beginTranscribing()
        try? tripPlanningSession.beginValidation(
            request: trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        if
            let target = ProcessInfo.processInfo.environment[
                "GIA_DEBUG_GROUP_MEMBER"
            ]
        {
            selectedTravelerID =
                target == "private"
                ? trip.travelers.first {
                    $0.preferences.visibility == .privateToTraveler
                }?.id
                : trip.organizerTravelerID
        }
        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_DECISION_PROPOSAL"
        ] == "1" {
            isDecisionProposalPresented = true
        }
        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_GROUP_CHAT"
        ] == "1" {
            isChatPresented = true
        }
        #endif
    }
}

private struct GroupWorkspaceView: View {
    @Environment(JudgeDemoController.self)
    private var judgeDemoController

    let presentation: GroupWorkspacePresentation
    let onInvite: () -> Void
    let onSelectMember: (UUID) -> Void
    let onRevokeInvitation: (UUID) -> Void
    let onOpenChat: () -> Void
    let onProposeDecision: () -> Void
    let onVote: (UUID, VoteChoice) -> String?
    let onRevise: (UUID) -> String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header
                    if judgeDemoController.isActive {
                        Label(
                            "JUDGE-SAFE DEMO · BUNDLED TOKYO DATA",
                            systemImage: "shield.checkered"
                        )
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )
                        .padding(.horizontal, 15)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .planSurface(cornerRadius: 16)
                    }
                    OfflineTripStorageSection(
                        currentTrip: presentation.trip
                    )
                    TripIntegrationSection(
                        trip: presentation.trip
                    )
                    constellation
                    readiness
                    communication
                    decisions
                    members

                    if !presentation.pendingInvitations.isEmpty {
                        pendingInvitations
                    }

                    privacyFooter
                }
                .padding(
                    .horizontal,
                    GIASpacing.screenEdge(
                        for: geometry.size.width
                    )
                )
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(alignment: .leading, spacing: 7) {
                Text("GROUP CONSTELLATION")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.46)
                    )

                Text(presentation.trip.title)
                    .font(.system(size: 31, weight: .light))
                    .foregroundStyle(GIAColor.primaryText)

                Text(
                    "\(presentation.members.count) members · "
                    + "\(presentation.pendingInvitations.count) pending"
                )
                .font(.system(size: 12))
                .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            if presentation.canManage {
                Button(action: onInvite) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(GIAColor.canvas)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(GIAColor.primaryText)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Invite a trip member")
            }
        }
    }

    private var constellation: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("TRIP MEMBERS")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(GIAColor.secondaryText)

                Spacer()

                Text("INVITED ACCESS ONLY")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(GIAColor.intelligenceAccent)
            }

            HStack(spacing: 0) {
                ForEach(
                    Array(presentation.members.enumerated()),
                    id: \.element.id
                ) { index, member in
                    Button {
                        onSelectMember(member.id)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        member.isViewer
                                            ? GIAColor
                                                .intelligenceAccent
                                            : GIAColor.primaryText
                                                .opacity(0.07)
                                    )
                                Text(member.traveler.initials)
                                    .font(
                                        .caption.weight(.semibold)
                                    )
                                    .foregroundStyle(
                                        member.isViewer
                                            ? GIAColor.canvas
                                            : GIAColor.primaryText
                                    )
                            }
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .stroke(
                                        member.isViewer
                                            ? GIAColor
                                                .intelligenceAccent
                                            : GIAColor.subtleStroke,
                                        lineWidth: 0.8
                                    )
                            }

                            Text(member.traveler.displayName)
                                .font(.caption2)
                                .foregroundStyle(
                                    GIAColor.primaryText
                                )
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(member.traveler.displayName), "
                        + member.roleLabel
                    )
                    .accessibilityValue(
                        member.isViewer
                            ? "Current traveler"
                            : member.availabilityLabel
                    )
                    .accessibilityHint("Opens member details")
                    .frame(maxWidth: .infinity)

                    if index < presentation.members.count - 1 {
                        Rectangle()
                            .fill(
                                GIAColor.primaryText.opacity(0.13)
                            )
                            .frame(maxWidth: 26)
                            .frame(height: 0.7)
                            .offset(y: -10)
                    }
                }
            }
        }
        .padding(18)
        .planSurface(cornerRadius: 24)
    }

    private var readiness: some View {
        HStack(spacing: 0) {
            GroupReadinessMetric(
                value:
                    "\(presentation.availableCount)"
                    + "/\(presentation.members.count)",
                label: "AVAILABLE",
                symbol: "calendar.badge.checkmark"
            )

            GroupReadinessMetric(
                value: "\(presentation.constraintCount)",
                label: "CONSTRAINTS",
                symbol: "slider.horizontal.3"
            )

            GroupReadinessMetric(
                value:
                    "\(presentation.pendingInvitations.count)",
                label: "PENDING",
                symbol: "paperplane"
            )
        }
        .padding(.vertical, 17)
        .planSurface(cornerRadius: 22)
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("MEMBER CONTEXT")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.42)
                )

            ForEach(presentation.members) { member in
                Button {
                    onSelectMember(member.id)
                } label: {
                    GroupMemberCard(member: member)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens member details")
            }
        }
    }

    private var decisions: some View {
        GroupDecisionSection(
            trip: presentation.trip,
            viewerID: presentation.viewerID,
            canManage: presentation.canManage,
            onPropose: onProposeDecision,
            onVote: onVote,
            onRevise: onRevise
        )
    }

    private var communication: some View {
        GroupCommunicationSummary(
            trip: presentation.trip,
            viewerID: presentation.viewerID,
            onOpen: onOpenChat
        )
    }

    private var pendingInvitations: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("PENDING INVITATIONS")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.42)
                )

            ForEach(presentation.pendingInvitations) { invitation in
                HStack(spacing: 12) {
                    Image(systemName: "paperplane")
                        .font(.caption)
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )
                        .frame(width: 28, height: 28)
                        .background {
                            Circle().fill(
                                GIAColor.intelligenceAccent.opacity(0.08)
                            )
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(invitation.inviteeName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GIAColor.primaryText)
                        Text(invitation.inviteeEmailAddress)
                            .font(.caption2)
                            .foregroundStyle(GIAColor.secondaryText)
                    }

                    Spacer()

                    if presentation.canManage {
                        Button("REVOKE") {
                            onRevokeInvitation(invitation.id)
                        }
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(GIAColor.warningAccent)
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "Revoke invitation for "
                            + invitation.inviteeName
                        )
                    }
                }
                .padding(15)
                .planSurface(cornerRadius: 18)
            }
        }
    }

    private var privacyFooter: some View {
        Label(
            "Sensitive preferences follow each member's visibility setting.",
            systemImage: "lock.shield"
        )
        .font(.caption2)
        .foregroundStyle(GIAColor.secondaryText)
        .padding(.horizontal, 4)
    }
}

private struct GroupDecisionSection: View {
    let trip: Trip
    let viewerID: UUID
    let canManage: Bool
    let onPropose: () -> Void
    let onVote: (UUID, VoteChoice) -> String?
    let onRevise: (UUID) -> String?

    private var decisions: [GroupDecisionPresentation] {
        trip.decisions
            .map {
                GroupDecisionPresentation(
                    decision: $0,
                    trip: trip,
                    viewerID: viewerID
                )
            }
            .sorted {
                let left = stateRank($0.decision.state)
                let right = stateRank($1.decision.state)
                if left != right {
                    return left < right
                }
                return $0.decision.proposedAt
                    > $1.decision.proposedAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DECISIONS")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.42)
                        )

                    Text(
                        "\(trip.decisions.count) proposals · "
                        + "\(openCount) open"
                    )
                    .font(.caption2)
                    .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                if canManage {
                    Button(action: onPropose) {
                        Label("PROPOSE", systemImage: "plus")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(
                                GIAColor.intelligenceAccent
                            )
                            .padding(.horizontal, 11)
                            .frame(minHeight: 44)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(
                                        GIAColor.intelligenceAccent
                                            .opacity(0.08)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Propose a new group decision")
                }
            }

            if decisions.isEmpty {
                Label(
                    "No decisions have been proposed.",
                    systemImage: "checkmark.bubble"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .padding(17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .planSurface(cornerRadius: 18)
            } else {
                ForEach(decisions) {
                    GroupDecisionCard(
                        presentation: $0,
                        onVote: onVote,
                        onRevise: onRevise
                    )
                }
            }
        }
    }

    private var openCount: Int {
        trip.decisions.count {
            $0.state == .proposed
                || $0.state == .voting
                || $0.state == .tied
                || $0.state == .needsRevision
        }
    }

    private func stateRank(_ state: DecisionState) -> Int {
        switch state {
        case .voting, .proposed:
            0
        case .tied, .needsRevision:
            1
        case .approved:
            2
        case .rejected:
            3
        }
    }
}

private struct GroupDecisionCard: View {
    let presentation: GroupDecisionPresentation
    let onVote: (UUID, VoteChoice) -> String?
    let onRevise: (UUID) -> String?

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: presentation.subjectIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(stateColor)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle().fill(stateColor.opacity(0.09))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        if let revision = presentation.revisionLabel {
                            Text(revision)
                                .font(.system(size: 7, weight: .bold))
                                .tracking(0.9)
                                .foregroundStyle(
                                    GIAColor.intelligenceAccent
                                )
                        }

                        Text(presentation.ruleLabel.uppercased())
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.9)
                            .foregroundStyle(GIAColor.secondaryText)
                    }

                    Text(presentation.decision.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.subjectLabel)
                        .font(.caption)
                        .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer(minLength: 4)

                Text(presentation.stateLabel.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.8)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(stateColor)
            }

            HStack {
                tallyMetric(
                    value: presentation.tally.approveCount,
                    label: "YES",
                    color: GIAColor.confirmedAccent
                )
                tallyMetric(
                    value: presentation.tally.rejectCount,
                    label: "NO",
                    color: GIAColor.warningAccent
                )
                tallyMetric(
                    value: presentation.tally.abstainCount,
                    label: "PASS",
                    color: GIAColor.secondaryText
                )

                Spacer()

                DecisionVoterStack(
                    initials: presentation.decision.votes.compactMap {
                        vote in
                        presentation.trip.travelers.first {
                            $0.id == vote.travelerID
                        }?.initials
                    }
                )
            }

            Text(presentation.progressDescription)
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)

            if presentation.canViewerVote {
                HStack(spacing: 8) {
                    voteButton(.approve, title: "YES")
                    voteButton(.reject, title: "NO")
                    voteButton(.abstain, title: "PASS")
                }
            } else if let vote = presentation.viewerVote {
                Label(
                    "Your vote: \(voteLabel(vote.choice))",
                    systemImage: "checkmark.circle"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(GIAColor.intelligenceAccent)
            }

            if presentation.canViewerRevise {
                Button {
                    errorMessage = onRevise(presentation.id)
                } label: {
                    HStack {
                        Text("CREATE REVISION")
                        Spacer()
                        Image(systemName: "arrow.triangle.branch")
                    }
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(GIAColor.warningAccent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background {
                        Capsule(style: .continuous)
                            .fill(GIAColor.warningAccent.opacity(0.07))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Create a revision for "
                    + presentation.decision.title
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(GIAColor.warningAccent)
            }
        }
        .padding(16)
        .planSurface(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(stateColor.opacity(0.18), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
    }

    private func tallyMetric(
        value: Int,
        label: String,
        color: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(GIAColor.secondaryText)
        }
        .frame(width: 42)
        .accessibilityElement(children: .combine)
    }

    private func voteButton(
        _ choice: VoteChoice,
        title: String
    ) -> some View {
        Button {
            errorMessage = onVote(presentation.id, choice)
        } label: {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .tracking(1)
                .foregroundStyle(
                    choice == .approve
                        ? GIAColor.canvas
                        : GIAColor.primaryText
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            choice == .approve
                                ? GIAColor.primaryText
                                : GIAColor.primaryText.opacity(0.05)
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Vote \(voteLabel(choice)) on "
            + presentation.decision.title
        )
    }

    private var stateColor: Color {
        switch presentation.decision.state {
        case .approved:
            GIAColor.confirmedAccent
        case .rejected, .tied, .needsRevision:
            GIAColor.warningAccent
        case .proposed, .voting:
            GIAColor.intelligenceAccent
        }
    }

    private func voteLabel(_ choice: VoteChoice) -> String {
        switch choice {
        case .approve:
            "Yes"
        case .reject:
            "No"
        case .abstain:
            "Pass"
        }
    }
}

private struct DecisionVoterStack: View {
    let initials: [String]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(initials.prefix(5).enumerated()), id: \.offset) {
                index,
                value in
                Text(value)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(GIAColor.primaryText)
                    .frame(width: 25, height: 25)
                    .background {
                        Circle().fill(GIAColor.planSurface)
                    }
                    .overlay {
                        Circle().stroke(
                            GIAColor.primaryText.opacity(0.2),
                            lineWidth: 0.7
                        )
                    }
                    .zIndex(Double(initials.count - index))
            }
        }
        .accessibilityLabel("\(initials.count) ballots recorded")
    }
}

private struct DecisionProposalSheet: View {
    let trip: Trip
    let onPropose:
        (String, DecisionSubject, DecisionRule) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedSubject: DecisionSubject
    @State private var rule: DecisionRule = .majority
    @State private var errorMessage: String?

    private let subjects: [(DecisionSubject, String)]

    init(
        trip: Trip,
        onPropose:
            @escaping (
                String,
                DecisionSubject,
                DecisionRule
            ) -> String?
    ) {
        self.trip = trip
        self.onPropose = onPropose
        let subjects =
            DecisionSubjectResolver.availableSubjects(in: trip)
        self.subjects = subjects
        _selectedSubject = State(
            initialValue: subjects.first?.0 ?? .budget
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("NEW GROUP DECISION")
                            .font(.caption2.weight(.semibold))
                            .tracking(2)
                            .foregroundStyle(GIAColor.secondaryText)

                        Text("Open a vote")
                            .font(.largeTitle.weight(.light))
                            .foregroundStyle(GIAColor.primaryText)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("QUESTION")
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )
                            TextField(
                                "What should the group decide?",
                                text: $title,
                                axis: .vertical
                            )
                            .lineLimit(2...4)
                        }
                        .padding(16)
                        .planSurface(cornerRadius: 18)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("SUBJECT")
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )

                            Picker(
                                "Decision subject",
                                selection: $selectedSubject
                            ) {
                                ForEach(
                                    Array(subjects.enumerated()),
                                    id: \.offset
                                ) { _, subject in
                                    Text(subject.1)
                                        .tag(subject.0)
                                }
                            }
                            .tint(GIAColor.primaryText)
                        }
                        .padding(16)
                        .planSurface(cornerRadius: 18)

                        VStack(alignment: .leading, spacing: 11) {
                            Text("APPROVAL RULE")
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )

                            Picker("Approval rule", selection: $rule) {
                                Text("Majority")
                                    .tag(DecisionRule.majority)
                                Text("Unanimous")
                                    .tag(DecisionRule.unanimous)
                                Text("Organizer")
                                    .tag(DecisionRule.organizer)
                            }
                            .pickerStyle(.segmented)

                            Text(ruleDescription)
                                .font(.caption2)
                                .foregroundStyle(
                                    GIAColor.secondaryText
                                )
                        }
                        .padding(16)
                        .planSurface(cornerRadius: 18)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    GIAColor.warningAccent
                                )
                        }

                        Button(action: propose) {
                            Text("OPEN VOTING")
                                .font(.caption.weight(.semibold))
                                .tracking(1.3)
                                .foregroundStyle(GIAColor.canvas)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(GIAColor.primaryText)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(22)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Propose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(GIAColor.primaryText)
                }
            }
            .toolbarBackground(GIAColor.canvas, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationBackground(GIAColor.canvas)
    }

    private var ruleDescription: String {
        switch rule {
        case .majority:
            "More than half of eligible members must approve."
        case .unanimous:
            "Every eligible member must approve."
        case .organizer:
            "Only the organizer's ballot decides."
        }
    }

    private func propose() {
        if let message = onPropose(title, selectedSubject, rule) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}

private struct GroupReadinessMetric: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(GIAColor.intelligenceAccent)

            Text(value)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(GIAColor.primaryText)

            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .tracking(1)
                .foregroundStyle(GIAColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct GroupMemberCard: View {
    let member: GroupMemberPresentation

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        member.isViewer
                            ? GIAColor.intelligenceAccent
                            : GIAColor.primaryText.opacity(0.06)
                    )
                Text(member.traveler.initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        member.isViewer
                            ? GIAColor.canvas
                            : GIAColor.primaryText
                    )
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(member.traveler.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)

                    Text(member.roleLabel.uppercased())
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(
                            member.roleLabel == "Organizer"
                                ? GIAColor.intelligenceAccent
                                : GIAColor.secondaryText
                        )
                }

                Text(member.preferenceSummary)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(
                        member.availabilityLabel,
                        systemImage: member.availabilitySymbol
                    )
                    Label(
                        member.budgetLabel,
                        systemImage: "wallet.pass"
                    )
                }
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                Image(
                    systemName:
                        member.canViewSensitiveDetails
                        ? "eye"
                        : "lock"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
            }
        }
        .padding(16)
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

private struct GroupMemberDetailSheet: View {
    let member: GroupMemberPresentation
    let canManage: Bool
    let onSaveVisibility: (PreferenceVisibility) -> Void
    let onRemove: (UUID) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var visibility: PreferenceVisibility
    @State private var isRemoveConfirmationPresented = false
    @State private var errorMessage: String?

    init(
        member: GroupMemberPresentation,
        canManage: Bool,
        onSaveVisibility:
            @escaping (PreferenceVisibility) -> Void,
        onRemove: @escaping (UUID) -> String?
    ) {
        self.member = member
        self.canManage = canManage
        self.onSaveVisibility = onSaveVisibility
        self.onRemove = onRemove
        _visibility = State(
            initialValue: member.traveler.preferences.visibility
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        identity

                        if member.canViewSensitiveDetails {
                            preferenceDetails
                        } else {
                            privateState
                        }

                        if member.isViewer {
                            visibilityControl
                        }

                        if
                            canManage,
                            member.traveler.id
                                != member.trip.organizerTravelerID
                        {
                            removeAction
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    GIAColor.warningAccent
                                )
                        }
                    }
                    .padding(22)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Member Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if member.isViewer {
                            onSaveVisibility(visibility)
                        }
                        dismiss()
                    }
                    .foregroundStyle(GIAColor.primaryText)
                }
            }
            .toolbarBackground(GIAColor.canvas, for: .navigationBar)
            .confirmationDialog(
                "Remove \(member.traveler.displayName)?",
                isPresented: $isRemoveConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Remove Member", role: .destructive) {
                    if let message = onRemove(member.id) {
                        errorMessage = message
                    } else {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(
                    "Their membership ends, but prior votes and "
                    + "membership history remain."
                )
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(GIAColor.canvas)
    }

    private var identity: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(GIAColor.intelligenceAccent.opacity(0.12))
                Text(member.traveler.initials)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(GIAColor.intelligenceAccent)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.traveler.displayName)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                Text(member.roleLabel)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                Text(member.availabilityLabel)
                    .font(.caption)
                    .foregroundStyle(GIAColor.intelligenceAccent)
            }
        }
    }

    private var preferenceDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupDetailRow(
                title: "PERSONAL BUDGET",
                value: member.budgetLabel,
                symbol: "wallet.pass"
            )
            GroupDetailRow(
                title: "PACE",
                value:
                    member.traveler.preferences.preferredPace
                        .rawValue.capitalized,
                symbol: "figure.walk"
            )
            GroupDetailRow(
                title: "INTERESTS",
                value: list(
                    member.traveler.preferences.interests
                ),
                symbol: "sparkles"
            )
            GroupDetailRow(
                title: "DIETARY",
                value: list(
                    member.traveler.preferences
                        .dietaryRequirements
                ),
                symbol: "fork.knife"
            )
            GroupDetailRow(
                title: "ACCESSIBILITY",
                value: list(
                    member.traveler.preferences
                        .accessibilityRequirements
                ),
                symbol: "accessibility"
            )
        }
        .padding(18)
        .planSurface(cornerRadius: 22)
    }

    private var privateState: some View {
        Label(
            "This member's sensitive preferences are private.",
            systemImage: "lock.shield"
        )
        .font(.subheadline)
        .foregroundStyle(GIAColor.secondaryText)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .planSurface(cornerRadius: 20)
    }

    private var visibilityControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREFERENCE VISIBILITY")
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(GIAColor.secondaryText)

            Picker("Preference visibility", selection: $visibility) {
                Text("Only me")
                    .tag(PreferenceVisibility.privateToTraveler)
                Text("Organizer")
                    .tag(PreferenceVisibility.organizers)
                Text("Members")
                    .tag(PreferenceVisibility.tripMembers)
            }
            .pickerStyle(.segmented)

            Text(
                "Controls dietary, accessibility, notes, pace, "
                + "and personal budget visibility."
            )
            .font(.caption2)
            .foregroundStyle(GIAColor.secondaryText)
        }
        .padding(18)
        .planSurface(cornerRadius: 20)
    }

    private var removeAction: some View {
        Button {
            isRemoveConfirmationPresented = true
        } label: {
            Label("REMOVE FROM TRIP", systemImage: "person.badge.minus")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(GIAColor.warningAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    Capsule(style: .continuous)
                        .fill(GIAColor.warningAccent.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
    }

    private func list<T: RawRepresentable>(
        _ values: Set<T>
    ) -> String where T.RawValue == String, T: Hashable {
        let labels = values.map {
            $0.rawValue
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .capitalized
        }.sorted()
        return labels.isEmpty
            ? "None supplied"
            : labels.joined(separator: ", ")
    }
}

private struct GroupDetailRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(GIAColor.intelligenceAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroupInviteSheet: View {
    let onInvite: (String, String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emailAddress = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text("INVITE TO SHARED TRIP")
                        .font(.caption2.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(GIAColor.secondaryText)

                    Text("Add a traveler")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(GIAColor.primaryText)

                    VStack(spacing: 12) {
                        TextField("Display name", text: $name)
                            .textContentType(.name)
                        TextField(
                            "Email address",
                            text: $emailAddress
                        )
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    }
                    .textFieldStyle(.plain)
                    .padding(17)
                    .background {
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .fill(GIAColor.planSurface)
                    }
                    .foregroundStyle(GIAColor.primaryText)

                    Label(
                        "Invitations grant member access only after "
                        + "acceptance.",
                        systemImage: "lock.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(GIAColor.warningAccent)
                    }

                    Button(action: invite) {
                        Text("CREATE INVITATION")
                            .font(.caption.weight(.semibold))
                            .tracking(1.3)
                            .foregroundStyle(GIAColor.canvas)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(GIAColor.primaryText)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(GIAColor.primaryText)
                }
            }
            .toolbarBackground(GIAColor.canvas, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationBackground(GIAColor.canvas)
    }

    private func invite() {
        if let message = onInvite(name, emailAddress) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}

private struct GroupEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No shared trip", systemImage: "person.2")
        } description: {
            Text(
                "Create a plan first, then invite travelers "
                + "to collaborate."
            )
        }
        .foregroundStyle(GIAColor.secondaryText)
    }
}

private struct GroupAccessDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Invitation required", systemImage: "lock.shield")
        } description: {
            Text(
                "Only accepted trip members can open this workspace."
            )
        }
        .foregroundStyle(GIAColor.secondaryText)
    }
}

extension GroupWorkspaceError {
    var userMessage: String {
        switch self {
        case .invalidPhase:
            "The group workspace is not ready yet."
        case .noCurrentTrip:
            "No shared trip is available."
        case .noActiveTraveler, .accessDenied:
            "An accepted trip invitation is required."
        case .organizerRequired:
            "Only the organizer can manage members."
        case .invalidInvitation:
            "Enter a valid name and email address."
        case .duplicateInvitation:
            "This traveler already has access or a pending invitation."
        case .unknownInvitation:
            "The invitation is no longer available."
        case .unknownTraveler:
            "The traveler is no longer part of this trip."
        case .cannotRemoveOrganizer:
            "Transfer organizer ownership before removing this member."
        }
    }
}

extension DecisionVotingError {
    var userMessage: String {
        switch self {
        case .invalidPhase:
            "Voting is not available while the trip is changing."
        case .noCurrentTrip:
            "No shared trip is available."
        case .noActiveTraveler, .accessDenied:
            "An accepted trip membership is required."
        case .organizerRequired:
            "Only the organizer can create or revise decisions."
        case .invalidTitle:
            "Enter a decision question."
        case .invalidSubject:
            "Choose an option that still exists in the trip."
        case .unknownDecision:
            "This decision is no longer available."
        case .decisionClosed:
            "Voting has already closed for this decision."
        case .ineligibleVoter:
            "You are not eligible to vote on this decision."
        case .duplicateVote:
            "Your vote has already been recorded."
        case .revisionNotAllowed:
            "Only tied, rejected, or revision-needed decisions "
                + "can be revised."
        }
    }
}

extension TripCommunicationError {
    var userMessage: String {
        switch self {
        case .invalidPhase:
            "Chat is unavailable while the trip is changing."
        case .noCurrentTrip:
            "No shared trip is available."
        case .noActiveTraveler, .accessDenied:
            "An accepted trip membership is required."
        case .emptyMessage:
            "Enter a message first."
        case .messageTooLong:
            "Messages must contain 2,000 characters or fewer."
        case .invalidContext:
            "The linked trip item is no longer available."
        case .invalidMention:
            "One mentioned traveler is no longer a trip member."
        case .unknownMessage:
            "This message is no longer available."
        }
    }
}

struct GroupScreen_Previews: PreviewProvider {
    static var previews: some View {
        GroupScreen()
            .environment(TripPlanningSession())
            .environment(JudgeDemoController())
            .environment(TripPersistenceController())
            .environment(TripNotificationCoordinator())
            .environment(TripCalendarCoordinator())
            .preferredColorScheme(.dark)
    }
}
