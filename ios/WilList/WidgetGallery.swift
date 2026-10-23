#if DEBUG
import SwiftUI
import WidgetKit
import WilListCore

/// Every widget at its real iPhone size, drawn from the current plan, for screenshots
/// (`-gallery` on launch). A script can't add widgets to the Home Screen, so this is where they
/// are checked by eye.
struct WidgetGallery: View {
    @Environment(Store.self) private var store

    var body: some View {
        let glance = Glance(store.state, today: store.today)
        let empty = Glance(AppState(), today: store.today)
        // `-gallery lock` shows the Lock Screen and the large size, `-gallery focus` the focus Live
        // Activity running and paused, `-gallery ticked` the rest a moment after a tick on each
        // (the A1, the row after it, a to-do); anything else the rest.
        let tick = UserDefaults.standard.string(forKey: "gallery") == "ticked"
        VStack(spacing: 18) {
            if UserDefaults.standard.string(forKey: "gallery") == "focus" {
                // A course's colour (the first, blue), and no course (the teal).
                let a = FocusAttributes(title: "Problem set 5", label: "A1", minutes: 50, color: 0)
                let b = FocusAttributes(title: "Read chapter 4 for psych and write a one-page summary", label: "B2", minutes: 25)
                let start = Date.now.addingTimeInterval(-8 * 60)
                activity(a) { FocusLockView(attributes: a, state: .init(start: start, end: start.addingTimeInterval(3000), left: 2520)) }
                activity(a) { FocusLockView(attributes: a, state: .init(start: start, end: nil, left: 1234)) }
                activity(b) { FocusLockView(attributes: b, state: .init(start: start, end: start.addingTimeInterval(1500), left: 1020)) }
                activity(a) { FocusLockView(attributes: a, state: .init(start: start, end: start.addingTimeInterval(480), left: 0), over: true) }
            } else if UserDefaults.standard.string(forKey: "gallery") == "lock" {
                lock(width: 300) { FirstWidgetView(glance: glance, family: .accessoryInline) }
                HStack(spacing: 12) {
                    lock(width: 76) { TodayWidgetView(glance: glance, family: .accessoryCircular) }
                    lock(width: 172) { FirstWidgetView(glance: glance, family: .accessoryRectangular) }
                }
                home(.systemLarge) { TodayWidgetView(glance: glance, family: .systemLarge) }
                home(.systemMedium) { TodayWidgetView(glance: empty, family: .systemMedium) }
            } else {
                HStack(spacing: 22) {
                    home(.systemSmall, a1: true) { FirstWidgetView(glance: glance.markingDone(tick ? glance.first?.id : nil), family: .systemSmall) }
                    home(.systemSmall, a1: true) { FirstWidgetView(glance: empty, family: .systemSmall) }
                }
                home(.systemMedium, a1: true) { FirstWidgetView(glance: glance.markingDone(tick ? glance.next.first?.id : nil), family: .systemMedium) }
                home(.systemMedium) { TodayWidgetView(glance: glance.markingDone(tick ? glance.todos.first?.id : nil), family: .systemMedium) }
            }
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The deep slate of a Home Screen, where the widgets really sit, not the app's light ground.
        .background(LinearGradient(colors: [Color(hex: 0x667C8F), Color(hex: 0x52667A)], startPoint: .top, endPoint: .bottom))
    }

    private func home(_ family: WidgetFamily, a1: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        let size: CGSize = switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        default: CGSize(width: 364, height: 382)
        }
        return content()
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background { if a1 { A1WidgetGround() } else { Color.white } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// A Live Activity on the Lock Screen: 16 pt in from each side, on its course's colour.
    private func activity(_ a: FocusAttributes, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: 370)
            .background(CourseColor.of(a.color))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func lock(width: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .frame(width: width, height: width == 300 ? 24 : 76)
    }
}
#endif
