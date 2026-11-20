import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Locks chosen games (Roblox) with Screen Time until the daily math goal is met.
///
/// Needs the Family Controls capability, which Apple only gives to paid developer accounts.
/// It's compiled in only for the "Math7 with Roblox Lock" scheme (see SETUP.md).
final class GateManager: ObservableObject {
    static let shared = GateManager()

    #if GATE_On
    static let isBuiltIn = true
    #else
    static let isBuiltIn = false
    #endif

    @Published private(set) var authStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var selection = FamilyActivitySelection()
    @Published private(set) var enabled = false
    @Published private(set) var protectApps = false
    @Published private(set) var unlocked = true
    @Published private(set) var bedtimeMinutes = 0
    @Published var lastError: String?

    private let center = DeviceActivityCenter()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        guard GateManager.isBuiltIn else { return }
        authStatus = AuthorizationCenter.shared.authorizationStatus
        selection = GateShared.loadSelection()
        enabled = GateShared.isEnabled
        protectApps = GateShared.defaults.bool(forKey: "gate.protectApps")
        unlocked = GateShared.shouldBeUnlocked()
        bedtimeMinutes = GateShared.defaults.integer(forKey: GateShared.Key.bedtime)
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.authStatus = $0 }
            .store(in: &cancellables)
    }

    var isAuthorized: Bool { authStatus == .approved }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }
    /// The gate is actually doing something.
    var isActive: Bool { GateManager.isBuiltIn && enabled && isAuthorized && hasSelection }

    // MARK: - Parent setup

    /// On a child's iPad in Family Sharing, a parent approves with their Apple Account.
    /// Then he can't turn it off or delete the app without the parent.
    @MainActor
    func requestAuthorization(child: Bool) async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: child ? .child : .individual)
            lastError = nil
        } catch {
            lastError = "Screen Time permission wasn't granted: \(error.localizedDescription)"
        }
        authStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func setSelection(_ s: FamilyActivitySelection, store: Store) {
        selection = s
        GateShared.saveSelection(s)
        sync(store: store)
    }

    func setEnabled(_ on: Bool, store: Store) {
        enabled = on
        GateShared.defaults.set(on, forKey: GateShared.Key.enabled)
        if on {
            startDailyMonitoring(restart: true)
        } else {
            center.stopMonitoring([.daily, .earned, .bedtime])
            GateShared.defaults.set(0, forKey: GateShared.Key.earnedUntil)
        }
        sync(store: store)
    }

    /// Blocks deleting apps (so the lock can't be removed by deleting Math 7).
    func setProtectApps(_ on: Bool) {
        protectApps = on
        GateShared.defaults.set(on, forKey: "gate.protectApps")
        ManagedSettingsStore(named: GateShared.protectStore).application.denyAppRemoval = on ? true : nil
    }

    /// Re-lock games every evening at this time (minutes after midnight, 0 = off).
    func setBedtime(_ minutes: Int, store: Store) {
        bedtimeMinutes = minutes
        GateShared.defaults.set(minutes, forKey: GateShared.Key.bedtime)
        center.stopMonitoring([.bedtime])
        if minutes > 0 && enabled {
            // Ends at 23:59; Screen Time needs at least 15 minutes, so the latest bedtime offered is 23:30.
            let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: minutes / 60, minute: minutes % 60),
                                                  intervalEnd: DateComponents(hour: 23, minute: 59),
                                                  repeats: true)
            do { try center.startMonitoring(.bedtime, during: schedule) }
            catch { lastError = "Couldn't set the bedtime lock: \(error.localizedDescription)" }
        }
        sync(store: store)
    }

    func parentLockToday(store: Store) {
        let d = GateShared.defaults
        d.set(GateShared.dayKey(), forKey: GateShared.Key.parentLockDay)
        d.removeObject(forKey: GateShared.Key.unlockDay)
        d.set(0, forKey: GateShared.Key.earnedUntil)
        center.stopMonitoring([.earned])
        sync(store: store)
    }

    func parentUnlockToday(store: Store) {
        let d = GateShared.defaults
        d.removeObject(forKey: GateShared.Key.parentLockDay)
        d.set(GateShared.dayKey(), forKey: GateShared.Key.unlockDay)
        sync(store: store)
    }

    // MARK: - Keeping the lock in step with progress

    /// Call on launch, when the app comes to the front, after each answer and after settings change.
    func sync(store: Store) {
        guard GateManager.isBuiltIn else { return }
        let d = GateShared.defaults
        let today = GateShared.dayKey()
        d.set(store.solvedToday, forKey: GateShared.Key.solved)
        d.set(store.goal, forKey: GateShared.Key.goal)
        d.set(today, forKey: GateShared.Key.progressDay)

        if enabled && store.gateMode == "day" && store.goalMetToday && d.string(forKey: GateShared.Key.parentLockDay) != today {
            d.set(today, forKey: GateShared.Key.unlockDay)
        }
        if enabled { startDailyMonitoring(restart: false) }
        GateShared.apply()
        unlocked = GateShared.shouldBeUnlocked()
    }

    var earnedUntil: Date? {
        let t = GateShared.defaults.double(forKey: GateShared.Key.earnedUntil)
        return t > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: t) : nil
    }

    /// "minutes" mode: he spends one earned unlock to play for the set number of minutes.
    func startEarnedSession(store: Store) {
        guard isActive, store.unlocksLeftToday > 0 else { return }
        let cal = Calendar.current
        let now = Date()
        var end = now.addingTimeInterval(Double(store.unlockMinutes) * 60)
        let lastMinute = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? end
        if end > lastMinute { end = lastMinute }
        // Screen Time schedules must be at least 15 minutes long.
        let start = min(now, end.addingTimeInterval(-15 * 60))
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: cal.dateComponents(comps, from: start),
                                              intervalEnd: cal.dateComponents(comps, from: end),
                                              repeats: false)
        center.stopMonitoring([.earned])
        do {
            try center.startMonitoring(.earned, during: schedule)
        } catch {
            lastError = "Couldn't start the play timer: \(error.localizedDescription)"
            return
        }
        store.useUnlock()
        GateShared.defaults.set(end.timeIntervalSince1970, forKey: GateShared.Key.earnedUntil)
        sync(store: store)
    }

    private func startDailyMonitoring(restart: Bool) {
        if !restart && center.activities.contains(.daily) { return }
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59),
                                              repeats: true)
        do {
            center.stopMonitoring([.daily])
            try center.startMonitoring(.daily, during: schedule)
        } catch {
            lastError = "Couldn't start the daily lock: \(error.localizedDescription)"
        }
    }
}
