import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public struct RiskEngineInput: Sendable {
    public let event: PurchaseEvent
    public let baseline: SpendingBaseline
    public let settings: GuardSettings
    public let recentEvents: [PurchaseEvent]
    public let todaySpend: Decimal

    public init(
        event: PurchaseEvent,
        baseline: SpendingBaseline,
        settings: GuardSettings,
        recentEvents: [PurchaseEvent],
        todaySpend: Decimal
    ) {
        self.event = event
        self.baseline = baseline
        self.settings = settings
        self.recentEvents = recentEvents
        self.todaySpend = todaySpend
    }
}

public enum RiskEngine {
    public static func assess(_ input: RiskEngineInput) -> RiskAssessment {
        var signals: [RiskSignal] = []
        let event = input.event
        let hour = Calendar.current.component(.hour, from: event.purchasedAt)

        if event.amount > input.settings.singlePurchaseLimit {
            signals.append(RiskSignal(
                code: "single_limit",
                message: "单笔 \(event.formattedAmount) 超过设定上限 \(input.settings.singlePurchaseLimit)",
                weight: 35
            ))
        }

        if input.todaySpend + event.amount > input.settings.dailySpendLimit {
            signals.append(RiskSignal(
                code: "daily_limit",
                message: "今日累计消费将超出日限额",
                weight: 30
            ))
        }

        if isNightHour(hour, settings: input.settings) {
            signals.append(RiskSignal(
                code: "night_purchase",
                message: "深夜时段出现购买（\(hour):00）",
                weight: 25
            ))
        }

        if input.baseline.sampleCount >= 3,
           input.baseline.averageAmount > 0,
           event.amount > input.baseline.averageAmount * 3 {
            signals.append(RiskSignal(
                code: "amount_spike",
                message: "金额约为历史均值的 3 倍以上",
                weight: 28
            ))
        }

        let merchantKey = BaselineLearner.normalizeMerchant(event.merchant)
        if input.baseline.sampleCount >= 2, !input.baseline.knownMerchants.contains(merchantKey) {
            signals.append(RiskSignal(
                code: "unknown_merchant",
                message: "首次出现的商户/应用：\(event.merchant)",
                weight: 20
            ))
        }

        if !BaselineLearner.isTypicalHour(hour, baseline: input.baseline) {
            signals.append(RiskSignal(
                code: "unusual_hour",
                message: "购买时间与你的常用时段不符",
                weight: 15
            ))
        }

        let burstCount = input.recentEvents.filter {
            event.purchasedAt.timeIntervalSince($0.purchasedAt) >= -600
        }.count
        if burstCount >= 2 {
            signals.append(RiskSignal(
                code: "burst",
                message: "10 分钟内出现多笔购买",
                weight: 22
            ))
        }

        if input.settings.aiEnhancedAnalysis, let raw = event.rawText {
            signals.append(contentsOf: semanticSignals(from: raw))
        }

        let score = min(100, signals.map(\.weight).reduce(0, +))
        let actions = recommendedActions(for: RiskLevel.from(score: score))

        return RiskAssessment(score: score, signals: signals, recommendedActions: actions)
    }

    private static func isNightHour(_ hour: Int, settings: GuardSettings) -> Bool {
        if settings.nightQuietStart <= settings.nightQuietEnd {
            return hour >= settings.nightQuietStart && hour < settings.nightQuietEnd
        }
        return hour >= settings.nightQuietStart || hour < settings.nightQuietEnd
    }

    private static func semanticSignals(from text: String) -> [RiskSignal] {
        var signals: [RiskSignal] = []
        let lowered = text.lowercased()

        let fraudKeywords = [
            "subscription renewal", "订阅续期", "in-app purchase", "应用内购买",
            "family sharing", "家人共享", "gift card", "礼品卡",
        ]
        for keyword in fraudKeywords where lowered.contains(keyword.lowercased()) {
            signals.append(RiskSignal(
                code: "keyword_\(keyword.prefix(8))",
                message: "收据含敏感关键词：\(keyword)",
                weight: 8
            ))
        }

        #if canImport(NaturalLanguage)
        if #available(iOS 17.0, macOS 14.0, *) {
            let tagger = NLTagger(tagSchemes: [.sentimentScore])
            tagger.string = text
            let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let raw = tag?.rawValue, let score = Double(raw), score < -0.4 {
                signals.append(RiskSignal(
                    code: "nlp_anomaly",
                    message: "AI 文本分析标记为异常语气/结构",
                    weight: 12
                ))
            }
        }
        #endif

        return signals
    }

    private static func recommendedActions(for level: RiskLevel) -> [String] {
        switch level {
        case .safe:
            return ["继续监控即可"]
        case .caution:
            return [
                "核对 Apple ID 最近购买记录",
                "确认是否为家人共享或订阅自动续费",
            ]
        case .critical:
            return [
                "立即在 设置 → Apple ID → 媒体与购买项目 查看订单",
                "修改 Apple ID 密码并开启双重认证",
                "联系 Apple 支持报告可疑交易",
                "在钱包中暂时移除付款方式",
            ]
        }
    }
}
