import SwiftUI
import WilListCore

/// A letter mark: a chip in the letter's colour, the usual order of urgency from red to blue. E
/// is struck out too, and no letter yet is a dashed grey outline.
struct LetterMark: View {
    let letter: Letter?
    var label: String?
    var large = false
    /// On a card filled with colour, the A turns white with its letter in that colour (`field`)
    /// and the other letters are drawn in white.
    var onBrand = false
    @Environment(\.field) private var field

    var body: some View {
        let text = label ?? letter?.rawValue ?? "–"
        Text(text)
            .font(large ? .headline : .footnote.weight(.semibold))
            .monospacedDigit()
            .strikethrough(letter == .E)
            // A mark never wraps, however narrow the space it's offered: "A1" stays on one line.
            .fixedSize()
            .foregroundStyle(ink)
            .padding(.horizontal, text.count > 1 ? 6 : 0)
            .frame(minWidth: large ? 40 : 30, minHeight: large ? 32 : 26)
            // Past the largest standard size a letter would outgrow its round mark.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .background(fill, in: Capsule())
            .overlay {
                if letter == nil || (onBrand && letter != .A) {
                    Capsule().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1.25, dash: letter == .D || letter == nil ? [3, 2] : []))
                }
            }
            .accessibilityLabel(letter.map { "Priority \(label ?? $0.rawValue)" } ?? "No letter")
    }

    // Fixed colours, not hierarchical styles: inside a button those pick up the tint, and the
    // letters must read the same everywhere.
    private var fill: Color {
        guard let letter else { return .clear }
        if onBrand { return letter == .A ? .white : .clear }
        return letter.color
    }

    private var ink: Color {
        guard let letter else { return onBrand ? .white : .secondary }
        if onBrand { return letter == .A ? field : .white }
        return letter.ink
    }

    private var stroke: Color {
        onBrand ? .white.opacity(letter == .B ? 1 : 0.6) : Color(.tertiaryLabel)
    }
}

extension Letter {
    /// The letter's colour, the usual order of urgency: red, orange, yellow, green, blue.
    var color: Color {
        switch self {
        case .A: Color(hex: 0xD92D20)
        case .B: Color(hex: 0xFF9500)
        case .C: Color(hex: 0xFFCC00)
        case .D: Color(hex: 0x34C759)
        case .E: Color(hex: 0x2563EB)
        }
    }

    /// The letter's words on its colour, 4.8:1 or better: white on the red and the blue, a deep
    /// shade of the colour on the three light ones.
    var ink: Color {
        switch self {
        case .A, .E: .white
        case .B: Color(hex: 0x4A2500)
        case .C: Color(hex: 0x4A3B00)
        case .D: Color(hex: 0x0A3316)
        }
    }

    /// Tracy's name for each letter.
    var name: String {
        switch self {
        case .A: "Must do"
        case .B: "Should do"
        case .C: "Nice to do"
        case .D: "Delegate"
        case .E: "Eliminate"
        }
    }

    /// What the letter means, in plain words.
    var detail: String {
        switch self {
        case .A: "Serious consequences"
        case .B: "Mild consequences"
        case .C: "No consequences"
        case .D: "Hand it off"
        case .E: "Drop it"
        }
    }

    var meaning: String { "\(name): \(detail.prefix(1).lowercased())\(detail.dropFirst())." }
}
