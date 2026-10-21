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
    @State private var searching = false

    private var today: Day { store.today }
    private var sessions: [Row] { studyRows(store.state.items, today) }
    private var ahead: [Vital] { readiness(store.state.items, today) }
    private var week: [Ahead] { radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin) }

    var body: some View {
        NavigationStack {
            List {
                Section("Study today") {
                    if sessions.isEmpty {
                        Text("Nothing to study today.").foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { sessionRow($0) }
                }

                Section("This week") {
                    WeekChart(days: week, budget: store.state.settings.perDayMin, today: today)
                    if week.contains(where: \.over) {
                        Text("Red days have more than your \(Fmt.minutes(store.state.settings.perDayMin)) a day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden, edges: .top)
                    }
                }

                Section("Coming up") {
                    if ahead.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No exams or deadlines in the next 45 days.").foregroundStyle(.secondary)
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
            .listStyle(.plain)
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

    private func sessionRow(_ row: Row) -> some View {
        let s = row.session!
        return HStack(spacing: 10) {
            CheckButton(done: ticking.contains(row.key)) { complete(row) }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.label).strikethrough(ticking.contains(row.key), color: .secondary)
                Text([row.item.title, Fmt.when(row.item, today)].compactMap { $0 }.joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.secondary)
                if row.overdue {
                    Text("Missed \(Fmt.day(s.date, today, inSentence: true)). Do it today.")
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.item.title).foregroundStyle(.primary)
                    Text(Fmt.subline(v.item, today)).font(.subheadline).foregroundStyle(.secondary)
                    if let status = status(v) {
                        Text(status).font(.subheadline).foregroundStyle(v.status == .short || v.status == .behind ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    }
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
        .tint(.primary)
    }

    /// Only what needs attention; on track says nothing.
    private func status(_ v: Vital) -> String? {
        let missed = v.item.sessions.filter { !$0.done && diffDays(today, $0.date) < 0 }.count
        return switch v.status {
        case .short: "Not enough time: \(Fmt.minutes(v.item.shortfallMin)) short"
        case .behind: "Behind by \(missed) \(missed == 1 ? "session" : "sessions")"
        case .notStarted: "Study starts \(v.startBy.map { Fmt.day($0, today, inSentence: true) } ?? "soon")"
        case .noPlan: "No study planned. Tap to set the prep time."
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

/// Planned study per day for the next week, against the daily budget.
struct WeekChart: View {
    let days: [Ahead]
    let budget: Int
    let today: Day

    var body: some View {
        Chart {
            ForEach(days, id: \.date) { d in
                BarMark(x: .value("Day", d.date), y: .value("Minutes", d.load), width: .ratio(0.55))
                    .foregroundStyle(d.over ? Color.red : Color.accentColor.opacity(0.35))
                    .cornerRadius(3)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Double(max(budget, days.map(\.load).max() ?? 0)) * 1.1)
        .chartXAxis {
            AxisMarks(values: days.map(\.date)) { value in
                AxisValueLabel(centered: true) {
                    if let d = value.as(String.self) { dayLabel(d) }
                }
            }
        }
        .frame(height: 130)
        .padding(.vertical, 8)
        .accessibilityLabel(days.map { "\(Fmt.day($0.date, today)): \(Fmt.minutes($0.load))" }.joined(separator: ", "))
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
