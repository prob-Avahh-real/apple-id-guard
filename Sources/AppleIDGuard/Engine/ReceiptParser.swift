import Foundation

public struct ReceiptParseResult: Equatable, Sendable {
    public let merchant: String
    public let amount: Decimal
    public let currency: String
    public let purchasedAt: Date?

    public init(merchant: String, amount: Decimal, currency: String, purchasedAt: Date?) {
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.purchasedAt = purchasedAt
    }
}

public enum ReceiptParser {
    private static let amountPatterns: [String] = [
        #"(?:总计|Total|TOTAL|金额|Amount)[^\d]{0,20}([¥$€£]\s?[\d,]+(?:\.\d{1,2})?)"#,
        #"([¥$€£]\s?[\d,]+(?:\.\d{1,2})?)"#,
        #"([\d,]+(?:\.\d{1,2})?)\s?(?:元|CNY|USD)"#,
    ]

    private static let merchantPatterns: [String] = [
        #"(?:App|应用|软件|订阅|Subscription)[：:\s]+(.{2,60})"#,
        #"(?:来自 Apple 的收据|Your receipt from Apple)[^\n]*\n[^\n]*?(.{2,60})"#,
        #"(?:账单摘要|Invoice)[^\n]*\n[^\n]*?(.{2,60})"#,
    ]

    public static func parse(_ text: String, referenceDate: Date = Date()) -> ReceiptParseResult? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        guard let amountMatch = firstMatch(in: normalized, patterns: amountPatterns),
              let parsedAmount = parseAmount(amountMatch) else {
            return nil
        }

        let merchant = firstMatch(in: normalized, patterns: merchantPatterns)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            ?? inferMerchant(from: normalized)

        let purchasedAt = parseDate(from: normalized, referenceDate: referenceDate)

        return ReceiptParseResult(
            merchant: merchant,
            amount: parsedAmount.amount,
            currency: parsedAmount.currency,
            purchasedAt: purchasedAt
        )
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: text) else {
                continue
            }
            let value = String(text[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func parseAmount(_ raw: String) -> (amount: Decimal, currency: String)? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var currency = "CNY"
        var numeric = cleaned

        if cleaned.hasPrefix("¥") || cleaned.contains("元") {
            currency = "CNY"
            numeric = cleaned.replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: "元", with: "")
        } else if cleaned.hasPrefix("$") {
            currency = "USD"
            numeric = cleaned.replacingOccurrences(of: "$", with: "")
        } else if cleaned.hasPrefix("€") {
            currency = "EUR"
            numeric = cleaned.replacingOccurrences(of: "€", with: "")
        } else if cleaned.hasPrefix("£") {
            currency = "GBP"
            numeric = cleaned.replacingOccurrences(of: "£", with: "")
        }

        guard let decimal = Decimal(string: numeric.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return (decimal, currency)
    }

    private static func inferMerchant(from text: String) -> String {
        let lines = text.split(separator: "\n").map(String.init)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 2, trimmed.count <= 40, !trimmed.contains("Apple ID") {
                return trimmed
            }
        }
        return "Apple 购买"
    }

    private static func parseDate(from text: String, referenceDate: Date) -> Date? {
        let patterns = [
            #"(\d{4}[/-]\d{1,2}[/-]\d{1,2})"#,
            #"(\d{1,2}[/-]\d{1,2}[/-]\d{4})"#,
        ]
        let formatters = [
            "yyyy/MM/dd", "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
        ]

        guard let raw = firstMatch(in: text, patterns: patterns) else { return nil }

        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return referenceDate
    }
}
