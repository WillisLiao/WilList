import SwiftUI
import WilListCore

/// Progress: what got done lately, how much study the next week holds, and what to do about
/// anything that needs it.
struct ProgressTab: View {
    @Environment(Store.self) private var store
    @State private var sorting: LetterSorter.Batch?

    private var today: Day { store.today }
    private var week: [Ahead] { radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin) }

    var body: some View {
        let stats = store.state.weekStats(today)
        let tips = suggestions(store.state, today)
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    numbers(stats)
                    DoneChart(days: store.state.doneByDay(today, days: 7), today: today)
                } header: {
                    Text("Last 7 days").onGround()
                }

                if !tips.isEmpty {
                    Section {
                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in suggestionRow(tip) }
                    } header: {
                        Text("Suggestions").onGround()
                    }
                }

                Section {
                    if week.allSatisfy({ $0.load == 0 }) {
                        Text("No study planned").foregroundStyle(.secondary)
                    } else {
                        WeekChart(days: week, budget: store.state.settings.perDayMin, today: today) { store.state.courseColor($0.course) }
                        VStack(alignment: .leading, spacing: 8) {
                            // The chart reads out each day's courses itself.
                            courseKey?.accessibilityHidden(true)
                            Text("Dashed line: \(Fmt.minutes(store.state.settings.perDayMin)) a day")
                        }
                        .font(.hand(.subheadline))
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden, edges: .top)
                    }
                } header: {
                    Text("Next 7 days").onGround()
                }
                .id("next")
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .ground()
            .readableColumn()
            #if DEBUG
            // `-scroll next` on launch, for screenshots.
            .onAppear { UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) } }
            #endif
            }
            .navigationTitle("Progress")
            .profileButton()
            .sheet(item: $sorting) { LetterSorter(ids: $0.ids) }
            .toastHost()
        }
    }

    // MARK: last 7 days

    /// Three numbers side by side: things done, A's done, focus time.
    private func numbers(_ w: WeekStats) -> some View {
        let cells: [(String, String)] = [
            ("\(w.done)", "Done"),
            ("\(w.aDone)", "A’s"),
            (Fmt.minutes(w.focusMin), "Focus"),
        ]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(cells, id: \.1) { value, label in
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.hand(.title2))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(label).font(.hand(.footnote)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: suggestions

    private func suggestionRow(_ tip: Suggestion) -> some View {
        HStack(spacing: 10) {
            SketchIcon(glyph: symbol(tip), size: 20)
                .foregroundStyle(tint(tip))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(words(tip).title)
                if let detail = words(tip).detail {
                    Text(detail).font(.hand(.subheadline)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let (label, run) = action(tip) {
                Button(label, action: run)
                    .font(.hand(.subheadline))
                    .buttonStyle(.borderless)
                    .tapArea()
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16))
    }

    private func symbol(_ tip: Suggestion) -> SketchIcon.Glyph {
        switch tip {
        case .overloaded: .warning
        case .startEarly: .flag
        case .review: .restore
        }
    }

    /// Red only for a problem: a day past its time.
    private func tint(_ tip: Suggestion) -> Color {
        switch tip {
        case .overloaded: .red
        default: .brand
        }
    }

    private func words(_ tip: Suggestion) -> (title: String, detail: String?) {
        switch tip {
        case .overloaded(let day, let minutes, let budget):
            ("\(Fmt.day(day, today)): \(Fmt.minutes(minutes)) of study", "Over your \(Fmt.minutes(budget)) a day")
        case .startEarly(let it): ("Start \u{201C}\(it.title)\u{201D}", it.date.map { "Due \(Fmt.day($0, today, inSentence: true))" })
        case .review(let ids): ("\(ids.count) old C to E \(ids.count == 1 ? "item" : "items")", "Still worth it?")
        }
    }

    private func action(_ tip: Suggestion) -> (String, () -> Void)? {
        switch tip {
        case .overloaded:
            nil
        case .startEarly(let it):
            ("Add to Today", { withAnimation { store.change(undo: "Added to Today") { s in if let i = s.index(of: it.id) { s.items[i].myDay = today } } } })
        case .review(let ids):
            ("Review", { sorting = LetterSorter.Batch(ids: ids) })
        }
    }

    // MARK: next 7 days

    /// The courses in the week's bars, each by its colour; none when no study has a course.
    private var courseKey: Text? {
        var names: [Int?: String] = [:]
        for it in week.flatMap(\.study).map(\.item) where names[store.state.courseColor(it.course)] == nil {
            names[store.state.courseColor(it.course)] = it.course ?? "No course"
        }
        guard names.keys.contains(where: { $0 != nil }) else { return nil }
        // No-break spaces inside each name, so a dot never ends a line without its name; plain ones
        // between names, where the line may wrap (`Fmt.meta`'s gaps don't, and broke "No course").
        return names.sorted { ($0.key ?? .max) < ($1.key ?? .max) }.map { color, name in
            Text("\(Text(Image(systemName: "circle.fill")).font(.system(size: 9)).baselineOffset(1).foregroundStyle(CourseColor.of(color)))\u{00A0}\(name.replacingOccurrences(of: " ", with: "\u{00A0}"))")
        }
        .reduce(nil) { line, part in line.map { Text("\($0)   \(part)") } ?? part }
    }
}

/// What got done each of the last seven days: each bar stacks the day's letters in their colours,
/// A on the floor, to-dos and anything without a letter in grey on top, with the day and its count
/// under it, drawn like the week ahead below it.
struct DoneChart: View {
    let days: [DayDone]
    let today: Day
    private let height: CGFloat = 64

    private static let order: [Letter?] = [.A, .B, .C, .D, .E, nil]

    var body: some View {
        // One or two things done never fill the card: the scale starts at three.
        let top = Double(max(3, days.map(\.total).max() ?? 0))
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(days, id: \.date) { d in
                    VStack(spacing: 1.5) {
                        ForEach(Self.order.reversed().filter { (d.counts[$0] ?? 0) > 0 }, id: \.self) { l in
                            (l?.color ?? Color(.systemGray4))
                                .frame(height: max(height * Double(d.counts[l] ?? 0) / top - 1.5, 1.5))
                        }
                    }
                    .frame(width: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .bottom)
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { d in
                    VStack(spacing: 3) {
                        Text(d.date == today ? "Today" : Fmt.date(d.date).formatted(.dateTime.weekday(.abbreviated)))
                            .fontWeight(d.date == today ? .semibold : .regular)
                        Text(d.total > 0 ? "\(d.total)" : "–").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.hand(.caption2))
                    .frame(maxWidth: .infinity)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days.map { "\(Fmt.day($0.date, today)): \($0.total) done" }.joined(separator: ". "))
    }
}

/// Planned study per day for the next week: each bar stacks its courses in their colours, against
/// your daily study time (the dashed line); a day past it has its time in red. A heavy day shows
/// how much is too much and which course makes it so.
struct WeekChart: View {
    let days: [Ahead]
    let budget: Int
    let today: Day
    /// The colour number of an item's course (`CourseColor`).
    let color: (Item) -> Int?
    private let height: CGFloat = 110

    /// A day's study by course, in palette order (no course last), with the course's name.
    private func parts(_ d: Ahead) -> [(color: Color, name: String?, minutes: Int)] {
        Dictionary(grouping: d.study) { color($0.item) }
            .sorted { ($0.key ?? .max) < ($1.key ?? .max) }
            .map { (CourseColor.of($0.key), $0.value.first?.item.course, $0.value.reduce(0) { $0 + $1.minutes }) }
    }

    /// What VoiceOver reads for a day: its total, then each course's share when there are courses.
    private func spoken(_ d: Ahead) -> String {
        let total = "\(Fmt.day(d.date, today)): \(Fmt.minutes(d.load))\(d.over ? ", past your daily time" : "")"
        let courses = parts(d).compactMap { p in p.name.map { "\($0) \(Fmt.minutes(p.minutes))" } }
        return ([total] + courses).joined(separator: ", ")
    }

    var body: some View {
        let top = Double(max(budget, days.map(\.load).max() ?? 0)) * 1.1
        let y = { (minutes: Int) in height * Double(minutes) / top }
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(days, id: \.date) { d in
                        // Bottom up: the first course sits on the floor, red on top.
                        VStack(spacing: 1.5) {
                            ForEach(Array(parts(d).reversed().enumerated()), id: \.offset) { _, p in
                                p.color.frame(height: max(y(p.minutes) - 1.5, 1.5))
                            }
                        }
                        .frame(width: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .frame(maxWidth: .infinity)
                    }
                }
                Rule()
                    .stroke(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(height: 1)
                    .offset(y: -y(budget))
            }
            .frame(height: height, alignment: .bottom)
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { dayLabel($0.date).frame(maxWidth: .infinity) }
            }
            // Seven columns hold "Today" and "3h35" up to the largest standard size; VoiceOver
            // reads every day in full.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days.map(spoken).joined(separator: ". "))
    }

    private struct Rule: Shape {
        func path(in r: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: r.minX, y: r.midY)); $0.addLine(to: CGPoint(x: r.maxX, y: r.midY)) }
        }
    }

    private func dayLabel(_ d: Day) -> some View {
        let day = days.first { $0.date == d }
        return VStack(spacing: 3) {
            Text(d == today ? "Today" : Fmt.date(d).formatted(.dateTime.weekday(.abbreviated)))
                .font(.hand(.caption2))
                .fontWeight(d == today ? .semibold : .regular)
            Text(day.map { $0.load > 0 ? hours($0.load) : "–" } ?? "–")
                .font(.hand(.caption2))
                .monospacedDigit()
                .foregroundStyle(day?.over == true ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
    }

    private func hours(_ m: Int) -> String {
        m < 60 ? "\(m)m" : m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h\(m % 60)"
    }
}
