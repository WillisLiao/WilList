import Foundation
import WilListCore

/// The saved plan. It lives in the app group's folder, so the widgets read and tick the same file
/// the app writes.
enum PlanFile {
    static let group = "group.com.lull.willist"

    /// Plans from before the widgets were kept in the app's own folder; the first launch with the
    /// app group copies it across. Without the app group (a build missing the entitlement) the plan
    /// simply stays there.
    static let url: URL = {
        let own = URL.applicationSupportDirectory.appending(path: "willist.v1.json")
        guard let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            return own
        }
        let url = shared.appending(path: "willist.v1.json")
        if !FileManager.default.fileExists(atPath: url.path()), FileManager.default.fileExists(atPath: own.path()) {
            try? FileManager.default.copyItem(at: own, to: url)
        }
        return url
    }()

    static func read() -> AppState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: data)
    }

    /// Changes the plan from outside the app, such as a tick on a widget. The app takes the change
    /// in when it next comes to the front (`Store.reload`).
    static func update(_ edit: (inout AppState) -> Void) {
        guard var state = read() else { return }
        edit(&state)
        try? JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
