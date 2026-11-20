import Foundation
import Combine

enum SessionKind: Equatable {
    case unit(String), skill(String), review, weak
}

enum AnswerStatus { case ask, wrong, retry, right, shown }

struct CurrentProblem {
    var p: Problem
    var input = ""
    var tries = 0
    var status: AnswerStatus = .ask
    var picked: [Int] = []
    var recorded = false
    var firstGiven = ""
    var wrongInput = ""
    var showSteps = false
    var usedPencil = false

    var isDone: Bool { status == .right || status == .shown }
}

final class PracticeSession: ObservableObject {
    static let length = 10

    let kind: SessionKind
    let title: String
    private let ids: [String]
    private unowned let store: Store
    private let started = Date()
    private var last: String?

    @Published var index = 0
    @Published var results: [Bool] = []
    @Published var cur: CurrentProblem
    @Published var finished: (c: Int, n: Int, secs: Int)?

    /// Called after every recorded answer so the game gate can update.
    var onRecord: (() -> Void)?

    init(kind: SessionKind, store: Store) {
        self.kind = kind
        self.store = store
        let e = store.engine
        switch kind {
        case .unit(let id):
            let u = e.unit(id) ?? store.currentUnit
            ids = u.skills.map(\.id); title = "Unit \(u.n): \(u.name)"
        case .skill(let id):
            ids = [id]; title = e.skill(id)?.name ?? "Practice"
        case .review:
            let r = store.reviewSkillIDs
            ids = r.isEmpty ? store.currentUnit.skills.map(\.id) : r; title = "Review mix"
        case .weak:
            ids = store.weakSkillIDs; title = "Fix my mistakes"
        }
        let first = store.weightedPick(ids, avoid: nil)
        last = first
        cur = CurrentProblem(p: store.makeProblem(first)!)
    }

    private func nextProblem() {
        var id = store.weightedPick(ids, avoid: last)
        var p = store.makeProblem(id)
        if p == nil { id = ids[0]; p = store.makeProblem(id) }
        last = id
        cur = CurrentProblem(p: p!)
    }

    private func record(firstTry: Bool, solved: Bool) {
        guard !cur.recorded else { return }
        cur.recorded = true
        store.record(problem: cur.p, firstTry: firstTry, solved: solved, tries: cur.tries,
                     given: cur.firstGiven, how: cur.usedPencil ? "pencil" : "keys")
        results.append(firstTry)
        onRecord?()
    }

    // MARK: - Number answers

    func setInput(_ s: String, fromPencil: Bool) {
        guard !cur.isDone else { return }
        if fromPencil { cur.usedPencil = true }
        if cur.status == .wrong && s != cur.input { cur.status = .retry }
        cur.input = s
    }

    func key(_ k: String) {
        guard !cur.isDone else { if k == "enter" { advance() }; return }
        var s = cur.input
        switch k {
        case "enter": submit(); return
        case "back": if !s.isEmpty { s.removeLast() }
        case "clear": s = ""
        case "-": s = s.hasPrefix("-") ? String(s.dropFirst()) : "-" + s
        case "/": if !s.contains("/"), let l = s.last, l.isNumber { s += "/" }
        case ".":
            let part = s.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? ""
            if !part.contains(".") { s += (s.last?.isNumber == true ? "" : "0") + "." }
        default:
            if k.count == 1, k.first!.isNumber, s.filter(\.isNumber).count < 9 { s += k }
        }
        setInput(s, fromPencil: false)
    }

    func submit() {
        guard !cur.isDone, !cur.input.isEmpty, cur.input != "-" else { return }
        cur.tries += 1
        if cur.tries == 1 { cur.firstGiven = cur.input.replacingOccurrences(of: "-", with: "−") }
        if store.engine.check(cur.input, against: cur.p) {
            cur.status = .right
            record(firstTry: cur.tries == 1, solved: true)
        } else if cur.tries >= 2 {
            cur.status = .shown
            cur.wrongInput = cur.input
            record(firstTry: false, solved: false)
        } else {
            cur.status = .wrong
            cur.wrongInput = cur.input
            cur.input = ""
        }
    }

    // MARK: - Multiple choice

    func pick(_ i: Int) {
        guard !cur.isDone, !cur.picked.contains(i), case .choice(let choices, let correct) = cur.p.answer else { return }
        cur.tries += 1
        cur.picked.append(i)
        if cur.tries == 1 { cur.firstGiven = HTMLText.plain(choices[i]) }
        if i == correct {
            cur.status = .right
            record(firstTry: cur.tries == 1, solved: true)
        } else if cur.tries >= 2 || choices.count == 2 {
            cur.status = .shown
            record(firstTry: false, solved: false)
        } else {
            cur.status = .wrong
        }
    }

    // MARK: - Flow

    func showMe() {
        guard !cur.isDone else { return }
        cur.status = .shown
        record(firstTry: false, solved: false)
    }

    func advance() {
        index += 1
        if index >= PracticeSession.length { finish() } else { nextProblem() }
    }

    func finish() {
        let secs = Int(Date().timeIntervalSince(started))
        let c = results.filter { $0 }.count
        store.finishSession(title: title, n: results.count, c: c, secs: secs)
        finished = (c, results.count, secs)
    }
}
