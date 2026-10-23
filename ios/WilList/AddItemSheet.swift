import SwiftUI
import WilListCore

/// Add items by typing them the way you'd say them. The sheet stays open, so a whole week can
/// go in one after another.
struct AddItemSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var preset: ItemType?
    /// The letter chosen as it opens: A when Today asks for the day's A1.
    var startLetter: Letter?
    #if DEBUG
    @State private var text = UserDefaults.standard.string(forKey: "draft") ?? ""
    #else
    @State private var text = ""
    #endif
    @State private var chosenLetter: Letter??
    @State private var chosenType: ItemType?
    @State private var added: [String] = []
    @FocusState private var focused: Bool

    private var parsed: Parsed { quickAdd(text, today: store.today, minute: nowMinutes(), dateOrder: store.dateOrder) }
    private var type: ItemType { chosenType ?? (parsed.type == .task ? preset ?? .task : parsed.type) }
    private var letter: Letter? { chosenLetter ?? parsed.priority ?? suggestedLetter(type, weightPct: parsed.weightPct) }
    private var empty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .font(.title3)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                } footer: {
                    if empty {
                        Text("Like \u{201C}Essay due fri 4h #ENG101\u{201D}")
                    } else if let hint = parsed.hints.first {
                        Text(advice(hint))
                    }
                }

                if !empty { understood }

                Section {
                    HStack(spacing: 8) {
                        ForEach(Letter.allCases, id: \.self) { l in
                            Button { chosenLetter = .some(l == letter ? nil : l) } label: {
                                Text(l.rawValue)
                                    .font(.headline)
                                    .strikethrough(l == .E)
                                    // Its colour in full once chosen, a pale wash of it until then (yellow
                                    // and green words can't be read on white).
                                    .foregroundStyle(letter == l ? l.ink : Color.primary)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(letter == l ? l.color : l.color.opacity(0.22), in: Capsule())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(l.rawValue): \(l.meaning)")
                            .accessibilityAddTraits(letter == l ? .isSelected : [])
                        }
                    }
                    .sensoryFeedback(.selection, trigger: letter)
                } header: {
                    Text("Letter")
                } footer: {
                    if let letter { Text(letter.meaning) }
                }

                if !added.isEmpty {
                    Section("Added") {
                        ForEach(added.indices, id: \.self) { Text(added[$0]).foregroundStyle(.secondary) }
                    }
                }
            }
            .sheetGround()
            .navigationTitle("New \(type.name.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(added.isEmpty ? "Cancel" : "Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(empty)
                }
            }
            .sensoryFeedback(.success, trigger: added.count)
            .onAppear {
                if let startLetter, chosenLetter == nil { chosenLetter = .some(startLetter) }
                #if DEBUG
                if UserDefaults.standard.string(forKey: "draft") != nil { return } // screenshots without the keyboard
                #endif
                focused = true
            }
        }
    }

    private var placeholder: String {
        switch preset {
        case .exam: "Chem quiz thu 9am #CHEM110"
        case .deadline: "Lab report due fri 5pm"
        default: "What and when"
        }
    }

    /// What WilList read from the text, so a wrong guess is caught before it's saved.
    private var understood: some View {
        let p = parsed
        return Section {
            Picker("Kind", selection: Binding(get: { type }, set: { chosenType = $0 })) {
                ForEach(ItemType.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            if p.title != text.trimmingCharacters(in: .whitespaces) { LabeledContent("Title", value: p.title) }
            if let d = p.date {
                LabeledContent("When", value: [Fmt.date(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), Fmt.time(p.time)].compactMap { $0 }.joined(separator: ", "))
            }
            if let r = p.recur { LabeledContent("Repeats", value: Fmt.recur(r)) }
            if let c = p.course { LabeledContent("Course", value: c) }
            if let w = p.weightPct { LabeledContent("Share of grade", value: "\(w.formatted())%") }
            if let plan = planPreview { LabeledContent("Plan", value: plan) }
        }
    }

    private var draft: Item {
        var it = Item(parsed)
        it.type = type
        it.priority = letter
        return it
    }

    /// "8 h in 6 sessions from Mon" for work WilList will plan.
    private var planPreview: String? {
        guard plannedTypes.contains(type), parsed.recur == nil, parsed.date != nil else { return nil }
        let it = makeItem(draft, store.state.settings, store.today, store.state.items)
        guard let start = it.sessions.first?.date else {
            return it.shortfallMin > 0 ? "Too late to plan" : nil
        }
        return "\(Fmt.minutes(it.effortMin)) in \(it.sessions.count) \(it.sessions.count == 1 ? "session" : "sessions") from \(Fmt.day(start, store.today, inSentence: true))"
    }

    private func advice(_ hint: Hint) -> String {
        switch hint {
        case .tryTo: "Don’t try. Decide."
        case .wish: "Give the wish a date."
        case .haveTo: "You choose to. Say \u{201C}I will\u{201D}."
        case .problem: "Call it a situation."
        }
    }

    private func add() {
        guard !empty else { return }
        let it = draft
        withAnimation { store.add(it) }
        added.insert(it.title, at: 0)
        text = ""
        chosenLetter = nil
        chosenType = nil
        focused = true
    }
}
