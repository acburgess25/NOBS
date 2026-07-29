import XCTest
@testable import NOBS

final class ModelRouterTests: XCTestCase {
    private let router = ModelRouter()

    func testTankPreferredWhenTankAvailable() {
        let decision = router.route(
            .chat("What's on my calendar?"),
            context: baseContext(tankAvailable: true)
        )
        XCTAssertEqual(decision.route, ProcessingRoute.tank)
        XCTAssertEqual(decision.reason, .preferredPrivateCompute)
    }

    func testLocalFirstStaysLocalWithoutTankWhenPreferenceSet() {
        let decision = router.route(
            .chat("hello"),
            context: baseContext(
                tankAvailable: false,
                preferences: RoutingPreferences(tankOfflineBehavior: .localOnly)
            )
        )
        XCTAssertEqual(decision.route, ProcessingRoute.local)
        XCTAssertEqual(decision.reason, .tankOfflinePreference)
    }

    func testPromptWhenTankOfflineAndAskEachTime() {
        let decision = router.route(
            .chat("hello"),
            context: baseContext(tankAvailable: false)
        )
        XCTAssertTrue(decision.needsUserPrompt)
        XCTAssertNotNil(decision.promptMessage)
    }

    func testPCCRouteWhenConfiguredAndEscalationRequested() {
        let decision = router.route(
            .chat("think harder about my schedule"),
            context: baseContext(
                tankAvailable: false,
                pccAvailable: true,
                pccRoutingEnabled: true,
                developerEntitled: true,
                preferences: RoutingPreferences(tankOfflineBehavior: .useAppleCloud)
            )
        )
        XCTAssertEqual(decision.route, ProcessingRoute.pcc)
    }

    func testPCCFallsBackWhenQuotaReached() {
        let decision = router.route(
            .chat("think harder"),
            context: baseContext(
                tankAvailable: false,
                pccAvailable: true,
                pccRoutingEnabled: true,
                pccQuotaLimitReached: true,
                developerEntitled: true,
                preferences: RoutingPreferences(tankOfflineBehavior: .useAppleCloud)
            )
        )
        XCTAssertEqual(decision.route, ProcessingRoute.local)
    }

    func testCloudRouteRequiresSubscriptionAndPolicy() {
        let decision = router.route(
            .chat("analyze this long document " + String(repeating: "word ", count: 800)),
            context: baseContext(
                tankAvailable: false,
                hasNOBScloud: true,
                profile: UserProfile(privacyComfort: .cloudOk),
                preferences: RoutingPreferences(tankOfflineBehavior: .useNOBScloud)
            )
        )
        // Without PCC available/enabled, subscription still selects the cloud route
        // so AppModel can explain that Apple Cloud capacity is unavailable.
        XCTAssertEqual(decision.route, ProcessingRoute.cloud)
        XCTAssertEqual(decision.reason, .paidFallback)
    }

    func testNOBScloudUsesAppleCloudWhenPCCAvailable() {
        let decision = router.route(
            .chat("analyze this long document " + String(repeating: "word ", count: 800)),
            context: baseContext(
                tankAvailable: false,
                pccAvailable: true,
                pccRoutingEnabled: true,
                developerEntitled: true,
                hasNOBScloud: true,
                profile: UserProfile(privacyComfort: .cloudOk),
                preferences: RoutingPreferences(tankOfflineBehavior: .useNOBScloud)
            )
        )
        XCTAssertEqual(decision.route, ProcessingRoute.pcc)
        XCTAssertEqual(decision.reason, .paidFallback)
        XCTAssertTrue(decision.receipt.processed.contains("NOBScloud"))
    }

    func testDoesNotClaimPCCWhenUnavailable() {
        let decision = router.route(
            .chat("think harder"),
            context: baseContext(
                tankAvailable: false,
                pccAvailable: false,
                pccRoutingEnabled: true,
                developerEntitled: true,
                preferences: RoutingPreferences(tankOfflineBehavior: .useAppleCloud)
            )
        )
        XCTAssertNotEqual(decision.route, ProcessingRoute.pcc)
    }

    private func baseContext(
        tankAvailable: Bool = false,
        localFMAvailable: Bool = false,
        pccAvailable: Bool = false,
        pccRoutingEnabled: Bool = false,
        pccQuotaLimitReached: Bool = false,
        developerEntitled: Bool = false,
        hasNOBScloud: Bool = false,
        profile: UserProfile = UserProfile(),
        preferences: RoutingPreferences = RoutingPreferences()
    ) -> RoutingContext {
        RoutingContext(
            tankAvailable: tankAvailable,
            localFMAvailable: localFMAvailable,
            pccAvailable: pccAvailable,
            pccRoutingEnabled: pccRoutingEnabled,
            pccQuotaLimitReached: pccQuotaLimitReached,
            developerEntitled: developerEntitled,
            hasNOBScloud: hasNOBScloud,
            profile: profile,
            preferences: preferences
        )
    }
}

/// Fixture catalog for manual Evaluations / QA (Issue 31).
enum ModelRouterEvaluationFixtures {
    static let privacyComfortMatrix: [(PrivacyComfort, ProcessingRoute)] = [
        (.localFirst, .local),
        (.tankPreferred, .tank),
        (.cloudOk, .cloud),
    ]
}
