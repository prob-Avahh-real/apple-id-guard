import Foundation

public struct IngestResult: Equatable, Sendable {
    public let event: PurchaseEvent
    public let assessment: RiskAssessment

    public init(event: PurchaseEvent, assessment: RiskAssessment) {
        self.event = event
        self.assessment = assessment
    }
}

public enum IngestError: Error, Equatable, Sendable {
    case parseFailed
}

public enum ReceiptIngestService {
    public static func ingest(
        text: String,
        source: PurchaseSource,
        store: PurchaseStore = .shared
    ) -> Result<IngestResult, IngestError> {
        let normalized = SharePayloadExtractor.normalizedReceiptText(from: text)
        guard let parsed = ReceiptParser.parse(normalized) else {
            return .failure(.parseFailed)
        }

        let settings = store.loadSettings()
        let baseline = store.loadBaseline()
        let existingEvents = store.loadEvents()

        var event = PurchaseEvent(
            merchant: parsed.merchant,
            amount: parsed.amount,
            currency: parsed.currency,
            purchasedAt: parsed.purchasedAt ?? Date(),
            source: source,
            rawText: normalized
        )

        let assessment = RiskEngine.assess(
            RiskEngineInput(
                event: event,
                baseline: baseline,
                settings: settings,
                recentEvents: existingEvents,
                todaySpend: store.todaySpend(reference: event.purchasedAt)
            )
        )
        event.riskScore = assessment.score

        var all = existingEvents
        all.insert(event, at: 0)
        store.saveEvents(all)

        var snapshot = store.loadSnapshot()
        snapshot.pendingAlerts = store.pendingAlertsCount()
        snapshot.todaySpend = store.todaySpend()
        store.saveSnapshot(snapshot)

        return .success(IngestResult(event: event, assessment: assessment))
    }
}
