import Combine
import Foundation

@MainActor
public final class GuardViewModel: ObservableObject, BackgroundScanHandler {
    @Published public private(set) var events: [PurchaseEvent] = []
    @Published public private(set) var settings: GuardSettings
    @Published public private(set) var snapshot: GuardSnapshot
    @Published public var receiptDraft: String = ""
    @Published public var lastError: String?

    private let store: PurchaseStore
    private var baseline: SpendingBaseline

    public init(store: PurchaseStore = .shared) {
        self.store = store
        self.settings = store.loadSettings()
        self.baseline = store.loadBaseline()
        self.snapshot = store.loadSnapshot()
        reload()
    }

    public func reload() {
        events = store.loadEvents().sorted { $0.purchasedAt > $1.purchasedAt }
        settings = store.loadSettings()
        baseline = store.loadBaseline()
        refreshSnapshot()
    }

    public func importReceiptText(_ text: String, source: PurchaseSource = .receiptEmail) {
        switch ReceiptIngestService.ingest(text: text, source: source, store: store) {
        case .success(let result):
            lastError = nil
            reload()
            Task {
                await NotificationService.notifyRisk(
                    event: result.event,
                    assessment: result.assessment,
                    settings: settings
                )
            }
            receiptDraft = ""
        case .failure:
            lastError = "无法从文本解析 Apple 收据，请检查内容或手动录入。"
        }
    }

    public func addManualPurchase(merchant: String, amount: Decimal, currency: String = "CNY") {
        var event = PurchaseEvent(
            merchant: merchant,
            amount: amount,
            currency: currency,
            source: .manual
        )
        let assessment = assess(event)
        event.riskScore = assessment.score
        persist(event: event, assessment: assessment)
    }

    public func confirmLegitimate(_ event: PurchaseEvent) {
        updateStatus(for: event.id, status: .confirmedLegit)
        baseline = BaselineLearner.learn(from: store.loadEvents(), current: baseline)
        store.saveBaseline(baseline)
        refreshSnapshot()
    }

    public func reportFraud(_ event: PurchaseEvent) {
        updateStatus(for: event.id, status: .confirmedFraud)
        refreshSnapshot()
    }

    public func updateSettings(_ settings: GuardSettings) {
        self.settings = settings
        store.saveSettings(settings)
        BackgroundScheduler.scheduleNextRefresh(settings: settings)
    }

    public func performBackgroundScan() async {
        var snapshot = store.loadSnapshot()
        snapshot.lastScanAt = Date()
        snapshot.pendingAlerts = store.pendingAlertsCount()
        snapshot.todaySpend = store.todaySpend()
        store.saveSnapshot(snapshot)
        self.snapshot = snapshot

        let pending = store.loadEvents().filter { $0.status == .pendingReview && ($0.riskScore ?? 0) >= 70 }
        for event in pending {
            let assessment = assess(event)
            await NotificationService.notifyRisk(event: event, assessment: assessment, settings: settings)
        }
    }

    public func assessment(for event: PurchaseEvent) -> RiskAssessment {
        assess(event)
    }

    public var flaggedEvents: [PurchaseEvent] {
        events.filter { ($0.riskScore ?? 0) >= 35 && $0.status == .pendingReview }
    }

    private func assess(_ event: PurchaseEvent) -> RiskAssessment {
        RiskEngine.assess(
            RiskEngineInput(
                event: event,
                baseline: baseline,
                settings: settings,
                recentEvents: events,
                todaySpend: store.todaySpend(reference: event.purchasedAt)
            )
        )
    }

    private func persist(event: PurchaseEvent, assessment: RiskAssessment) {
        var all = store.loadEvents()
        all.insert(event, at: 0)
        store.saveEvents(all)
        events = all.sorted { $0.purchasedAt > $1.purchasedAt }
        refreshSnapshot()

        Task {
            await NotificationService.notifyRisk(event: event, assessment: assessment, settings: settings)
        }
    }

    private func updateStatus(for id: UUID, status: PurchaseStatus) {
        var all = store.loadEvents()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].status = status
        store.saveEvents(all)
        events = all.sorted { $0.purchasedAt > $1.purchasedAt }
    }

    private func refreshSnapshot() {
        let snap = GuardSnapshot(
            shieldActive: true,
            pendingAlerts: store.pendingAlertsCount(),
            todaySpend: store.todaySpend(),
            lastScanAt: snapshot.lastScanAt
        )
        store.saveSnapshot(snap)
        snapshot = snap
    }
}
