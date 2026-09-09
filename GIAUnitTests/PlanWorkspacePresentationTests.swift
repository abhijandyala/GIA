import XCTest
@testable import GIA

final class PlanWorkspacePresentationTests: XCTestCase {
    func testPhaseTitlesAreReadableSentenceCase() {
        XCTAssertEqual(
            PlanPhasePresentation.title(for: .searching),
            "Finding travel options"
        )
        XCTAssertEqual(
            PlanPhasePresentation.title(for: .ready),
            "Your plan"
        )
        XCTAssertFalse(
            PlanPhasePresentation.title(for: .buildingItinerary)
                .contains("SYNTHESIS")
        )
    }

    func testWorkspaceStatusHidesWhenPlanIsReady() {
        XCTAssertNil(
            PlanPhasePresentation.workspaceStatus(
                phase: .ready,
                orchestration: .ready,
                failureMessage: nil
            )
        )
        XCTAssertEqual(
            PlanPhasePresentation.workspaceStatus(
                phase: .searching,
                orchestration: .searching,
                failureMessage: nil
            ),
            "Finding travel options"
        )
        XCTAssertEqual(
            PlanPhasePresentation.workspaceStatus(
                phase: .failed,
                orchestration: .failed,
                failureMessage: "Gateway timed out"
            ),
            "Gateway timed out"
        )
    }

    func testDateStripUsesToInsteadOfDash() {
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: Date(timeIntervalSince1970: 1_800_000_000),
                end: Date(timeIntervalSince1970: 1_800_604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 4,
            totalBudget: Money(amount: 6_000, currencyCode: "USD")
        )
        let dates = PlanPresentationBuilder.contextMetrics(
            for: request
        ).first { $0.kind == .dates }?.value ?? ""

        XCTAssertTrue(dates.contains(" to "))
        XCTAssertFalse(dates.contains("–"))
        XCTAssertFalse(dates.contains("—"))
    }

    func testJumpAnchorsKeepStableScrollIdentifiers() {
        XCTAssertEqual(
            PlanJumpAnchor.days.rawValue,
            "itinerary-timeline"
        )
        XCTAssertEqual(
            PlanJumpAnchor.flights.rawValue,
            "flight-comparison"
        )
        XCTAssertEqual(
            PlanJumpAnchor.stay.rawValue,
            "hotel-comparison"
        )
        XCTAssertEqual(
            PlanJumpAnchor.budget.rawValue,
            "budget-conflict"
        )
        XCTAssertEqual(
            PlanJumpAnchor.allCases.map(\.title),
            ["Days", "Flights", "Stay", "Budget"]
        )
    }
}
