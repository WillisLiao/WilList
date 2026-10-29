import SwiftUI
import WilListCore

/// A month under the rows of Plan and Study, each day showing what's planned on it: up to two
/// short titles in their colours, or one and "+2" for the rest. Today's number is in the teal;
/// tapping a day chooses it (filled teal), and again lets it go, so the screen can list it in full.
struct MonthCalendar: View {
    /// One thing on a day: its title, and the colour it is drawn in with the words on it.
    struct Mark {
        let title: String
        let fill: Color
        let ink: Color
    }

    @Binding var selection: Day?
    let today: Day
    /// What's planned on a day, in the order shown.
    let planned: (Day) -> [Mark]
    @State private var month: Day

    init(selection: Binding<Day?>, today: Day, planned: @escaping (Day) -> [Mark]) {
        _selection = selection
        self.today = today
        self.planned = planned
        _month = State(initialValue: Self.first(of: selection.wrappedValue ?? today))
    }

    private static func first(of d: Day) -> Day { String(d.prefix(8)) + "01" }

    private func shift(_ months: Int) -> Day {
        let d = Calendar.current.date(byAdding: .month, value: months, to: Fmt.date(month)) ?? Fmt.date(month)
        return Self.first(of: WilListCore.today(d))
    }

    /// The month's days, after blanks for the days of the week before its first.
    private var cells: [Day?] {
        let lead = (weekday(month) - (Calendar.current.firstWeekday - 1) + 7) % 7
        let count = Calendar.current.range(of: .day, in: .month, for: Fmt.date(month))?.count ?? 30
        return Array(repeating: nil, count: lead) + (0..<count).map { addDays(month, $0) }
    }

    private var weekdays: [String] {
        let s = Calendar.current.veryShortStandaloneWeekdaySymbols, k = Calendar.current.firstWeekday - 1
        return Array(s[k...] + s[..<k])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text(Fmt.date(month).formatted(.dateTime.month(.wide).year()))
                    .font(.hand(.headline))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { month = shift(-1) } label: { SketchIcon(glyph: .chevron, size: 15).rotationEffect(.degrees(180)).tapArea() }
                    .accessibilityLabel("Previous month")
                Button { month = shift(1) } label: { SketchIcon(glyph: .chevron, size: 15).tapArea() }
                    .accessibilityLabel("Next month")
            }
            .font(.hand(.body))
            .buttonStyle(.borderless)
            HStack(spacing: 2) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, w in
                    Text(w).font(.hand(.caption)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            // Plain rows of seven: a lazy grid inside a list's row sent the list's layout round in a
            // loop until the app stopped (DESIGN pitfall 28).
            let all = cells
            VStack(spacing: 4) {
                ForEach(0..<(all.count + 6) / 7, id: \.self) { w in
                    HStack(alignment: .top, spacing: 2) {
                        ForEach(0..<7, id: \.self) { k in
                            if let d = all.indices.contains(w * 7 + k) ? all[w * 7 + k] : nil {
                                cell(d)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                    }
                }
            }
        }
        // Seven columns hold their numbers and short titles up to this size; VoiceOver reads each
        // day in full.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .padding(.bottom, 4)
        .onChange(of: selection) { if let selection { month = Self.first(of: selection) } }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func cell(_ d: Day) -> some View {
        let chosen = d == selection, marks = planned(d)
        // Two titles fit; with more, one and how many others.
        let shown = marks.count > 2 ? 1 : marks.count
        return Button { selection = chosen ? nil : d } label: {
            VStack(spacing: 2) {
                Text("\(Int(d.suffix(2)) ?? 0)")
                    .font(.hand(.subheadline))
                    .monospacedDigit()
                    .foregroundStyle(chosen ? Color.white : d == today ? Color.brand : Color.primary)
                    .frame(width: 28, height: 28)
                    .background(chosen ? Color.brand : .clear, in: Circle())
                ForEach(0..<shown, id: \.self) { i in
                    Text(marks[i].title)
                        .font(.hand(.caption2, size: 10))
                        .lineLimit(1)
                        .foregroundStyle(marks[i].ink)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity)
                        .background(marks[i].fill, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                if marks.count > shown {
                    Text("+\(marks.count - shown)").font(.hand(.caption2, size: 10)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Fmt.date(d).formatted(date: .complete, time: .omitted))
        .accessibilityValue(marks.map(\.title).joined(separator: ", "))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
