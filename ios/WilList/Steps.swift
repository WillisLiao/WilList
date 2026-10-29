import SwiftUI
import WilListCore

// The pieces the short guided flows share: the welcome and Plan tomorrow.

/// One step of a guided flow: where you are and a way out at the top, a big title with a line
/// under it in white on a field of colour, the step itself on white, and one button at the bottom.
struct StepPage<Content: View>: View {
    /// The colour the top of the page sits on, and its button: the teal, or night for the evening.
    var field: Color = .brand
    let step: Int
    let of: Int
    /// A small line above the title, such as how today went.
    var about: String?
    let title: String
    let subtitle: String
    /// "Skip" or "Close"; either way, what's been written is kept.
    let exit: String
    let back: () -> Void
    let leave: () -> Void
    let button: String
    var enabled = true
    let next: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A new step's words appear as the old ones go, rising a little, so the two never cross.
    private var arrive: AnyTransition {
        .asymmetric(insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 10)), removal: .identity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if step > 1 {
                    Button(action: back) {
                        SketchIcon(glyph: .chevron, size: 17).rotationEffect(.degrees(180)).tapArea()
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
                Button(action: leave) { Text(exit).tapArea() }
            }
            // In the middle, where Back coming and going doesn't move it; the number rolls on.
            .overlay {
                Text("\(step) of \(of)")
                    .font(.hand(.subheadline))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(step)))
            }
            .font(.hand(.body))
            .tint(.white)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .background(field)
            ScrollView {
              VStack(spacing: 0) {
                // The words change inside a frame that stays, so the band never goes with them.
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let about {
                            Text(about).font(.hand(.subheadline)).foregroundStyle(.white)
                        }
                        Text(title)
                            .font(.hand(.largeTitle))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
                    .transition(arrive)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                // The field reaches up behind the top bar, also when the page is pulled down.
                .background(field.padding(.top, -1000))
                ZStack(alignment: .topLeading) {
                    content()
                        .id(step)
                        .transition(arrive)
                }
                // The step's controls take the page's colour: night in the evening.
                .environment(\.field, field)
                .tint(field)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
              }
            }
            .scrollDismissesKeyboard(.interactively)
            Button(action: next) {
                Text(button).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(field)
            .controlSize(.large)
            .disabled(!enabled)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
    }
}

/// Lines written one under another, the way a list on paper grows: return adds the next.
struct LinesEntry: View {
    @Binding var lines: [String]
    @Binding var draft: String
    let typing: FocusState<Bool>.Binding
    let placeholder: String
    @Environment(\.field) private var field

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    DrawnCheck(done: false).accessibilityHidden(true)
                    Text(lines[i]).frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        withAnimation(.snappy) { _ = lines.remove(at: i) }
                    } label: {
                        SketchIcon(glyph: .xmark, size: 15).tapArea()
                    }
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityLabel("Remove \(lines[i])")
                }
                .frame(minHeight: 48)
                Divider().padding(.leading, 36)
            }
            HStack(spacing: 12) {
                SketchIcon(glyph: .plusCircle, size: 21).foregroundStyle(field)
                    .accessibilityHidden(true)
                TextField(lines.isEmpty ? placeholder : "And next?", text: $draft)
                    .focused(typing)
                    .submitLabel(.next)
                    .onSubmit {
                        Self.keep(&draft, in: &lines)
                        typing.wrappedValue = true
                    }
            }
            .frame(minHeight: 48)
        }
    }

    /// Moves the line being typed into the list, if there is one.
    static func keep(_ draft: inout String, in lines: inout [String]) {
        let line = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        withAnimation(.snappy) { lines.append(line) }
        draft = ""
    }
}

/// A row in a list where one thing becomes the A1: the chosen one gets the A1 mark.
struct A1Choice: View {
    let title: String
    var detail: String?
    /// Its letter now, on the right while it isn't the chosen one.
    var letter: Letter?
    let chosen: Bool
    let choose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: choose) {
                HStack(spacing: 12) {
                    Group {
                        if chosen {
                            LetterMark(letter: .A, label: "A1")
                        } else {
                            // Drawn by the same hand as every other circle you choose or tick.
                            DrawnCheck(done: false)
                        }
                    }
                    .frame(width: 36)
                    // The circle stops growing where the letter marks do, so every row's words line up.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(Color.primary)
                            .fontWeight(chosen ? .semibold : .regular)
                        if let detail {
                            Text(detail).font(.hand(.subheadline)).foregroundStyle(Color.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let letter, !chosen { LetterMark(letter: letter) }
                }
                .padding(.vertical, 6)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel([title, detail, letter.map { "now \($0.rawValue)" }].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(chosen ? .isSelected : [])
            Divider().padding(.leading, 48)
        }
    }
}

/// The last page of a flow: a symbol and a few lines in the middle, its buttons at the bottom.
/// When the lines don't fit (the largest text sizes), the middle scrolls instead of cutting words off.
/// With a field, the whole page is that colour and its words white; without, it lies on whatever
/// the sheet is laid on.
struct FinishPage<Middle: View, Buttons: View>: View {
    var field: Color?
    let symbol: SketchIcon.Glyph
    @ViewBuilder let middle: () -> Middle
    @ViewBuilder let buttons: () -> Buttons
    /// The drawn mark lands once the page has come in.
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .vertical) {
                lines.frame(maxHeight: .infinity)
                ScrollView { lines.padding(.vertical, 24) }
            }
            buttons().controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .foregroundStyle(field == nil ? Color.primary : .white)
        .background(field ?? .clear)
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            arrived = true
        }
    }

    private var lines: some View {
        VStack(spacing: 12) {
            SketchIcon(glyph: symbol, size: 56)
                .foregroundStyle(field == nil ? Color.brand : .white)
                // The pen's one flourish on an end page: it lands as the page comes in.
                .scaleEffect(arrived || reduceMotion ? 1 : 0.7)
                .animation(reduceMotion ? nil : .bouncy(duration: 0.5), value: arrived)
            middle()
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension Int {
    func clamped(_ low: Int, _ high: Int) -> Int { Swift.min(Swift.max(self, low), high) }
}
