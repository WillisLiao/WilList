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
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .fontDesign(Look.current.titles)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)
                    switch step {
                    case 1: writeDown
                    case 2: pickFirst
                    default: mainGoal
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            primaryButton
        }
        .background(Color.white)
        .animation(.snappy, value: step)
        .sensoryFeedback(.selection, trigger: first)
        .onAppear { if step == 1 { typing = true } }
    }

    // MARK: chrome

    private var topBar: some View {
        HStack {
            if step > 1 {
                Button("Back", systemImage: "chevron.left") { step -= 1 }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
            Text("\(step) of 3")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.leading, step > 1 ? 0 : 12)
            Spacer()
            Button("Skip") { finish() }
                .frame(minWidth: 44, minHeight: 44)
        }
        .font(.body.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var title: String {
        switch step {
        case 1: "What do you have to do?"
        case 2: "Which one matters most?"
        default: "What's your main goal?"
        }
    }

    private var subtitle: String {
        switch step {
        case 1: "Get it out of your head, one thing per line. Dates are read for you, like \u{201C}Essay due fri\u{201D}."
        case 2: "If you could do only one of these, which would it be? That's your A1. You do it first."
        default: "The one goal that would change the most for you this term. Written down, it's far more likely to happen."
        }
    }

    private var primaryButton: some View {
        Button(action: next) {
            Text(step == 1 ? "Next" : step == 2 ? "Make it my A1" : "Start")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(step == 1 ? lines.isEmpty && trimmed(draft).isEmpty : step == 2 ? first == nil : false)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: steps

    private var writeDown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Image(systemName: Look.current.box.empty).font(.title3).foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                    Text(lines[i]).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Remove", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { _ = lines.remove(at: i) }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Remove \(lines[i])")
                }
                .frame(minHeight: 48)
                Divider().padding(.leading, 36)
            }
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
                TextField(lines.isEmpty ? "Read chapter 4 by Monday" : "And next?", text: $draft)
                    .focused($typing)
                    .submitLabel(.next)
                    .onSubmit(addLine)
            }
            .frame(minHeight: 48)
        }
    }

    private var pickFirst: some View {
        VStack(spacing: 0) {
            ForEach(lines.indices, id: \.self) { i in
                Button { first = i } label: {
                    HStack(spacing: 12) {
                        Group {
                            if first == i {
                                LetterMark(letter: .A, label: "A1")
                            } else {
                                Image(systemName: Look.current.box.empty).font(.title3).foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                        .frame(width: 36)
                        Text(lines[i])
                            .foregroundStyle(Color.primary)
                            .fontWeight(first == i ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lines[i])
                .accessibilityAddTraits(first == i ? .isSelected : [])
                Divider().padding(.leading, 48)
            }
        }
    }

    private var mainGoal: some View {
        TextField("Finish the term with a 3.7 GPA", text: $goal, axis: .vertical)
            .font(.title3)
            .fontDesign(Look.current.titles)
            .lineLimit(2...5)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: actions

    private func addLine() {
        let t = trimmed(draft)
        guard !t.isEmpty else { return }
        withAnimation(.snappy) { lines.append(t) }
        draft = ""
        typing = true
    }

    private func next() {
        switch step {
        case 1:
            addLine()
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
