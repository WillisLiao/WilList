import SwiftUI
import WilListCore

/// Study: what to study today, how full the week is, whether each exam and deadline coming up
/// is on track, and a month with every exam and deadline on its day.
struct StudyView: View {
    @Environment(Store.self) private var store
    /// At the largest text sizes the numbers on the right join the lines under a title instead,
    /// so no word breaks in half.
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var adding = false
    @State private var importing = false
    @State private var editing: Item?
    @State private var ticking: Set<String> = []
    @State private var searching = false
    /// The day tapped on the calendar, listed in full under it.
    @State private var picked: Day?

    private var today: Day { store.today }
    private var sessions: [Row] { studyRows(store.state.items, today) }
    private var ahead: [Vital] { readiness(store.state.items, today) }
    private var week: [Ahead] { radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin) }
    /// The courses in this week's bars, each by its colour; none when no study has a course.
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

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty && ahead.isEmpty && week.allSatisfy({ $0.load == 0 }) {
                    firstRun
                } else {
                    Section {
                        if sessions.isEmpty {
                            Text("Nothing today.").foregroundStyle(.secondary)
                        }
                        ForEach(sessions) { sessionRow($0) }
                    } header: {
                        Text("Study today").onGround()
                    }

                    Section {
                        if week.allSatisfy({ $0.load == 0 }) {
                            Text("Nothing this week.").foregroundStyle(.secondary)
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
                        Text("This week").onGround()
                    }

                    Section {
                        if ahead.isEmpty {
                            Text("Nothing in the next 45 days.").foregroundStyle(.secondary)
                        }
                        ForEach(ahead, id: \.item.id) { readinessRow($0) }
                    } header: {
                        Text("Coming up").onGround()
                    }
                }
                let byDay = byDay
                Section {
                    MonthCalendar(selection: $picked, today: today) { d in
                        (byDay[d] ?? []).map { MonthCalendar.Mark(title: $0.title, fill: CourseColor.of(store.state.courseColor($0.course)), ink: .white) }
                    }
                    ForEach(picked.flatMap { byDay[$0] } ?? []) { pickedRow($0) }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .ground()
            .readableColumn()
            .navigationTitle("Study")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Search", systemImage: "magnifyingglass") { searching = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $searching) { SearchView() }
            .refreshable { await store.syncFeeds(force: true) }
            .sheet(isPresented: $adding) { AddItemSheet(preset: .exam) }
            .sheet(isPresented: $importing) { ImportSheet() }
            .sheet(item: $editing) { ItemEditor(item: $0) }
            .toastHost()
        }
    }

    /// Nothing to study yet: what this tab does, and the two ways to start.
    private var firstRun: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { adding = true } label: {
                Text("Add an exam or deadline").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button { importing = true } label: {
                Text("Bring in a schedule").foregroundStyle(Color.brandDeep).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .heroCard()
        // A card of its own on the ground, not one inside a section's.
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// The exams, deadlines, presentations and readings on each day, still to come, by time.
    private var byDay: [Day: [Item]] {
        Dictionary(grouping: store.state.items.filter { plannedTypes.contains($0.type) && $0.date != nil && isOpen($0, today) }) { $0.date! }
            .mapValues { $0.sorted { ($0.time ?? "") < ($1.time ?? "") } }
    }

    /// One thing on the chosen day, under the calendar: its course's dot, its title and its kind.
    private func pickedRow(_ it: Item) -> some View {
        Button { editing = it } label: {
            HStack(spacing: 10) {
                Circle().fill(CourseColor.of(store.state.courseColor(it.course))).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(it.title).foregroundStyle(.primary)
                    Text([it.type.name, Fmt.time(it.time), it.course].compactMap { $0 }.joined(separator: ", "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .tint(.primary)
    }

    private func sessionRow(_ row: Row) -> some View {
        let s = row.session!
        let minutes = Text(Fmt.minutes(s.minutes * (1 + row.extra)))
            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        return HStack(spacing: 10) {
            CheckButton(done: ticking.contains(row.key)) { complete(row) }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.label).strikethrough(ticking.contains(row.key), color: .secondary)
                // What it's for, and its course in the course's colour, as in the chart below.
                Text("\(row.item.title)\(Fmt.subline(row.item, today, in: store.state).map { Text(", \($0)") } ?? Text(""))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if row.overdue {
                    Text("Missed \(Fmt.day(s.date, today, inSentence: true))")
                        .font(.footnote).foregroundStyle(.red)
                }
                if typeSize.isAccessibilitySize { minutes }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
            if !typeSize.isAccessibilitySize { minutes }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 16))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.brand)
        }
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

    private func complete(_ row: Row) {
        ticking.insert(row.key)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change { $0.complete(row, today: today) }
                ticking.remove(row.key)
            }
        }
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
