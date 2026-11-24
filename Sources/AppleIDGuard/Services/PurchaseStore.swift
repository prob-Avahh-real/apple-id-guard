import Foundation

public final class PurchaseStore: @unchecked Sendable {
    public static let shared = PurchaseStore()

    private let defaults: UserDefaults
    private let eventsKey = "apple_id_guard.events"
    private let baselineKey = "apple_id_guard.baseline"
    private let settingsKey = "apple_id_guard.settings"
    private let snapshotKey = "apple_id_guard.snapshot"
    private let queue = DispatchQueue(label: "com.skat.appleidguard.store")

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroupConstants.sharedDefaults
    }

    public func loadEvents() -> [PurchaseEvent] {
        queue.sync {
            decode([PurchaseEvent].self, forKey: eventsKey) ?? []
        }
    }

    public func saveEvents(_ events: [PurchaseEvent]) {
        queue.sync {
            encode(events, forKey: eventsKey)
        }
    }

    public func loadBaseline() -> SpendingBaseline {
        queue.sync {
            decode(SpendingBaseline.self, forKey: baselineKey) ?? SpendingBaseline()
        }
    }

    public func saveBaseline(_ baseline: SpendingBaseline) {
        queue.sync {
            encode(baseline, forKey: baselineKey)
        }
    }

    public func loadSettings() -> GuardSettings {
        queue.sync {
            decode(GuardSettings.self, forKey: settingsKey) ?? GuardSettings()
        }
    }

    public func saveSettings(_ settings: GuardSettings) {
        queue.sync {
            encode(settings, forKey: settingsKey)
        }
    }

    public func loadSnapshot() -> GuardSnapshot {
        queue.sync {
            decode(GuardSnapshot.self, forKey: snapshotKey) ?? GuardSnapshot()
        }
    }

    public func saveSnapshot(_ snapshot: GuardSnapshot) {
        queue.sync {
            encode(snapshot, forKey: snapshotKey)
        }
    }

    public func todaySpend(reference: Date = Date()) -> Decimal {
        let calendar = Calendar.current
        return loadEvents()
            .filter { calendar.isDate($0.purchasedAt, inSameDayAs: reference) }
            .map(\.amount)
            .reduce(0, +)
    }

    public func pendingAlertsCount() -> Int {
        loadEvents().filter { $0.status == .pendingReview && ($0.riskScore ?? 0) >= 35 }.count
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
