import SwiftUI

// The sketch hand. WilList is Tracy's *written* list: you letter each task with a pen and circle
// the one that comes first. So the marks that say "this one" are drawn rather than set, by one pen
// with one wobble, in five places and no more: the check on every row, the focus ring, the tab you
// are in, the A1, and a rule under the day's date, as on a page of paper.
//
// The twist: a circle drawn by hand means *this one*. The one you have done, the one you are on,
// the tab you are in, the task that comes first.
//
// The wobble is hand-set, not random: every mark in the app has the same one, so a list reads as
// one pen and nothing shimmers as it is laid out again.

extension Color {
    /// The pen: a graphite that sits beside the teal without competing with it, and never reads as
    /// a problem the way red would. 8:1 on a white card.
    static let pencil = Color(hex: 0x44505C, highContrast: 0x232C35)
}

/// A smooth open path through the given points (Catmull-Rom written as cubics), so a few hand-set
/// points read as one unbroken stroke.
/// `wrap` is for a stroke that ends where it began (a circle with no overshoot): the neighbours
/// are read round the loop, so the pen runs on through the join instead of leaving a peak there.
nonisolated func sketched(_ p: [CGPoint], wrap: Bool = false) -> Path {
    var path = Path()
    guard let first = p.first, p.count > 1 else { return path }
    path.move(to: first)
    for i in 0..<(p.count - 1) {
        let before = i > 0 ? p[i - 1] : (wrap ? p[p.count - 2] : p[0])
        let after = i + 2 < p.count ? p[i + 2] : (wrap ? p[1] : p[p.count - 1])
        path.addCurve(to: p[i + 1],
                      control1: CGPoint(x: p[i].x + (p[i + 1].x - before.x) / 6,
                                        y: p[i].y + (p[i + 1].y - before.y) / 6),
                      control2: CGPoint(x: p[i + 1].x - (after.x - p[i].x) / 6,
                                        y: p[i + 1].y - (after.y - p[i].y) / 6))
    }
    return path
}

/// A circle drawn by hand: round enough to read as a circle, uneven enough to read as a pen.
/// It starts at the top and goes clockwise, so trimming it from 0 shows time or progress without
/// turning it first. In a rect that isn't square it becomes the matching oval (the A1's chip).
struct SketchCircle: Shape {
    /// The pen carries a little past its own start and crosses it, as a hand does.
    /// Off where the circle measures something (the focus ring), so a quarter drawn is a quarter
    /// of the time.
    var overshoot = true

    func path(in rect: CGRect) -> Path {
        // How far the pen strays from true, point by point, all the way round.
        let radii = [0.500, 0.470, 0.497, 0.476, 0.503, 0.474, 0.493, 0.480, 0.499, 0.527]
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let sweep = overshoot ? 378.0 : 360.0
        let last = radii.count - 1
        let points = (0...last).map { i -> CGPoint in
            let angle = (-90 + sweep * Double(i) / Double(last)) * .pi / 180
            // Closing on the start again, the pen must land exactly on it or leave a kink.
            let r = overshoot || i < last ? radii[i] : radii[0]
            return CGPoint(x: centre.x + cos(angle) * r * rect.width,
                           y: centre.y + sin(angle) * r * rect.height)
        }
        return sketched(points, wrap: !overshoot)
    }
}

/// A tick drawn by hand: down to the elbow, then a longer stroke up. Drawn across the check as it
/// fills, so trimming it from 0 lays it down the way a pen would.
struct SketchTick: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [(0.07, 0.50), (0.21, 0.64), (0.32, 0.76), (0.37, 0.75),
                      (0.55, 0.47), (0.74, 0.23), (0.93, 0.07)]
        return sketched(points.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) })
    }
}

/// A rule drawn by hand, left to right, waving a little: under the day's date, as on paper.
struct SketchRule: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [(0.00, 0.60), (0.17, 0.33), (0.39, 0.55), (0.62, 0.31),
                      (0.83, 0.52), (1.00, 0.34)]
        return sketched(points.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) })
    }
}

