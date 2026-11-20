import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen a locked game shows: tells him how many problems are left.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private var defaults: UserDefaults {
        var id = Bundle.main.bundleIdentifier ?? "math7"
        if let dot = id.lastIndex(of: ".") { id = String(id[..<dot]) }
        return UserDefaults(suiteName: "group." + id) ?? .standard
    }

    private func make() -> ShieldConfiguration {
        let d = defaults
        let today: String = {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }()
        let solved = d.string(forKey: "gate.progressDay") == today ? d.integer(forKey: "gate.solvedToday") : 0
        let goal = max(1, d.integer(forKey: "gate.goal"))
        let left = max(0, goal - solved)
        let subtitle = left > 0
            ? "Solve \(left) more problem\(left == 1 ? "" : "s") in Math 7 to unlock this. You've done \(solved) of \(goal) today."
            : "Open Math 7 to unlock your play time."
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: nil,
            icon: UIImage(systemName: "function"),
            title: ShieldConfiguration.Label(text: "Math first!", color: .label),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }
}
