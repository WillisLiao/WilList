import PhotosUI
import StoreKit
import SwiftUI
import UniformTypeIdentifiers
import WilListCore

/// The Agent: hand it anything with dates in it (a file or a photo) and it proposes what to add.
/// Not a chat: there is nothing to type and nothing to ask. It is a subscription, and asks before
/// anything is first sent to the AI model; nothing goes into the plan without a tap.
struct AgentView: View {
    @State private var pass = AgentPass.shared
    @AppStorage("agentConsent") private var consented = false

    var body: some View {
        NavigationStack {
            Group {
                if !AgentPass.available {
                    unavailable
                } else if !pass.unlocked {
                    paywall
                } else {
                    AgentUpload(consented: $consented)
                }
            }
            .navigationTitle("Agent")
            .profileButton()
        }
    }

    private var unavailable: some View {
        ScrollView {
            AgentIntro(title: "Coming soon", detail: "The Agent will read your syllabus, timetable or photos and fill in your plan.")
                .padding(16)
        }
        .ground()
        .readableColumn()
    }

    private var paywall: some View {
        SubscriptionStoreView(productIDs: [AgentPass.product]) {
            AgentIntro(title: "Hand it anything with dates", detail: "A syllabus, timetable, photo or email. The Agent finds what to add.")
                .padding(.horizontal, 16)
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
        .containerBackground(LinearGradient.ground, for: .subscriptionStoreFullHeight)
        .tint(.brand)
    }
}

/// The Agent's title card: what it does, in a sentence.
private struct AgentIntro: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SketchIcon(glyph: .sparkles, size: 30)
                .foregroundStyle(Color.brand)
                .accessibilityHidden(true)
            Text(title).font(.hand(.title2))
            Text(detail).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard()
    }
}

// MARK: the subscription

/// Whether the student subscribes to the Agent, and the App Store's signed proof of it that the
/// WilList server checks.
@Observable @MainActor
final class AgentPass {
    static let product = "com.lull.willist.agent.monthly"
    static let shared = AgentPass()
    /// The App Store's signed transaction for an active subscription, nil without one.
    private(set) var signed: String?
    private var watching = false

    /// The WilList server's address for the Agent (`WLAgentServer` in Info.plist), empty until it exists.
    private static let server = (Bundle.main.object(forInfoDictionaryKey: "WLAgentServer") as? String).flatMap { URL(string: $0) }

    #if DEBUG
    /// Debug builds can talk to a provider directly with `AGENT_KEY` in the environment: DeepSeek's
    /// cheapest model on low effort (the owner's pick, 2026-10-25) unless `AGENT_URL` (a chat
    /// completions address), `AGENT_MODEL` and `AGENT_EFFORT` name another.
    /// `-agentDemo YES` answers from a script instead (screenshots and UI tests). No subscription.
    private static let debugRoute: Agent.Route? = {
        if UserDefaults.standard.bool(forKey: "agentDemo") { return Agent.Route(base: URL(string: "https://demo.invalid")!, key: "demo") }
        let env = ProcessInfo.processInfo.environment
        guard let key = env["AGENT_KEY"], !key.isEmpty else { return nil }
        let base = env["AGENT_URL"].flatMap { URL(string: $0) } ?? URL(string: "https://api.deepseek.com")!
        return Agent.Route(base: base, key: key, model: env["AGENT_MODEL"] ?? "deepseek-flash", effort: env["AGENT_EFFORT"] ?? "low")
    }()
    #else
    private static let debugRoute: Agent.Route? = nil
    #endif

    /// The owner's own key in a build installed on their own devices (`WLAgentKey`): the same
    /// DeepSeek route, with no subscription. Never set in a build that ships.
    private static let ownKey: Agent.Route? = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "WLAgentKey") as? String, key.hasPrefix("sk-") else { return nil }
        return Agent.Route(base: URL(string: "https://api.deepseek.com")!, key: key, model: "deepseek-flash", effort: "low")
    }()

    static var available: Bool { debugRoute != nil || ownKey != nil || server != nil }
    var unlocked: Bool { Self.debugRoute != nil || Self.ownKey != nil || signed != nil }

    var route: Agent.Route? {
        if let r = Self.debugRoute ?? Self.ownKey { return r }
        guard let server = Self.server, let signed else { return nil }
        return Agent.Route(base: server, key: signed)
    }

    /// Checks the subscription now and again whenever the App Store reports a change, from launch on.
    func watch() async {
        guard !watching else { return }
        watching = true
        defer { watching = false }
        await refresh()
        for await update in Transaction.updates {
            if case .verified(let t) = update { await t.finish() }
            await refresh()
        }
    }

    private func refresh() async {
        var found: String?
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.product, t.revocationDate == nil { found = result.jwsRepresentation }
        }
        signed = found
    }
}

// MARK: the upload

/// What the Agent found: items to tick and Add, or a word that there was nothing.
private struct Found: Identifiable {
    enum Kind {
        case items([Item])
        case note(String)
    }

