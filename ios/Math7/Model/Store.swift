import Foundation
import CryptoKit
import Combine

/// Owns all progress data and saves it as JSON in Application Support.
final class Store: ObservableObject {
    @Published var data: ProgressData

    let engine = ProblemEngine.shared
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("progress.json")
        if let raw = try? Data(contentsOf: fileURL), let d = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = d
        } else {
            data = ProgressData()
        }
    }

    func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: - Days

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var today: DayStat { data.days[Store.dayKey()] ?? DayStat() }
    var goal: Int { max(1, data.settings.goal) }
    var solvedToday: Int { today.goalCount }
    var goalMetToday: Bool { solvedToday >= goal }

    /// Days in a row the goal was met. Today not done yet doesn't break the streak.
    var streak: Int {
        var n = 0
        var d = Date()
        let met: (Date) -> Bool = { (self.data.days[Store.dayKey($0)]?.goalCount ?? 0) >= self.goal }
        if !met(d) { d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        while met(d) {
            n += 1
            d = Calendar.current.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    // MARK: - Units and mastery

    var units: [UnitInfo] { engine.units }
    var pacedUnitID: String { engine.pacedUnitID() }
    var currentUnitID: String { data.settings.unitOverride ?? pacedUnitID }
    var currentUnit: UnitInfo { engine.unit(currentUnitID) ?? units[0] }

    func stat(_ id: String) -> SkillStat? { data.skills[id] }

    func mastery(_ id: String) -> Double? {
        guard let s = data.skills[id], !s.hist.isEmpty else { return nil }
        return Double(s.hist.reduce(0, +)) / Double(s.hist.count)
    }

    /// Unpracticed skills count as 0 so the bar reflects coverage too.
    func unitMastery(_ u: UnitInfo) -> Double {
        let vals = u.skills.map { s -> Double in
            guard let m = mastery(s.id) else { return 0 }
            return m * min(1, Double(data.skills[s.id]?.att ?? 0) / 5)
        }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }

    func unitAttempts(_ u: UnitInfo) -> Int { u.skills.reduce(0) { $0 + (data.skills[$1.id]?.att ?? 0) } }

    // MARK: - Picking problems

    private func weight(_ id: String) -> Double {
        let att = data.skills[id]?.att ?? 0
        let m = mastery(id)
        return 1 + (m == nil ? 1.5 : (1 - m!) * 3) + (att < 3 ? 1 : 0)
    }

    func weightedPick(_ ids: [String], avoid: String?) -> String {
        let pool = ids.count > 1 ? ids.filter { $0 != avoid } : ids
        let ws = pool.map(weight)
        var t = ws.reduce(0, +) * Double.random(in: 0..<1)
        for (i, w) in ws.enumerated() {
            t -= w
            if t <= 0 { return pool[i] }
        }
        return pool.last ?? ids[0]
    }

    func makeProblem(_ skill: String) -> Problem? {
        engine.generate(skill: skill, level: data.skills[skill]?.level ?? 1)
    }

    /// Skills from units before the current one.
    var reviewSkillIDs: [String] {
        let cur = currentUnit.n
        return units.filter { $0.n < cur }.flatMap { $0.skills.map(\.id) }
    }

    /// Lowest-scoring practiced skills; falls back to the current unit.
    var weakSkillIDs: [String] {
        let tried = data.skills.filter { engine.skill($0.key) != nil && $0.value.att > 0 }.map(\.key)
            .sorted { (mastery($0) ?? 0) < (mastery($1) ?? 0) }
        let ids = Array(tried.prefix(5))
        return ids.isEmpty ? currentUnit.skills.map(\.id) : ids
    }

    // MARK: - Recording answers

    /// firstTry: right on the first try. solved: right on either try.
    func record(problem: Problem, firstTry: Bool, solved: Bool, tries: Int, given: String, how: String) {
        var s = data.skills[problem.skill] ?? SkillStat()
        s.att += 1
        if firstTry { s.cor += 1 }
        s.hist.append(firstTry ? 1 : 0)
        if s.hist.count > 10 { s.hist.removeFirst(s.hist.count - 10) }
        s.run += 1
        if s.run >= 5 {
            let last5 = s.hist.suffix(5)
            let acc = Double(last5.reduce(0, +)) / Double(last5.count)
            if acc >= 0.8 && s.level < 3 { s.level += 1; s.run = 0 }
            else if acc <= 0.4 && s.level > 1 { s.level -= 1; s.run = 0 }
        }
        data.skills[problem.skill] = s

        let k = Store.dayKey()
        var d = data.days[k] ?? DayStat()
        d.n += 1
        if firstTry { d.c += 1 }
        if solved { d.solved = (d.solved ?? 0) + 1 }
        data.days[k] = d

        let correct: String
        switch problem.answer {
        case .choice(let choices, let i): correct = HTMLText.plain(choices[i])
        case .number(let show, let unit):
            correct = (unit == "$" ? "$" : "") + HTMLText.plain(show) + ((unit != nil && unit != "$") ? " " + unit! : "")
        }
        data.log.append(LogEntry(t: Date().timeIntervalSince1970 * 1000, skill: problem.skill, lvl: problem.level,
                                 ok: firstTry, tries: tries, q: HTMLText.plain(problem.questionHTML),
                                 given: given, correct: correct, how: how))
        if data.log.count > 400 { data.log.removeFirst(data.log.count - 400) }
        save()
    }

    func finishSession(title: String, n: Int, c: Int, secs: Int) {
        let k = Store.dayKey()
        var d = data.days[k] ?? DayStat()
        d.secs = (d.secs ?? 0) + secs
        data.days[k] = d
        data.sessions.append(SessionEntry(t: Date().timeIntervalSince1970 * 1000, title: title, n: n, c: c, secs: secs))
        if data.sessions.count > 200 { data.sessions.removeFirst(data.sessions.count - 200) }
        save()
    }

    // MARK: - Game unlocks ("minutes" mode)

    var gateMode: String { data.settings.gateMode ?? "day" }
    var unlockMinutes: Int { data.settings.unlockMinutes ?? 30 }
    var unlocksEarnedToday: Int { solvedToday / goal }
    var unlocksUsedToday: Int { today.unlocks ?? 0 }
    var unlocksLeftToday: Int { max(0, unlocksEarnedToday - unlocksUsedToday) }

    func useUnlock() {
        let k = Store.dayKey()
        var d = data.days[k] ?? DayStat()
        d.unlocks = (d.unlocks ?? 0) + 1
        data.days[k] = d
        save()
    }

    // MARK: - PIN

    static func hashPIN(_ pin: String) -> String {
        SHA256.hash(data: Data(("m7:" + pin).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Backup

    func backupFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("math7-progress-\(Store.dayKey()).json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? enc.encode(data), (try? raw.write(to: url)) != nil else { return nil }
        return url
    }

    /// Restores a backup made by this app or the web app. Keeps the current PIN.
    func restore(from url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url), var d = try? JSONDecoder().decode(ProgressData.self, from: raw) else { return false }
        d.settings.pin = data.settings.pin
        data = d
        save()
        return true
    }

    func resetProgress() {
        let s = data.settings
        data = ProgressData()
        data.settings = s
        save()
    }
}
