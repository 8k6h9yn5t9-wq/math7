import UIKit
import PencilKit
import Vision

/// Reads a handwritten math answer: integers, decimals, negatives, fractions (stacked or with a slash)
/// and mixed numbers.
///
/// Apple's text recognizer (Vision) is good at digits but often misses the small marks that matter in
/// math: a minus sign, a decimal point, a fraction bar. So we first look at the Pencil strokes
/// themselves to find those marks, and only send the runs of digits to Vision.
enum HandwritingRecognizer {

    struct Result {
        let text: String      // e.g. "-3/4", "2.5"; what gets checked
    }

    // MARK: - Layout

    private enum Piece {
        case text(String)
        case digits([[PKStroke]])   // one entry per handwritten character
    }

    private struct Layout {
        var whole: [Piece] = []       // everything for a plain number; the part left of a fraction bar otherwise
        var numerator: [Piece]? = nil
        var denominator: [Piece]? = nil
    }

    static func recognize(_ drawing: PKDrawing, completion: @escaping (Result?) -> Void) {
        let strokes = drawing.strokes.filter { $0.renderBounds.width > 0.5 || $0.renderBounds.height > 0.5 }
        guard !strokes.isEmpty else { completion(nil); return }
        let layout = makeLayout(strokes)

        // Render every digit run to an image now (on the main thread), then read them in the background.
        var runs: [[[PKStroke]]] = []
        func collect(_ pieces: [Piece]?) { pieces?.forEach { if case .digits(let s) = $0 { runs.append(s) } } }
        collect(layout.whole); collect(layout.numerator); collect(layout.denominator)
        let images = runs.map { render($0.flatMap { $0 }) }

        DispatchQueue.global(qos: .userInitiated).async {
            var texts: [String?] = []
            for (i, img) in images.enumerated() {
                texts.append(readRun(image: img, characters: runs[i]))
            }
            var cursor = 0
            func assemble(_ pieces: [Piece]?) -> String? {
                guard let pieces = pieces else { return nil }
                var out = ""
                for p in pieces {
                    switch p {
                    case .text(let t): out += t
                    case .digits:
                        guard let t = texts[cursor] else { return nil }
                        cursor += 1
                        out += t
                    }
                }
                return out
            }
            let wholeText = assemble(layout.whole)
            var answer: String?
            if layout.numerator != nil {
                if let w = wholeText, let n = assemble(layout.numerator), let d = assemble(layout.denominator) {
                    answer = combineFraction(left: w, num: n, den: d)
                }
            } else {
                answer = wholeText.flatMap(cleanNumber)
            }
            DispatchQueue.main.async { completion(answer.map { Result(text: $0) }) }
        }
    }

    private static func makeLayout(_ strokes: [PKStroke]) -> Layout {
        var layout = Layout()
        if let barIndex = fractionBar(in: strokes) {
            let b = strokes[barIndex].renderBounds
            let reach = b.width * 0.25
            var left: [PKStroke] = [], num: [PKStroke] = [], den: [PKStroke] = []
            for (i, s) in strokes.enumerated() where i != barIndex {
                let r = s.renderBounds
                if r.maxX < b.minX + reach * 0.3 && r.midX < b.minX { left.append(s) }
                else if r.midY < b.midY { num.append(s) }
                else { den.append(s) }
            }
            layout.whole = inline(left)
            layout.numerator = inline(num)
            layout.denominator = inline(den)
        } else {
            layout.whole = inline(strokes)
        }
        return layout
    }

    /// A long flat stroke with ink above and below it.
    private static func fractionBar(in strokes: [PKStroke]) -> Int? {
        let candidates = strokes.indices.filter {
            let r = strokes[$0].renderBounds
            return r.width >= 18 && r.height < max(10, r.width * 0.28)
        }.sorted { strokes[$0].renderBounds.width > strokes[$1].renderBounds.width }
        for bar in candidates {
            let b = strokes[bar].renderBounds
            let lo = b.minX - b.width * 0.25, hi = b.maxX + b.width * 0.25
            let others = strokes.indices.filter { $0 != bar && strokes[$0].renderBounds.midX >= lo && strokes[$0].renderBounds.midX <= hi }
                .map { strokes[$0].renderBounds }
            let above = others.contains { $0.maxY < b.midY + 2 }
            let below = others.contains { $0.minY > b.midY - 2 }
            if above && below { return bar }
        }
        return nil
    }

    /// Splits one line of writing into digits and the marks Vision tends to miss.
    private static func inline(_ strokes: [PKStroke]) -> [Piece] {
        guard !strokes.isEmpty else { return [] }
        // Group strokes that overlap left-to-right into characters (a "4" or "5" is often two strokes).
        var clusters: [(rect: CGRect, strokes: [PKStroke])] = []
        for s in strokes.sorted(by: { $0.renderBounds.minX < $1.renderBounds.minX }) {
            let r = s.renderBounds
            if let last = clusters.last, r.minX < last.rect.maxX - min(r.width, last.rect.width) * 0.3 {
                clusters[clusters.count - 1] = (last.rect.union(r), last.strokes + [s])
            } else {
                clusters.append((r, [s]))
            }
        }
        let all = clusters.reduce(clusters[0].rect) { $0.union($1.rect) }
        let tall = clusters.map { $0.rect.height }.max() ?? all.height
        let lineH = max(tall, 20)

        var pieces: [Piece] = []
        var run: [[PKStroke]] = []
        func flush() { if !run.isEmpty { pieces.append(.digits(run)); run = [] } }

        for (i, c) in clusters.enumerated() {
            let r = c.rect
            let single = c.strokes.count == 1
            let isFirst = i == 0, isLast = i == clusters.count - 1
            if single && isFirst && clusters.count > 1 && r.height < max(8, r.width * 0.45) && r.width > lineH * 0.15 {
                flush(); pieces.append(.text("-"))
            } else if r.width < lineH * 0.25 && r.height < lineH * 0.25 && r.midY > all.minY + all.height * 0.45 && !isFirst && !isLast {
                flush(); pieces.append(.text("."))
            } else if single && !isFirst && !isLast && isSlash(c.strokes[0], lineH: lineH) {
                flush(); pieces.append(.text("/"))
            } else {
                run.append(c.strokes)
            }
        }
        flush()
        return pieces
    }