/// Everything in the app that is ticked or chosen: a pen circle that fills teal, with a tick laid
/// across it by the same hand. The tick is trimmed by `done`, so a tap draws it on while a row
/// that is already done, scrolled into view, simply has it (motion answers an action, never an
/// arrival). `done` is a constant false where the circle is only ever empty (a line waiting to be
/// added, a task waiting to be chosen).
struct DrawnCheck: View {
    let done: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SketchCircle().fill(Color.brand).opacity(done ? 1 : 0)
            // The pen edge stays when the circle fills, so a done check reads as drawn and then
            // coloured in, with the hand's little tail past the top; filled alone it read as a blob.
            SketchCircle()
                .stroke(done ? Color.brand : Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            SketchTick().trim(from: 0, to: done ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .padding(6)
        }
        .frame(width: 25, height: 25)
        // On the check alone: the same modifier on a screen animates everything that changes with it.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: done)
    }
}

extension View {
    /// The pen circle round what comes first: the A1's letter, and nothing else in a list.
    /// Drawn outside the mark it circles, so the mark keeps its own size and place.
    @ViewBuilder func penCircled(_ on: Bool) -> some View {
        if on {
            overlay {
                SketchCircle()
                    .stroke(Color.pencil, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .padding(-4)
                    .accessibilityHidden(true)
            }
        } else {
            self
        }
    }

    /// A pen rule under the day's date, the width of the words above it.
    func penRule() -> some View {
        overlay(alignment: .bottomLeading) {
            SketchRule()
                .stroke(Color.groundInk.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(height: 5)
                .offset(y: 7)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - The hand the app is written in

// The face itself touches nothing on the main actor, and the letters' marks are drawn by a
// `@Sendable` closure the widgets may also hold, so it is free of it.
nonisolated extension Font {
    /// Patrick Hand (SIL OFL, `PatrickHand-OFL.txt`): the app's one pen, for every word on every
    /// screen. It is a real person's felt-tip hand rather than a sketch effect laid over a typeface,
    /// and of the hands tried on screen (Noteworthy, Bradley Hand, Marker Felt, Chalkboard SE,
    /// Caveat, Architects Daughter) it was the only one still crisp at footnote size in grey, where
    /// dates, times and counts live ("11/9", "9:00 AM", "1 of 3").
    ///
    /// A hand has one pen, so there is no bold: this family has a single weight and SwiftUI does not
    /// synthesise one. Emphasis is size and colour, which is what a person writing actually has.
    ///
    /// Always built with `relativeTo:`, so every word still grows with Dynamic Type.
    static func hand(_ style: Font.TextStyle = .body, size: CGFloat? = nil) -> Font {
        .custom(handName, size: (size ?? handSize(style)) * handScale, relativeTo: style)
    }

    static let handName = "PatrickHand-Regular"
    /// The hand's lowercase sits a little under the system's, so every size is nudged up to match.
    static let handScale: CGFloat = 1.06

    /// The system's own point size for a text style at the default (Large) setting. `Font` does not
    /// give these up, and `UIFont.preferredFont` returns the size already scaled, which `relativeTo:`
    /// would then scale a second time.
    static func handSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

nonisolated extension UIFont {
    /// The same hand for the bits of chrome UIKit draws (the large title in a tab's bar).
    static func hand(_ style: UIFont.TextStyle, size: CGFloat) -> UIFont {
        let hand = UIFont(name: Font.handName, size: size * Font.handScale) ?? .preferredFont(forTextStyle: style)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: hand)
    }
}

// MARK: - The icons, drawn by the same pen

/// Every icon the app shows in its own layout, drawn as strokes through hand-set points in the unit
/// square, by the pen that draws the checks and the circles. The wobble is written down, never
/// random, so a list of rows never shimmers as it is laid out again.
///
/// What stays a system symbol: anything inside a system `Menu`, a swipe action or a share sheet,
/// which take a symbol name and draw it themselves.
struct SketchGlyph: Shape {
    let glyph: SketchIcon.Glyph

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let d = glyph.drawing
        for (i, stroke) in d.strokes.enumerated() {
            let pts = stroke.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
            path.addPath(sketched(pts, wrap: d.wrapped.contains(i)))
        }
        return path
    }
}

/// One icon: the glyph, at a size that grows with Dynamic Type, in one stroke style (round caps,
/// about 2 pt at 24 pt) and the foreground colour of wherever it sits.
struct SketchIcon: View {
    let glyph: Glyph
    var size: CGFloat = 24
    /// A star that is on, a sun that is on: drawn and then coloured in, as the ticked check is.
    var filled = false
    @ScaledMetric(relativeTo: .body) private var typeScale = 1.0

    var body: some View {
        let side = size * typeScale
        ZStack {
            if filled { SketchGlyph(glyph: glyph).fill() }
            SketchGlyph(glyph: glyph)
                .stroke(style: StrokeStyle(lineWidth: side / 12.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    nonisolated enum Glyph {
        case checklist, listNumber, bars, target, sparkles
        case play, pause, star, magnifier, plus, plusCircle, sort, chevron, check, xmark
        case paperclip, page, photo, trash, restore, share, warning, flag
        case bell, calendar, repeatArrows, sun, person, pencil, cap
    }
}

/// A glyph's strokes, in the unit square with y running down. `wrapped` names the strokes that end
/// where they began, so the pen runs on through the join instead of leaving a peak there.
nonisolated struct SketchDrawing {
    var strokes: [[CGPoint]]
    var wrapped: Set<Int> = []

    init(_ strokes: [[(Double, Double)]], wrapped: Set<Int> = []) {
        self.strokes = strokes.map { $0.map { CGPoint(x: $0.0, y: $0.1) } }
        self.wrapped = wrapped
    }
}

nonisolated extension SketchIcon.Glyph {
    /// A ring the pen drew: the same ten strays from true as `SketchCircle`, so every round thing in
    /// the app is the same hand.
    private static func ring(_ cx: Double, _ cy: Double, _ r: Double) -> [(Double, Double)] {
        let strays = [1.000, 0.940, 0.994, 0.952, 1.006, 0.948, 0.986, 0.960, 0.998, 1.000]
        return (0..<strays.count).map { i in
            let a = (-90.0 + 360.0 * Double(i) / Double(strays.count - 1)) * .pi / 180
            return (cx + cos(a) * r * strays[i], cy + sin(a) * r * strays[i])
        }
    }

    /// A star of `points` tips: the five-pointed one, and the four-pointed sparkle.
    private static func star(_ cx: Double, _ cy: Double, _ outer: Double, _ inner: Double, _ tips: Int) -> [(Double, Double)] {
        let wobble = [1.0, 0.96, 1.03, 0.97, 1.02, 0.95, 1.01, 0.98, 1.02, 0.96]
        var out: [(Double, Double)] = []
        for i in 0...(tips * 2) {
            let a = (-90.0 + 180.0 * Double(i) / Double(tips)) * .pi / 180
            let r = (i % 2 == 0 ? outer : inner) * (i == tips * 2 ? wobble[0] : wobble[i % wobble.count])
            out.append((cx + cos(a) * r, cy + sin(a) * r))
        }
        return out
    }

    var drawing: SketchDrawing {
        switch self {
        case .checklist:
            SketchDrawing([[(0.02, 0.21), (0.09, 0.29), (0.23, 0.09)],
                           [(0.02, 0.57), (0.09, 0.65), (0.23, 0.45)],
                           [(0.03, 0.87), (0.13, 0.85), (0.22, 0.89)],
                           [(0.37, 0.17), (0.67, 0.14), (0.98, 0.18)],
                           [(0.37, 0.53), (0.67, 0.50), (0.98, 0.54)],
                           [(0.37, 0.89), (0.67, 0.86), (0.98, 0.90)]])
        case .listNumber:
            SketchDrawing([[(0.01, 0.11), (0.07, 0.03), (0.07, 0.25)],
                           [(0.00, 0.41), (0.06, 0.37), (0.11, 0.43), (0.05, 0.53), (0.00, 0.59), (0.12, 0.58)],
                           [(0.00, 0.73), (0.09, 0.71), (0.05, 0.80), (0.11, 0.85), (0.01, 0.93)],
                           [(0.33, 0.13), (0.66, 0.10), (0.99, 0.14)],
                           [(0.33, 0.49), (0.66, 0.46), (0.99, 0.50)],
                           [(0.33, 0.85), (0.66, 0.82), (0.99, 0.86)]])
        case .bars:
            SketchDrawing([[(0.02, 0.94), (0.35, 0.96), (0.68, 0.95), (0.98, 0.93)],
                           [(0.16, 0.90), (0.17, 0.66), (0.15, 0.42)],
                           [(0.48, 0.91), (0.49, 0.52), (0.47, 0.14)],
                           [(0.80, 0.90), (0.79, 0.58), (0.81, 0.26)]])
        case .target:
            // One ring and a dart in the middle of it. Rings inside rings turned to soup under the
            // tab bar's own pen circle, and a second circle would blunt what that circle means.
            SketchDrawing([Self.ring(0.42, 0.58, 0.40), Self.ring(0.42, 0.58, 0.085),
                           [(0.97, 0.05), (0.70, 0.31), (0.45, 0.55)],
                           [(0.72, 0.06), (0.97, 0.04), (0.95, 0.28)]], wrapped: [0, 1])
        case .sparkles:
            SketchDrawing([Self.star(0.41, 0.47, 0.44, 0.13, 4), Self.star(0.84, 0.17, 0.16, 0.05, 4)],
                          wrapped: [0, 1])
        case .play:
            SketchDrawing([[(0.21, 0.07), (0.56, 0.29), (0.89, 0.50), (0.56, 0.71), (0.21, 0.93), (0.21, 0.50), (0.21, 0.07)]],
                          wrapped: [0])
        case .pause:
            SketchDrawing([[(0.33, 0.11), (0.34, 0.50), (0.32, 0.89)], [(0.67, 0.11), (0.66, 0.50), (0.68, 0.89)]])
        case .star:
            SketchDrawing([Self.star(0.50, 0.53, 0.47, 0.195, 5)], wrapped: [0])
        case .magnifier:
            SketchDrawing([Self.ring(0.42, 0.40, 0.33), [(0.66, 0.65), (0.80, 0.80), (0.94, 0.95)]], wrapped: [0])
        case .plus:
            SketchDrawing([[(0.50, 0.07), (0.49, 0.50), (0.51, 0.93)], [(0.07, 0.50), (0.50, 0.52), (0.93, 0.49)]])
        case .plusCircle:
            SketchDrawing([Self.ring(0.50, 0.50, 0.46),
                           [(0.50, 0.26), (0.49, 0.50), (0.51, 0.74)],
                           [(0.26, 0.50), (0.50, 0.51), (0.74, 0.49)]], wrapped: [0])
        case .sort:
            SketchDrawing([[(0.28, 0.93), (0.27, 0.50), (0.28, 0.08)], [(0.13, 0.25), (0.28, 0.07), (0.43, 0.25)],
                           [(0.72, 0.07), (0.73, 0.50), (0.72, 0.92)], [(0.57, 0.75), (0.72, 0.93), (0.87, 0.75)]])
        case .chevron:
            SketchDrawing([[(0.33, 0.07), (0.50, 0.28), (0.67, 0.49), (0.50, 0.71), (0.33, 0.93)]])
        case .check:
            SketchDrawing([[(0.05, 0.47), (0.20, 0.62), (0.32, 0.76), (0.38, 0.75), (0.56, 0.45), (0.76, 0.20), (0.95, 0.05)]])
        case .xmark:
            SketchDrawing([[(0.13, 0.12), (0.50, 0.49), (0.88, 0.89)], [(0.89, 0.12), (0.51, 0.50), (0.12, 0.88)]])
        case .paperclip:
            SketchDrawing([[(0.50, 0.27), (0.49, 0.63), (0.51, 0.79), (0.62, 0.86), (0.72, 0.76),
                            (0.73, 0.45), (0.72, 0.22), (0.63, 0.09), (0.45, 0.07), (0.30, 0.15),
                            (0.27, 0.35), (0.27, 0.66), (0.29, 0.85)]])
        case .page:
            SketchDrawing([[(0.22, 0.06), (0.60, 0.04), (0.79, 0.23), (0.78, 0.95), (0.50, 0.97), (0.22, 0.95), (0.22, 0.06)],
                           [(0.60, 0.04), (0.62, 0.22), (0.79, 0.23)],
                           [(0.34, 0.47), (0.50, 0.45), (0.67, 0.47)],
                           [(0.34, 0.65), (0.50, 0.63), (0.67, 0.65)],
                           [(0.34, 0.82), (0.45, 0.80), (0.57, 0.82)]], wrapped: [0])
        case .photo:
            SketchDrawing([[(0.05, 0.17), (0.50, 0.14), (0.95, 0.17), (0.96, 0.85), (0.50, 0.88), (0.04, 0.85), (0.05, 0.17)],
                           Self.ring(0.29, 0.36, 0.085),
                           [(0.13, 0.81), (0.37, 0.49), (0.55, 0.67), (0.70, 0.53), (0.94, 0.83)]],
                          wrapped: [0, 1])
        case .trash:
            SketchDrawing([[(0.09, 0.24), (0.50, 0.21), (0.91, 0.24)],
                           [(0.37, 0.20), (0.39, 0.08), (0.61, 0.07), (0.63, 0.19)],
                           [(0.19, 0.27), (0.24, 0.72), (0.29, 0.94), (0.50, 0.96), (0.71, 0.94), (0.76, 0.72), (0.81, 0.27)],
                           [(0.40, 0.40), (0.41, 0.62), (0.40, 0.83)],
                           [(0.60, 0.40), (0.59, 0.62), (0.60, 0.83)]])
        case .restore:
            SketchDrawing([[(0.62, 0.14), (0.38, 0.12), (0.18, 0.28), (0.11, 0.52), (0.19, 0.76),
                            (0.40, 0.90), (0.64, 0.89), (0.83, 0.74), (0.89, 0.53)],
                           [(0.73, 0.04), (0.60, 0.14), (0.72, 0.26)]])
        case .share:
            SketchDrawing([[(0.50, 0.93), (0.49, 0.52), (0.50, 0.11)], [(0.33, 0.30), (0.50, 0.10), (0.68, 0.30)],
                           [(0.27, 0.41), (0.15, 0.43), (0.14, 0.70), (0.16, 0.95), (0.50, 0.97),
                            (0.84, 0.95), (0.86, 0.70), (0.85, 0.43), (0.73, 0.41)]])
        case .bell:
            SketchDrawing([[(0.21, 0.75), (0.22, 0.46), (0.31, 0.24), (0.50, 0.13), (0.69, 0.24), (0.78, 0.46), (0.79, 0.75)],
                           [(0.11, 0.77), (0.50, 0.81), (0.89, 0.77)],
                           [(0.41, 0.87), (0.50, 0.95), (0.59, 0.87)]])
        case .calendar:
            SketchDrawing([[(0.06, 0.23), (0.50, 0.20), (0.94, 0.23), (0.95, 0.93), (0.50, 0.96), (0.05, 0.93), (0.06, 0.23)],
                           [(0.06, 0.42), (0.50, 0.39), (0.94, 0.42)],
                           [(0.28, 0.07), (0.28, 0.17), (0.28, 0.27)],
                           [(0.71, 0.06), (0.71, 0.16), (0.71, 0.26)]], wrapped: [0])
        case .repeatArrows:
            SketchDrawing([[(0.17, 0.42), (0.25, 0.26), (0.49, 0.21), (0.79, 0.27)],
                           [(0.67, 0.13), (0.82, 0.27), (0.69, 0.39)],
                           [(0.83, 0.58), (0.75, 0.74), (0.51, 0.79), (0.21, 0.73)],
                           [(0.33, 0.87), (0.18, 0.73), (0.31, 0.61)]])
        case .sun:
            SketchDrawing([Self.ring(0.50, 0.50, 0.27),
                           [(0.50, 0.00), (0.50, 0.11)], [(0.50, 0.89), (0.50, 1.00)],
                           [(0.00, 0.50), (0.11, 0.50)], [(0.89, 0.50), (1.00, 0.50)],
                           [(0.15, 0.14), (0.23, 0.23)], [(0.78, 0.77), (0.86, 0.86)],
                           [(0.86, 0.14), (0.78, 0.23)], [(0.23, 0.77), (0.15, 0.86)]], wrapped: [0])
        case .person:
            SketchDrawing([Self.ring(0.50, 0.27, 0.21),
                           [(0.09, 0.97), (0.15, 0.74), (0.31, 0.61), (0.50, 0.58), (0.69, 0.61), (0.85, 0.74), (0.91, 0.97)]],
                          wrapped: [0])
        case .pencil:
            SketchDrawing([[(0.17, 0.85), (0.45, 0.52), (0.74, 0.19)],
                           [(0.31, 0.95), (0.59, 0.63), (0.88, 0.30)],
                           [(0.17, 0.85), (0.08, 0.97), (0.31, 0.95)],
                           [(0.74, 0.19), (0.79, 0.08), (0.91, 0.19), (0.88, 0.30)]])
        case .warning:
            SketchDrawing([[(0.50, 0.06), (0.74, 0.49), (0.97, 0.91), (0.50, 0.93), (0.03, 0.91), (0.26, 0.49), (0.50, 0.06)],
                           [(0.50, 0.37), (0.49, 0.50), (0.50, 0.63)],
                           [(0.50, 0.78), (0.50, 0.80)]], wrapped: [0])
        case .flag:
            SketchDrawing([[(0.17, 0.04), (0.15, 0.50), (0.18, 0.96)],
                           [(0.17, 0.08), (0.52, 0.12), (0.88, 0.07), (0.86, 0.44), (0.51, 0.49), (0.16, 0.45)]])
        case .cap:
            SketchDrawing([[(0.50, 0.12), (0.95, 0.34), (0.50, 0.56), (0.05, 0.34), (0.50, 0.12)],
                           [(0.25, 0.44), (0.26, 0.74), (0.50, 0.85), (0.74, 0.74), (0.75, 0.44)],
                           [(0.92, 0.36), (0.93, 0.62), (0.91, 0.76)]], wrapped: [0])
        }
    }
}

extension SketchIcon {
    /// The handful of marks that sit inside a run of words (a to-do's line: a bell, a calendar, a
    /// repeat, a page). `Text` will only take an `Image`, so each is drawn once and kept, as a
    /// template so the words' own colour still tints it.
    @MainActor static func inline(_ glyph: Glyph, _ size: CGFloat = 12) -> Image {
        let key = "\(glyph)-\(size)"
        if let had = cache[key] { return had }
        let side = size * 1.05
        let renderer = ImageRenderer(content:
            SketchGlyph(glyph: glyph)
                .stroke(style: StrokeStyle(lineWidth: side / 12.5, lineCap: .round, lineJoin: .round))
                .frame(width: side, height: side)
                .foregroundStyle(.black))
        renderer.scale = UIScreen.main.scale
        let image = (renderer.uiImage?.withRenderingMode(.alwaysTemplate)).map { Image(uiImage: $0) }
            ?? Image(systemName: "questionmark")
        cache[key] = image
        return image
    }

    private static var cache: [String: Image] = [:]
}

extension Label where Title == Text, Icon == SketchIcon {
    /// `Label(_, systemImage:)` with the app's own pen in its place, where the words are shown.
    ///
    /// A control that shows the icon **alone** does not use this: a drawn icon carries no name of
    /// its own the way a symbol does, so `.labelStyle(.iconOnly)` would leave the control with no
    /// description at all (the accessibility audit catches it). Those take `SketchIcon` directly
    /// and say what they are on `.accessibilityLabel`. iOS 26's glass toolbar buttons want the same,
    /// since they draw the words of a `Label` whose icon is not an `Image`.
    init(_ title: String, sketch: SketchIcon.Glyph, size: CGFloat = 20) {
        self.init { Text(title) } icon: { SketchIcon(glyph: sketch, size: size) }
    }
}
