import SwiftUI

struct TripRequestCorrectionSheet: View {
    let field: PlanContextMetric.Kind
    let request: TripRequest
    let onSave: (TripRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destinationName: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var travelerCount: Int
    @State private var budgetAmount: String
    @State private var currencyCode: String
    @FocusState private var isTextFieldFocused: Bool

    init(
        field: PlanContextMetric.Kind,
        request: TripRequest,
        onSave: @escaping (TripRequest) -> Void
    ) {
        self.field = field
        self.request = request
        self.onSave = onSave

        let calendar = Calendar.current
        let defaultStart =
            request.dateRange?.start
            ?? calendar.date(
                byAdding: .day,
                value: 30,
                to: Date()
            )
            ?? Date()
        let defaultDuration = max(request.durationDays ?? 7, 1)
        let defaultEnd =
            request.dateRange?.end
            ?? calendar.date(
                byAdding: .day,
                value: defaultDuration - 1,
                to: defaultStart
            )
            ?? defaultStart

        _destinationName = State(
            initialValue: request.destinations.first?.name ?? ""
        )
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)
        _travelerCount = State(
            initialValue: min(max(request.travelerCount ?? 1, 1), 30)
        )
        _budgetAmount = State(
            initialValue: request.totalBudget.map {
                NSDecimalNumber(decimal: $0.amount).stringValue
            } ?? ""
        )
        _currencyCode = State(
            initialValue: request.totalBudget?.currencyCode ?? "USD"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GIAColor.canvas
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(fieldTitle.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(2.2)
                            .foregroundStyle(
                                GIAColor.intelligenceAccent
                            )

                        Text(fieldPrompt)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(GIAColor.primaryText)
                    }

                    fieldEditor

                    Spacer(minLength: 0)

                    Button(action: save) {
                        Text("SAVE DETAIL")
                            .font(.caption.weight(.semibold))
                            .tracking(1.7)
                            .foregroundStyle(GIAColor.canvas)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(GIAColor.primaryText)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.42)
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(GIAColor.secondaryText)
                }
            }
            .toolbarBackground(GIAColor.canvas, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(GIAColor.canvas)
        .onAppear {
            if field == .destination || field == .budget {
                isTextFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var fieldEditor: some View {
        switch field {
        case .destination:
            TextField("City or country", text: $destinationName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .font(.title3)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .planSurface(cornerRadius: 16)
                .accessibilityLabel("Destination")
        case .dates:
            VStack(spacing: 12) {
                DatePicker(
                    "Departure",
                    selection: $startDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )

                DatePicker(
                    "Return",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
            }
            .font(.body.weight(.medium))
            .foregroundStyle(GIAColor.primaryText)
            .padding(17)
            .planSurface(cornerRadius: 18)
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = newStart
                }
            }
        case .travelers:
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("GROUP SIZE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.48)
                        )

                    Text(
                        travelerCount == 1
                            ? "1 traveler"
                            : "\(travelerCount) travelers"
                    )
                    .font(.title3.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                }

                Spacer()

                Stepper(
                    "Travelers",
                    value: $travelerCount,
                    in: 1...30
                )
                .labelsHidden()
            }
            .padding(18)
            .planSurface(cornerRadius: 18)
        case .budget:
            HStack(spacing: 12) {
                TextField("Total budget", text: $budgetAmount)
                    .keyboardType(.decimalPad)
                    .focused($isTextFieldFocused)
                    .font(.title3)
                    .accessibilityLabel("Total budget")

                Picker("Currency", selection: $currencyCode) {
                    ForEach(
                        ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"],
                        id: \.self
                    ) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .tint(GIAColor.intelligenceAccent)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .planSurface(cornerRadius: 16)
        }
    }

    private var fieldTitle: String {
        switch field {
        case .destination:
            "Destination"
        case .dates:
            "Travel dates"
        case .travelers:
            "Travelers"
        case .budget:
            "Trip budget"
        }
    }

    private var fieldPrompt: String {
        switch field {
        case .destination:
            "Where should the group go?"
        case .dates:
            "When should the trip happen?"
        case .travelers:
            "How many people are going?"
        case .budget:
            "What total should GIA protect?"
        }
    }

    private var canSave: Bool {
        switch field {
        case .destination:
            !destinationName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        case .dates:
            endDate >= startDate
        case .travelers:
            (1...30).contains(travelerCount)
        case .budget:
            parsedBudgetAmount.map { $0 > 0 } ?? false
        }
    }

    private var parsedBudgetAmount: Decimal? {
        Decimal(
            string: budgetAmount
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func save() {
        guard canSave else { return }
        var updatedRequest = request

        switch field {
        case .destination:
            let cleanedName = destinationName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            updatedRequest.destinations = [
                TravelLocation(name: cleanedName)
            ]
        case .dates:
            let timeZoneIdentifier =
                updatedRequest.destinations.first?.timeZoneIdentifier
                ?? TimeZone.current.identifier
            updatedRequest.dateRange = TripDateRange(
                start: startDate,
                end: endDate,
                timeZoneIdentifier: timeZoneIdentifier
            )
            updatedRequest.durationDays =
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: startDate),
                    to: Calendar.current.startOfDay(for: endDate)
                ).day.map { $0 + 1 }
        case .travelers:
            updatedRequest.travelerCount = travelerCount
        case .budget:
            if let amount = parsedBudgetAmount {
                updatedRequest.totalBudget = Money(
                    amount: amount,
                    currencyCode: currencyCode
                )
            }
        }

        onSave(updatedRequest)
        dismiss()
    }
}
