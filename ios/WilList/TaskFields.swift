import SwiftUI
import WilListCore

// The rows every task's detail screen shares, to-dos and items alike: steps, Remind me, the
// due date and time, and Repeat. Empty, each is one tap to a short menu of the usual choices;
// set, it shows the value with a picker to fine-tune it and a button to clear it.

/// Steps: tick them off one by one, add with return, swipe to delete, drag to reorder.
struct StepsList: View {
    @Binding var steps: [Step]
    @State private var draft = ""
    @FocusState private var adding: Bool

    var body: some View {
        ForEach($steps) { $step in
            HStack(spacing: 12) {
                Button { withAnimation(.snappy) { step.done.toggle() } } label: {
                    Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(step.done ? Color.brand : Color(.tertiaryLabel))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(trigger: step.done) { old, new in !old && new ? .success : nil }
                .accessibilityLabel(step.done ? "Step done" : "Mark step done")
                TextField("Step", text: $step.title, axis: .vertical)
                    .strikethrough(step.done, color: .secondary)
                    .foregroundStyle(step.done ? .secondary : .primary)
            }
        }
        .onDelete { steps.remove(atOffsets: $0) }
        .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
        HStack(spacing: 12) {
            Image(systemName: "plus").font(.title3).foregroundStyle(Color.brand).frame(width: 24)
            TextField(steps.isEmpty ? "Add a step" : "Next step", text: $draft)
                .focused($adding)
                .submitLabel(.next)
                .onSubmit {
                    let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { adding = false; return }
                    withAnimation(.snappy) { steps.append(Step(id: newID(), title: t)) }
                    draft = ""
                    adding = true
                }
        }
    }
}

/// "Remind me": later today, tomorrow morning, next week, or any date and time.
struct ReminderRow: View {
    @Binding var at: String?
    let today: Day

    private var date: Date? { Reminders.remind(at).flatMap { Calendar.current.date(from: $0) } }

    var body: some View {
        HStack(spacing: 12) {
            ReminderMenu(at: $at, today: today) {
                if let date {
                    // "Remind me at 9:00 AM" over "Tomorrow", as Microsoft To Do puts it.
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(date < .now ? Color.red : Color.brand)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Remind me at \(date.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(Color.primary)
                            Text(Fmt.day(WilListCore.today(date), today))
                                .font(.subheadline)
                                .foregroundStyle(date < .now ? Color.red : Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Label("Remind me", systemImage: "bell").frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if at != nil {
                Button { at = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove reminder")
            }
        }
    }

    /// Three hours on, on the hour; not offered late in the evening.
    static var laterToday: Date? {
        let cal = Calendar.current, soon = Date.now.addingTimeInterval(3 * 3600)
        guard var hour = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: soon)) else { return nil }
        if hour < soon { hour.addTimeInterval(3600) }
        return cal.isDateInToday(hour) && cal.component(.hour, from: hour) <= 22 ? hour : nil
    }

    static func morning(in days: Int) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: .now)) ?? .now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// Days until next Monday (a full week on when today is Monday).
    static var daysToMonday: Int {
        let wd = Calendar.current.component(.weekday, from: .now) // 1 = Sunday
        return (9 - wd) % 7 == 0 ? 7 : (9 - wd) % 7
    }
}

/// Remind me's choices, as a menu with any label: later today, tomorrow morning, next week, or any
/// date and time. Setting one asks for notifications the first time.
struct ReminderMenu<Label: View>: View {
    @Environment(Store.self) private var store
    @Binding var at: String?
    let today: Day
    @ViewBuilder let label: Label
    @State private var picking = false

    var body: some View {
        Menu {
            if let later = ReminderRow.laterToday {
                choice("Later today", later)
            }
            choice("Tomorrow", ReminderRow.morning(in: 1))
            choice("Next week", ReminderRow.morning(in: ReminderRow.daysToMonday))
            Button("Pick a date and time") { picking = true }
            if at != nil { Button("Remove", role: .destructive) { at = nil } }
        } label: {
            label
        }
        .sheet(isPresented: $picking) {
            DateTimePicker(title: "Remind me", initial: Reminders.remind(at).flatMap { Calendar.current.date(from: $0) } ?? ReminderRow.morning(in: 1),
                           from: .now) { set($0) }
        }
    }

