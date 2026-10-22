import SwiftUI
import WilListCore

/// Study: what to study today, how full the week is, and whether each exam and deadline
/// coming up is on track.
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

    private var today: Day { store.today }
    private var sessions: [Row] { studyRows(store.state.items, today) }
    private var ahead: [Vital] { readiness(store.state.items, today) }
    private var week: [Ahead] { radar(store.state.items, today, days: 7, perDayMin: store.state.settings.perDayMin) }

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty && ahead.isEmpty && week.allSatisfy({ $0.load == 0 }) {
                    firstRun
                } else {
                    Section("Study today") {
                        if sessions.isEmpty {
                            Text("Nothing to study today.").foregroundStyle(.secondary)
                        }
                        ForEach(sessions) { sessionRow($0) }
                    }

                    Section("This week") {
                        if week.allSatisfy({ $0.load == 0 }) {
                            Text("No study planned this week.").foregroundStyle(.secondary)
                        } else {
                            WeekChart(days: week, budget: store.state.settings.perDayMin, today: today)
                            Text("The dashed line is your \(Fmt.minutes(store.state.settings.perDayMin)) a day.\(week.contains(where: \.over) ? " Red is past it." : "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowSeparator(.hidden, edges: .top)
                        }
                    }

                    Section("Coming up") {
                        if ahead.isEmpty {
                            Text("No exams or deadlines in the next 45 days.").foregroundStyle(.secondary)
                        }
                        ForEach(ahead, id: \.item.id) { readinessRow($0) }
                    }
                }
            }
            .listStyle(.plain)
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
            Text("Add an exam or a deadline, and WilList spreads your study over the days before it, so you never have to cram.")
                .fixedSize(horizontal: false, vertical: true)
            Button { adding = true } label: {
                Text("Add an exam or deadline").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button { importing = true } label: {
                Text("Bring in a schedule").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .heroCard(empty: true)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
    }

    private func sessionRow(_ row: Row) -> some View {
        let s = row.session!
        let minutes = Text(Fmt.minutes(s.minutes * (1 + row.extra)))
            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
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
                if typeSize.isAccessibilitySize { minutes }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
            if !typeSize.isAccessibilitySize { minutes }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 16))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.brand)
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

/// Planned study per day for the next week: each bar is green up to your daily study time (the
/// dashed line) and red past it, so a heavy day shows how much is too much.
struct WeekChart: View {
    let days: [Ahead]
    let budget: Int
    let today: Day
    private let height: CGFloat = 110

    var body: some View {
        let top = Double(max(budget, days.map(\.load).max() ?? 0)) * 1.1
        let y = { (minutes: Int) in height * Double(minutes) / top }
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(days, id: \.date) { d in
                        VStack(spacing: 0) {
                            Color.red.frame(height: y(max(d.load - budget, 0)))
                            Color.brand.opacity(0.35).frame(height: y(min(d.load, budget)))
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
        .accessibilityLabel(days.map { "\(Fmt.day($0.date, today)): \(Fmt.minutes($0.load))" }.joined(separator: ", "))
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
