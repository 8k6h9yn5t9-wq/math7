import SwiftUI
import UIKit

extension Color {
    static let brand = Color(light: UIColor(red: 0.184, green: 0.435, blue: 0.871, alpha: 1),
                             dark: UIColor(red: 0.357, green: 0.561, blue: 0.941, alpha: 1))
    static let good = Color(light: UIColor(red: 0.122, green: 0.616, blue: 0.333, alpha: 1),
                            dark: UIColor(red: 0.235, green: 0.812, blue: 0.490, alpha: 1))
    static let bad = Color(light: UIColor(red: 0.839, green: 0.271, blue: 0.271, alpha: 1),
                           dark: UIColor(red: 0.941, green: 0.439, blue: 0.439, alpha: 1))
    static let warn = Color(light: UIColor(red: 0.78, green: 0.467, blue: 0, alpha: 1),
                            dark: UIColor(red: 0.941, green: 0.69, blue: 0.29, alpha: 1))
    static let appBackground = Color(light: UIColor(red: 0.953, green: 0.965, blue: 0.984, alpha: 1),
                                     dark: UIColor(red: 0.063, green: 0.078, blue: 0.11, alpha: 1))
    static let cardFill = Color(light: .white, dark: UIColor(red: 0.102, green: 0.125, blue: 0.188, alpha: 1))
    static let keyFill = Color(light: UIColor(red: 0.933, green: 0.949, blue: 0.973, alpha: 1),
                               dark: UIColor(red: 0.145, green: 0.176, blue: 0.251, alpha: 1))
    static let brandSoft = Color(light: UIColor(red: 0.902, green: 0.937, blue: 1, alpha: 1),
                                 dark: UIColor(red: 0.122, green: 0.173, blue: 0.29, alpha: 1))

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension View {
    func card() -> some View {
        background(RoundedRectangle(cornerRadius: 18).fill(Color.cardFill)
            .shadow(color: .black.opacity(0.06), radius: 7, y: 3))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var expand = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(maxWidth: expand ? .infinity : nil, minHeight: 52)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.brand.opacity(enabled ? 1 : 0.4)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct PillButtonStyle: ButtonStyle {
    var large = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(large ? .headline : .subheadline.weight(.semibold))
            .padding(.horizontal, large ? 22 : 14)
            .frame(minHeight: large ? 52 : 40)
            .foregroundStyle(.primary)
            .background(RoundedRectangle(cornerRadius: large ? 14 : 11).fill(Color.keyFill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Progress ring for today's goal.
struct GoalRing: View {
    let done: Int
    let goal: Int
    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 7)
            Circle().trim(from: 0, to: min(1, CGFloat(done) / CGFloat(max(goal, 1))))
                .stroke(Color.good, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(goal)").font(.caption.weight(.bold))
        }
        .frame(width: 58, height: 58)
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule().fill(Color.good).frame(width: g.size.width * CGFloat(max(0, min(1, value))))
            }
        }
        .frame(height: 8)
    }
}
