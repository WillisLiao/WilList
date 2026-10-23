import SwiftUI
import WilListCore

/// The first launch, in three short steps that are Tracy's method in miniature: write down what
/// you have to do, pick the one that matters most (your A1), and name your main goal.
/// Skip keeps whatever has been typed so far.
struct WelcomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Called once the plan is saved, so the app can open on the A1.
    let finished: () -> Void

    #if DEBUG
    // `-welcome 2` or `-welcome 3` on launch opens that step with sample lines (screenshots).
    @State private var step = UserDefaults.standard.integer(forKey: "welcome").clamped(1, 3)
    @State private var lines = UserDefaults.standard.integer(forKey: "welcome") > 1
        ? ["Read chapter 4 for psych", "Lab report due fri", "Calc midterm next thu", "Email Prof. Chen"] : []
    @State private var first: Int? = UserDefaults.standard.integer(forKey: "welcome") > 1 ? 1 : nil
    #else
    @State private var step = 1
    @State private var lines: [String] = []
    @State private var first: Int?
    #endif
    @State private var draft = ""
    @State private var goal = ""
    @FocusState private var typing: Bool

    var body: some View {
        StepPage(step: step, of: 3, title: title, subtitle: subtitle, exit: "Skip", back: { step -= 1 }, leave: finish,
                 button: step == 1 ? "Next" : step == 2 ? "Make it my A1" : "Start",
                 enabled: step == 1 ? !(lines.isEmpty && trimmed(draft).isEmpty) : step == 2 ? first != nil : true,
                 next: next) {
            switch step {
            case 1:
                LinesEntry(lines: $lines, draft: $draft, typing: $typing, placeholder: "Read chapter 4 by Monday")
            case 2:
                VStack(spacing: 0) {
                    ForEach(lines.indices, id: \.self) { i in
                        A1Choice(title: lines[i], chosen: first == i) { first = i }
                    }
                }
            default:
                mainGoal
            }
        }
        .animation(.snappy, value: step)
        .sensoryFeedback(.selection, trigger: first)
        .onAppear { if step == 1 { typing = true } }
    }

    private var title: String {
        switch step {
        case 1: "What do you have to do?"
        case 2: "Which one matters most?"
        default: "What is your main goal?"
        }
    }

    private var subtitle: String {
        switch step {
        case 1: "One thing per line."
        case 2: "If you could do only one, that’s your A1."
        default: "Written down, it’s far more likely to happen."
        }
    }

    // MARK: steps

    private var mainGoal: some View {
        TextField("Finish the term with a 3.7 GPA", text: $goal, axis: .vertical)
            .font(.title3)
            .lineLimit(2...5)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: actions

    private func next() {
        switch step {
        case 1:
            LinesEntry.keep(&draft, in: &lines)
            typing = false
            // With one thing written down, it is the A1: preselect it.
            if lines.count == 1 { first = 0 }
            step = 2
        case 2:
            step = 3
        default:
            finish()
        }
    }

    /// Saves what's been written so far, marks the welcome as seen and opens the plan.
    private func finish() {
        let all = lines + (step == 1 && !trimmed(draft).isEmpty ? [trimmed(draft)] : [])
        let chosen = step > 1 ? first : nil
        let today = store.today, order = store.dateOrder, goal = trimmed(goal)
        store.change { s in
            for (i, line) in all.enumerated() {
                var draft = Item(quickAdd(line, today: today, minute: nowMinutes(), dateOrder: order))
                if i == chosen { draft.priority = .A }
                s.items.append(makeItem(draft, s.settings, today, s.items))
            }
            if !goal.isEmpty { s.mdp = goal }
            s.meta.onboarded = true
        }
        dismiss()
        finished()
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Int {
    func clamped(_ low: Int, _ high: Int) -> Int { Swift.min(Swift.max(self, low), high) }
}
