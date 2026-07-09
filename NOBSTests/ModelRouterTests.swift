import XCTest
@testable import NOBS

final class ModelRouterTests: XCTestCase {
    private let router = ModelRouter()

    func testTankPreferredWhenTankAvailable() {
        let decision = router.route(
            .chat("What's on my calendar?"),
            context: baseContext(tankAvailable: true)
        )
        XCTAssertEqual(decision.route, .tank)
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
        XCTAssertEqual(decision.route, .local)
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
        XCTAssertEqual(decision.route, .pcc)
    }

    func testPCCFallsBackWhenQuotaReached() {
        let decision = router.route(
            .chat("think harder"),
            context: baseContext(
                tankAvailable: false,
                pccAvailable: true,
                pccRoutingEnabled: true,
                developerEntitled: true,
                pccQuotaLimitReached: true,
                preferences: RoutingPreferences(tankOfflineBehavior: .useAppleCloud)
            )
        )
        XCTAssertEqual(decision.route, .local)
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
        XCTAssertEqual(decision.route, .cloud)
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
        XCTAssertNotEqual(decision.route, .pcc)
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