    private func set(_ date: Date) {
        at = Reminders.stamp(date)
        Task {
            if await Reminders.allowed() {
                await Reminders.sync(Reminders.due(store.state, today: store.today))
            } else {
                store.say("Turn on notifications for WilList in Settings.")
            }
        }
    }

    private func choice(_ title: String, _ date: Date) -> some View {
        Button { set(date) } label: {
            Text(title)
            Text(Fmt.reminder(Reminders.stamp(date), today) ?? "")
        }
    }
}

/// A date's choices, as a menu with any label: today, tomorrow, next week, or any day.
struct DateMenu<Label: View>: View {
    @Binding var date: Day?
    let today: Day
    var title = "Date"
    @ViewBuilder let label: Label
    @State private var picking = false

    var body: some View {
        Menu {
            pick("Today", today)
            pick("Tomorrow", addDays(today, 1))
            pick("Next week", addDays(today, ReminderRow.daysToMonday))
            Button("Pick a date") { picking = true }
            if date != nil { Button("Remove", role: .destructive) { date = nil } }
        } label: {
            label
        }
        .sheet(isPresented: $picking) {
            DateTimePicker(title: title, initial: Fmt.date(date ?? addDays(today, 1)), components: .date) { date = WilListCore.today($0) }
        }
    }

    private func pick(_ title: String, _ d: Day) -> some View {
        Button { date = d } label: {
            Text(title)
            Text(Fmt.date(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
        }
    }
}

/// A calendar, and a clock when it's a time too.
private struct DateTimePicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var date: Date
    /// The earliest it can be: now, for a reminder.
    let from: Date
    let components: DatePickerComponents
    let done: (Date) -> Void

    init(title: String, initial: Date, from: Date = .distantPast, components: DatePickerComponents = [.date, .hourAndMinute],
         done: @escaping (Date) -> Void) {
        self.title = title
        _date = State(initialValue: initial)
        self.from = from
        self.components = components
        self.done = done
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(title, selection: $date, in: from..., displayedComponents: components)
                    .datePickerStyle(.graphical)
            }
            .sheetGround()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Set") { done(date); dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

/// The due date, and the time it is due if it has one.
struct DueRow: View {
    @Binding var date: Day?
    @Binding var time: String?
    let today: Day
    var title = "Due"
    var add = "Add a due date"

    var body: some View {
        // The date and its time side by side in one row, after the calendar (a word beside both
        // squeezed onto two lines; VoiceOver still reads it). The clear button takes off the time
        // first, then the date.
        if let d = date {
            SetRow(symbol: "calendar", overdue: diffDays(today, d) < 0,
                   clearLabel: time == nil ? "Remove the date" : "Remove the time",
                   clear: { if time == nil { date = nil } else { time = nil } }) {
                HStack(spacing: 6) {
                    DayChip(title: title, day: Binding(get: { d }, set: { date = $0 }))
                    if let t = time {
                        DatePicker("Time", selection: Binding(
                            get: { Calendar.current.date(bySettingHour: (timeToMin(t) ?? 1020) / 60, minute: (timeToMin(t) ?? 1020) % 60, second: 0, of: .now) ?? .now },
                            set: { time = minToTime(nowMinutes($0)) }), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    } else {
                        // Set like the date beside it.
                        Button { time = "17:00" } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.subheadline.weight(.semibold))
                                Text("Time")
                            }
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Add a time")
                    }
                    Spacer(minLength: 0)
                }
                // Without words to line up with, the separator below would start at the row's edge.
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            }
        } else {
            DateMenu(date: $date, today: today, title: title) { Label(add, systemImage: "calendar").fillsRow() }
        }
    }
}

extension ItemType {
    /// What an item's date means, as the date row names it.
    var dueWord: String {
        switch self {
        case .deadline, .reading: "Due"
        case .exam, .presentation, .event, .study: "On"
        case .task: "Date"
        }
    }
}

/// A day as a chip, "Oct 26" (the year only when it isn't this year), that opens the calendar like
/// the system's compact picker. That one always writes the year, which left no room for the time
/// beside it under Display Zoom.
private struct DayChip: View {
    let title: String
    @Binding var day: Day
    @State private var picking = false

