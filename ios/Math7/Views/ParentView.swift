import SwiftUI
import UniformTypeIdentifiers

struct ParentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    var done: () -> Void

    @State private var unlocked = false

    var body: some View {
        if unlocked {
            ParentDashboard(done: done, lock: { unlocked = false; done() })
        } else {
            PinView(onSuccess: { unlocked = true }, onCancel: done)
        }
    }
}

// MARK: - PIN

struct PinView: View {
    @EnvironmentObject var store: Store
    var onSuccess: () -> Void
    var onCancel: () -> Void
    var forceCreate = false

    @State private var entry = ""
    @State private var first = ""
    @State private var stage: Stage = .enter
    @State private var message: String?
    enum Stage { case enter, create, confirm }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onCancel) { Label("Back", systemImage: "chevron.left") }.buttonStyle(PillButtonStyle())
                Spacer()
            }
            Spacer()
            VStack(spacing: 18) {
                Text("🔒 " + title).font(.title2.bold())
                if stage == .create {
                    Text("This keeps the parent view and the game lock settings private.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle().fill(i < entry.count ? Color.brand : Color.secondary.opacity(0.25)).frame(width: 18, height: 18)
                    }
                }
                if let m = message { Text(m).foregroundStyle(Color.bad).font(.subheadline) }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 12), count: 3), spacing: 12) {
                    ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"], id: \.self) { k in
                        if k.isEmpty { Color.clear.frame(height: 64) } else {
                            Button { press(k) } label: {
                                Text(k).font(.system(size: 28, weight: .semibold))
                                    .frame(width: 90, height: 64)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.keyFill))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if stage == .enter {
                    Text("Forgot the PIN? Delete and reinstall the app. Back up progress first from this screen next time.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
                }
            }
            .padding(30).card()
            Spacer()
        }
        .padding(20)
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { stage = (forceCreate || store.data.settings.pin == nil) ? .create : .enter }
    }

    private var title: String {
        switch stage {
        case .enter: return "Enter parent PIN"
        case .create: return "Create a 4-digit parent PIN"
        case .confirm: return "Enter the PIN again"
        }
    }

    private func press(_ k: String) {
        message = nil
        if k == "⌫" { if !entry.isEmpty { entry.removeLast() }; return }
        guard entry.count < 4 else { return }
        entry += k
        guard entry.count == 4 else { return }
        let pin = entry
        entry = ""
        switch stage {
        case .create:
            first = pin; stage = .confirm
        case .confirm:
            if pin == first {
                store.data.settings.pin = Store.hashPIN(pin)
                store.save()
                onSuccess()
            } else {
                stage = .create; message = "PINs didn't match. Try again."
            }
        case .enter:
            if Store.hashPIN(pin) == store.data.settings.pin { onSuccess() } else { message = "Wrong PIN" }
        }
    }
}

// MARK: - Dashboard

