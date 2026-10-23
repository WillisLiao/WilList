import Charts
import SwiftUI
import WilListCore

/// Progress: what got done lately, how the next week looks, whether each exam and deadline is on
/// track, and what to do about anything that isn't.
struct ProgressTab: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editing: Item?
    @State private var sorting: LetterSorter.Batch?

    private var today: Day { store.today }
    private var ahead: [Vital] { readiness(store.state.items, today) }
    private var week: [Ahead] { radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin) }

    var body: some View {
        let stats = store.state.weekStats(today)
        let todosDone = store.state.todos.filter { $0.done && $0.doneAt.map { diffDays($0, today) < 7 && diffDays($0, today) >= 0 } ?? false }.count
        let tips = suggestions(store.state, today)
        NavigationStack {
            List {
                Section {
                    numbers(stats, done: stats.done + todosDone)
                    DoneChart(days: store.state.doneByDay(today, days: 14), today: today)
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden, edges: .top)
                    }
                } header: {
                    Text("Next 7 days").onGround()
                }

                if !ahead.isEmpty {
                    Section {
                        ForEach(ahead, id: \.item.id) { readinessRow($0) }
                    } header: {
                        Text("Coming up").onGround()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .ground()
            .readableColumn()
            .navigationTitle("Progress")
            .profileButton()
            .sheet(item: $editing) { ItemEditor(item: $0) }
            .sheet(item: $sorting) { LetterSorter(ids: $0.ids) }
            .toastHost()
        }
    }

    // MARK: last 7 days

    /// Four numbers side by side: things done, A's done, days that started with an A, focus time.
    private func numbers(_ w: WeekStats, done: Int) -> some View {
        let cells: [(String, String)] = [
            ("\(done)", "Done"),
            ("\(w.aDone)", "A’s"),
            ("\(w.aFirstDays) of 7", "A first"),
            (w.focusMin == 0 ? "0" : Fmt.minutes(w.focusMin), "Focus"),
        ]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(cells, id: \.1) { value, label in
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(label).font(.footnote).foregroundStyle(.secondary)
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
            Image(systemName: symbol(tip))
                .font(.body.weight(.semibold))
                .foregroundStyle(tint(tip))
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(words(tip).title)
                if let detail = words(tip).detail {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let (label, run) = action(tip) {
                Button(label, action: run)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tapArea()
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16))
    }

    private func symbol(_ tip: Suggestion) -> String {
        switch tip {
        case .replan: "arrow.triangle.2.circlepath"
        case .overloaded: "exclamationmark.triangle"
        case .startEarly: "flag"
        case .letter: "textformat.abc"
        case .review: "tray.full"
        case .calibrate: "timer"
        }
    }

    /// Red only for a problem: missed work and a day past its time.
    private func tint(_ tip: Suggestion) -> Color {
        switch tip {
        case .replan, .overloaded: .red
        default: .brand
        }
    }

    private func words(_ tip: Suggestion) -> (title: String, detail: String?) {
        switch tip {
        case .replan(let n): ("\(n) missed \(n == 1 ? "session" : "sessions")", "Spread them over the days left")
        case .overloaded(let day, let minutes, let budget):
            ("\(Fmt.day(day, today)): \(Fmt.minutes(minutes)) of study", "Over your \(Fmt.minutes(budget)) a day")
        case .startEarly(let it): ("Start \u{201C}\(it.title)\u{201D}", it.date.map { "Due \(Fmt.day($0, today, inSentence: true))" })
        case .letter(let n): ("\(n) \(n == 1 ? "needs" : "need") a letter", nil)
        case .review(let ids): ("\(ids.count) old C to E \(ids.count == 1 ? "item" : "items")", "Still worth it?")
        case .calibrate(let c): ("\(c.label) takes you \(c.ratio.formatted())× as long", "From \(c.n) focus sessions")
        }
    }

    private func action(_ tip: Suggestion) -> (String, () -> Void)? {
        switch tip {
        case .replan:
            ("Replan", { withAnimation { store.change(undo: "Replanned") { _ = $0.replanAll(today: today) } } })
        case .overloaded:
            nil
        case .startEarly(let it):
            ("Add to Today", { withAnimation { store.change(undo: "Added to Today") { s in if let i = s.index(of: it.id) { s.items[i].myDay = today } } } })
        case .letter:
            ("Letter them", { sorting = LetterSorter.Batch(ids: unsorted(store.state.items, today).map(\.id)) })
        case .review(let ids):
            ("Review", { sorting = LetterSorter.Batch(ids: ids) })
        case .calibrate(let c):
            ("Adjust", {
                withAnimation {
                    store.change(undo: "Adjusted") { s in
                        s.settings.calib[c.type.rawValue] = c.ratio
                        _ = s.replanAll(today: today)
                    }
                }
            })
        }
    }

    // MARK: next 7 days and coming up

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

    private func readinessRow(_ v: Vital) -> some View {
        Button { editing = v.item } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.item.title).foregroundStyle(.primary)
                    Fmt.subline(v.item, today, in: store.state)?.font(.subheadline).foregroundStyle(.secondary)
                    if let status = status(v) {
                        Text(status).font(.subheadline).foregroundStyle(v.status == .short || v.status == .behind ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    }
                    if v.total > 0 && typeSize.isAccessibilitySize {
                        Text("\(v.done) of \(v.total) sessions").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if v.total > 0 && !typeSize.isAccessibilitySize {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(v.done) of \(v.total)").monospacedDigit().foregroundStyle(.primary)
                        Text("sessions").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.primary)
    }

    /// Only what needs attention; on track says nothing.
    private func status(_ v: Vital) -> String? {
        let missed = v.item.sessions.filter { !$0.done && diffDays(today, $0.date) < 0 }.count
        if v.item.date == nil { return "No date" }
        return switch v.status {
        case .short: "\(Fmt.minutes(v.item.shortfallMin)) short"
        case .behind: "\(missed) \(missed == 1 ? "session" : "sessions") behind"
        case .notStarted: "Starts \(v.startBy.map { Fmt.day($0, today, inSentence: true) } ?? "soon")"
        case .noPlan: "No study planned"
        case .onTrack: nil
        }
    }
}

/// Things done on each of the last two weeks' days, stacked by letter in its colour (to-dos and
/// unlettered items in grey), today on the right.
struct DoneChart: View {
    let days: [DayDone]
    let today: Day

    private static let order: [Letter?] = [.A, .B, .C, .D, .E, nil]
    private static func name(_ l: Letter?) -> String { l?.rawValue ?? "Other" }

    var body: some View {
        Chart {
            ForEach(days, id: \.date) { d in
                ForEach(Self.order, id: \.self) { l in
                    if let n = d.counts[l], n > 0 {
                        BarMark(x: .value("Day", Fmt.date(d.date), unit: .day), y: .value("Done", n))
                            .foregroundStyle(by: .value("Letter", Self.name(l)))
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: Self.order.map(Self.name), range: Self.order.map { $0?.color ?? Color(.systemGray4) })
        .chartLegend(.hidden)
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 130)
        .padding(.vertical, 6)
        .accessibilityLabel("Done each day, last 14 days")
        .accessibilityValue(days.suffix(7).map { "\(Fmt.day($0.date, today)): \($0.total)" }.joined(separator: ", "))
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
                .font(.caption2)
                .fontWeight(d == today ? .semibold : .regular)
            Text(day.map { $0.load > 0 ? hours($0.load) : "–" } ?? "–")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(day?.over == true ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
    }

    private func hours(_ m: Int) -> String {
        m < 60 ? "\(m)m" : m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h\(m % 60)"
    }
}
