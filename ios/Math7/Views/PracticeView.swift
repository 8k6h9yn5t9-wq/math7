import SwiftUI

struct PracticeView: View {
    @ObservedObject var session: PracticeSession
    var onStop: () -> Void

    @AppStorage("inputMode") private var inputMode = "write"
    @State private var webHeight: CGFloat = 120
    @State private var readFailed = false
    @State private var padClears = 0
    @State private var scratchTool: ScratchPad.Tool = .pen
    @State private var scratchClears = 0

    private var c: CurrentProblem { session.cur }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height && geo.size.width > 900
            VStack(spacing: 14) {
                topBar
                if wide {
                    HStack(alignment: .top, spacing: 16) {
                        ScrollView { questionCard }
                            .frame(width: geo.size.width * 0.53)
                        scratchCard
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            questionCard
                            scratchCard.frame(height: 340)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: stop) { Label("Stop", systemImage: "xmark") }
                .buttonStyle(PillButtonStyle())
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<PracticeSession.length, id: \.self) { i in
                    Circle().fill(dotColor(i)).frame(width: 14, height: 14)
                }
            }
            Spacer()
            Text("\(min(session.index + 1, PracticeSession.length)) / \(PracticeSession.length)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func dotColor(_ i: Int) -> Color {
        if i < session.results.count { return session.results[i] ? .good : .bad }
        return i == session.index ? .brand : Color.secondary.opacity(0.25)
    }

    private func stop() {
        if session.results.isEmpty { onStop() } else { session.finish() }
    }

    // MARK: - Question

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(skillName) · \(String(repeating: "●", count: c.p.level))\(String(repeating: "○", count: 3 - c.p.level))")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.bottom, 6)
            QuestionWebView(state: webState, height: $webHeight) { session.pick($0) }
                .frame(height: webHeight)
            if case .number(_, let unit) = c.p.answer {
                numberAnswer(unit: unit)
            }
            controls.padding(.top, 14)
        }
        .padding(22)
        .card()
    }

    private var skillName: String { ProblemEngine.shared.skill(c.p.skill)?.name ?? "" }

    private static let praise = ["✅ Correct!", "✅ Nice!", "✅ You got it!", "✅ Great job!"]

    private var webState: [String: Any] {
        var s: [String: Any] = ["q": c.p.questionHTML]
        if case .choice(let choices, let correct) = c.p.answer {
            s["choices"] = choices
            s["choiceState"] = choices.indices.map { i -> String in
                if c.picked.contains(i) { return i == correct ? "ok" : "no" }
                if c.isDone && i == correct { return "ok" }
                return ""
            }
            s["locked"] = c.isDone
        }
        switch c.status {
        case .right:
            let msg = c.tries == 1 ? Self.praise[session.index % Self.praise.count] : "✅ Got it on the second try!"
            s["feedback"] = ["kind": "ok", "html": msg, "pop": true]
        case .wrong, .retry:
            s["feedback"] = ["kind": "no", "html": "Not quite. Try once more."]
            if let h = c.p.hint { s["hint"] = h }
        case .shown:
            s["feedback"] = ["kind": "no", "html": "Here's how to solve it:"]
            if case .number(let show, let unit) = c.p.answer {
                s["answer"] = (unit == "$" ? "$" : "") + show + ((unit != nil && unit != "$") ? " " + unit! : "")
            }
        case .ask: break
        }
        if c.status == .shown || (c.status == .right && c.showSteps) { s["steps"] = c.p.steps }
        return s
    }

    // MARK: - Number answers

    @ViewBuilder
    private func numberAnswer(unit: String?) -> some View {
        VStack(spacing: 12) {
            AnswerBox(input: c.status == .shown ? c.wrongInput : c.input,
                      unit: unit,
                      status: c.status,
                      placeholder: placeholder)
            if !c.isDone {
                Picker("Answer with", selection: $inputMode) {
                    Label("Write", systemImage: "pencil.tip").tag("write")
                    Label("Keys", systemImage: "number").tag("keys")
                }
                .pickerStyle(.segmented)
                if inputMode == "write" { writePad } else { Keypad { session.key($0) } }
            }
        }
        .padding(.top, 12)
    }

    private var placeholder: String {
        if readFailed { return "Hmm, I can't read that. Write bigger, or tap Keys." }
        if c.status == .wrong { return "Try again" }
        return inputMode == "write" ? "Write your answer below" : "Type your answer"
    }

    private var writePad: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16).fill(Color.appBackground)
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.brand.opacity(0.5), lineWidth: 2)
                Text("✏️ Write here. Fractions: top number, a line, bottom number.")
                    .font(.footnote).foregroundStyle(.secondary).padding(10)
                    .allowsHitTesting(false)
                HandwritingPad(clearToken: padClears, onRead: { text in
                    if let t = text, ProblemEngine.shared.isValidNumber(t) {
                        readFailed = false
                        session.setInput(t, fromPencil: true)
                    } else {
                        readFailed = true
                        session.setInput("", fromPencil: true)
                    }
                }, onEmpty: {
                    readFailed = false
                    session.setInput("", fromPencil: true)
                })
                .id("pad-\(session.index)-\(c.tries)") // fresh paper for each try
            }
            .frame(height: 190)
            HStack(spacing: 12) {
                Button { padClears += 1; readFailed = false; session.setInput("", fromPencil: true) } label: {
                    Label("Erase", systemImage: "eraser")
                }
                .buttonStyle(PillButtonStyle())
                Button { session.key("-") } label: { Text("±").font(.title3.bold()) }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityLabel("Make negative")
                Spacer()
                Button("Check") { session.submit() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(c.input.isEmpty || c.input == "-")
            }
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if c.isDone {
            HStack(spacing: 12) {
                if c.status == .right && !c.showSteps {
                    Button("Show steps") { session.cur.showSteps = true }.buttonStyle(PillButtonStyle(large: true))
                }
                Button(session.index + 1 >= PracticeSession.length ? "Finish" : "Next ›") {
                    readFailed = false
                    scratchClears += 1
                    session.advance()
                }
                .buttonStyle(PrimaryButtonStyle(expand: true))
            }
        } else {
            HStack {
                Spacer()
                Button("Show me how") { session.showMe() }.foregroundStyle(Color.brand)
            }
        }
    }

    // MARK: - Scratch paper

    private var scratchCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Scratch work ✏️").bold()
                Spacer()
                ToolButton(title: "Pen", on: scratchTool == .pen) { scratchTool = .pen }
                ToolButton(title: "Eraser", on: scratchTool == .eraser) { scratchTool = .eraser }
                ToolButton(title: "Clear", on: false) { scratchClears += 1 }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.appBackground)
                GridBackground().clipShape(RoundedRectangle(cornerRadius: 12))
                ScratchPad(tool: scratchTool, clearToken: scratchClears)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(12)
        .card()
    }
}

