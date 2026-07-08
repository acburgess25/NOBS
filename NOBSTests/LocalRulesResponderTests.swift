import XCTest
@testable import NOBS

final class LocalRulesResponderTests: XCTestCase {
    private let responder = LocalRulesResponder()

    func testCalendarQuestionUsesAgendaSummaryWhenAvailable() {
        let context = NOBSModelContext(
            userName: "Alex",
            hasCalendarAccess: true,
            agendaSummary: "You have 2 events today. First is Standup at 9:00 AM.",
            tankAvailable: false,
            shouldUseTomorrowFraming: false
        )

        let outcome = responder.respond(to: "What's on my calendar today?", context: context)

        XCTAssertEqual(outcome.response.route, .localRules)
        XCTAssertEqual(outcome.response.text, context.agendaSummary)
        XCTAssertTrue(outcome.response.privacyReceipt.used.contains("today's calendar summary"))
    }

    func testGenericFallbackWhenTankUnavailable() {
        let context = NOBSModelContext(
            userName: nil,
            hasCalendarAccess: false,
            agendaSummary: nil,
            tankAvailable: false,
            shouldUseTomorrowFraming: false
        )

        let outcome = responder.respond(to: "Help me think through my afternoon", context: context)

        XCTAssertEqual(outcome.response.route, .localRules)
        XCTAssertTrue(outcome.response.text.contains("Tank is unavailable"))
        XCTAssertEqual(outcome.response.privacyReceipt.processed, "Local rules on this iPhone")
    }

    func testFocusResetMutation() {
        let context = NOBSModelContext(
            userName: nil,
            hasCalendarAccess: false,
            agendaSummary: nil,
            tankAvailable: false,
            shouldUseTomorrowFraming: false
        )

        let outcome = responder.respond(to: "reset focus", context: context)

        XCTAssertEqual(outcome.profileMutations, [.resetFocusPolicies])
        XCTAssertTrue(outcome.response.text.contains("Focus behavior reset"))
    }
}

final class NOBSModelContractTests: XCTestCase {
    func testResponseMapsToConversationEntry() {
        let response = NOBSModelResponse(
            text: "Hello",
            route: .onDeviceFoundationModel,
            routeReason: "On-device model answered",
            fallbackFrom: nil,
            privacyReceipt: NOBSModelPrivacyReceipt(
                used: ["text entered in this conversation"],
                processed: "On-device AI on this iPhone",
                shared: [],
                changed: [],
                dataCategories: ["conversation text"]
            )
        )

        let entry = response.conversationEntry()

        XCTAssertEqual(entry.route, .onDeviceAI)
        XCTAssertEqual(entry.text, "Hello")
        XCTAssertEqual(entry.receipt?.processed, "On-device AI on this iPhone")
        XCTAssertTrue(entry.receipt?.changed.contains("On-device model answered") == true)
    }

    func testFallbackMetadataAppearsInReceipt() {
        let response = NOBSModelResponse(
            text: "Rules answer",
            route: .localRules,
            routeReason: "Foundation Models unavailable",
            fallbackFrom: .onDeviceFoundationModel,
            privacyReceipt: NOBSModelPrivacyReceipt(
                used: ["text entered in this conversation"],
                processed: "Local rules on this iPhone",
                shared: [],
                changed: [],
                dataCategories: ["conversation text"]
            )
        )

        let receipt = response.privacyReceipt.appReceipt(
            routeReason: response.routeReason,
            fallbackFrom: response.fallbackFrom
        )

        XCTAssertTrue(receipt.changed.contains("Fallback from On-device AI"))
        XCTAssertTrue(receipt.changed.contains("Foundation Models unavailable"))
    }
}
