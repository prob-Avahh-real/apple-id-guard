import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

public enum NotificationService {
    public static func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func notifyRisk(event: PurchaseEvent, assessment: RiskAssessment, settings: GuardSettings) async {
        guard shouldNotify(level: assessment.level, settings: settings) else { return }

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = assessment.level == .critical ? "⚠️ 账户盾：可疑 Apple 购买" : "账户盾：请核对购买"
        content.body = "\(event.merchant) · \(event.formattedAmount) · 风险 \(assessment.score)"
        content.sound = assessment.level == .critical ? .defaultCritical : .default
        content.categoryIdentifier = "PURCHASE_ALERT"
        content.userInfo = [
            "purchaseId": event.id.uuidString,
            "riskScore": assessment.score,
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "purchase-\(event.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    private static func shouldNotify(level: RiskLevel, settings: GuardSettings) -> Bool {
        switch level {
        case .safe: return false
        case .caution: return settings.notifyOnCaution
        case .critical: return true
        }
    }
}
