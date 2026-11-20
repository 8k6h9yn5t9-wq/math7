import Foundation
import CoreGraphics
import PencilKit

/// Recognizes one handwritten digit from its Pencil strokes with the $P point-cloud recognizer
/// (Vatavu, Anthony & Wobbrock, 2012), matched against hand-made templates of common ways to write 0–9.
/// Works offline and in the Simulator, and doesn't care about stroke order or direction.
enum DigitRecognizer {
    private static let n = 32

    struct Match { let digit: String; let distance: Double }

    static func recognize(_ strokes: [PKStroke]) -> Match? {
        var raw: [(CGPoint, Int)] = []
        for (i, s) in strokes.enumerated() {
            let pts = s.path.interpolatedPoints(by: .distance(3)).map { $0.location.applying(s.transform) }
            if pts.count == 1 { raw.append((pts[0], i)) }
            for p in pts { raw.append((p, i)) }
        }
        guard raw.count >= 2 else { return nil }
        let cloud = normalize(raw)
        var best: Match?
        for t in templates {
            let d = cloudDistance(cloud, t.cloud)
            if best == nil || d < best!.distance { best = Match(digit: t.digit, distance: d) }
        }
        return best
    }

    // MARK: - Templates (x right, y down, in a 0...1 box)

    private struct Template { let digit: String; let cloud: [CGPoint] }

