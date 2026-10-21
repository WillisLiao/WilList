import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WilListCore

/// Bring in a whole schedule at once: any file or photo (read by Claude), a calendar file,
/// pasted text, or a calendar link that stays in sync.
struct ImportSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var phase = Phase.choose
    @State private var choosingFile = false
    @State private var photo: PhotosPickerItem?
    @State private var pasting = false
    @State private var pasted = ""
    @State private var found: [Item] = []
    @State private var keep: Set<Int> = []
    @State private var cost: Double?
    @State private var work: Task<Void, Never>?

    enum Phase: Equatable { case choose, reading(String), review, failed(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .choose: choose
                case .reading(let what): reading(what)
                case .review: review
                case .failed(let why): failed(why)
                }
            }
            .navigationTitle("Bring in a schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { work?.cancel(); dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { open(url) }
        }
        .task {
            if let url = store.incomingFile {
                store.incomingFile = nil
                open(url)
            }
        }
        .onChange(of: photo) {
            guard let photo else { return }
            phase = .reading("your photo")
            Task {
                let ext = photo.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                if let data = try? await photo.loadTransferable(type: Data.self) { read(data, name: "Photo.\(ext)") }
                else { phase = .failed("Couldn't open that photo.") }
                self.photo = nil
            }
        }
    }

    // MARK: phases

    private var choose: some View {
        Form {
            Section {
                Button { choosingFile = true } label: {
                    ImportOption(title: "Choose a file", detail: "PDF, Word, Excel, PowerPoint, a calendar file or text", symbol: "doc")
                }
                PhotosPicker(selection: $photo, matching: .images) {
                    ImportOption(title: "Choose a photo", detail: "A printed timetable, a whiteboard, a screenshot", symbol: "photo")
                }
                Button { pasting.toggle() } label: {
                    ImportOption(title: "Paste text", detail: "An email, a course page, a list", symbol: "doc.on.clipboard")
                }
                if pasting {
                    TextField("Paste or type the schedule here", text: $pasted, axis: .vertical).lineLimit(4...12)
                    Button("Read it") { read(text: pasted) }.disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } footer: {
                Text(Keychain.apiKey == nil
                     ? "Files, photos and text are read by Claude. Add your Anthropic API key in More first. Calendar files don't need it."
                     : "Claude reads it and finds every exam, deadline, class and shift, for any kind of course, job or project. You check the list before anything is added.")
            }
            Section {
                NavigationLink { AddFeedSheet() } label: {
                    ImportOption(title: "Add a calendar link", detail: "Canvas, Moodle, Google and others stay up to date by themselves", symbol: "link")
                }
            }
        }
    }


    private func reading(_ what: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Reading \(what)…").font(.headline)
            Text("A long syllabus can take a minute.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failed(_ why: String) -> some View {
        Form {
            Section {
                Text(why)
                Button("Try something else") { phase = .choose }
            }
        }
    }

    private var review: some View {
        let plan = planImport(store.state.items, found)
        let existing = Set(found.indices.filter { i in !plan.adds.contains { $0 == found[i] } })
        return Form {
            Section {
                ForEach(found.indices, id: \.self) { i in
                    let it = found[i]
                    Button {
                        if keep.contains(i) { keep.remove(i) } else { keep.insert(i) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: keep.contains(i) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(keep.contains(i) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.title).foregroundStyle(.primary)
                                Text([it.type.name, Fmt.subline(it, store.today), existing.contains(i) ? "already in WilList" : nil]
                                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("Found \(found.count)")
            } footer: {
                if let cost { Text("Reading it cost about \(cost.formatted(.currency(code: "USD").precision(.fractionLength(2...3)))) on your Anthropic account.") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                let chosen = keep.sorted().map { found[$0] }
                store.change { s in s.applyImport(planImport(s.items, chosen), today: store.today) }
                store.say("Added \(chosen.count) \(chosen.count == 1 ? "item" : "items"). Give them a letter in Goals.")
                dismiss()
            } label: {
                Text("Add \(keep.count) \(keep.count == 1 ? "item" : "items")").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(keep.isEmpty)
            .padding()
        }
        .onAppear { keep = Set(found.indices).subtracting(existing) }
    }

    // MARK: reading

    private func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { phase = .failed("Couldn't open that file."); return }
        read(data, name: url.lastPathComponent)
    }

    private func read(_ data: Data, name: String) {
        if (name as NSString).pathExtension.lowercased() == "ics" {
            let r = importICS(String(decoding: data, as: UTF8.self), today: store.today)
            show(r.items, cost: nil, empty: r.past > 0 ? "Everything in that calendar is already over." : "No dated items in that calendar.")
            return
        }
        do {
            let content = try Claude.fileContent(data, name: name)
            ask(content, what: name.hasPrefix("Photo.") ? "your photo" : name)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't read that file.")
        }
    }

    private func read(text: String) {
        ask(Claude.textContent(text), what: "your text")
    }

    private func ask(_ content: [JSONValue], what: String) {
        phase = .reading(what)
        work = Task {
            do {
                let r = try await Claude.extract(content, today: store.today, key: Keychain.apiKey ?? "")
                show(r.items, cost: r.costUSD, empty: "Claude found nothing with a date in it.")
            } catch is CancellationError {
            } catch {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Something went wrong.")
            }
        }
    }

    private func show(_ items: [Item], cost: Double?, empty: String) {
        guard !items.isEmpty else { phase = .failed(empty); return }
        found = items.sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }
        self.cost = cost
        phase = .review
    }
}

private struct ImportOption: View {
    let title: String, detail: String, symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }
}