// MARK: - Pieces

struct AnswerBox: View {
    let input: String
    let unit: String?
    let status: AnswerStatus
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            if input.isEmpty {
                Text(placeholder).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                if unit == "$" { Text("$") }
                MathNumber(text: input)
                    .strikethrough(status == .shown)
                    .opacity(status == .shown ? 0.6 : 1)
                if let u = unit, u != "$" { Text(u).font(.title2).foregroundStyle(.secondary) }
            }
        }
        .font(.system(size: 34, weight: .bold))
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(border, lineWidth: 3))
    }

    private var border: Color {
        switch status {
        case .right: return .good
        case .shown: return .bad
        default: return .brand
        }
    }
    private var fill: Color {
        switch status {
        case .right: return .good.opacity(0.12)
        case .shown: return .bad.opacity(0.1)
        default: return .appBackground
        }
    }
}

/// Shows "-3/4" as a stacked fraction with a real minus sign.
struct MathNumber: View {
    let text: String
    var body: some View {
        let neg = text.hasPrefix("-")
        let digits = neg ? String(text.dropFirst()) : text
        let parts = digits.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        HStack(spacing: 4) {
            if neg { Text("−") }
            if parts.count == 2 {
                VStack(spacing: 2) {
                    Text(parts[0].isEmpty ? " " : parts[0])
                    Rectangle().frame(height: 2.5)
                    Text(parts[1].isEmpty ? " " : parts[1])
                }
                .font(.system(size: 26, weight: .bold))
                .fixedSize()
            } else {
                Text(digits)
            }
        }
    }
}

struct Keypad: View {
    var onKey: (String) -> Void
    private let keys = ["7", "8", "9", "back", "4", "5", "6", "-", "1", "2", "3", "/", "0", ".", "clear", "enter"]
    private let labels = ["back": "⌫", "-": "±", "/": "a/b", "clear": "C", "enter": "Check"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(keys, id: \.self) { k in
                Button { onKey(k) } label: {
                    Text(labels[k] ?? k)
                        .font(.system(size: k == "enter" ? 21 : 28, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .foregroundStyle(k == "enter" ? Color.white : (Int(k) == nil ? Color.brand : Color.primary))
                        .background(RoundedRectangle(cornerRadius: 14).fill(k == "enter" ? Color.brand : Color.keyFill))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ToolButton: View {
    let title: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).frame(minHeight: 38)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color.brand : Color.keyFill))
        }
        .buttonStyle(.plain)
    }
}
