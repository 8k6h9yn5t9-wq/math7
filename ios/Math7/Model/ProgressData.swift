import Foundation

// Same JSON shape as the web app's backup file, so backups move between the two.
// Native-only fields are optional and ignored by the web app.

struct Settings: Codable, Equatable {
    var pin: String?            // SHA-256 of "m7:" + PIN, hex
    var goal: Int = 10          // problems to solve each day
    var unitOverride: String?
    var name: String = ""
    // native only
    var gateMode: String?       // "day" (unlock for rest of day) or "minutes"
    var unlockMinutes: Int?     // minutes earned per goal in "minutes" mode

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pin = try c.decodeIfPresent(String.self, forKey: .pin)
        goal = (try? c.decodeIfPresent(Int.self, forKey: .goal)) ?? 10
        unitOverride = try? c.decodeIfPresent(String.self, forKey: .unitOverride)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        gateMode = try? c.decodeIfPresent(String.self, forKey: .gateMode)
        unlockMinutes = try? c.decodeIfPresent(Int.self, forKey: .unlockMinutes)
    }
}

struct SkillStat: Codable, Equatable {
    var hist: [Int] = []   // last 10 results, 1 = right on first try
    var att = 0
    var cor = 0
    var level = 1
    var run = 0

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hist = (try? c.decodeIfPresent([Int].self, forKey: .hist)) ?? []
        att = (try? c.decodeIfPresent(Int.self, forKey: .att)) ?? 0
        cor = (try? c.decodeIfPresent(Int.self, forKey: .cor)) ?? 0
        level = (try? c.decodeIfPresent(Int.self, forKey: .level)) ?? 1
        run = (try? c.decodeIfPresent(Int.self, forKey: .run)) ?? 0
    }
}

struct DayStat: Codable, Equatable {
    var n = 0          // problems answered
    var c = 0          // right on first try
    var secs: Int?     // practice time
    var solved: Int?   // native: right on first or second try (counts toward the goal)
    var unlocks: Int?  // native: game unlock sessions used

    init() {}
    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        n = (try? k.decodeIfPresent(Int.self, forKey: .n)) ?? 0
        c = (try? k.decodeIfPresent(Int.self, forKey: .c)) ?? 0
        secs = try? k.decodeIfPresent(Int.self, forKey: .secs)
        solved = try? k.decodeIfPresent(Int.self, forKey: .solved)
        unlocks = try? k.decodeIfPresent(Int.self, forKey: .unlocks)
    }

    /// Problems that count toward the daily goal. Days logged by the web app have no `solved`.
    var goalCount: Int { solved ?? c }
}

struct LogEntry: Codable, Equatable {
    var t: Double        // ms since 1970
    var skill: String
    var lvl: Int
    var ok: Bool
    var tries: Int
    var q: String
    var given: String
    var correct: String
    var how: String?     // native: "pencil" or "keys"
}

struct SessionEntry: Codable, Equatable {
    var t: Double
    var title: String
    var n: Int
    var c: Int
    var secs: Int
}

struct ProgressData: Codable, Equatable {
    var settings = Settings()
    var skills: [String: SkillStat] = [:]
    var days: [String: DayStat] = [:]
    var log: [LogEntry] = []
    var sessions: [SessionEntry] = []

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decode(Settings.self, forKey: .settings)
        skills = try c.decode([String: SkillStat].self, forKey: .skills)
        days = (try? c.decodeIfPresent([String: DayStat].self, forKey: .days)) ?? [:]
        log = (try? c.decodeIfPresent([LogEntry].self, forKey: .log)) ?? []
        sessions = (try? c.decodeIfPresent([SessionEntry].self, forKey: .sessions)) ?? []
    }
}
