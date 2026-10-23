import SwiftUI
import UIKit
import WilListCore

// How WilList looks: Lagoon, the owner's pick of four on 2026-10-23. One teal for everything that
// acts or is done, the system's own type, and the A1 on a pale teal card.

extension Color {
    /// The one bright colour: ticks, the A, the primary button, set values, links. Deep enough to
    /// read at 4.5:1 on white and on the A1's pale card, and to carry white words; darker still
    /// with Increase Contrast.
    static let brand = Color(hex: 0x057785, highContrast: 0x04606B)

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

/// The colours courses are drawn in, by the number the plan keeps for each course
/// (`AppState.colorCourses`): the most different first, the app's teal last, as it is already
/// the colour of everything without a course. Each holds white text at 4.5:1 or better.
enum CourseColor {
    static let all: [Color] = [
        Color(hex: 0x2563D8, highContrast: 0x1C4FB0), // blue
        Color(hex: 0xC44A12, highContrast: 0x9E3A0C), // tangerine
        Color(hex: 0x7E3FB3, highContrast: 0x66308F), // plum
        Color(hex: 0x0F8044, highContrast: 0x0B6B39), // green
        Color(hex: 0xC0245E, highContrast: 0x9C1C4B), // raspberry
        Color(hex: 0x9A5800, highContrast: 0x7A4600), // ochre
        Color(hex: 0x3D4F6B, highContrast: 0x2F3E55), // slate
        .brand,
    ]

    /// A course's colour, or the app's own for none.
    static func of(_ number: Int?) -> Color { number.map { all[$0 % all.count] } ?? .brand }

    /// A course's colour lifted to read on the black of the Dynamic Island (5.5:1 or better).
    static func onDark(_ number: Int?) -> Color { number == nil ? .brandOnDark : of(number).mix(with: .white, by: 0.35) }
}

extension EnvironmentValues {
    /// The colour of a field a screen is laid on (Focus, the welcome, Plan tomorrow): a course's,
    /// or the app's own. A letter on it takes it too.
    @Entry var field: Color = .brand
}
