import SwiftUI
import WilListCore

/// Add items by typing them the way you'd say them. The sheet stays open, so a whole week can
/// go in one after another. As New study block (`preset` `.study`) it adds a set time to study,
/// every week if you like.
struct AddItemSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var preset: ItemType?
    #if DEBUG
    @State private var text = UserDefaults.standard.string(forKey: "draft") ?? ""
    #else
    @State private var text = ""
    #endif
    @State private var chosenLetter: Letter??
    @State private var weekly = false
    @State private var added: [String] = []
    @FocusState private var focused: Bool

    private var parsed: Parsed { quickAdd(text, today: store.today, minute: nowMinutes(), dateOrder: store.dateOrder) }
    private var type: ItemType { preset == .study ? .study : parsed.type == .task ? preset ?? .task : parsed.type }
    private var study: Bool { type == .study }
    private var letter: Letter? { chosenLetter ?? parsed.priority ?? suggestedLetter(type, weightPct: parsed.weightPct) }
    private var empty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
    /// A study block needs its time.
    private var ready: Bool { !empty && !(study && parsed.time == nil) }

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
                        Text(study ? "Like \u{201C}Organic chem tue 7pm 2h\u{201D}" : "Like \u{201C}Essay due fri 4h #ENG101\u{201D}")
                    } else if study && parsed.time == nil {
                        Text("Add a time, like \u{201C}7pm\u{201D}")
                    } else if let hint = parsed.hints.first {
                        Text(advice(hint))
                    }
                }

                if !empty { understood }

                if !study {
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
                    Button("Add", action: add).disabled(!ready)
                }
            }
            .sensoryFeedback(.success, trigger: added.count)
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.string(forKey: "draft") != nil { return } // screenshots without the keyboard
                #endif
                focused = true
            }
        }
    }

    private var placeholder: String {
        switch preset {
        case .study: "What and when"
        case .exam: "Chem quiz thu 9am #CHEM110"
        case .deadline: "Lab report due fri 5pm"
        default: "What and when"
        }
    }

    /// What WilList read from the text, so a wrong guess is caught before it's saved.
    private var understood: some View {
        let p = parsed
        return Section {
            if p.title != text.trimmingCharacters(in: .whitespaces) { LabeledContent("Title", value: p.title) }
            if let d = p.date {
                LabeledContent("When", value: [Fmt.date(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), Fmt.time(p.time)].compactMap { $0 }.joined(separator: ", "))
            }
            if study, p.time != nil { LabeledContent("Lasts", value: Fmt.minutes(p.durationMin ?? 60)) }
            if let r = p.recur {
                LabeledContent("Repeats", value: Fmt.recur(r))
            } else if study {
                Toggle("Every week", isOn: $weekly).tint(.brand)
            }
            if let c = p.course { LabeledContent("Course", value: c) }
            if let w = p.weightPct { LabeledContent("Share of grade", value: "\(w.formatted())%") }
            if let plan = planPreview { LabeledContent("Plan", value: plan) }
        }
    }

    private var draft: Item {
        var it = Item(parsed)
        it.type = type
        it.priority = study ? nil : letter
        if study && weekly && it.recur == nil, let d = it.date { it.recur = Recur(.weekly, days: [weekday(d)]) }
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
        guard ready else { return }
        let it = draft
        withAnimation { store.add(it) }
        added.insert(it.title, at: 0)
        text = ""
        chosenLetter = nil
        weekly = false
        focused = true
    }
}
