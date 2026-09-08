import SwiftUI

struct BookingConfirmationSheet: View {
    let presentation: BookingReviewPresentation
    let mode: BookingConfirmationMode
    let onConfirm:
        () -> Result<BookingRecord, BookingConfirmationError>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var completedRecord: BookingRecord?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas
                    .ignoresSafeArea()

                ScrollView {
                    if let displayedCompletion {
                        completionView(displayedCompletion)
                    } else {
                        reviewView
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Review Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
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
        .task {
            #if DEBUG
            guard
                ProcessInfo.processInfo.environment[
                    "GIA_DEBUG_AUTOCONFIRM_BOOKING"
                ] == "1"
            else {
                return
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, completedRecord == nil else {
                return
            }
            guard displayedCompletion == nil else { return }
            confirm()
            #endif
        }
    }

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 22) {
            modeBadge

            VStack(alignment: .leading, spacing: 7) {
                Text(presentation.categoryLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(presentation.title)
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            pricePanel
            termsPanel
            truthPanel

            if let errorMessage {
                Label(
                    errorMessage,
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(GIAColor.warningAccent)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: confirm) {
                HStack {
                    Text(primaryActionTitle)
                        .font(.caption.weight(.semibold))
                        .tracking(1.3)

                    Spacer()

                    Image(
                        systemName:
                            mode == .fblaDemo
                            ? "checkmark"
                            : "arrow.up.right"
                    )
                }
                .foregroundStyle(GIAColor.canvas)
                .padding(.horizontal, 18)
                .frame(minHeight: 51)
                .background {
                    Capsule(style: .continuous)
                        .fill(GIAColor.primaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(primaryActionHint)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 34)
    }

    private var displayedCompletion: BookingRecord? {
        if let completedRecord {
            return completedRecord
        }
        guard
            let existing = presentation.existingBookingRecord,
            existing.status == .demoConfirmed
                || existing.status == .confirmed
        else {
            return nil
        }
        return existing
    }

    private var modeBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(
                    mode == .fblaDemo
                        ? GIAColor.intelligenceAccent
                        : GIAColor.warningAccent
                )
                .frame(width: 5, height: 5)

            Text(
                mode == .fblaDemo
                    ? "FBLA DEMONSTRATION"
                    : "EXTERNAL PROVIDER CHECKOUT"
            )
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.4)
        }
        .foregroundStyle(
            mode == .fblaDemo
                ? GIAColor.intelligenceAccent
                : GIAColor.warningAccent
        )
        .padding(.horizontal, 11)
        .frame(minHeight: 29)
        .background {
            Capsule(style: .continuous)
                .fill(GIAColor.primaryText.opacity(0.05))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    (
                        mode == .fblaDemo
                        ? GIAColor.intelligenceAccent
                        : GIAColor.warningAccent
                    ).opacity(0.25),
                    lineWidth: 0.8
                )
        }
    }

    private var pricePanel: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SOURCED TOTAL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(
                    BookingReviewBuilder.money(presentation.price)
                )
                .font(.system(size: 38, weight: .light))
                .monospacedDigit()
                .foregroundStyle(GIAColor.primaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(presentation.providerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                    .multilineTextAlignment(.trailing)

                Text(sourceLabel)
                    .font(.caption2)
                    .foregroundStyle(GIAColor.secondaryText)
            }
        }
        .padding(18)
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private var termsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(
                title: "CANCELLATION / CHANGES",
                value: presentation.cancellationSummary,
                icon: "arrow.uturn.backward"
            )

            Divider()
                .overlay(GIAColor.subtleStroke)

            detailRow(
                title: "SOURCE RETRIEVED",
                value: presentation.sourceRetrievedAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                ),
                icon: "clock"
            )
        }
        .padding(18)
        .planSurface(cornerRadius: 20)
    }

    private var truthPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    mode == .fblaDemo
                        ? GIAColor.intelligenceAccent
                        : GIAColor.warningAccent
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    mode == .fblaDemo
                        ? "NO PAYMENT OR REAL RESERVATION"
                        : "GIA DOES NOT COMPLETE THE BOOKING"
                )
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(GIAColor.primaryText)

                Text(
                    mode == .fblaDemo
                        ? "Continue creates a clearly labeled demo record "
                            + "for the competition presentation only."
                        : "Continue opens the provider. This selection "
                            + "remains unconfirmed until the provider "
                            + "finishes checkout."
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GIAColor.primaryText.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    GIAColor.warningAccent.opacity(0.22),
                    lineWidth: 0.8
                )
        }
        .accessibilityElement(children: .combine)
    }

    private func completionView(
        _ record: BookingRecord
    ) -> some View {
        VStack(spacing: 21) {
            ZStack {
                Circle()
                    .stroke(
                        GIAColor.intelligenceAccent.opacity(0.18),
                        lineWidth: 1
                    )
                    .frame(width: 112, height: 112)

                Image(
                    systemName:
                        record.status == .demoConfirmed
                        ? "checkmark"
                        : "arrow.up.right"
                )
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(GIAColor.intelligenceAccent)
            }

            VStack(spacing: 8) {
                Text(completionTitle(for: record))
                    .font(.title2.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                    .multilineTextAlignment(.center)

                Text(completionMessage(for: record))
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                confirmationRow(
                    "Status",
                    completionStatus(record)
                )
                Divider().overlay(GIAColor.subtleStroke)
                confirmationRow(
                    "Amount",
                    record.amount.map(BookingReviewBuilder.money)
                        ?? "Not supplied"
                )
                Divider().overlay(GIAColor.subtleStroke)
                confirmationRow(
                    "Provider",
                    record.providerName
                )
            }
            .padding(.horizontal, 17)
            .planSurface(cornerRadius: 20)

            Button("DONE") {
                dismiss()
            }
            .font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(GIAColor.canvas)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background {
                Capsule(style: .continuous)
                    .fill(GIAColor.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 65)
        .padding(.bottom, 32)
        .accessibilityElement(children: .contain)
    }

    private func detailRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
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

    private func confirmationRow(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(GIAColor.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(GIAColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func confirm() {
        switch onConfirm() {
        case .success(let record):
            completedRecord = record
            errorMessage = nil
            if
                mode == .externalProvider,
                let checkoutURL = record.checkoutURL
            {
                openURL(checkoutURL)
            }
        case .failure(let error):
            errorMessage = error.userMessage
        }
    }

    private var primaryActionTitle: String {
        mode == .fblaDemo
            ? "CONFIRM DEMO SELECTION"
            : "CONTINUE TO PROVIDER"
    }

    private var primaryActionHint: String {
        mode == .fblaDemo
            ? "Creates a demo confirmation without payment"
            : "Opens external checkout; no booking is made in GIA"
    }

    private var sourceLabel: String {
        switch presentation.sourceOrigin {
        case .live:
            "Live provider result"
        case .cached:
            "Cached provider result"
        case .demo:
            "Demo source data"
        case .userEntered:
            "User-entered source"
        }
    }

    private func completionTitle(
        for record: BookingRecord
    ) -> String {
        record.status == .demoConfirmed
            ? "Demo booking confirmed"
            : record.status == .confirmed
                ? "Provider booking confirmed"
                : "Provider checkout opened"
    }

    private func completionStatus(
        _ record: BookingRecord
    ) -> String {
        switch record.status {
        case .demoConfirmed:
            "Demo confirmed"
        case .confirmed:
            "Provider confirmed"
        case .externalCheckoutRequired:
            "External checkout required"
        default:
            record.status.rawValue
        }
    }

    private func completionMessage(
        for record: BookingRecord
    ) -> String {
        record.status == .demoConfirmed
            ? "This is a demonstration record only. No payment was "
                + "processed and no real reservation was created."
            : record.status == .confirmed
                ? "The provider confirmation remains attached to this "
                    + "shared trip."
                : "GIA saved the selection, but it is not booked until "
                    + "the external provider confirms checkout."
    }
}
