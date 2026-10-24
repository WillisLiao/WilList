import SwiftUI
import WilListCore

/// Add tasks by typing them the way you'd say them: the words give the date, time, repeat and
/// course, never the kind, which is always a task. The sheet stays open, so a whole week can go in
/// one after another. As New study block (`study`) it adds a set time to study, every week if you like.
struct AddItemSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var study = false
    #if DEBUG
    @State private var text = UserDefaults.standard.string(forKey: "draft") ?? ""
    #else
    @State private var text = ""
    #endif
    @State private var chosenLetter: Letter??
    // A reminder, date, time or repeat set in the rows; nil until then, so the words decide.
    @State private var remindAt: String?
    @State private var chosenDate: Day??
    @State private var chosenTime: String??
    @State private var chosenRecur: Recur??
    @State private var weekly = false
    @State private var added: [String] = []
    @FocusState private var focused: Bool

    private var parsed: Parsed { quickAdd(text, today: store.today, minute: nowMinutes(), dateOrder: store.dateOrder) }
    private var type: ItemType { study ? .study : .task }
    private var letter: Letter? { chosenLetter ?? parsed.priority }
    private var date: Binding<Day?> { Binding(get: { chosenDate ?? parsed.date }, set: { chosenDate = .some($0) }) }
    private var time: Binding<String?> { Binding(get: { chosenTime ?? parsed.time }, set: { chosenTime = .some($0) }) }
    private var recur: Binding<Recur?> { Binding(get: { chosenRecur ?? parsed.recur }, set: { chosenRecur = .some($0) }) }
    private var empty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
    /// A study block needs its time.
    private var ready: Bool { !empty && !(study && parsed.time == nil) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What and when", text: $text)
                        .font(.title3)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                } footer: {
                    if empty {
                        Text(study ? "Like \u{201C}Organic chem tue 7pm 2h\u{201D}" : "Like \u{201C}Essay due fri 5pm #ENG101\u{201D}")
                    } else if study && parsed.time == nil {
                        Text("Add a time, like \u{201C}7pm\u{201D}")
                    } else if let hint = parsed.hints.first {
                        Text(advice(hint))
                    }
                }

                // A study block's when and how long come first; a task's letter, reminder, date and
                // repeat do, so they stay above the keyboard.
                if study {
                    if !empty { understood }
                } else {
                    Section {
                        LetterChips(letter: letter) { chosenLetter = .some($0) }
                    } header: {
                        Text("Letter")
                    } footer: {
                        if let letter { Text(letter.meaning) }
                    }

                    // The same rows as the item's details, so nothing waits until it's added.
                    Section {
                        ReminderRow(at: $remindAt, today: store.today)
                        DueRow(date: date, time: time, today: store.today, title: type.dueWord, add: "Add a date")
                        RepeatRow(recur: recur, date: date, today: store.today)
                    }

                    if !empty { understood }
                }

                if !added.isEmpty {
                    Section("Added") {
                        ForEach(added.indices, id: \.self) { Text(added[$0]).foregroundStyle(.secondary) }
                    }
                }
            }
            .listSectionSpacing(.compact)
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

    /// What WilList read from the text, so a wrong guess is caught before it's saved.
    private var understood: some View {
        let p = parsed
        return Section {
            if p.title != text.trimmingCharacters(in: .whitespaces) { LabeledContent("Title", value: p.title) }
            // A task's date and repeat show in their own rows.
            if study {
                if let d = p.date {
                    LabeledContent("When", value: [Fmt.date(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), Fmt.time(p.time)].compactMap { $0 }.joined(separator: ", "))
                }
                if p.time != nil { LabeledContent("Lasts", value: Fmt.minutes(p.durationMin ?? 60)) }
                if let r = p.recur {
                    LabeledContent("Repeats", value: Fmt.recur(r))
                } else {
                    Toggle("Every week", isOn: $weekly).tint(.brand)
                }
            }
            if let c = p.course { LabeledContent("Course", value: c) }
        }
    }

    private var draft: Item {
        var it = Item(parsed)
        it.type = type
        it.priority = study ? nil : letter
        it.date = date.wrappedValue
        it.time = time.wrappedValue
        it.recur = recur.wrappedValue
        it.remindAt = remindAt
        if study && weekly && it.recur == nil, let d = it.date { it.recur = Recur(.weekly, days: [weekday(d)]) }
        return it
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
        remindAt = nil
        chosenDate = nil
        chosenTime = nil
        chosenRecur = nil
        weekly = false
        focused = true
    }
}
