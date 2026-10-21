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
        // `-gallery lock` shows the Lock Screen and the large size; anything else the rest.
        VStack(spacing: 18) {
            if UserDefaults.standard.string(forKey: "gallery") == "lock" {
                lock(width: 300) { FirstWidgetView(glance: glance, family: .accessoryInline) }
                HStack(spacing: 12) {
                    lock(width: 76) { TodayWidgetView(glance: glance, family: .accessoryCircular) }
                    lock(width: 172) { FirstWidgetView(glance: glance, family: .accessoryRectangular) }
                }
                home(.systemLarge, hero: false) { TodayWidgetView(glance: glance, family: .systemLarge) }
                home(.systemMedium, hero: false) { TodayWidgetView(glance: empty, family: .systemMedium) }
            } else {
                HStack(spacing: 22) {
                    home(.systemSmall, hero: true) { FirstWidgetView(glance: glance, family: .systemSmall) }
                    home(.systemSmall, hero: true) { FirstWidgetView(glance: empty, family: .systemSmall) }
                }
                home(.systemMedium, hero: true) { FirstWidgetView(glance: glance, family: .systemMedium) }
                home(.systemMedium, hero: false) { TodayWidgetView(glance: glance, family: .systemMedium) }
            }
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LinearGradient(colors: [Color(hex: 0x8FA7B8), Color(hex: 0x5D7183)], startPoint: .top, endPoint: .bottom))
    }

    private func home(_ family: WidgetFamily, hero: Bool, @ViewBuilder content: () -> some View) -> some View {
        let size: CGSize = switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        default: CGSize(width: 364, height: 382)
        }
        return content()
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background { if hero { Look.heroGround } else { Color.white } }
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
