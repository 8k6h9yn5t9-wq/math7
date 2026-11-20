import Foundation
import JavaScriptCore

// The problem bank lives in ../problems.js (shared with the web app).
// We run it in JavaScriptCore so the web and iPad apps always generate the same problems.

struct SkillInfo: Identifiable, Hashable {
    let id: String
    let name: String
}

struct UnitInfo: Identifiable, Hashable {
    let id: String
    let n: Int
    let name: String
    let short: String
    let icon: String
    let skills: [SkillInfo]
}

enum AnswerKind {
    /// A number answer. `show` is HTML for the correct answer, `unit` is "$", "%", "cm²", etc.
    case number(show: String, unit: String?)
    /// Multiple choice. Choices are HTML.
    case choice(choices: [String], correct: Int)
}

struct Problem {
    let skill: String
    let level: Int
    let questionHTML: String
    let answer: AnswerKind
    let answerJSON: String // raw answer object, handed back to JS to check typed answers
    let steps: [String]
    let hint: String?

    var isChoice: Bool { if case .choice = answer { return true } else { return false } }
}

final class ProblemEngine {
    static let shared = ProblemEngine()

    private let context: JSContext
    private(set) var units: [UnitInfo] = []
    private var skillIndex: [String: (skill: SkillInfo, unit: UnitInfo)] = [:]

    private init() {
        context = JSContext()!
        context.exceptionHandler = { _, exception in
            print("problems.js error:", exception?.toString() ?? "unknown")
        }
        guard let url = Bundle.main.url(forResource: "problems", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("problems.js is missing from the app bundle")
        }
        context.evaluateScript(source, withSourceURL: url)
        context.evaluateScript("""
        function __units() {
          return JSON.stringify(M7.UNITS.map(function (u, i) {
            return { id: u.id, n: i + 1, name: u.name, short: u.short, icon: u.icon,
                     skills: u.skills.map(function (s) { return { id: s.id, name: s.name }; }) };
          }));
        }
        function __gen(id, level) {
          for (var i = 0; i < M7.UNITS.length; i++) {
            var sk = M7.UNITS[i].skills;
            for (var j = 0; j < sk.length; j++) if (sk[j].id === id) return JSON.stringify(sk[j].gen(level));
          }
          return null;
        }
        function __paced(y, m, d) { return M7.pacedUnit(new Date(y, m - 1, d)); }
        function __check(input, answerJSON) { return M7.checkNum(input, JSON.parse(answerJSON)); }
        function __parse(input) { var v = M7.parseAnswer(input); return isNaN(v) ? null : v; }
        """)
        loadUnits()
    }

    private func loadUnits() {
        guard let json = context.objectForKeyedSubscript("__units").call(withArguments: [])?.toString(),
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        units = arr.map { u in
            let skills = (u["skills"] as? [[String: Any]] ?? []).map {
                SkillInfo(id: $0["id"] as? String ?? "", name: $0["name"] as? String ?? "")
            }
            return UnitInfo(id: u["id"] as? String ?? "", n: u["n"] as? Int ?? 0,
                            name: u["name"] as? String ?? "", short: u["short"] as? String ?? "",
                            icon: u["icon"] as? String ?? "", skills: skills)
        }
        for u in units { for s in u.skills { skillIndex[s.id] = (s, u) } }
    }

    func unit(_ id: String) -> UnitInfo? { units.first { $0.id == id } }
    func skill(_ id: String) -> SkillInfo? { skillIndex[id]?.skill }
    func unitOf(skill id: String) -> UnitInfo? { skillIndex[id]?.unit }

    /// The unit the class is on today, from the PACING table in problems.js.
    func pacedUnitID(on date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let v = context.objectForKeyedSubscript("__paced").call(withArguments: [c.year ?? 2026, c.month ?? 1, c.day ?? 1])
        return v?.toString() ?? units.first?.id ?? "u1"
    }

    func generate(skill: String, level: Int) -> Problem? {
        guard let json = context.objectForKeyedSubscript("__gen").call(withArguments: [skill, level]),
              !json.isNull, !json.isUndefined,
              let data = json.toString().data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let a = obj["a"] as? [String: Any] else { return nil }
        let kind: AnswerKind
        if (a["type"] as? String) == "mc" {
            kind = .choice(choices: a["choices"] as? [String] ?? [], correct: a["correct"] as? Int ?? 0)
        } else {
            kind = .number(show: a["show"] as? String ?? "", unit: a["unit"] as? String)
        }
        let aJSON = (try? JSONSerialization.data(withJSONObject: a)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return Problem(skill: skill, level: level, questionHTML: obj["q"] as? String ?? "",
                       answer: kind, answerJSON: aJSON, steps: obj["steps"] as? [String] ?? [],
                       hint: obj["hint"] as? String)
    }

    /// Same rules as the web app: integers, decimals, fractions, rounded decimals for repeating fractions.
    func check(_ input: String, against problem: Problem) -> Bool {
        context.objectForKeyedSubscript("__check").call(withArguments: [input, problem.answerJSON])?.toBool() ?? false
    }

    func isValidNumber(_ input: String) -> Bool {
        guard let v = context.objectForKeyedSubscript("__parse").call(withArguments: [input]) else { return false }
        return !v.isNull && !v.isUndefined
    }
}

// MARK: - HTML helpers

enum HTMLText {
    /// Plain-text version of question HTML, for the parent view's mistake log.
    static func plain(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: #"<span class="fr"><span>(.*?)</span><span>(.*?)</span></span>"#,
                                   with: "($1/$2)", options: .regularExpression)
        s = s.replacingOccurrences(of: "<br>", with: " ")
        s = s.replacingOccurrences(of: #"<div class="fig">[\s\S]*</div>"#, with: " [figure]", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (k, v) in ["&lt;": "<", "&gt;": ">", "&quot;": "\"", "&nbsp;": " ", "&amp;": "&"] {
            s = s.replacingOccurrences(of: k, with: v)
        }
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
