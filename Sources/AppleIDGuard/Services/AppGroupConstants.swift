import Foundation

public enum AppGroupConstants {
    public static let identifier = "group.com.skat.appleidguard"

    public static var sharedDefaults: UserDefaults {
        if let suite = UserDefaults(suiteName: identifier) {
            migrateFromStandardIfNeeded(to: suite)
            return suite
        }
        return .standard
    }

    private static let migrationKey = "apple_id_guard.migrated_to_app_group"

    private static func migrateFromStandardIfNeeded(to groupDefaults: UserDefaults) {
        guard !groupDefaults.bool(forKey: migrationKey) else { return }

        let standard = UserDefaults.standard
        let keys = [
            "apple_id_guard.events",
            "apple_id_guard.baseline",
            "apple_id_guard.settings",
            "apple_id_guard.snapshot",
        ]

        for key in keys {
            if let value = standard.object(forKey: key) {
                groupDefaults.set(value, forKey: key)
            }
        }

        groupDefaults.set(true, forKey: migrationKey)
    }
}
