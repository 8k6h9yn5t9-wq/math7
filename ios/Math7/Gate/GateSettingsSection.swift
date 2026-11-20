import SwiftUI
import FamilyControls

/// Parent view section for locking Roblox (or any apps) until the daily goal is met.
struct GateSettingsSection: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var gate: GateManager
    @State private var picking = false
    @State private var pickerSelection = FamilyActivitySelection()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Game lock").font(.title2.bold())
            if !GateManager.isBuiltIn {
                notBuiltIn
            } else if !gate.isAuthorized {
                authorize
            } else {
                configured
            }
            if let e = gate.lastError { Text(e).font(.footnote).foregroundStyle(Color.bad) }
        }
        .padding(18).card()
    }

    private var notBuiltIn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lock Roblox until today's math is done.").font(.headline)
            Text("This uses Apple's Screen Time controls, which Apple only allows in apps built with a paid Apple Developer account ($99/year). Once you have one, pick the \"Math7 with Roblox Lock\" scheme in Xcode and run it on this iPad. SETUP.md has the steps.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var authorize: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 1: allow Screen Time control").font(.headline)
            Text("On your child's iPad, tap below and sign in with your parent Apple Account when asked. After that he can't turn the lock off or delete Math 7 without you.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("This is my child's iPad (Family Sharing)") { Task { await gate.requestAuthorization(child: true) } }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Use without Family Sharing") { Task { await gate.requestAuthorization(child: false) } }
                    .buttonStyle(PillButtonStyle(large: true))
            }
        }
    }

    private var configured: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps and websites to lock").font(.headline)
                    selectionSummary
                }
                Spacer()
                Button(gate.hasSelection ? "Change" : "Choose apps") {
                    pickerSelection = gate.selection
                    picking = true
                }
                .buttonStyle(PillButtonStyle(large: true))
            }
            Text("Pick Roblox under Games, and also roblox.com under Websites so it can't be played in Safari.")
                .font(.footnote).foregroundStyle(.secondary)

            Toggle("Lock these until the daily goal is met", isOn: Binding(
                get: { gate.enabled }, set: { gate.setEnabled($0, store: store) }))
                .disabled(!gate.hasSelection)

            if gate.enabled {
                LabeledPicker(label: "When the goal is met") {
                    Picker("When the goal is met", selection: Binding(
                        get: { store.gateMode == "minutes" ? store.unlockMinutes : 0 },
                        set: { v in
                            store.data.settings.gateMode = v == 0 ? "day" : "minutes"
                            if v > 0 { store.data.settings.unlockMinutes = v }
                            store.save(); gate.sync(store: store)
                        })) {
                        Text("Unlock for the rest of the day").tag(0)
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text("Unlock \($0) min per goal").tag($0) }
                    }
                }
                if store.gateMode == "minutes" {
                    Text("He taps Unlock when he wants to play. Each extra \(store.goal) problems solved earns another \(store.unlockMinutes) minutes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                LabeledPicker(label: "Lock again at bedtime") {
                    Picker("Bedtime", selection: Binding(get: { gate.bedtimeMinutes }, set: { gate.setBedtime($0, store: store) })) {
                        Text("Off").tag(0)
                        ForEach(Array(stride(from: 17 * 60, through: 23 * 60 + 30, by: 30)), id: \.self) { m in
                            Text(timeLabel(m)).tag(m)
                        }
                    }
                }
                Toggle("Don't allow deleting apps", isOn: Binding(get: { gate.protectApps }, set: { gate.setProtectApps($0) }))
                Text("Stops apps (including Math 7) from being deleted on this iPad while on. Turn it off here when you need to delete something.")
                    .font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(gate.unlocked ? "Right now: unlocked 🎮" : "Right now: locked 🔒").bold()
                    Spacer()
                    Button("Lock for today") { gate.parentLockToday(store: store) }.buttonStyle(PillButtonStyle())
                    Button("Unlock for today") { gate.parentUnlockToday(store: store) }.buttonStyle(PillButtonStyle())
                }
            }
        }
        .familyActivityPicker(isPresented: $picking, selection: $pickerSelection)
        .onChange(of: pickerSelection) { _, newValue in
            gate.setSelection(newValue, store: store)
        }
    }

    @ViewBuilder
    private var selectionSummary: some View {
        let s = gate.selection
        if !gate.hasSelection {
            Text("Nothing chosen yet").font(.subheadline).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(s.applicationTokens), id: \.self) { Label($0).font(.subheadline) }
                ForEach(Array(s.webDomainTokens), id: \.self) { Label($0).font(.subheadline) }
                ForEach(Array(s.categoryTokens), id: \.self) { Label($0).font(.subheadline) }
            }
        }
    }

    private func timeLabel(_ minutes: Int) -> String {
        var c = DateComponents(); c.hour = minutes / 60; c.minute = minutes % 60
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}
