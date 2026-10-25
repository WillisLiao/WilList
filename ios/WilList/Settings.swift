import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import WilListCore


/// The profile picture at the top left of every tab: it opens Settings.
struct ProfileButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        Button { store.showingSettings = true } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand)
                .tapArea()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Settings")
    }
}

extension View {
    /// The profile picture at the top left of a tab's navigation bar.
    func profileButton() -> some View {
        toolbar { ToolbarItem(placement: .topBarLeading) { ProfileButton() } }
    }
}

/// How WilList behaves, and backups.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var restoring = false
    @State private var restoreError: String?
    @State private var deletingProgress = false
    // `-open trash` on launch opens the Trash, for tests and screenshots.
    @State private var showingTrash = UserDefaults.standard.string(forKey: "open") == "trash"
    @AppStorage("newOnTop") private var newOnTop = false
    @AppStorage("starredOnTop") private var starredOnTop = true
    @AppStorage("confirmDelete") private var confirmDelete = false
    @AppStorage("playSound") private var playSound = true
    @AppStorage("readDates") private var readDates = true
    @AppStorage("badge") private var badge = Badge.off

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("New to-dos on top", isOn: $newOnTop).tint(.brand)
                    Toggle("Starred on top", isOn: $starredOnTop).tint(.brand)
                    Toggle("Read dates in titles", isOn: $readDates).tint(.brand)
                    Toggle("Completion sound", isOn: $playSound).tint(.brand)
                    Toggle("Confirm deletes", isOn: $confirmDelete).tint(.brand)
                    Picker("Icon badge", selection: $badge) {
                        ForEach(Badge.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("To-dos").onGround()
                }

                Section {
                    Stepper("Per day: \(Fmt.minutes(store.state.settings.perDayMin))", value: setting(\.perDayMin), in: 30...480, step: 15)
                } header: {
                    Text("Study").onGround()
                }

                Section {
                    clock("Plan tomorrow from", \.planTime)
                    Toggle("Remind me to plan", isOn: Binding(get: { store.state.settings.notify }, set: { on in store.change { $0.settings.notify = on } }))
                        .tint(.brand)
                } header: {
                    Text("Day").onGround()
                }

                // Links the Agent subscribed to; they are read again every half hour.
                if !store.state.feeds.isEmpty {
                    Section {
                        ForEach(store.state.feeds) { feed in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.name)
                                Text(feed.error ?? feed.syncedAt.map { "Read \($0.formatted(.relative(presentation: .named)))" } ?? "Not read yet")
                                    .font(.subheadline)
                                    .foregroundStyle(feed.error == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                            }
                        }
                        .onDelete { idx in idx.map { store.state.feeds[$0].url }.forEach(store.removeFeed) }
                    } header: {
                        Text("Calendar links").onGround()
                    }
                }

                Section {
                    ShareLink(item: backup, preview: SharePreview("WilList backup")) {
                        Label("Back up", systemImage: "square.and.arrow.up")
                    }
                    Button("Restore", systemImage: "arrow.counterclockwise") { restoring = true }
                } header: {
                    Text("Backup").onGround()
                } footer: {
                    if let restoreError { Text(restoreError).foregroundStyle(.red) }
                }

                Section {
                    NavigationLink { TrashView() } label: {
                        LabeledContent {
                            if !store.state.trash.isEmpty { Text("\(store.state.trash.count)") }
                        } label: {
                            Label("Trash", systemImage: "trash")
                        }
                    }
                }

                Section {
                    // On the button, so iOS 26 points its popover here. Finished tasks and to-dos
                    // stay, so one ticked off by mistake can still be brought back.
                    Button("Delete progress", role: .destructive) { deletingProgress = true }
                        .confirmationDialog("Delete progress?", isPresented: $deletingProgress, titleVisibility: .visible) {
                            Button("Delete progress", role: .destructive) {
                                store.change(undo: "Progress deleted") { $0.deleteProgress(today: store.today) }
                            }
                        } message: {
                            Text("Progress and the last 21 days in Goals start from zero. Your tasks and to-dos stay.")
                        }
                }

                Section {
                    LabeledContent("Method", value: "Brian Tracy’s ABCDE")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .ground()
            .readableColumn(inline: true)
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showingTrash) { TrashView() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { restore($0) }
            .onChange(of: badge) {
                guard badge != .off else { return }
                Task {
                    if await Reminders.allowed() {
                        try? await UNUserNotificationCenter.current().setBadgeCount(badge.count(store.state, today: store.today))
                    } else {
                        store.say("Turn on notifications for WilList in Settings.")
                    }
                }
            }
            .toastHost()
        }
    }

    private func setting(_ path: WritableKeyPath<Settings, Int>) -> Binding<Int> {
        Binding(get: { store.state.settings[keyPath: path] }, set: { v in store.change { $0.settings[keyPath: path] = v } })
    }

    private func clock(_ title: String, _ path: WritableKeyPath<Settings, String>) -> some View {
        DatePicker(title, selection: Binding(
            get: {
                let m = timeToMin(store.state.settings[keyPath: path]) ?? 480
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now
            },
            set: { d in store.change { $0.settings[keyPath: path] = minToTime(nowMinutes(d)) } }
        ), displayedComponents: .hourAndMinute)
    }

    private var backup: URL {
        let url = URL.temporaryDirectory.appending(path: "WilList backup \(store.today).json")
        try? JSONEncoder().encode(store.state).write(to: url)
        return url
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(AppState.self, from: data),
              !(state.items.isEmpty && state.todos.isEmpty && state.goals.isEmpty) else {
            restoreError = "That file isn’t a WilList backup."
            return
        }
        restoreError = nil
        store.change(undo: "Restored \(state.items.count) items") { $0 = state }
    }
}

/// What was deleted in the last 30 days, newest first: Restore puts it back, a swipe deletes it
/// for good.
struct TrashView: View {
    @Environment(Store.self) private var store
    @State private var emptying = false

    var body: some View {
        let today = store.today
        List {
            if store.state.trash.isEmpty {
                Text("Nothing here").foregroundStyle(.secondary)
            }
            ForEach(store.state.trash) { t in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title)
                        // Where it goes back to, and how long it stays.
                        Text("\(t.item == nil ? "Today" : "Plan"), \(AppState.daysLeft(t.deletedAt, today)) \(AppState.daysLeft(t.deletedAt, today) == 1 ? "day" : "days") left")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    Button("Restore") {
                        withAnimation { store.change(undo: "Restored \u{201C}\(t.title)\u{201D}") { $0.restore(t.id) } }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tapArea()
                    .accessibilityLabel("Restore \(t.title)")
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        withAnimation { store.change(undo: "Deleted for good") { s in s.trash.removeAll { $0.id == t.id } } }
                    }
                }
            }
        }
        .ground()
        .readableColumn(inline: true)
        .navigationTitle("Trash")
        .toolbar {
            if !store.state.trash.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Empty", role: .destructive) { emptying = true }
                        .confirmationDialog("Empty the trash?", isPresented: $emptying, titleVisibility: .visible) {
                            Button("Empty trash", role: .destructive) {
                                withAnimation { store.change(undo: "Trash emptied") { $0.trash = [] } }
                            }
                        } message: {
                            Text("Everything in it is deleted for good.")
                        }
                }
            }
        }
        .toastHost()
    }
}
