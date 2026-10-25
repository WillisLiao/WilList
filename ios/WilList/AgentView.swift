import PhotosUI
import StoreKit
import SwiftUI
import UniformTypeIdentifiers
import WilListCore

/// The Agent: a chat that takes anything with dates in it (a file, a photo, words), proposes what
/// to add, and answers questions about the plan. It is a subscription, and asks before anything is
/// first sent to the AI model; nothing goes into the plan without a tap.
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
                    AgentChat(consented: $consented)
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
            AgentIntro(title: "Hand it anything with dates", detail: "A syllabus, timetable, photo or email. The Agent finds what to add and answers questions about your plan.")
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
            Image(systemName: "sparkles")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.brand)
                .accessibilityHidden(true)
            Text(title).font(.title2.bold())
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

    static var available: Bool { debugRoute != nil || server != nil }
    var unlocked: Bool { Self.debugRoute != nil || signed != nil }

    var route: Agent.Route? {
        if let r = Self.debugRoute { return r }
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

// MARK: the chat

private struct ChatEntry: Identifiable {
    enum Kind {
        case you(String, files: [String])
        case agent(String)
        case items([Item])
        case calendar(Feed)
    }

    let id = UUID()
    var kind: Kind
    /// For proposed items: the ones ticked to add.
    var keep: Set<Int> = []
    /// Added or followed.
    var done = false
}

private struct AgentChat: View {
    @Environment(Store.self) private var store
    @Binding var consented: Bool
    @State private var messages: [JSONValue] = []
    @State private var entries: [ChatEntry] = []
    /// Everything the student typed: only links in it can be followed.
    @State private var typed = ""
    @State private var draft = ""
    @State private var files: [Agent.Attachment] = []
    /// The files still being read.
    @State private var reading: [String] = []
    @State private var problem: String?
    @State private var work: Task<Void, Never>?
    @State private var choosingFile = false
    @State private var photo: PhotosPickerItem?
    @State private var keyboardUp = false
    @FocusState private var focused: Bool

    private var busy: Bool { work != nil }
    private var canSend: Bool { !busy && reading.isEmpty && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.isEmpty) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty { start }
                ForEach($entries) { $entry in row($entry) }
                if busy {
                    ProgressView()
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color.white, in: bubble)
                        .accessibilityLabel("The Agent is answering")
                }
                if let problem {
                    Text(problem)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)
        }
        // New messages scroll into view; a short chat still starts at the top.
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .ground()
        .readableColumn()
        // The toast sits just above the message field, not under it.
        .toastHost()
        .environment(\.tabBarRoom, 0)
        .safeAreaInset(edge: .bottom) {
            if consented {
                composer
                    // Clear of the tab bar, or of the keyboard when it's up (it covers the bar).
                    .padding(.bottom, keyboardUp ? 8 : TabBar.room)
            } else {
                Color.clear.frame(height: TabBar.room)
            }
        }
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.bottom > 150 } action: { keyboardUp = $0 }
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil") { newChat() }
                }
            }
        }
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
        // `-agentAsk "words"` on launch sends them (screenshots).
        .task {
            if let ask = UserDefaults.standard.string(forKey: "agentAsk"), entries.isEmpty, consented { send(ask) }
        }
        #endif
    }

    private var bubble: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }

    // MARK: rows

    /// Before the first message: what the Agent does, and the consent to send things to the AI model.
    @ViewBuilder private var start: some View {
        if consented {
            AgentIntro(title: "Hand it anything with dates", detail: "A syllabus, timetable, photo or email. You choose what goes in.")
            ForEach(["What should I do first today?", "How did my week go?"], id: \.self) { ask in
                Button(ask) { send(ask) }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.brandDeep)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.white, in: Capsule())
                    .buttonStyle(.plain)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                AgentIntro(title: "Before you start", detail: "Your phone reads what you share and sends the text, with your plan, to an AI model to answer. Nothing goes into your plan until you tap Add.")
                Button { withAnimation { consented = true } } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder private func row(_ entry: Binding<ChatEntry>) -> some View {
        switch entry.wrappedValue.kind {
        case .you(let text, let names):
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "paperclip").font(.subheadline.weight(.medium)).lineLimit(1)
                }
                if !text.isEmpty { Text(verbatim: text) }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.brandDeep, in: bubble)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
        case .agent(let text):
            // Plain words, never links or formatting: what a file says can't become something to tap.
            Text(verbatim: text)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white, in: bubble)
                .padding(.trailing, 40)
        case .items(let items):
            ItemsCard(items: items, entry: entry)
        case .calendar(let feed):
            CalendarCard(feed: feed, entry: entry)
        }
    }

    // MARK: composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !files.isEmpty || !reading.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(reading, id: \.self) { name in
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(name).lineLimit(1)
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color.white, in: Capsule())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Reading \(name)")
                        }
                        ForEach(files, id: \.name) { f in
                            HStack(spacing: 4) {
                                Label(f.name, systemImage: "paperclip").lineLimit(1)
                                Button("Remove \(f.name)", systemImage: "xmark.circle.fill") { files.removeAll { $0.name == f.name } }
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.secondary)
                                    .tapArea()
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.leading, 12)
                            .background(Color.white, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            HStack(alignment: .bottom, spacing: 4) {
                Menu {
                    Button("Choose a file", systemImage: "doc") { choosingFile = true }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose a photo", systemImage: "photo") }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.brandDeep)
                        .tapArea()
                }
                // A plain + on every device; a Mac would draw a pop-up button with a chevron, and
                // sizes the menu to its glyph, which then sat low in the bar.
                .menuIndicator(.hidden)
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Attach")
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.vertical, 11)
                Button("Send", systemImage: "arrow.up.circle.fill") { send(draft) }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? Color.brand : Color(.systemGray3))
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .tapArea()
                    .buttonStyle(.borderless)
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        // In the chat's column on a wide screen (iPad, Mac), lined up with the bubbles.
        .frame(maxWidth: ReadableColumn.width)
    }

    // MARK: sending

    private func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !text.isEmpty || !files.isEmpty, let route = AgentPass.shared.route else { return }
        let files = self.files, you = ChatEntry(kind: .you(text, files: files.map(\.name)))
        entries.append(you)
        draft = ""
        self.files = []
        problem = nil
        let start = messages + [Agent.message(text, files: files, today: store.today)]
        let typed = self.typed + "\n" + text
        let state = store.state, today = store.today
        work = Task {
            do {
                let turn = try await Agent.run(start, state: state, today: today, typed: typed, route: route, send: transport)
                messages = turn.messages
                self.typed = typed
                for shown in turn.shown {
                    switch shown {
                    case .text(let t): entries.append(ChatEntry(kind: .agent(t)))
                    case .proposal(.items(let items)): entries.append(itemsEntry(items))
                    case .proposal(.calendar(let feed)): entries.append(ChatEntry(kind: .calendar(feed)))
                    }
                }
            } catch is CancellationError {
            } catch {
                // Nothing of the turn is kept: the words and files go back to be sent again.
                entries.removeAll { $0.id == you.id }
                draft = text
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
    private func itemsEntry(_ items: [Item]) -> ChatEntry {
        let adds = planImport(store.state.items, items).adds
        return ChatEntry(kind: .items(items), keep: Set(items.indices.filter { i in adds.contains { $0 == items[i] } }))
    }

    private func newChat() {
        work?.cancel()
        work = nil
        messages = []
        entries = []
        typed = ""
        problem = nil
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
            entries.append(ChatEntry(kind: .you("", files: [name])))
            entries.append(r.items.isEmpty
                ? ChatEntry(kind: .agent(r.past > 0 ? "It’s all in the past." : "Nothing with a date in it."))
                : itemsEntry(r.items.sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }))
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
    @Binding var entry: ChatEntry

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
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(on ? Color.brand : Color(.tertiaryLabel))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(items[i].title).foregroundStyle(Color.primary)
                            Text(Fmt.subline(items[i], store.today)).font(.subheadline).foregroundStyle(Color.secondary)
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
                    Label("Added", systemImage: "checkmark").foregroundStyle(Color.brandDeep).font(.body.weight(.semibold))
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

/// A calendar link the student typed, to follow or not.
private struct CalendarCard: View {
    @Environment(Store.self) private var store
    let feed: Feed
    @Binding var entry: ChatEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus").font(.title3).foregroundStyle(Color.brand).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.name).font(.headline)
                Text(URL(string: feed.url)?.host() ?? feed.url).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if entry.done {
                Label("Following", systemImage: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.brandDeep)
            } else {
                Button("Follow") {
                    withAnimation { entry.done = true }
                    Task { await store.addFeed(feed.url, name: feed.name) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#if DEBUG
/// Scripted answers for `-agentDemo YES`: a file or a syllabus is read against the plan and three
/// things are proposed; a question is answered in words.
enum AgentDemo {
    static func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await Task.sleep(for: .seconds(1))
        let body = try JSONDecoder().decode(JSONValue.self, from: request.httpBody ?? Data())
        let last = body["messages"]?.array?.last
        func item(_ title: String, _ days: Int, _ time: String) -> JSONValue {
            ["title": .string(title), "date": .string(addDays(WilListCore.today(), days)), "time": .string(time), "course": "CHEM110", "repeatDays": []]
        }
        func call(_ id: String, _ name: String, _ input: JSONValue) -> JSONValue {
            ["role": "assistant", "content": .null, "tool_calls": [["id": .string(id), "type": "function", "function": [
                "name": .string(name), "arguments": .string(String(decoding: try! JSONEncoder().encode(input), as: UTF8.self))]]]]
        }
        let words = last?["content"]?.string ?? ""
        let shared = words.contains("The student attached") || words.lowercased().contains("syllabus")
        let message: JSONValue
        switch last?["role"] == "tool" ? last?["tool_call_id"]?.string : nil {
        case "demo1":
            message = call("demo2", "propose_items", ["items": [item("Quiz 3", 3, "09:00"), item("Lab report", 6, "23:59"), item("Read chapter 7", 2, "")]])
        case "demo2":
            message = ["role": "assistant", "content": "I found a quiz, a lab report and a reading. Tick what you want and tap Add."]
        default:
            message = shared
                ? call("demo1", "read_plan", [:])
                : ["role": "assistant", "content": "You finished 9 things this week, 4 of them A’s. Thursday is your heaviest day, so start the lab report tomorrow."]
        }
        let finish: JSONValue = message["tool_calls"] == nil ? "stop" : "tool_calls"
        return (try JSONEncoder().encode(["choices": [["index": 0, "message": message, "finish_reason": finish]]] as JSONValue), 200)
    }
}
#endif
