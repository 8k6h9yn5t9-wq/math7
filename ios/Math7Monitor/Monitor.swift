import DeviceActivity
import Foundation

/// Runs in the background, even when Math 7 isn't open.
class Monitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // A new day started: lock games unless they were already unlocked for today.
        if activity == .daily || activity == .bedtime { GateShared.apply() }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .earned {
            GateShared.defaults.set(0, forKey: GateShared.Key.earnedUntil)
            GateShared.apply()
        }
    }
}
