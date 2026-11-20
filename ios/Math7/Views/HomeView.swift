import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    var start: (SessionKind) -> Void
    var openUnit: (String) -> Void
    var openParent: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 270), spacing: 14)]

    var body: some View {
        let cur = store.currentUnit
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if gate.isActive { GateBanner() }
                hero(cur)
                LazyVGrid(columns: columns, spacing: 14) {
                    if !store.reviewSkillIDs.isEmpty {
                        ActionCard(icon: "↻", title: "Review mix", subtitle: "Earlier units, weakest skills first") { start(.review) }
                    }
                    ActionCard(icon: "🎯", title: "Fix my mistakes", subtitle: "Skills with the lowest scores") { start(.weak) }
                }
                Text("All units").font(.title2.bold())
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.units) { u in UnitCard(unit: u, isCurrent: u.id == cur.id) { openUnit(u.id) } }
                }
                HStack {
                    Text("Units follow the class pacing. A parent can change the current unit.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: openParent) { Label("Parent", systemImage: "lock.fill") }
                        .buttonStyle(PillButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.data.settings.name.isEmpty ? "Math 7 Practice" : "Hi, \(store.data.settings.name)!")
                    .font(.largeTitle.bold())
                Text(store.goalMetToday ? "Daily goal done. Nice work!" : "Today: \(store.solvedToday) of \(store.goal) problems solved")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("🔥 \(store.streak) day\(store.streak == 1 ? "" : "s")")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color.cardFill))
            GoalRing(done: store.solvedToday, goal: store.goal)
        }
    }

    private func hero(_ cur: UnitInfo) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("IN CLASS NOW · UNIT \(cur.n)").font(.caption.weight(.bold)).opacity(0.85)
                Text(cur.name).font(.title.bold())
                Text(cur.short).opacity(0.9)
            }
            Spacer()
            Button { start(.unit(cur.id)) } label: {
                Label("Practice \(PracticeSession.length)", systemImage: "play.fill")
                    .font(.title3.bold())
                    .padding(.horizontal, 24).frame(minHeight: 58)
                    .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.75))
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 22).fill(
            LinearGradient(colors: [.brand, Color(red: 0.416, green: 0.361, blue: 0.941)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

/// Shows whether games are locked and what it takes to unlock them.
struct GateBanner: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager

    var body: some View {
        HStack(spacing: 14) {
            Text(gate.unlocked ? "🎮" : "🔒").font(.system(size: 34))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if store.gateMode == "minutes" && !gate.unlocked && store.unlocksLeftToday > 0 {
                Button("Unlock \(store.unlockMinutes) min") { gate.startEarnedSession(store: store) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(gate.unlocked ? Color.good.opacity(0.14) : Color.brandSoft))
    }

    private var left: Int { max(0, store.goal - store.solvedToday) }

    private var title: String {
        if gate.unlocked {
            if let until = gate.earnedUntil { return "Games unlocked until \(until.formatted(date: .omitted, time: .shortened))" }
            return "Games unlocked for today!"
        }
        if store.gateMode == "minutes" && store.unlocksLeftToday > 0 {
            return "You earned \(store.unlocksLeftToday) play session\(store.unlocksLeftToday == 1 ? "" : "s")!"
        }
        return "Games are locked"
    }

    private var subtitle: String {
        if gate.unlocked { return "Great work on today's math." }
        if store.gateMode == "minutes" {
            if store.unlocksLeftToday > 0 { return "Tap Unlock when you're ready to play." }
            let toNext = store.goal - store.solvedToday % store.goal
            return "Solve \(toNext) more problem\(toNext == 1 ? "" : "s") to earn \(store.unlockMinutes) minutes of play."
        }
        if store.goalMetToday { return "Games are locked for now. Ask a parent." }
        return "Solve \(left) more problem\(left == 1 ? "" : "s") to unlock them."
    }
}

struct ActionCard: View {
    let icon: String, title: String, subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconTile(icon: icon, filled: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct UnitCard: View {
    @EnvironmentObject var store: Store
    let unit: UnitInfo
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        let m = store.unitMastery(unit)
        let att = store.unitAttempts(unit)
        Button(action: action) {
            HStack(spacing: 14) {
                IconTile(icon: unit.icon, filled: isCurrent)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(unit.n). \(unit.name)").font(.headline).lineLimit(2)
                        if isCurrent { Tag(text: "Now", color: .brand) }
                        else if m >= 0.8 { Tag(text: "★ Mastered", color: .good) }
                    }
                    Text(att > 0 ? "\(Int((m * 100).rounded()))% mastery · \(att) solved" : unit.short)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    ProgressBar(value: m).padding(.top, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct IconTile: View {
    let icon: String
    let filled: Bool
    var body: some View {
        Text(icon).font(.system(size: 24, weight: .heavy))
            .frame(width: 50, height: 50)
            .foregroundStyle(filled ? Color.white : Color.brand)
            .background(RoundedRectangle(cornerRadius: 14).fill(filled ? Color.brand : Color.brandSoft))
    }
}

struct Tag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}
