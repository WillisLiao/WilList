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
    @Environment(Store.self) private var store
    @Binding var at: String?
    let today: Day
    @State private var picking = false

    private var date: Date? { Reminders.remind(at).flatMap { Calendar.current.date(from: $0) } }

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                if let later = Self.laterToday {
                    choice("Later today", later)
                }
                choice("Tomorrow", Self.morning(in: 1))
                choice("Next week", Self.morning(in: Self.daysToMonday))
                Button("Pick a date and time") { picking = true }
            } label: {
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
        .sheet(isPresented: $picking) {
            DateTimePicker(initial: date ?? Self.morning(in: 1)) { set($0) }
        }
    }

    /// Sets the reminder, asking for notifications the first time.
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

/// A calendar and a clock, for "Pick a date and time".
private struct DateTimePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    let done: (Date) -> Void

    init(initial: Date, done: @escaping (Date) -> Void) {
        _date = State(initialValue: initial)
        self.done = done
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Remind me", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }
            .sheetGround()
            .navigationTitle("Remind me")
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
                    DatePicker(title, selection: Binding(get: { Fmt.date(d) }, set: { date = WilListCore.today($0) }),
                               displayedComponents: .date)
                        .labelsHidden()
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
            Menu {
                pick("Today", today)
                pick("Tomorrow", addDays(today, 1))
                pick("Next week", addDays(today, ReminderRow.daysToMonday))
                Button("Pick a date") { date = addDays(today, 1) }
            } label: {
                Label(add, systemImage: "calendar").fillsRow()
            }
        }
    }

    private func pick(_ title: String, _ d: Day) -> some View {
        Button { date = d } label: {
            Text(title)
            Text(Fmt.date(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
        }
    }
}

/// "Repeat": the usual choices, or every so many days, weeks, months or years.
struct RepeatRow: View {
    @Binding var recur: Recur?
    /// A repeat counts from the due date, so setting one without a date starts it today.
    @Binding var date: Day?
    let today: Day
    @State private var customizing = false

    var body: some View {
        Group {
            if let r = recur {
                SetRow(symbol: "repeat", overdue: false, clear: { recur = nil }) {
                    Menu { choices } label: {
                        HStack {
                            Text("Repeat").foregroundStyle(Color.primary)
                            Spacer()
                            Text(Fmt.recur(r)).foregroundStyle(Color.secondary)
                        }
                    }
                }
            } else {
                Menu { choices } label: { Label("Repeat", systemImage: "repeat").fillsRow() }
            }
        }
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
