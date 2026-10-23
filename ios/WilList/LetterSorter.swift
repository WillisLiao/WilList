import SwiftUI
import WilListCore

/// Letters the items waiting for one, one at a time: the item large at the top, the five letters
/// under it with what each one means, the suggested one marked. Choosing moves on to the next;
/// at the end it names your A1.
struct LetterSorter: View {
    /// The items to letter, fixed when the sheet opens so the list doesn't shift as letters land.
    struct Batch: Identifiable {
        let id = UUID()
        let ids: [String]
    }

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let ids: [String]
    @State private var at = 0
    @State private var forward = true

    private var today: Day { store.today }
    private var item: Item? { ids.indices.contains(at) ? store.state.items.first { $0.id == ids[at] } : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ZStack {
                if let item {
                    ScrollView { page(item) }
                        .id(item.id)
                        .transition(slide)
                } else {
                    finished.transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        // The letters are cards on the sheet's ground, as everywhere else; words straight on it
        // take the deeper teal.
        .background(Color.sheet)
        .tint(Color.brandDeep)
        .sensoryFeedback(.selection, trigger: at)
    }

    // MARK: chrome

    private var topBar: some View {
        HStack {
            if at > 0 {
                Button { go(-1) } label: {
                    Label("Back", systemImage: "chevron.left").labelStyle(.iconOnly).tapArea()
                }
            }
            Spacer()
            // The last page has its own Done.
            if item != nil {
                Button { dismiss() } label: { Text("Close").tapArea() }
            }
        }
        // In the middle, where Back coming and going doesn't move it; the number rolls on.
        .overlay {
            if item != nil {
                Text("\(at + 1) of \(ids.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(at)))
            }
        }
        .font(.body.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    /// Forward slides the next item in from the right; Back brings the last one in from the left.
    private var slide: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: pages

    private func page(_ item: Item) -> some View {
        let suggested = suggestedLetter(item.type, weightPct: item.weightPct)
        return VStack(alignment: .leading, spacing: 10) {
            if let about = about(item) {
                Text(about).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(item.title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 14)
            ForEach(Letter.allCases, id: \.self) { letterButton($0, item: item, suggested: suggested) }
            Button { go(1) } label: {
                Text("Skip").frame(maxWidth: .infinity).tapArea()
            }
            .font(.body.weight(.medium))
                .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// What kind of thing it is and when it's due: "Assignment, Due Fri, CHEM110".
    private func about(_ item: Item) -> String? {
        let sub = Fmt.subline(item, today)
        let parts = [item.type == .task ? nil : item.type.name, sub.isEmpty ? nil : sub].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func letterButton(_ letter: Letter, item: Item, suggested: Letter?) -> some View {
        let current = item.priority == letter
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let words = VStack(alignment: .leading, spacing: 2) {
            // The tag goes under the name when both don't fit on a line.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { Text(letter.name).font(.headline); tag(letter, suggested, current) }
                VStack(alignment: .leading, spacing: 4) { Text(letter.name).font(.headline); tag(letter, suggested, current) }
            }
            Text(letter.detail).font(.subheadline).foregroundStyle(.secondary)
        }
        let check = Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(letter.color)
        return Button { choose(letter, for: item) } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    // At the largest text sizes the letter sits above the words, so none breaks in half.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            LetterMark(letter: letter, large: true)
                            Spacer()
                            if current { check }
                        }
                        words
                    }
                } else {
                    HStack(spacing: 14) {
                        LetterMark(letter: letter, large: true)
                        words
                        Spacer(minLength: 8)
                        if current { check }
                    }
                }
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(letter.color.opacity(current ? 0.09 : 0), in: shape)
            .background(Color.white, in: shape)
            .overlay { if letter == suggested && !current { shape.strokeBorder(Color.brand.opacity(0.45), lineWidth: 1.5) } }
            .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .accessibilityLabel("\(letter.rawValue), \(letter.name). \(letter.detail)\(letter == suggested ? ". Suggested" : "")")
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    @ViewBuilder private func tag(_ letter: Letter, _ suggested: Letter?, _ current: Bool) -> some View {
        if letter == suggested && !current {
            Text("Suggested")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.brand.opacity(0.12), in: Capsule())
                .fixedSize()
        }
    }

    private var finished: some View {
        let a1 = doRows(store.state.items, today).first
        let left = unsorted(store.state.items, today).filter { ids.contains($0.id) }.count
        return FinishPage(symbol: "checkmark.circle.fill") {
            Text(left == 0 ? "All lettered" : "Done for now")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            if let a1 {
                Text("Your A1 is \u{201C}\(a1.item.title)\u{201D}.")
            }
            if left > 0 {
                Text("\(left) still \(left == 1 ? "needs" : "need") a letter").foregroundStyle(.secondary)
            }
        } buttons: {
            Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand)
        }
    }

    // MARK: actions

    private func choose(_ letter: Letter, for item: Item) {
        store.change { $0.setLetter(item.id, letter, today: today) }
        go(1)
    }

    private func go(_ step: Int) {
        forward = step > 0
        // The new direction has to reach the leaving page before it leaves.
        Task { @MainActor in
            withAnimation(.snappy) { at = min(max(at + step, 0), ids.count) }
        }
    }
}

/// Shrinks a little under the finger.
private struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
