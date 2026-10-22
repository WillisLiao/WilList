import SwiftUI
import WilListCore

/// A letter mark. Letters differ by intensity, not by hue: A is the one filled in the accent,
/// B is outlined in ink, C is grey, D is dashed (someone else does it) and E is struck out.
struct LetterMark: View {
    let letter: Letter?
    var label: String?
    var large = false
    /// On a card filled with the brand colour, the A turns white with a green letter and the
    /// other letters are drawn in white.
    var onBrand = false

    var body: some View {
        let text = label ?? letter?.rawValue ?? "–"
        Text(text)
            .font(large ? .headline : .footnote.weight(.semibold))
            .monospacedDigit()
            .strikethrough(letter == .E)
            .foregroundStyle(ink)
            .padding(.horizontal, text.count > 1 ? 6 : 0)
            .frame(minWidth: large ? 40 : 30, minHeight: large ? 32 : 26)
            // Past the largest standard size a letter would outgrow its round mark.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .background(letter == .A ? (onBrand ? Color.white : Color.brand) : Color.clear, in: Capsule())
            .overlay {
                if letter != .A {
                    Capsule().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1.25, dash: letter == .D || letter == nil ? [3, 2] : []))
                }
            }
            .accessibilityLabel(letter.map { "Priority \(label ?? $0.rawValue)" } ?? "No letter")
    }

    // Fixed colours, not hierarchical styles: inside a button those pick up the tint, and the
    // letters must read the same everywhere.
    private var ink: Color {
        switch letter {
        case .A: onBrand ? .brand : .white
        case .B: onBrand ? .white : .primary
        default: onBrand ? .white.opacity(0.75) : .secondary
        }
    }

    private var stroke: Color {
        if onBrand { return .white.opacity(letter == .B ? 1 : 0.6) }
        return letter == .B ? .primary : Color(.tertiaryLabel)
    }
}

extension Letter {
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
        case .A: "Serious consequences if not done"
        case .B: "Mild consequences"
        case .C: "No consequences either way"
        case .D: "Someone else can do it"
        case .E: "Drop it"
        }
    }

    var meaning: String { "\(name): \(detail.prefix(1).lowercased())\(detail.dropFirst())." }
}