    /// A slanted line going up to the right, without the flat top a 7 has.
    private static func isSlash(_ s: PKStroke, lineH: CGFloat) -> Bool {
        let r = s.renderBounds
        guard r.height > lineH * 0.6, r.width > r.height * 0.3 else { return false }
        let pts = s.path.map { $0.location.applying(s.transform) }
        guard let top = pts.min(by: { $0.y < $1.y }), let bottom = pts.max(by: { $0.y < $1.y }) else { return false }
        return top.x > r.minX + r.width * 0.7 && bottom.x < r.minX + r.width * 0.3
    }

    // MARK: - Reading digits

    private static func render(_ strokes: [PKStroke]) -> CGImage? {
        let drawing = PKDrawing(strokes: strokes)
        let rect = drawing.bounds.insetBy(dx: -24, dy: -24)
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: 2)
        }
        guard let ink = image else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = ink.scale
        let flat = UIGraphicsImageRenderer(size: ink.size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: ink.size))
            ink.draw(at: .zero)
        }
        return flat.cgImage
    }

    private static func readDigits(_ image: CGImage?) -> String? {
        guard let image = image else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0
        do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { return nil }
        let obs = (request.results ?? []).sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        guard !obs.isEmpty else { return nil }
        var out = ""
        for o in obs {
            let best = o.topCandidates(10).lazy.compactMap { digitsOnly($0.string) }.first
            guard let b = best else { return nil }
            out += b
        }
        return out.isEmpty ? nil : out
    }

    /// Letters that handwriting recognizers commonly confuse with digits.
    private static let lookalikes: [Character: String] = [
        "O": "0", "o": "0", "D": "0", "Q": "0", "U": "0",
        "l": "1", "I": "1", "i": "1", "|": "1", "!": "1", "]": "1", "[": "1", "j": "1", "J": "1", "L": "1",
        "Z": "2", "z": "2",
        "S": "5", "s": "5", "$": "5",
        "b": "6", "G": "6",
        "T": "7", "?": "7", ">": "7",
        "B": "8", "&": "8",
        "g": "9", "q": "9", "a": "9",
        "A": "4", "y": "4", "h": "4",
        "−": "-", "—": "-", "–": "-", "_": "-", "~": "-",
        ",": ".", "·": ".",
    ]

    private static func digitsOnly(_ raw: String) -> String? {
        var out = ""
        for ch in raw where !ch.isWhitespace {
            if ch.isASCII && ch.isNumber { out.append(ch) }
            else if ch == "." || ch == "-" || ch == "/" { out.append(ch) }
            else if let m = lookalikes[ch] { out += m }
            else { return nil }
        }
        return out.contains(where: \.isNumber) ? out : nil
    }

    /// Use Vision when it found one digit per handwritten character; otherwise (it often returns
    /// nothing for a lone digit, and doesn't work in the Simulator) read each character with $P.
    private static func readRun(image: CGImage?, characters: [[PKStroke]]) -> String? {
        if let v = readDigits(image), v.filter(\.isNumber).count == characters.count {
            return v
        }
        var out = ""
        for c in characters {
            guard let m = DigitRecognizer.recognize(c) else { return nil }
            out += m.digit
        }
        return out.isEmpty ? nil : out
    }

    // MARK: - Assembling

    private static func cleanNumber(_ s: String) -> String? {
        var t = s
        let isNeg = t.hasPrefix("-")
        if isNeg { t.removeFirst() }
        t = t.replacingOccurrences(of: "-", with: "")
        if t.hasPrefix("/") || t.hasSuffix("/") || t.filter({ $0 == "/" }).count > 1 { return nil }
        if t.filter({ $0 == "." }).count > 1 && !t.contains("/") { return nil }
        guard !t.isEmpty else { return nil }
        return (isNeg ? "-" : "") + t
    }

    private static func combineFraction(left: String, num: String, den: String) -> String? {
        var neg = false
        var w = left
        if w.hasPrefix("-") { neg = true; w.removeFirst() }
        var n = num
        if n.hasPrefix("-") { neg.toggle(); n.removeFirst() }
        guard !n.isEmpty, !den.isEmpty, !den.contains("-") else { return nil }
        if w.isEmpty { return (neg ? "-" : "") + n + "/" + den }
        // Mixed number: 2 3/4 → 11/4
        guard let wi = Int(w), let ni = Int(n), let di = Int(den), di != 0 else { return nil }
        return (neg ? "-" : "") + "\(wi * di + ni)/\(di)"
    }
}
