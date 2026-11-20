import SwiftUI

struct UnitView: View {
    @EnvironmentObject var store: Store
    let unitID: String
    var start: (SessionKind) -> Void
    var back: () -> Void

    var body: some View {
        let u = store.engine.unit(unitID) ?? store.currentUnit
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: back) { Label("Back", systemImage: "chevron.left") }.buttonStyle(PillButtonStyle())
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unit \(u.n)").foregroundStyle(.secondary)
                        Text(u.name).font(.largeTitle.bold())
                        Text(u.short).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { start(.unit(u.id)) } label: { Label("Practice whole unit", systemImage: "play.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20).card()
                Text("Skills").font(.title2.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
                    ForEach(u.skills) { s in
                        Button { start(.skill(s.id)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.name).font(.headline)
                                    Text(detail(s.id)).font(.subheadline).foregroundStyle(.secondary)
                                    ProgressBar(value: store.mastery(s.id) ?? 0).padding(.top, 4)
                                }
                                Image(systemName: "play.fill").foregroundStyle(.secondary)
                            }
                            .padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).card()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func detail(_ id: String) -> String {
        guard let st = store.stat(id), st.att > 0 else { return "Not started yet" }
        return "\(Int(((store.mastery(id) ?? 0) * 100).rounded()))% recently · level \(st.level) · \(st.att) tried"
    }
}

struct SummaryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    @ObservedObject var session: PracticeSession
    var home: () -> Void
    var again: () -> Void

    var body: some View {
        let d = session.finished ?? (0, 0, 0)
        let pct = d.n > 0 ? Double(d.c) / Double(d.n) : 0
        ScrollView {
            VStack(spacing: 14) {
                Text(session.title).foregroundStyle(.secondary)
                Text("\(d.c) / \(d.n)").font(.system(size: 64, weight: .heavy))
                Text(pct == 1 ? "Perfect score! 🏆" : pct >= 0.8 ? "Excellent work! 🌟" : pct >= 0.6 ? "Good effort, keep going! 💪" : "Every mistake is practice. Try again! 🌱")
                    .font(.title2.bold())
                Text("\(d.secs / 60) min \(d.secs % 60) s · \(store.solvedToday) solved today · 🔥 \(store.streak) day streak")
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(Array(session.results.enumerated()), id: \.offset) { _, r in
                        Circle().fill(r ? Color.good : Color.bad).frame(width: 14, height: 14)
                    }
                }
                .padding(.vertical, 8)
                if gate.isActive { GateBanner() }
                HStack(spacing: 12) {
                    Button("Home", action: home).buttonStyle(PillButtonStyle(large: true))
                    Button("Practice again", action: again).buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(30)
            .frame(maxWidth: 600)
            .card()
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}
