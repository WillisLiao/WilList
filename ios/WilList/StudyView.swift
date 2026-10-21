import Charts
import SwiftUI
import WilListCore

/// Study: what to study today, how full the week is, and whether each exam and deadline
/// coming up is on track.
struct StudyView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var importing = false
    @State private var editing: Item?
    @State private var ticking: Set<String> = []

    private var today: Day { store.today }
    private var sessions: [Row] { studyRows(store.state.items, today) }
    private var ahead: [Vital] { readiness(store.state.items, today) }

    var body: some View {
        NavigationStack {
            List {
                if !store.state.feeds.isEmpty { feedStatus }

                Section("Study today") {
                    if sessions.isEmpty {
                        Text(ahead.isEmpty ? "Nothing to study today." : "Nothing due today. The next session is on its way below.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { sessionRow($0) }
                }

                Section {
                    WeekChart(days: radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin),
                              budget: store.state.settings.perDayMin, today: today)
                } header: {
                    Text("Next 7 days")
                } footer: {
                    Text("Planned study per day against your budget of \(Fmt.minutes(store.state.settings.perDayMin)). A dot marks an exam or a deadline.")
                }

                Section("Coming up") {
                    if ahead.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No exams or deadlines in the next 45 days. Add one, or bring in your syllabus or school calendar and WilList plans the study for you.")
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Add an exam") { adding = true }.buttonStyle(.bordered)
                                Button("Bring in a schedule") { importing = true }.buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    ForEach(ahead, id: \.item.id) { readinessRow($0) }
                }
            }
            .navigationTitle("Study")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { adding = true }
                }
            }
            .refreshable { await store.syncFeeds(force: true) }
            .sheet(isPresented: $adding) { AddItemSheet(preset: .exam) }
            .sheet(isPresented: $importing) { ImportSheet() }
            .sheet(item: $editing) { ItemEditor(item: $0) }
            .toastHost()
        }
    }

    private var feedStatus: some View {
        Section {
            ForEach(store.state.feeds) { feed in
                HStack {
                    Text(feed.name)
                    Spacer()
                    if let e = feed.error {
                        Text(e).font(.footnote).foregroundStyle(.red).lineLimit(1)
                    } else if let at = feed.syncedAt {
                        Text("Read \(at.formatted(.relative(presentation: .named)))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        } footer: {
            Text(store.syncing ? "Reading your calendars…" : "Pull down to read them again.")
        }
    }

    private func sessionRow(_ row: Row) -> some View {
        let s = row.session!
        return HStack(spacing: 10) {
            CheckButton(done: ticking.contains(row.key)) { complete(row) }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.label).strikethrough(ticking.contains(row.key), color: .secondary)
                Text([row.item.title, Fmt.when(row.item, today)].compactMap { $0 }.joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.secondary)
                if row.overdue {
                    Text("Missed \(Fmt.day(s.date, today, inSentence: true)). Do it now, or plan again in the item.")
                        .font(.footnote).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
            Text(Fmt.minutes(s.minutes * (1 + row.extra)))
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 16))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.accentColor)
        }
    }

    private func readinessRow(_ v: Vital) -> some View {
        Button { editing = v.item } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        if v.item.priority != nil { LetterMark(letter: v.item.priority) }
                        Text(v.item.title).foregroundStyle(.primary)
                    }
                    Text(Fmt.subline(v.item, today)).font(.subheadline).foregroundStyle(.secondary)
                    Text(status(v)).font(.subheadline).foregroundStyle(v.status == .short || v.status == .behind ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if v.total > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(v.done) of \(v.total)").monospacedDigit().foregroundStyle(.primary)
                        Text("sessions").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func status(_ v: Vital) -> String {
        let missed = v.item.sessions.filter { !$0.done && diffDays(today, $0.date) < 0 }.count
        return switch v.status {
        case .short: "Not enough time: \(Fmt.minutes(v.item.shortfallMin)) short"
        case .behind: "Behind by \(missed) \(missed == 1 ? "session" : "sessions")"
        case .notStarted: "Starts \(v.startBy.map { Fmt.day($0, today, inSentence: true) } ?? "soon")"
        case .noPlan: "No study planned. Tap to set the prep time."
        case .onTrack: "On track"
        }
    }

    private func complete(_ row: Row) {
        ticking.insert(row.key)
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change { $0.complete(row, today: today) }
                ticking.remove(row.key)
            }
        }
    }
}

/// Planned study per day for the next week, against the daily budget.
struct WeekChart: View {
    let days: [Ahead]
    let budget: Int
    let today: Day

    var body: some View {
        Chart {
            ForEach(days, id: \.date) { d in
                BarMark(x: .value("Day", d.date), y: .value("Minutes", d.load), width: .ratio(0.55))
                    .foregroundStyle(d.over ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if d.load > 0 {
                            Text(hours(d.load)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
            }
            RuleMark(y: .value("Budget", budget))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary)
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Double(max(budget, days.map(\.load).max() ?? 0)) * 1.25)
        .chartXAxis {
            AxisMarks(values: days.map(\.date)) { value in
                AxisValueLabel(centered: true) {
                    if let d = value.as(String.self) { dayLabel(d) }
                }
            }
        }
        .frame(height: 150)
        .padding(.vertical, 8)
        .accessibilityLabel(days.map { "\(Fmt.day($0.date, today)): \(Fmt.minutes($0.load))" }.joined(separator: ", "))
    }

    private func dayLabel(_ d: Day) -> some View {
        let due = days.first { $0.date == d }.map { !$0.due.isEmpty || $0.schedule.contains { $0.type != .event } } ?? false
        return VStack(spacing: 3) {
            Text(d == today ? "Today" : Fmt.date(d).formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .fontWeight(d == today ? .semibold : .regular)
            Circle().fill(due ? AnyShapeStyle(.primary) : AnyShapeStyle(.clear)).frame(width: 5, height: 5)
        }
    }

    private func hours(_ m: Int) -> String {
        m < 60 ? "\(m)m" : m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h\(m % 60)"
    }
}
