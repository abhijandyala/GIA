import SwiftUI

struct OfflineTripStorageSection: View {
    let currentTrip: Trip

    @Environment(TripPersistenceController.self)
    private var persistenceController
    @Environment(TripPlanningSession.self)
    private var tripPlanningSession
    @State private var isLibraryPresented = false
    @State private var errorMessage: String?

    private var currentSummary: StoredTripSummary? {
        persistenceController.summaries.first {
            $0.id == currentTrip.id
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OFFLINE LIBRARY")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.42)
                        )

                    Text(
                        "\(persistenceController.summaries.count) "
                        + "saved trips"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                Button {
                    saveNow()
                } label: {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GIAColor.secondaryText)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(
                                GIAColor.primaryText.opacity(0.05)
                            )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save trip now")

                Button {
                    isLibraryPresented = true
                } label: {
                    Text("MANAGE")
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
                .accessibilityLabel("Manage saved trips")
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(GIAColor.confirmedAccent.opacity(0.09))
                    Image(systemName: "checkmark.icloud")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(GIAColor.confirmedAccent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        currentSummary == nil
                            ? "Saving on device"
                            : "Available offline"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                    Text(storageDetail)
                        .font(.caption2)
                        .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                if currentTrip.usesDemoData {
                    Text("DEMO DATA")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(GIAColor.intelligenceAccent)
                }
            }
            .padding(15)
            .planSurface(cornerRadius: 19)

            if persistenceController.isEphemeralFallback {
                Label(
                    "Persistent storage is unavailable; this session "
                    + "is temporary.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.warningAccent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(GIAColor.warningAccent)
            }
        }
        .sheet(isPresented: $isLibraryPresented) {
            OfflineTripLibrarySheet()
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment[
                "GIA_DEBUG_OFFLINE_LIBRARY"
            ] == "1" {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    isLibraryPresented = true
                }
            }
            #endif
        }
    }

    private var storageDetail: String {
        guard let summary = currentSummary else {
            return "Autosave pending"
        }
        var parts = [
            "Saved \(relativeAge(summary.savedAt))"
        ]
        if let providerDate = summary.oldestProviderRetrievedAt {
            parts.append(
                "oldest source \(relativeAge(providerDate))"
            )
        }
        return parts.joined(separator: " · ")
    }

    private func saveNow() {
        do {
            try persistenceController.save(currentTrip)
            errorMessage = nil
        } catch let error as TripPersistenceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "The trip could not be saved."
        }
    }

    private func relativeAge(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }
}

private struct OfflineTripLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TripPersistenceController.self)
    private var persistenceController
    @Environment(TripPlanningSession.self)
    private var tripPlanningSession
    @State private var pendingDeleteID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas.ignoresSafeArea()

                if persistenceController.summaries.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No saved trips",
                            systemImage: "internaldrive"
                        )
                    } description: {
                        Text(
                            "Completed plans will appear here "
                            + "automatically."
                        )
                    }
                    .foregroundStyle(GIAColor.secondaryText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 11) {
                            ForEach(persistenceController.summaries) {
                                summary in
                                tripRow(summary)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(
                                        GIAColor.warningAccent
                                    )
                            }
                        }
                        .padding(18)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Offline Trips")
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
            .confirmationDialog(
                "Delete this local trip?",
                isPresented: Binding(
                    get: { pendingDeleteID != nil },
                    set: {
                        if !$0 {
                            pendingDeleteID = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Local Data", role: .destructive) {
                    deletePendingTrip()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(
                    "This removes the saved trip from this device. "
                    + "It does not cancel provider reservations."
                )
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(GIAColor.canvas)
    }

    private func tripRow(
        _ summary: StoredTripSummary
    ) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(
                        summary.id
                            == tripPlanningSession.currentTrip?.id
                            ? GIAColor.intelligenceAccent.opacity(0.12)
                            : GIAColor.primaryText.opacity(0.05)
                    )
                Image(systemName: "map")
                    .font(.caption)
                    .foregroundStyle(
                        summary.id
                            == tripPlanningSession.currentTrip?.id
                            ? GIAColor.intelligenceAccent
                            : GIAColor.secondaryText
                    )
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(summary.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)

                    if summary.containsDemoData {
                        Text("DEMO")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(
                                GIAColor.intelligenceAccent
                            )
                    }
                }

                Text(
                    "\(summary.lifecycleState.rawValue.capitalized) · "
                    + "saved \(relativeAge(summary.savedAt))"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            Button {
                open(summary.id)
            } label: {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.primaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(summary.title)")

            Button {
                pendingDeleteID = summary.id
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(GIAColor.warningAccent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(summary.title)")
        }
        .padding(15)
        .planSurface(cornerRadius: 19)
    }

    private func open(_ tripID: UUID) {
        do {
            let trip = try persistenceController.load(tripID)
            try tripPlanningSession.restorePersistedTrip(trip)
            errorMessage = nil
            dismiss()
        } catch let error as TripPersistenceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "The saved trip could not be opened."
        }
    }

    private func deletePendingTrip() {
        guard let tripID = pendingDeleteID else { return }
        do {
            try persistenceController.delete(tripID)
            if tripPlanningSession.currentTrip?.id == tripID {
                tripPlanningSession.clearCurrentTrip()
            }
            errorMessage = nil
        } catch let error as TripPersistenceError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "The saved trip could not be deleted."
        }
        pendingDeleteID = nil
    }

    private func relativeAge(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }
}
