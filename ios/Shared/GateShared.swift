import Foundation
import FamilyControls
import ManagedSettings

/// Shared by the app and the DeviceActivity monitor extension.
/// State lives in the App Group's UserDefaults so the extension can re-lock games at midnight
/// and when an earned play session ends, even if the app isn't running.
enum GateShared {
    static var appGroupID: String {
        var id = Bundle.main.bundleIdentifier ?? "math7"
        if Bundle.main.bundlePath.hasSuffix(".appex"), let dot = id.lastIndex(of: ".") {
            id = String(id[..<dot]) // extension IDs are <app id>.monitor
        }
        return "group." + id
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    static let shieldStore = ManagedSettingsStore.Name("math7.games")
    static let protectStore = ManagedSettingsStore.Name("math7.protect")

    enum Key {
        static let selection = "gate.selection"
        static let enabled = "gate.enabled"
        static let unlockDay = "gate.unlockDay"       // yyyy-mm-dd when games are unlocked for the rest of that day
        static let earnedUntil = "gate.earnedUntil"   // seconds since 1970 when an earned session ends
        static let parentLockDay = "gate.parentLockDay"
        static let solved = "gate.solvedToday"        // for the shield message
        static let goal = "gate.goal"
        static let progressDay = "gate.progressDay"
        static let bedtime = "gate.bedtimeMinutes"    // minutes after midnight; 0 = no bedtime lock
    }

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: Key.selection),
              let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return s
    }

    static func saveSelection(_ s: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: Key.selection) }
    }

    static var isEnabled: Bool { defaults.bool(forKey: Key.enabled) }

    /// True while games should be playable.
    static func shouldBeUnlocked(now: Date = Date()) -> Bool {
        guard isEnabled else { return true }
        let today = dayKey(now)
        if defaults.string(forKey: Key.parentLockDay) == today { return false }
        let bedtime = defaults.integer(forKey: Key.bedtime)
        if bedtime > 0 {
            let c = Calendar.current.dateComponents([.hour, .minute], from: now)
            if (c.hour ?? 0) * 60 + (c.minute ?? 0) >= bedtime { return false }
        }
        if defaults.string(forKey: Key.unlockDay) == today { return true }
        return defaults.double(forKey: Key.earnedUntil) > now.timeIntervalSince1970
    }

    static func lock() {
        let store = ManagedSettingsStore(named: shieldStore)
        guard isEnabled else { store.clearAllSettings(); return }
        let s = loadSelection()
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
        if s.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(s.categoryTokens)
            store.shield.webDomainCategories = .specific(s.categoryTokens)
        }
    }

    static func unlock() {
        ManagedSettingsStore(named: shieldStore).clearAllSettings()
    }

    /// Apply whichever state is right for now.
    static func apply() {
        if shouldBeUnlocked() { unlock() } else { lock() }
    }
}
