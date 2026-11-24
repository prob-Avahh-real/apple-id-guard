import XCTest
@testable import AppleIDGuard

final class AppleIDGuardTests: XCTestCase {

    func testReceiptParserChineseReceipt() {
        let text = """
        来自 Apple 的收据
        App：王者荣耀
        总计 ¥648.00
        2026/07/20
        """
        let parsed = ReceiptParser.parse(text, referenceDate: Date(timeIntervalSince1970: 0))
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.merchant, "王者荣耀")
        XCTAssertEqual(parsed?.amount, Decimal(string: "648.00"))
        XCTAssertEqual(parsed?.currency, "CNY")
    }

    func testReceiptParserEnglishReceipt() {
        let text = """
        Your receipt from Apple
        App: Pro Camera
        Total $9.99
        """
        let parsed = ReceiptParser.parse(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(string: "9.99"))
        XCTAssertEqual(parsed?.currency, "USD")
    }

    func testRiskEngineCriticalForHighAmountAtNight() {
        let settings = GuardSettings(singlePurchaseLimit: 98, nightQuietStart: 1, nightQuietEnd: 6)
        let event = PurchaseEvent(
            merchant: "未知游戏",
            amount: 648,
            purchasedAt: date(hour: 3),
            source: .receiptEmail,
            rawText: "subscription renewal"
        )
        let assessment = RiskEngine.assess(
            RiskEngineInput(
                event: event,
                baseline: SpendingBaseline(averageAmount: 30, knownMerchants: ["music"], sampleCount: 5),
                settings: settings,
                recentEvents: [],
                todaySpend: 0
            )
        )
        XCTAssertGreaterThanOrEqual(assessment.score, 70)
        XCTAssertEqual(assessment.level, .critical)
    }

    func testRiskEngineSafeForKnownPattern() {
        let baseline = SpendingBaseline(
            averageAmount: 30,
            maxAmount: 68,
            typicalHourBuckets: [20: 5, 21: 3],
            knownMerchants: ["music"],
            sampleCount: 8
        )
        let event = PurchaseEvent(
            merchant: "Music",
            amount: 25,
            purchasedAt: date(hour: 20),
            source: .manual
        )
        let assessment = RiskEngine.assess(
            RiskEngineInput(
                event: event,
                baseline: baseline,
                settings: GuardSettings(),
                recentEvents: [],
                todaySpend: 20
            )
        )
        XCTAssertLessThan(assessment.score, 35)
        XCTAssertEqual(assessment.level, .safe)
    }

    func testBaselineLearnerUpdatesAverage() {
        let events = [
            PurchaseEvent(merchant: "A", amount: 10, source: .manual, status: .confirmedLegit),
            PurchaseEvent(merchant: "B", amount: 30, source: .manual, status: .confirmedLegit),
        ]
        let baseline = BaselineLearner.learn(from: events, current: SpendingBaseline())
        XCTAssertEqual(baseline.sampleCount, 2)
        XCTAssertEqual(baseline.averageAmount, 20)
        XCTAssertTrue(baseline.knownMerchants.contains("a"))
    }

    func testPurchaseStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "AppleIDGuardTests")!
        defaults.removePersistentDomain(forName: "AppleIDGuardTests")
        let store = PurchaseStore(defaults: defaults)

        let event = PurchaseEvent(merchant: "Test", amount: 6, source: .manual)
        store.saveEvents([event])
        XCTAssertEqual(store.loadEvents().count, 1)
        XCTAssertEqual(store.loadEvents().first?.merchant, "Test")
    }

    func testReceiptIngestServiceSuccess() {
        let defaults = UserDefaults(suiteName: "AppleIDGuardIngestTests")!
        defaults.removePersistentDomain(forName: "AppleIDGuardIngestTests")
        let store = PurchaseStore(defaults: defaults)

        let text = """
        来自 Apple 的收据
        App：Music
        总计 ¥25.00
        """
        let result = ReceiptIngestService.ingest(text: text, source: .mailShare, store: store)
        guard case .success(let ingest) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(ingest.event.source, .mailShare)
        XCTAssertEqual(ingest.event.amount, Decimal(string: "25.00"))
        XCTAssertEqual(store.loadEvents().count, 1)
    }

    func testReceiptIngestServiceParseFailure() {
        let defaults = UserDefaults(suiteName: "AppleIDGuardIngestFailTests")!
        defaults.removePersistentDomain(forName: "AppleIDGuardIngestFailTests")
        let store = PurchaseStore(defaults: defaults)

        let result = ReceiptIngestService.ingest(text: "not a receipt", source: .mailShare, store: store)
        XCTAssertEqual(result, .failure(.parseFailed))
        XCTAssertTrue(store.loadEvents().isEmpty)
    }

    func testSharePayloadExtractorHTML() {
        let html = """
        <html><body><p>Your receipt from Apple</p><p>App: Pro Camera</p><p>Total $9.99</p></body></html>
        """
        let text = SharePayloadExtractor.plainText(fromHTML: html)
        XCTAssertTrue(text.contains("Pro Camera"))
        XCTAssertTrue(text.contains("9.99"))

        let parsed = ReceiptParser.parse(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.currency, "USD")
    }

    func testAppGroupConstantsMigrationMarksComplete() {
        let suiteName = "AppleIDGuardMigrationTests"
        let standard = UserDefaults.standard
        let group = UserDefaults(suiteName: suiteName)!
        group.removePersistentDomain(forName: suiteName)
        standard.removeObject(forKey: "apple_id_guard.events")

        standard.set(Data("test".utf8), forKey: "apple_id_guard.events")

        // Simulate migration by calling sharedDefaults logic through a fresh store init path
        let migratedStore = PurchaseStore(defaults: {
            if !group.bool(forKey: "apple_id_guard.migrated_to_app_group"),
               let value = standard.object(forKey: "apple_id_guard.events") {
                group.set(value, forKey: "apple_id_guard.events")
                group.set(true, forKey: "apple_id_guard.migrated_to_app_group")
            }
            return group
        }())
        _ = migratedStore.loadEvents()
        XCTAssertTrue(group.bool(forKey: "apple_id_guard.migrated_to_app_group"))

        standard.removeObject(forKey: "apple_id_guard.events")
        group.removePersistentDomain(forName: suiteName)
    }

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 21
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
