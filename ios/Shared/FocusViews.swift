import SwiftUI
import WilListCore

// The focus Live Activity's faces (ios/WilListWidgets/FocusActivity.swift lays them out on the Lock
// Screen and in the Dynamic Island). Shared so the app's widget gallery can draw them too.

/// The Lock Screen face, on its course's colour like the Focus screen: the letter and what it is,
/// the time left large, and the bar, all in white.
struct FocusLockView: View {
    let attributes: FocusAttributes
    let state: FocusAttributes.ContentState
    /// The planned minutes are up (the activity went stale at its end).
    var over = false

    var body: some View {
        let field = CourseColor.of(attributes.color)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                if attributes.letter != nil {
                    LetterMark(letter: attributes.letter, label: attributes.label, large: true, onBrand: true)
                }
                Text(attributes.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Pure white paused too, as every word on a field: the pause mark says it is paused,
                // and dimmed white falls below 3:1 on the lighter course colours.
                FocusClock(state: state, over: over)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            FocusBar(attributes: attributes, state: state).tint(.white)
        }
        .foregroundStyle(.white)
        .environment(\.field, field)
        .padding(16)
    }
}

/// Time left, counting down by itself while the session runs; still, after a pause sign, while
/// paused; Break once the planned minutes are up.
struct FocusClock: View {
    let state: FocusAttributes.ContentState
    var over = false

    var body: some View {
        Group {
            if over {
                Text("Break")
            } else if let end = state.end {
                Text(timerInterval: Date.now...max(end, .now), countsDown: true, showsHours: false)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill").imageScale(.small).font(.body.weight(.bold))
                    Text(Self.clock(state.left))
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.trailing)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// How much of the planned time has gone, filling by itself while the session runs.
struct FocusBar: View {
    let attributes: FocusAttributes
    let state: FocusAttributes.ContentState

    var body: some View {
        Group {
            if let end = state.end, end > state.start {
                ProgressView(timerInterval: state.start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            } else {
                ProgressView(value: 1 - state.left / max(attributes.total, 1))
            }
        }
        .progressViewStyle(.linear)
    }
}

/// The smallest Dynamic Island: a ring of the time gone.
struct FocusRing: View {
    let attributes: FocusAttributes
    let state: FocusAttributes.ContentState

    var body: some View {
        Group {
            if let end = state.end, end > state.start {
                ProgressView(timerInterval: state.start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            } else {
                ProgressView(value: 1 - state.left / max(attributes.total, 1))
            }
        }
        .progressViewStyle(.circular)
        .tint(CourseColor.onDark(attributes.color))
    }
}

extension FocusAttributes {
    var letter: Letter? { Letter(rawValue: String(label.prefix(1))) }
}

extension Color {
    /// The app's teal lifted for the black of the Dynamic Island.
    static let brandOnDark = Color(hex: 0x7FC3CF)
}
