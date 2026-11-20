import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import PencilKit

/// The box he writes his answer in. Reads it ~0.7 s after he stops writing.
struct HandwritingPad: UIViewRepresentable {
    var clearToken: Int
    var onRead: (String?) -> Void
    var onEmpty: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = InkCanvas()
        v.tool = PKInkingTool(.pen, color: .black, width: 7)
        v.backgroundColor = .clear
        v.isOpaque = false
        v.isScrollEnabled = false
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastClear != clearToken {
            context.coordinator.lastClear = clearToken
            v.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: HandwritingPad
        var lastClear: Int
        private var timer: Timer?
        private var generation = 0

        init(_ p: HandwritingPad) { parent = p; lastClear = p.clearToken }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            timer?.invalidate()
            generation += 1
            let drawing = canvasView.drawing
            if drawing.strokes.isEmpty { parent.onEmpty(); return }
            let gen = generation
            timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
                HandwritingRecognizer.recognize(drawing) { result in
                    guard let self = self, gen == self.generation else { return } // he kept writing
                    self.parent.onRead(result?.text)
                }
            }
        }
    }
}

/// A canvas that works inside a ScrollView and handles Pencil vs. finger.
/// - Drags inside the canvas draw instead of scrolling the page around it.
/// - Fingers (or the mouse in the Simulator) draw until an Apple Pencil touches any canvas;
///   after that only the Pencil draws, so a resting palm doesn't leave marks.
final class InkCanvas: PKCanvasView {
    static var pencilSeen = false
    private static let pencilNotice = Notification.Name("math7.pencilSeen")
    private weak var linkedScroll: UIScrollView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawingPolicy = InkCanvas.pencilSeen ? .pencilOnly : .anyInput
        let watcher = PencilWatcher { InkCanvas.notePencil() }
        addGestureRecognizer(watcher)
        NotificationCenter.default.addObserver(self, selector: #selector(pencilNotified), name: InkCanvas.pencilNotice, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private static func notePencil() {
        guard !pencilSeen else { return }
        pencilSeen = true
        NotificationCenter.default.post(name: pencilNotice, object: nil)
    }

    @objc private func pencilNotified() { drawingPolicy = .pencilOnly }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // Make any scroll view we sit in wait until our drawing gesture fails.
        var v = superview
        while let current = v {
            if let scroll = current as? UIScrollView, scroll !== linkedScroll {
                scroll.panGestureRecognizer.require(toFail: drawingGestureRecognizer)
                linkedScroll = scroll
                break
            }
            v = current.superview
        }
    }
}

/// Watches touches without interfering, to notice when an Apple Pencil is used.
private final class PencilWatcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onPencil: () -> Void
    init(onPencil: @escaping () -> Void) {
        self.onPencil = onPencil
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.contains(where: { $0.type == .pencil }) { onPencil() }
        state = .failed
    }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// Scratch paper next to the problem.
struct ScratchPad: UIViewRepresentable {
    enum Tool { case pen, eraser }
    var tool: Tool
    var clearToken: Int

    func makeCoordinator() -> Box { Box(clearToken) }
    final class Box { var lastClear: Int; init(_ c: Int) { lastClear = c } }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = InkCanvas()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.alwaysBounceVertical = false
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {
        v.tool = tool == .pen ? PKInkingTool(.pen, color: .black, width: 3) : PKEraserTool(.vector)
        if context.coordinator.lastClear != clearToken {
            context.coordinator.lastClear = clearToken
            v.drawing = PKDrawing()
        }
    }
}

/// Graph-paper background for the scratch pad.
struct GridBackground: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            stride(from: 0, through: size.width, by: 32).forEach { x in
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: 0, through: size.height, by: 32).forEach { y in
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.secondary.opacity(0.18)), lineWidth: 1)
        }
    }
}
