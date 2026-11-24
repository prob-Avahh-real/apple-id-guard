import Foundation

public enum BaselineLearner {
    public static func learn(from events: [PurchaseEvent], current: SpendingBaseline) -> SpendingBaseline {
        let legit = events.filter { $0.status == .confirmedLegit }
        guard !legit.isEmpty else { return current }

        var baseline = current
        var total = Decimal(0)
        var hourBuckets = baseline.typicalHourBuckets
        var merchants = baseline.knownMerchants

        for event in legit {
            total += event.amount
            merchants.insert(normalizeMerchant(event.merchant))

            let hour = Calendar.current.component(.hour, from: event.purchasedAt)
            hourBuckets[hour, default: 0] += 1
        }

        let count = legit.count
        baseline.sampleCount = count
        baseline.averageAmount = total / Decimal(count)
        baseline.maxAmount = legit.map(\.amount).max() ?? baseline.maxAmount
        baseline.typicalHourBuckets = hourBuckets
        baseline.knownMerchants = merchants
        return baseline
    }

    public static func normalizeMerchant(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isTypicalHour(_ hour: Int, baseline: SpendingBaseline) -> Bool {
        guard baseline.sampleCount >= 3 else { return true }
        let total = baseline.typicalHourBuckets.values.reduce(0, +)
        guard total > 0 else { return true }
        let bucket = baseline.typicalHourBuckets[hour, default: 0]
        return Double(bucket) / Double(total) >= 0.05
    }
}