    private static func arc(cx: Double, cy: Double, rx: Double, ry: Double, from a0: Double, to a1: Double, steps: Int = 16) -> [CGPoint] {
        (0...steps).map { i in
            let a = (a0 + (a1 - a0) * Double(i) / Double(steps)) * .pi / 180
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    private static func p(_ list: [(Double, Double)]) -> [CGPoint] { list.map { CGPoint(x: $0.0, y: $0.1) } }

    private static let templates: [Template] = {
        let defs: [(String, [[CGPoint]])] = [
            ("0", [arc(cx: 0.5, cy: 0.5, rx: 0.4, ry: 0.5, from: -90, to: 270, steps: 24)]),
            ("0", [arc(cx: 0.5, cy: 0.5, rx: 0.3, ry: 0.5, from: -90, to: 270, steps: 24)]),
            ("1", [p([(0.5, 0), (0.5, 1)])]),
            ("1", [p([(0.25, 0.2), (0.5, 0), (0.5, 1)])]),
            ("1", [p([(0.25, 0.2), (0.5, 0), (0.5, 1)]), p([(0.25, 1), (0.75, 1)])]),
            ("2", [arc(cx: 0.5, cy: 0.28, rx: 0.38, ry: 0.28, from: 190, to: 380) + p([(0.1, 1), (0.92, 1)])]),
            ("2", [p([(0.1, 0.2), (0.4, 0), (0.75, 0.05), (0.85, 0.3), (0.6, 0.6), (0.1, 1), (0.9, 1)])]),
            ("3", [arc(cx: 0.5, cy: 0.25, rx: 0.38, ry: 0.25, from: 200, to: 450) + arc(cx: 0.5, cy: 0.75, rx: 0.42, ry: 0.25, from: 270, to: 520)]),
            ("3", [p([(0.1, 0), (0.85, 0), (0.45, 0.4)]) + arc(cx: 0.5, cy: 0.7, rx: 0.4, ry: 0.3, from: 270, to: 510)]),
            ("4", [p([(0.6, 0), (0.05, 0.65), (0.95, 0.65)]), p([(0.72, 0.3), (0.72, 1)])]),
            ("4", [p([(0.15, 0), (0.1, 0.6), (0.9, 0.6)]), p([(0.72, 0), (0.72, 1)])]),
            ("4", [p([(0.15, 0), (0.1, 0.6), (0.9, 0.6), (0.72, 0.6), (0.72, 0), (0.72, 1)])]),
            ("5", [p([(0.85, 0), (0.2, 0)]), p([(0.2, 0), (0.15, 0.45)]) + arc(cx: 0.48, cy: 0.7, rx: 0.4, ry: 0.3, from: 230, to: 490)]),
            ("5", [p([(0.85, 0), (0.2, 0), (0.15, 0.45)]) + arc(cx: 0.48, cy: 0.7, rx: 0.4, ry: 0.3, from: 230, to: 490)]),
            ("6", [p([(0.75, 0), (0.4, 0.2), (0.15, 0.55)]) + arc(cx: 0.5, cy: 0.72, rx: 0.36, ry: 0.28, from: 180, to: 540)]),
            ("7", [p([(0.05, 0), (0.95, 0), (0.4, 1)])]),
            ("7", [p([(0.05, 0), (0.95, 0), (0.4, 1)]), p([(0.3, 0.5), (0.85, 0.5)])]),
            ("7", [p([(0.05, 0.15), (0.05, 0), (0.95, 0), (0.55, 1)])]),
            ("8", [arc(cx: 0.5, cy: 0.25, rx: 0.3, ry: 0.25, from: 90, to: -270) + arc(cx: 0.5, cy: 0.75, rx: 0.38, ry: 0.25, from: -90, to: 270)]),
            ("8", [arc(cx: 0.5, cy: 0.25, rx: 0.3, ry: 0.25, from: 0, to: 360), arc(cx: 0.5, cy: 0.75, rx: 0.38, ry: 0.25, from: 0, to: 360)]),
            ("9", [arc(cx: 0.5, cy: 0.3, rx: 0.36, ry: 0.3, from: 0, to: -360) + p([(0.86, 0.3), (0.86, 1)])]),
            ("9", [arc(cx: 0.5, cy: 0.3, rx: 0.36, ry: 0.3, from: 0, to: -360) + p([(0.86, 0.3), (0.75, 0.75), (0.45, 1)])]),
        ]
        return defs.map { digit, strokes in
            var raw: [(CGPoint, Int)] = []
            for (i, s) in strokes.enumerated() { for pt in s { raw.append((pt, i)) } }
            return Template(digit: digit, cloud: normalize(raw))
        }
    }()

    // MARK: - $P

    private static func normalize(_ raw: [(CGPoint, Int)]) -> [CGPoint] {
        var pts = resample(raw, to: n)
        // Scale uniformly so the aspect ratio (narrow 1 vs. wide 0) still counts.
        let xs = pts.map(\.x), ys = pts.map(\.y)
        let size = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!, 0.0001)
        let minX = xs.min()!, minY = ys.min()!
        pts = pts.map { CGPoint(x: ($0.x - minX) / size, y: ($0.y - minY) / size) }
        let cx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
        let cy = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
        return pts.map { CGPoint(x: $0.x - cx, y: $0.y - cy) }
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func resample(_ raw: [(CGPoint, Int)], to count: Int) -> [CGPoint] {
        var path = 0.0 as CGFloat
        for i in 1..<raw.count where raw[i].1 == raw[i - 1].1 { path += dist(raw[i].0, raw[i - 1].0) }
        guard path > 0 else { return Array(repeating: raw[0].0, count: count) }
        let step = path / CGFloat(count - 1)
        var out = [raw[0].0]
        var acc: CGFloat = 0
        var pts = raw
        var i = 1
        while i < pts.count {
            if pts[i].1 == pts[i - 1].1 {
                let d = dist(pts[i - 1].0, pts[i].0)
                if acc + d >= step && d > 0 {
                    let t = (step - acc) / d
                    let q = CGPoint(x: pts[i - 1].0.x + t * (pts[i].0.x - pts[i - 1].0.x),
                                    y: pts[i - 1].0.y + t * (pts[i].0.y - pts[i - 1].0.y))
                    out.append(q)
                    pts.insert((q, pts[i].1), at: i)
                    acc = 0
                } else {
                    acc += d
                }
            }
            i += 1
        }
        while out.count < count { out.append(raw[raw.count - 1].0) }
        return Array(out.prefix(count))
    }

    private static func cloudDistance(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        let step = max(1, Int(Double(a.count).squareRoot()))
        var best = Double.infinity
        for start in stride(from: 0, to: a.count, by: step) {
            best = min(best, greedy(a, b, start), greedy(b, a, start))
        }
        return best
    }

    private static func greedy(_ a: [CGPoint], _ b: [CGPoint], _ start: Int) -> Double {
        var matched = [Bool](repeating: false, count: a.count)
        var sum = 0.0
        var i = start
        repeat {
            var minD = CGFloat.infinity
            var index = 0
            for j in 0..<b.count where !matched[j] {
                let d = dist(a[i], b[j])
                if d < minD { minD = d; index = j }
            }
            matched[index] = true
            let weight = 1 - Double((i - start + a.count) % a.count) / Double(a.count)
            sum += weight * Double(minD)
            i = (i + 1) % a.count
        } while i != start
        return sum
    }
}