    var body: some View {
        let date = Fmt.date(day)
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        Button { picking = true } label: {
            // A fixed colour: inside a button, the primary style takes on the tint.
            Text(sameYear ? date.formatted(.dateTime.month(.abbreviated).day()) : date.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
        .accessibilityValue(date.formatted(date: .complete, time: .omitted))
        .popover(isPresented: $picking) {
            DatePicker(title, selection: Binding(get: { date }, set: { day = WilListCore.today($0); picking = false }),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.brand)
                // A popover takes its content's size, and the calendar on its own asks for almost none.
                .frame(width: 320)
                .padding(8)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// "Repeat": the usual choices, or every so many days, weeks, months or years.
struct RepeatRow: View {
    @Binding var recur: Recur?
    @Binding var date: Day?
    let today: Day

    var body: some View {
        if let r = recur {
            SetRow(symbol: "repeat", overdue: false, clear: { recur = nil }) {
                RepeatMenu(recur: $recur, date: $date, today: today) {
                    HStack {
                        Text("Repeat").foregroundStyle(Color.primary)
                        Spacer()
                        Text(Fmt.recur(r)).foregroundStyle(Color.secondary)
                    }
                }
            }
        } else {
            RepeatMenu(recur: $recur, date: $date, today: today) { Label("Repeat", systemImage: "repeat").fillsRow() }
        }
    }
}

/// Repeat's choices, as a menu with any label.
struct RepeatMenu<Label: View>: View {
    @Binding var recur: Recur?
    /// A repeat counts from the due date, so setting one without a date starts it today.
    @Binding var date: Day?
    let today: Day
    @ViewBuilder let label: Label
    @State private var customizing = false

    var body: some View {
        Menu { choices } label: { label }
            .sheet(isPresented: $customizing) {
                CustomRepeat(recur: recur ?? Recur(.weekly, days: [weekday(date ?? today)])) { set($0) }
            }
    }

    @ViewBuilder private var choices: some View {
        let wd = weekday(date ?? today)
        Button("Daily") { set(Recur(.daily)) }
        Button("Weekdays") { set(Recur(.weekdays)) }
        Button("Weekly") { set(Recur(.weekly, days: [wd])) }
        Button("Monthly") { set(Recur(.monthly)) }
        Button("Yearly") { set(Recur(.yearly)) }
        Divider()
        Button("Custom…") { customizing = true }
        if recur != nil { Button("Remove", role: .destructive) { recur = nil } }
    }

    private func set(_ r: Recur) {
        if date == nil { date = today }
        recur = r
    }
}

/// Every N days, weeks (on chosen weekdays), months or years.
private struct CustomRepeat: View {
    @Environment(\.dismiss) private var dismiss
    @State private var every: Int
    @State private var unit: Recur.Freq
    @State private var days: Set<Int>
    let done: (Recur) -> Void

    init(recur: Recur, done: @escaping (Recur) -> Void) {
        _every = State(initialValue: recur.every)
        _unit = State(initialValue: recur.freq == .biweekly || recur.freq == .weekdays ? .weekly : recur.freq)
        _days = State(initialValue: Set(recur.freq == .weekdays ? [1, 2, 3, 4, 5] : recur.days ?? []))
        self.done = done
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Every \(every) \(name)", value: $every, in: 1...99)
                    Picker("Unit", selection: $unit) {
                        Text("Days").tag(Recur.Freq.daily)
                        Text("Weeks").tag(Recur.Freq.weekly)
                        Text("Months").tag(Recur.Freq.monthly)
                        Text("Years").tag(Recur.Freq.yearly)
                    }
                    .pickerStyle(.segmented)
                }
                if unit == .weekly {
                    Section("On") {
                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { d in
                                let on = days.contains(d)
                                Button {
                                    if on { days.remove(d) } else { days.insert(d) }
                                } label: {
                                    Text(Calendar.current.veryShortWeekdaySymbols[d])
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(on ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(on ? Color.brand : Color(.secondarySystemFill), in: Circle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[d])
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .sheetGround()
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        done(Recur(unit, days: unit == .weekly ? days.sorted() : nil, interval: every == 1 ? nil : every))
                        dismiss()
                    }
                    .disabled(unit == .weekly && days.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var name: String {
        switch unit {
        case .daily: every == 1 ? "day" : "days"
        case .monthly: every == 1 ? "month" : "months"
        case .yearly: every == 1 ? "year" : "years"
        default: every == 1 ? "week" : "weeks"
        }
    }
}

/// A row that has a value: its symbol (red when the time has passed), the control, and a clear button.
private struct SetRow<Content: View>: View {
    let symbol: String
    let overdue: Bool
    var clearLabel = "Clear"
    let clear: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(overdue ? Color.red : Color.brand)
                .frame(width: 24)
            content
            Button(action: clear) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(clearLabel)
        }
    }
}

/// The five letters as chips: each a pale wash of its colour with dark words until chosen, then in
/// full (yellow and green words can't be read on white). Choosing the chosen one again clears it.
struct LetterChips: View {
    let letter: Letter?
    let choose: (Letter?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Letter.allCases, id: \.self) { l in
                Button { choose(l == letter ? nil : l) } label: {
                    Text(l.rawValue)
                        .font(.headline)
                        .strikethrough(l == .E)
                        .foregroundStyle(letter == l ? l.ink : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(letter == l ? l.color : l.color.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(l.rawValue): \(l.meaning)")
                .accessibilityAddTraits(letter == l ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: letter)
    }
}

/// "Add to Today": shows the item on the Today tab for the rest of the day, as Microsoft To Do's My Day.
struct AddToTodayRow: View {
    @Binding var myDay: Day?
    let today: Day

    var body: some View {
        if myDay == today {
            SetRow(symbol: "sun.max.fill", overdue: false, clear: { myDay = nil }) {
                Text("Added to Today").frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Button { myDay = today } label: { Label("Add to Today", systemImage: "sun.max") }
        }
    }
}

/// The star that marks a to-do as important.
struct StarButton: View {
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(on ? Color.brand : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(on ? "Important" : "Mark as important")
    }
}

/// Play beside a task: choose how long, and a focus session on it starts. The planned length, when
/// there is one, comes with the usual ones.
struct PlayButton: View {
    /// A study session's or a block's own length.
    var planned: Int?
    let start: (Int) -> Void

    var body: some View {
        Menu {
            Section("Focus for") {
                ForEach(Array(Set([15, 25, 45, 60, 90] + [planned].compactMap { $0 })).sorted(), id: \.self) { m in
                    Button { start(m) } label: {
                        Text(Fmt.minutes(m))
                        if m == planned { Text("As planned") }
                    }
                }
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.subheadline)
                .foregroundStyle(Color.brand)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .accessibilityLabel("Start a focus session")
    }
}

/// The column at a row's right end, as wide as the star: a letter, or nothing, so the Play
/// buttons beside it line up down a list.
struct MarkColumn<Content: View>: View {
    @ViewBuilder let content: Content

    // The clear fill keeps the width when there is nothing in it.
    var body: some View { ZStack { Color.clear; content }.frame(width: 44, height: 44) }
}

/// Play and the star or letter at a row's right end, side by side with no gap, and up against the
/// words: their 44-point frames already leave room round the marks, and on a narrow screen (Display
/// Zoom's 320 points) the words need every point, so "Due today, 17:00" stays on one line.
struct RowEnd<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View { HStack(spacing: 0) { content }.padding(.leading, -10) }
}
