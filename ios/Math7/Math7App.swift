import SwiftUI

@main
struct Math7App: App {
    @StateObject private var store = Store()
    @StateObject private var gate = GateManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(gate)
                .onAppear { gate.sync(store: store) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { gate.sync(store: store) }
                }
        }
    }
}

enum Route: Equatable {
    case home, unit(String), practice, parent
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    @State private var route: Route = .home
    @State private var session: PracticeSession?
    @State private var tick = 0 // forces home to refresh after practice

    var body: some View {
        Group {
            switch route {
            case .home:
                HomeView(start: start, openUnit: { route = .unit($0) }, openParent: { route = .parent })
                    .id(tick)
            case .unit(let id):
                UnitView(unitID: id, start: start, back: { route = .home })
            case .practice:
                if let s = session { PracticeContainer(session: s, home: goHome, again: { start(s.kind) }) }
            case .parent:
                ParentView(done: goHome)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: route)
    }

    private func start(_ kind: SessionKind) {
        let s = PracticeSession(kind: kind, store: store)
        let st = store, g = gate
        s.onRecord = { [weak st, weak g] in
            guard let st = st else { return }
            g?.sync(store: st)
        }
        session = s
        route = .practice
    }

    private func goHome() {
        session = nil
        tick += 1
        route = .home
    }
}

/// Switches from the problems to the score screen when the session ends.
struct PracticeContainer: View {
    @ObservedObject var session: PracticeSession
    var home: () -> Void
    var again: () -> Void

    var body: some View {
        if session.finished != nil {
            SummaryView(session: session, home: home, again: again)
        } else {
            PracticeView(session: session, onStop: home)
        }
    }
}