struct ParentDashboard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    var done: () -> Void
    var lock: () -> Void

    @State private var importing = false
    @State private var confirmReset = false
    @State private var changingPIN = false
    @State private var toast: String?

    private let goals = [5, 10, 15, 20, 25, 30]

    var body: some View {
        if changingPIN {
            PinView(onSuccess: { changingPIN = false; flash("PIN changed") }, onCancel: { changingPIN = false }, forceCreate: true)
        } else {
            dashboard
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Button(action: done) { Label("Done", systemImage: "chevron.left") }.buttonStyle(PillButtonStyle())
                    Spacer()
                    Text("Parent view").font(.title.bold())
                    Spacer()
                    Button(action: lock) { Label("Lock", systemImage: "lock.fill") }.buttonStyle(PillButtonStyle())
                }
                if let t = toast {
                    Text(t).font(.subheadline.weight(.semibold)).padding(10).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.good.opacity(0.15)))
                }
                overview
                settings
                GateSettingsSection()
                skillsTable
                mistakes
                sessions
                dataSection
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result, store.restore(from: url) {
                flash("Backup restored"); gate.sync(store: store)
            } else { flash("That file is not a valid backup") }
        }
        .alert("Erase all progress?", isPresented: $confirmReset) {
            Button("Erase", role: .destructive) { store.resetProgress(); gate.sync(store: store); flash("Progress erased") }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Settings and PIN are kept.") }
    }

    private func flash(_ s: String) {
        toast = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if toast == s { toast = nil } }
    }

    // MARK: Overview

    private var last14: [(Date, DayStat)] {
        (0..<14).reversed().map { i in
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            return (d, store.data.days[Store.dayKey(d)] ?? DayStat())
        }
    }

    private var overview: some View {
        let days = last14
        let week = days.suffix(7)
        let wn = week.reduce(0) { $0 + $1.1.n }
        let wc = week.reduce(0) { $0 + $1.1.c }
        let ws = week.reduce(0) { $0 + ($1.1.secs ?? 0) }
        let maxN = max(5, days.map(\.1.n).max() ?? 0)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Kpi(value: "\(wn)", label: "Problems, last 7 days")
                Kpi(value: wn > 0 ? "\(Int((Double(wc) / Double(wn) * 100).rounded()))%" : "—", label: "Correct on first try")
                Kpi(value: "\(ws / 60) min", label: "Practice time, 7 days")
                Kpi(value: "🔥 \(store.streak)", label: "Day streak (goal \(store.goal)/day)")
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let (d, v) = day
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(v.n > 0 ? Color.brand : Color.secondary.opacity(0.2))
                            .frame(height: max(3, CGFloat(v.n) / CGFloat(maxN) * 120))
                        Text(String(d.formatted(.dateTime.weekday(.narrow)))).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 145, alignment: .bottom)
            Text("Problems per day, last 14 days").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(18).card()
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.title2.bold())
            LabeledPicker(label: "Current class unit") {
            Picker("Current class unit", selection: Binding(
                get: { store.data.settings.unitOverride ?? "" },
                set: { store.data.settings.unitOverride = $0.isEmpty ? nil : $0; store.save(); flash("Current unit updated") })) {
                Text("Auto: follow class pacing (now Unit \(store.engine.unit(store.pacedUnitID)?.n ?? 1))").tag("")
                ForEach(store.units) { u in Text("Unit \(u.n): \(u.name)").tag(u.id) }
            }
            }
            LabeledPicker(label: "Daily goal (problems solved correctly)") {
            Picker("Daily goal", selection: Binding(
                get: { store.data.settings.goal },
                set: { store.data.settings.goal = $0; store.save(); gate.sync(store: store); flash("Daily goal updated") })) {
                ForEach(goals, id: \.self) { Text("\($0) problems").tag($0) }
                if !goals.contains(store.data.settings.goal) {
                    Text("\(store.data.settings.goal) problems").tag(store.data.settings.goal)
                }
            }
            }
            HStack {
                Text("Student's name")
                TextField("Name (optional)", text: Binding(
                    get: { store.data.settings.name },
                    set: { store.data.settings.name = String($0.prefix(20)); store.save() }))
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            }
            Text("Only correct answers (first or second try) count toward the daily goal. \"Show me how\" doesn't count. Auto pacing follows the teacher's 2026–27 slides.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(18).card()
    }

    // MARK: Skills

    private var skillsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills by unit").font(.title2.bold())
            HStack {
                Text("Skill").frame(maxWidth: .infinity, alignment: .leading)
                Text("Tried").frame(width: 70, alignment: .trailing)
                Text("Recent").frame(width: 80, alignment: .trailing)
                Text("Level").frame(width: 60, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(store.units) { u in
                HStack(spacing: 6) {
                    Text("Unit \(u.n): \(u.name)").bold()
                    if u.id == store.currentUnitID { Tag(text: "Now", color: .brand) }
                }
                .padding(.top, 10)
                ForEach(u.skills) { s in
                    let st = store.stat(s.id)
                    let m = store.mastery(s.id)
                    HStack {
                        Text(s.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(st?.att ?? 0)").frame(width: 70, alignment: .trailing)
                        Text(m.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                            .bold().foregroundStyle(m == nil ? Color.secondary : m! >= 0.8 ? Color.good : m! < 0.5 ? Color.bad : Color.warn)
                            .frame(width: 80, alignment: .trailing)
                        Text("\(st?.level ?? 1)").frame(width: 60, alignment: .trailing)
                    }
                    .font(.subheadline)
                    Divider()
                }
            }
            Text("\"Recent\" is the share right on the first try over the last 10 problems. Level (1–3) goes up or down automatically.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(18).card()
    }

    // MARK: Mistakes and sessions

    private func when(_ t: Double) -> String {
        Date(timeIntervalSince1970: t / 1000).formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var mistakes: some View {
        let list = Array(store.data.log.filter { !$0.ok }.suffix(15).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recent mistakes").font(.title2.bold())
            if list.isEmpty { Text("No mistakes yet.").foregroundStyle(.secondary) }
            ForEach(Array(list.enumerated()), id: \.offset) { _, l in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(when(l.t)) · \(store.engine.skill(l.skill)?.name ?? l.skill)\(l.how == "pencil" ? " · ✏️" : "")")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(l.q).font(.subheadline.weight(.semibold))
                    (Text("Answered: ") + Text(l.given.isEmpty ? "(asked for help)" : l.given).bold().foregroundColor(.bad)
                     + Text(" · Correct: ") + Text(l.correct).bold().foregroundColor(.good)).font(.subheadline)
                }
                Divider()
            }
        }
        .padding(18).card()
    }

    private var sessions: some View {
        let list = Array(store.data.sessions.suffix(10).reversed())
        return VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions").font(.title2.bold())
            if list.isEmpty { Text("No sessions yet.").foregroundStyle(.secondary) }
            ForEach(Array(list.enumerated()), id: \.offset) { _, s in
                HStack {
                    Text(when(s.t)).frame(width: 150, alignment: .leading).foregroundStyle(.secondary)
                    Text(s.title).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(s.c)/\(s.n)").frame(width: 60, alignment: .trailing)
                    Text("\(s.secs / 60) min").frame(width: 70, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(18).card()
    }

    // MARK: Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data").font(.title2.bold())
            Text("Progress is saved on this iPad only. Backups also work with the web version of Math 7.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if let url = store.backupFile() {
                    ShareLink(item: url) { Label("Back up progress", systemImage: "square.and.arrow.up") }
                        .buttonStyle(PillButtonStyle())
                }
                Button { importing = true } label: { Label("Restore backup", systemImage: "square.and.arrow.down") }
                    .buttonStyle(PillButtonStyle())
                Button("Change PIN") { changingPIN = true }.buttonStyle(PillButtonStyle())
                Button(role: .destructive) { confirmReset = true } label: {
                    Text("Reset all progress").foregroundStyle(Color.bad)
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .padding(18).card()
    }
}

struct Kpi: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title.bold())
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appBackground))
    }
}

struct LabeledPicker<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content.pickerStyle(.menu)
        }
    }
}
