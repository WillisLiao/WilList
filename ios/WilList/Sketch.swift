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
nonisolated private func sketched(_ p: [CGPoint], wrap: Bool = false) -> Path {
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