    let id = UUID()
    var kind: Kind
    /// For proposed items: the ones ticked to add.
    var keep: Set<Int> = []
    /// Added.
    var done = false
}

/// Not a chat, on purpose: there is nowhere to type, so nothing the student writes can steer the
/// model. They hand it files or photos, and it lists the tasks it found, to tick and add.
private struct AgentUpload: View {
    @Environment(Store.self) private var store
    @Binding var consented: Bool
    @State private var found: [Found] = []
    @State private var files: [Agent.Attachment] = []
    /// The files still being read.
    @State private var reading: [String] = []
    @State private var problem: String?
    @State private var work: Task<Void, Never>?
    @State private var choosingFile = false
    @State private var choosingPhoto = false
    @State private var photo: PhotosPickerItem?

    private var busy: Bool { work != nil }
    private var canFind: Bool { !busy && reading.isEmpty && !files.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if consented { upload } else { ask }
                ForEach($found) { $entry in result($entry) }
                if busy {
                    ProgressView()
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("The Agent is reading")
                }
                if let problem {
                    Text(problem).font(.hand(.subheadline)).foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .ground()
        .readableColumn()
        // The toast sits just above the tab bar's room.
        .toastHost()
        .environment(\.tabBarRoom, 0)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: TabBar.room) }
        .toolbar {
            if !found.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { found = []; problem = nil } label: { SketchIcon(glyph: .xmark, size: 19) }
                        .accessibilityLabel("Clear")
                }
            }
        }
        // A PhotosPicker inside a menu never opened: the menu closes first, so the picker is
        // presented from here.
        .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { urls.forEach(attach) }
        }
        .onChange(of: photo) {
            guard let photo else { return }
            Task {
                let ext = photo.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                if let data = try? await photo.loadTransferable(type: Data.self) { attach(data, name: "Photo.\(ext)") }
                else { problem = "Couldn’t open that photo." }
                self.photo = nil
            }
        }
        // A file shared to WilList from another app.
        .task(id: store.incomingFile) {
            guard let url = store.incomingFile else { return }
            store.incomingFile = nil
            attach(url)
        }
        #if DEBUG
        // `-agentAsk "words"` on launch reads a pretend file with these words (screenshots).
        .task {
            if let ask = UserDefaults.standard.string(forKey: "agentAsk"), found.isEmpty, consented {
                files = [Agent.Attachment(name: "Syllabus.txt", text: ask)]
                find()
            }
        }
        #endif
    }

    // MARK: before and while attaching

    /// The consent to send what is read to the AI model, before the first file.
    private var ask: some View {
        VStack(alignment: .leading, spacing: 16) {
            AgentIntro(title: "Before you start", detail: "Your phone reads what you share and sends the text to an AI model to find your tasks. Nothing goes into your plan until you tap Add.")
            Button { withAnimation { consented = true } } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    @ViewBuilder private var upload: some View {
        if found.isEmpty && files.isEmpty && reading.isEmpty {
            AgentIntro(title: "Hand it anything with dates", detail: "A syllabus, timetable, photo or email. It lists what to add, and you choose.")
        }
        HStack(spacing: 12) {
            pick("Choose a file", .page) { choosingFile = true }
            pick("Choose a photo", .photo) { choosingPhoto = true }
        }
        if !files.isEmpty || !reading.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(reading, id: \.self) { name in
                    chip(name) { ProgressView().controlSize(.small) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Reading \(name)")
                }
                ForEach(files, id: \.name) { f in
                    chip(f.name) {
                        SketchIcon(glyph: .paperclip, size: 21)
                        Button { files.removeAll { $0.name == f.name } } label: { SketchIcon(glyph: .xmark, size: 15) }
                            .accessibilityLabel("Remove \(f.name)")
                            .foregroundStyle(.secondary)
                            .tapArea()
                    }
                }
            }
            Button(action: find) {
                Text("Find tasks").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canFind)
        }
    }

    private func pick(_ title: String, _ symbol: SketchIcon.Glyph, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, sketch: symbol)
                .font(.hand(.body))
                .foregroundStyle(Color.brandDeep)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chip<Leading: View>(_ name: String, @ViewBuilder leading: () -> Leading) -> some View {
        HStack(spacing: 8) {
            leading()
            Text(name).lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.hand(.subheadline))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.white, in: Capsule())
    }

    @ViewBuilder private func result(_ entry: Binding<Found>) -> some View {
        switch entry.wrappedValue.kind {
        case .items(let items):
            ItemsCard(items: items, entry: entry)
        case .note(let text):
            // Plain words, never links or formatting: what a file says can't become something to tap.
            Text(verbatim: text)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: finding

    private func find() {
        guard canFind, let route = AgentPass.shared.route else { return }
        let files = self.files
        self.files = []
        problem = nil
        let state = store.state, today = store.today
        work = Task {
            do {
                let turn = try await Agent.run([Agent.message(files: files, today: today)], today: today, route: route, send: transport)
                for shown in turn.shown {
                    switch shown {
                    case .text(let t): found.append(Found(kind: .note(t)))
                    case .proposal(let items): found.append(itemsEntry(items, state: state))
                    }
                }
            } catch is CancellationError {
            } catch {
                // Nothing is kept: the files go back to be read again.
                self.files = files
                problem = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
            }
            work = nil
        }
    }

    private var transport: @Sendable (URLRequest) async throws -> (Data, Int) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "agentDemo") { return AgentDemo.send }
        #endif
        return Agent.post
    }

    /// Proposed items, with those already in the plan left unticked.
    private func itemsEntry(_ items: [Item], state: AppState) -> Found {
        let adds = planImport(state.items, items).adds
        return Found(kind: .items(items), keep: Set(items.indices.filter { i in adds.contains { $0 == items[i] } }))
    }

    // MARK: attachments

    private func attach(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { problem = "Couldn’t open that file."; return }
        attach(data, name: url.lastPathComponent)
    }

    private func attach(_ data: Data, name: String) {
        problem = nil
        // A calendar file is read here, exactly, with nothing sent anywhere.
        if (name as NSString).pathExtension.lowercased() == "ics" {
            let r = importICS(String(decoding: data, as: UTF8.self), today: store.today)
            found.append(r.items.isEmpty
                ? Found(kind: .note(r.past > 0 ? "It’s all in the past." : "Nothing with a date in it."))
                : itemsEntry(r.items.sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }, state: store.state))
            return
        }
        guard files.count + reading.count < 5 else { problem = "Five files at a time at most."; return }
        reading.append(name)
        Task {
            do {
                files.append(Agent.Attachment(name: name, text: try await fileText(data, name: name)))
            } catch {
                problem = (error as? LocalizedError)?.errorDescription ?? "Couldn’t read that file."
            }
            reading.removeAll { $0 == name }
        }
    }
}

