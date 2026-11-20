import DeviceActivity

extension DeviceActivityName {
    /// Repeats every day from 00:00. Its start re-locks games for the new day.
    static let daily = DeviceActivityName("math7.daily")
    /// One earned play session. Its end re-locks games.
    static let earned = DeviceActivityName("math7.earned")
    /// Repeats every day from the parent's bedtime. Its start re-locks games.
    static let bedtime = DeviceActivityName("math7.bedtime")
}
