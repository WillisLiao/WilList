import SwiftUI
import UIKit

/// How WilList looks: its one bright colour, the face of its titles, and how the A1 card is drawn.
/// Meadow ships. The others are variations for the owner to compare; debug builds open one with
/// `-look frog` on launch, and `npm run ios:shots` shoots them with `LOOK=frog`.
/// ponytail: four looks behind one switch; delete the ones not chosen.
enum Look: String, CaseIterable {
    /// Green that reads on white (4.5:1), New York titles, a pale green A1 card.
    case meadow
    /// Eat that frog: a deeper green, and the A1 card filled solid so it can't be missed.
    case frog
    /// A student's notebook: rounded titles, square tick boxes, the A1 card outlined with its title highlighted.
    case notebook
    /// One cool bright colour instead of green, with plain bold titles.
    case lagoon

    #if DEBUG
    static let current = UserDefaults.standard.string(forKey: "look").flatMap(Look.init) ?? .meadow
    #else
    static let current = Look.meadow
    #endif

    /// Each darkens with Increase Contrast, so green text on a pale tint still reads.
    var accent: Color {
        switch self {
        case .meadow: Color(hex: 0x12884A, highContrast: 0x0B6B39)
        case .frog: Color(hex: 0x0E7C42, highContrast: 0x0A6034)
        case .notebook: Color(hex: 0x14A04B, highContrast: 0x0D7A37)
        case .lagoon: Color(hex: 0x0A8796, highContrast: 0x066875)
        }
    }

    var titles: Font.Design {
        switch self {
        case .meadow, .frog: .serif
        case .notebook: .rounded
        case .lagoon: .default
        }
    }

    /// The tick box: round, or square like a paper checklist (Notebook).
    var box: (empty: String, done: String) {
        self == .notebook ? ("square", "checkmark.square.fill") : ("circle", "checkmark.circle.fill")
    }

    enum Hero { case pale, solid, outline }

    var hero: Hero {
        switch self {
        case .meadow, .lagoon: .pale
        case .frog: .solid
        case .notebook: .outline
        }
    }
}

extension View {
    /// Tints controls with a variation's colour. Meadow's green is the app's accent colour already,
    /// and tinting it again would turn the black toolbar icons green.
    func lookTint() -> some View { tint(Look.current == .meadow ? nil : Color.brand) }
}

extension Color {
    /// The one bright colour: ticks, the A, the primary button, set values, links. Made once, as
    /// the look can't change while the app runs.
    static let brand = Look.current.accent

    nonisolated init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// One colour normally, another when Increase Contrast is on. Nonisolated: SwiftUI resolves
    /// colours off the main thread, and a main-actor provider there stops the app.
    nonisolated init(hex: UInt32, highContrast: UInt32) {
        let normal = UIColor(Color(hex: hex)), high = UIColor(Color(hex: highContrast))
        self.init(uiColor: UIColor { @Sendable traits in traits.accessibilityContrast == .high ? high : normal })
    }
}
