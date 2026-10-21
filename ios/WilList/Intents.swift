import AppIntents
import WilListCore

// Siri, Shortcuts, Spotlight and the Action button: add without opening the app.

struct AddToDoIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a to-do"
    static let description = IntentDescription("Adds a line to Today in WilList.")

    @Parameter(title: "To-do", requestValueDialog: "What do you need to do?")
    var text: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return .result(dialog: "Nothing to add.") }
        Store.shared.change { $0.addTodo(line) }
        return .result(dialog: "Added \u{201C}\(line)\u{201D} to Today.")
    }
}

struct AddToPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to the plan"
    static let description = IntentDescription("Adds an exam, deadline, class or task to WilList, said the way you'd say it: \u{201C}Chem quiz Thursday 9am\u{201D}.")

    @Parameter(title: "What and when", requestValueDialog: "What is it, and when?")
    var text: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        let p = quickAdd(text, today: store.today, minute: nowMinutes(), dateOrder: store.dateOrder)
        guard !p.title.isEmpty else { return .result(dialog: "Nothing to add.") }
        var draft = Item(p)
        draft.priority = p.priority ?? suggestedLetter(p.type, weightPct: p.weightPct)
        store.add(draft)
        let when = p.date.map { " for \(Fmt.day($0, store.today, inSentence: true))" } ?? ""
        return .result(dialog: "Added \u{201C}\(p.title)\u{201D}\(when).")
    }
}

struct WilListShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddToDoIntent(),
                    phrases: ["Add a to-do in \(.applicationName)", "Add to \(.applicationName)"],
                    shortTitle: "Add a to-do", systemImageName: "checklist")
        AppShortcut(intent: AddToPlanIntent(),
                    phrases: ["Add to my \(.applicationName) plan", "Plan something in \(.applicationName)"],
                    shortTitle: "Add to the plan", systemImageName: "target")
    }
}
