import SwiftUI
import WidgetKit
import WilListCore

// Home Screen and Lock Screen widgets, and the focus Live Activity (FocusActivity.swift). The
// widgets' faces are in ios/Shared/WidgetViews.swift; this file says which sizes exist and when
// they redraw.

@main
struct WilListWidgets: WidgetBundle {
    var body: some Widget {
        FirstWidget()
        TodayWidget()
        FocusActivity()
    }
}

struct GlanceEntry: TimelineEntry {
    let date: Date
    let glance: Glance
}

/// One entry for now, and a fresh one at midnight when the day turns over. The app asks for a
/// redraw whenever the plan changes, and a tick on a widget redraws it by itself: first with the
/// line shown done, then a moment later without it.
struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: .now, glance: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: .now, glance: Self.current(preview: context.isPreview)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        let now = GlanceEntry(date: .now, glance: Self.current(preview: false))
        let entries = TickMark.fresh.map { [GlanceEntry(date: .now, glance: $0.glance), GlanceEntry(date: .now.addingTimeInterval(1), glance: now.glance)] }
        completion(Timeline(entries: entries ?? [now], policy: .after(midnight)))
    }

    /// The saved plan; in the widget picker, the sample when the plan is still empty.
    private static func current(preview: Bool) -> Glance {
        let glance = Glance.now()
        return preview && glance.first == nil && glance.todos.isEmpty ? .sample : glance
    }
}

struct FirstWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lull.willist.first", provider: GlanceProvider()) { entry in
            FirstWidgetEntry(glance: entry.glance)
        }
        .configurationDisplayName("Do this first")
        .description("Your A1, with Mark done right on it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lull.willist.today", provider: GlanceProvider()) { entry in
            TodayWidgetEntry(glance: entry.glance)
        }
        .configurationDisplayName("Today")
        .description("Your to-dos, ticked off from the Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryCircular])
    }
}

private struct FirstWidgetEntry: View {
    @Environment(\.widgetFamily) private var family
    let glance: Glance

    var body: some View {
        FirstWidgetView(glance: glance, family: family)
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium { A1WidgetGround() }
            }
            .widgetURL(URL(string: "willist://today"))
    }
}

private struct TodayWidgetEntry: View {
    @Environment(\.widgetFamily) private var family
    let glance: Glance

    var body: some View {
        TodayWidgetView(glance: glance, family: family)
            .containerBackground(for: .widget) {
                if family != .accessoryCircular { Color.white }
            }
            .widgetURL(URL(string: "willist://today"))
    }
}
