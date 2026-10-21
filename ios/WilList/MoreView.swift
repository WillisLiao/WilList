import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import WilListCore

/// Settings, calendar links, the Claude key and backups.
struct MoreView: View {
    @Environment(Store.self) private var store
    @State private var addingFeed = false
    @State private var importing = false
    @State private var key = Keychain.apiKey ?? ""
    @State private var restoring = false
    @State private var restoreError: String?
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
                    ForEach(store.state.feeds) { feed in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.name)
                            Text(feed.error ?? feed.syncedAt.map { "Read \($0.formatted(.relative(presentation: .named)))" } ?? "Not read yet")
                                .font(.subheadline)
                                .foregroundStyle(feed.error == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                        }
                    }
                    .onDelete { idx in idx.map { store.state.feeds[$0].url }.forEach(store.removeFeed) }
                    Button("Add a calendar link", systemImage: "link") { addingFeed = true }
                    Button("Bring in a schedule", systemImage: "square.and.arrow.down") { importing = true }
                } header: {
                    Text("Calendars and schedules")
                } footer: {
                    Text("A link from Canvas, Moodle, Google or Outlook keeps your deadlines and exams up to date.")
                }

                Section {
                    Toggle("Add new to-dos on top", isOn: $newOnTop)
                    Toggle("Move starred to-dos to top", isOn: $starredOnTop)
                    Toggle("Recognize dates and times in titles", isOn: $readDates)
                    Toggle("Play completion sound", isOn: $playSound)
                    Toggle("Confirm before deleting", isOn: $confirmDelete)
                    Picker("App icon badge", selection: $badge) {
                        ForEach(Badge.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("To-dos")
                } footer: {
                    Text("Reminders you set on a to-do or an item arrive as notifications, with Mark done right on them.")
                }

                Section {
                    Stepper("Study per day: \(Fmt.minutes(store.state.settings.perDayMin))", value: setting(\.perDayMin), in: 30...480, step: 15)
                    Stepper("Session length: \(Fmt.minutes(store.state.settings.sessionMin))", value: setting(\.sessionMin), in: 15...120, step: 5)
                    Stepper("Finish deadlines \(store.state.settings.bufferDays) \(store.state.settings.bufferDays == 1 ? "day" : "days") early", value: setting(\.bufferDays), in: 0...3)
                    Button("Plan everything again") {
                        let n = store.state.items.count
                        store.change { $0.replanAll(today: store.today) }
                        store.say(n == 0 ? "Nothing to plan yet." : "Planned again, A's first.")
                    }
                } header: {
                    Text("Study plan")
                } footer: {
                    Text("Plan everything again to use these for what's already planned.")
                }

                Section {
                    clock("Day starts", \.dayStart)
                    clock("Day ends", \.dayEnd)
                    clock("Plan tomorrow from", \.planTime)
                    Toggle("Remind me to plan", isOn: Binding(get: { store.state.settings.notify }, set: { on in store.change { $0.settings.notify = on } }))
                } header: {
                    Text("Your day")
                } footer: {
                    Text("Planning the night before saves time the next day.")
                }

                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { Keychain.apiKey = key }
                        .onChange(of: key) { Keychain.apiKey = key }
                    Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                } header: {
                    Text("Claude")
                } footer: {
                    Text("Claude reads the files and photos you bring in. Your key stays on this iPhone.")
                }

                Section {
                    ShareLink(item: backup, preview: SharePreview("WilList backup")) {
                        Label("Save a backup", systemImage: "square.and.arrow.up")
                    }
                    Button("Restore from a backup", systemImage: "arrow.counterclockwise") { restoring = true }
                } header: {
                    Text("Your data")
                } footer: {
                    Text(restoreError ?? "Everything stays on this device.")
                }

                Section {
                    LabeledContent("Method", value: "Brian Tracy's ABCDE")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("More")
            .sheet(isPresented: $addingFeed) { AddFeedSheet() }
            .sheet(isPresented: $importing) { ImportSheet() }
            .fileImporter(isPresented: $restoring, allowedContentTypes: [.json]) { restore($0) }
            .onChange(of: badge) {
                guard badge != .off else { return }
                Task {
                    if await Reminders.allowed() {
                        try? await UNUserNotificationCenter.current().setBadgeCount(badge.count(store.state, today: store.today))
                    } else {
                        store.say("Notifications are off for WilList. Turn them on in the Settings app to see the badge.")
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
            restoreError = "That file isn't a WilList backup."
            return
        }
        restoreError = nil
        store.change(undo: "Restored \(state.items.count) items") { $0 = state }
    }
}

/// Adding a calendar link, with where to find one in each system.
struct AddFeedSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var reading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https:// or webcal://", text: $link, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let pasted = UIPasteboard.general.hasURLs ? UIPasteboard.general.url : nil, link.isEmpty {
                        Button("Paste \(pasted.host() ?? "link")") { link = pasted.absoluteString }
                    }
                } footer: {
                    Text("WilList only reads the calendar. You can reset the link in your school's system at any time.")
                }
                Section("Where to find it") {
                    DisclosureGroup("Canvas") { Text("Calendar, then Calendar Feed at the bottom right. Copy the link.") }
                    DisclosureGroup("Moodle") { Text("Calendar, then Import or export calendars, then Export calendar. Choose All courses and Recent and next 60 days, then Get calendar URL.") }
                    DisclosureGroup("Blackboard") { Text("Calendar, then the settings gear, then Share Calendar. Copy the link.") }
                    DisclosureGroup("Brightspace (D2L)") { Text("Calendar, then Subscribe. Copy the link.") }
                    DisclosureGroup("Google Calendar") { Text("On a computer: Settings, choose the calendar, then Secret address in iCal format.") }
                    DisclosureGroup("Outlook") { Text("Settings, Calendar, Shared calendars, Publish a calendar. Copy the ICS link.") }
                }
            }
            .navigationTitle("Calendar link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(reading ? "Reading…" : "Add") {
                        reading = true
                        Task {
                            await store.addFeed(link, name: Self.name(for: link))
                            reading = false
                            dismiss()
                        }
                    }
                    .disabled(reading || URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines))?.host() == nil)
                }
            }
        }
    }

    static func name(for link: String) -> String {
        let host = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines))?.host()?.lowercased() ?? ""
        let known = [("instructure", "Canvas"), ("moodle", "Moodle"), ("blackboard", "Blackboard"), ("d2l", "Brightspace"),
                     ("brightspace", "Brightspace"), ("google", "Google Calendar"), ("outlook", "Outlook"), ("office365", "Outlook")]
        return known.first { host.contains($0.0) }?.1 ?? (host.isEmpty ? "Calendar" : host)
    }
}

enum Keychain {
    private static let account = "anthropic-api-key"

    static var apiKey: String? {
        get {
            var out: AnyObject?
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecReturnData as String: true]
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
            return String(decoding: data, as: UTF8.self)
        }
        set {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
            SecItemDelete(query as CFDictionary)
            guard let v = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return }
            var add = query
            add[kSecValueData as String] = Data(v.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
