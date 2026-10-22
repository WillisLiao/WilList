import ActivityKit
import SwiftUI
import WidgetKit
import WilListCore

/// A focus session's timer on the Lock Screen and in the Dynamic Island, with Mark done.
struct FocusActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            FocusLockView(attributes: context.attributes, state: context.state, over: context.isStale)
                .activityBackgroundTint(CourseColor.of(context.attributes.color))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "willist://today"))
        } dynamicIsland: { context in
            let a = context.attributes, s = context.state
            // On the island's black: the letter white in the course's colour, the rest lifted to read.
            let field = CourseColor.of(a.color), lifted = CourseColor.onDark(a.color)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LetterMark(letter: a.letter, label: a.label, large: true, onBrand: true)
                        .environment(\.field, field)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusClock(state: s, over: context.isStale)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(lifted)
                        .frame(maxWidth: 110, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(a.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        FocusBar(attributes: a, state: s).tint(lifted)
                        Button(intent: FinishFocusIntent()) {
                            Label("Mark done", systemImage: "checkmark").font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(field)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }
            } compactLeading: {
                LetterMark(letter: a.letter, label: a.label, onBrand: true)
                    .environment(\.field, field)
            } compactTrailing: {
                Group {
                    if s.end == nil { Image(systemName: "pause.fill") } else { FocusClock(state: s, over: context.isStale) }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(lifted)
                .frame(maxWidth: 48)
            } minimal: {
                FocusRing(attributes: a, state: s)
            }
            .widgetURL(URL(string: "willist://today"))
            .keylineTint(lifted)
        }
    }
}