// MARK: proposals

/// Proposed items to tick and add, or what was added.
private struct ItemsCard: View {
    @Environment(Store.self) private var store
    let items: [Item]
    @Binding var entry: Found

    /// Added, and still in the plan: Undo brings the button back.
    private var added: Bool { entry.done && planImport(store.state.items, entry.keep.sorted().map { items[$0] }).adds.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let on = entry.keep.contains(i)
                Button {
                    if on { entry.keep.remove(i) } else { entry.keep.insert(i) }
                } label: {
                    HStack(spacing: 12) {
                        DrawnCheck(done: on).frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(items[i].title).foregroundStyle(Color.primary)
                            Text(Fmt.subline(items[i], store.today)).font(.hand(.subheadline)).foregroundStyle(Color.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(added)
                .accessibilityAddTraits(on ? .isSelected : [])
                if i < items.count - 1 { Divider().padding(.leading, 36) }
            }
            Group {
                if added {
                    Label("Added", sketch: .check, size: 17).foregroundStyle(Color.brandDeep).font(.hand(.body))
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Button {
                        let chosen = entry.keep.sorted().map { items[$0] }
                        store.change(undo: "Added \(chosen.count) \(chosen.count == 1 ? "item" : "items")") { s in
                            _ = s.applyImport(planImport(s.items, chosen), today: store.today)
                        }
                        withAnimation { entry.done = true }
                    } label: {
                        Text("Add \(entry.keep.count)").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(entry.keep.isEmpty)
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.success, trigger: added) { _, now in now }
    }
}

#if DEBUG
/// Scripted answers for `-agentDemo YES`: whatever is handed over, three things are proposed.
enum AgentDemo {
    static func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await Task.sleep(for: .seconds(1))
        let body = try JSONDecoder().decode(JSONValue.self, from: request.httpBody ?? Data())
        let last = body["messages"]?.array?.last
        func item(_ title: String, _ days: Int, _ time: String) -> JSONValue {
            ["title": .string(title), "date": .string(addDays(WilListCore.today(), days)), "time": .string(time), "course": "CHEM110", "repeatDays": []]
        }
        let message: JSONValue
        if last?["role"] == "tool" {
            message = ["role": "assistant", "content": "I found a quiz, a lab report and a reading. Tick what you want and tap Add."]
        } else {
            let items: JSONValue = ["items": [item("Quiz 3", 3, "09:00"), item("Lab report", 6, "23:59"), item("Read chapter 7", 2, "")]]
            message = ["role": "assistant", "content": .null, "tool_calls": [["id": "demo1", "type": "function", "function": [
                "name": "propose_items", "arguments": .string(String(decoding: try JSONEncoder().encode(items), as: UTF8.self))]]]]
        }
        let finish: JSONValue = message["tool_calls"] == nil ? "stop" : "tool_calls"
        return (try JSONEncoder().encode(["choices": [["index": 0, "message": message, "finish_reason": finish]]] as JSONValue), 200)
    }
}
#endif
