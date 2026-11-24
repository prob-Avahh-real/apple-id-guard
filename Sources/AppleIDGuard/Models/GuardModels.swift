import Foundation

public enum PurchaseSource: String, Codable, CaseIterable, Sendable {
    case receiptEmail = "receipt_email"
    case mailShare = "mail_share"
    case manual = "manual"
    case shortcut = "shortcut"
    case backgroundScan = "background_scan"

    public var label: String {
        switch self {
        case .receiptEmail: return "邮件收据"
        case .mailShare: return "Mail 分享"
        case .manual: return "手动录入"
        case .shortcut: return "快捷指令"
        case .backgroundScan: return "后台巡检"
        }
    }
}

public enum PurchaseStatus: String, Codable, Sendable {
    case pendingReview = "pending"
    case confirmedLegit = "legit"
    case confirmedFraud = "fraud"
}

public struct PurchaseEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var merchant: String
    public var amount: Decimal
    public var currency: String
    public var purchasedAt: Date
    public var source: PurchaseSource
    public var rawText: String?
    public var status: PurchaseStatus
    public var riskScore: Int?

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Decimal,
        currency: String = "CNY",
        purchasedAt: Date = Date(),
        source: PurchaseSource,
        rawText: String? = nil,
        status: PurchaseStatus = .pendingReview,
        riskScore: Int? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.purchasedAt = purchasedAt
        self.source = source
        self.rawText = rawText
        self.status = status
        self.riskScore = riskScore
    }

    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: currency == "CNY" ? "zh_CN" : "en_US")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currency)"
    }
}

public enum RiskLevel: String, Codable, Sendable {
    case safe
    case caution
    case critical

    public var label: String {
        switch self {
        case .safe: return "安全"
        case .caution: return "注意"
        case .critical: return "高危"
        }
    }

    public static func from(score: Int) -> RiskLevel {
        switch score {
        case ..<35: return .safe
        case 35..<70: return .caution
        default: return .critical
        }
    }
}

public struct RiskSignal: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let code: String
    public let message: String
    public let weight: Int

    public init(id: UUID = UUID(), code: String, message: String, weight: Int) {
        self.id = id
        self.code = code
        self.message = message
        self.weight = weight
    }
}

public struct RiskAssessment: Codable, Equatable, Sendable {
    public let score: Int
    public let level: RiskLevel
    public let signals: [RiskSignal]
    public let recommendedActions: [String]

    public init(score: Int, signals: [RiskSignal], recommendedActions: [String]) {
        self.score = min(100, max(0, score))
        self.level = RiskLevel.from(score: self.score)
        self.signals = signals
        self.recommendedActions = recommendedActions
    }
}

public struct SpendingBaseline: Codable, Equatable, Sendable {
    public var averageAmount: Decimal
    public var maxAmount: Decimal
    public var typicalHourBuckets: [Int: Int]
    public var knownMerchants: Set<String>
    public var sampleCount: Int

    public init(
        averageAmount: Decimal = 0,
        maxAmount: Decimal = 0,
        typicalHourBuckets: [Int: Int] = [:],
        knownMerchants: Set<String> = [],
        sampleCount: Int = 0
    ) {
        self.averageAmount = averageAmount
        self.maxAmount = maxAmount
        self.typicalHourBuckets = typicalHourBuckets
        self.knownMerchants = knownMerchants
        self.sampleCount = sampleCount
    }
}

public struct GuardSettings: Codable, Equatable, Sendable {
    public var dailySpendLimit: Decimal
    public var singlePurchaseLimit: Decimal
    public var nightQuietStart: Int
    public var nightQuietEnd: Int
    public var backgroundRefreshEnabled: Bool
    public var notifyOnCaution: Bool
    public var aiEnhancedAnalysis: Bool

    public init(
        dailySpendLimit: Decimal = 200,
        singlePurchaseLimit: Decimal = 98,
        nightQuietStart: Int = 1,
        nightQuietEnd: Int = 6,
        backgroundRefreshEnabled: Bool = true,
        notifyOnCaution: Bool = true,
        aiEnhancedAnalysis: Bool = true
    ) {
        self.dailySpendLimit = dailySpendLimit
        self.singlePurchaseLimit = singlePurchaseLimit
        self.nightQuietStart = nightQuietStart
        self.nightQuietEnd = nightQuietEnd
        self.backgroundRefreshEnabled = backgroundRefreshEnabled
        self.notifyOnCaution = notifyOnCaution
        self.aiEnhancedAnalysis = aiEnhancedAnalysis
    }
}

public struct GuardSnapshot: Codable, Equatable, Sendable {
    public var shieldActive: Bool
    public var pendingAlerts: Int
    public var todaySpend: Decimal
    public var lastScanAt: Date?

    public init(
        shieldActive: Bool = true,
        pendingAlerts: Int = 0,
        todaySpend: Decimal = 0,
        lastScanAt: Date? = nil
    ) {
        self.shieldActive = shieldActive
        self.pendingAlerts = pendingAlerts
        self.todaySpend = todaySpend
        self.lastScanAt = lastScanAt
    }
}
