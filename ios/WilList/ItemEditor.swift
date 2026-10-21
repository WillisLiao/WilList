import SwiftUI
import WilListCore

/// Everything about one item, with its study plan.
struct ItemEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: Item
    @State private var confirmDelete = false

    init(item: Item) { _item = State(initialValue: item) }

    private var planned: Bool { plannedTypes.contains(item.type) && item.recur == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $item.title, axis: .vertical).font(.title3)
                    Picker("Kind", selection: $item.type) {
                        ForEach(ItemType.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Letter", selection: $item.priority) {
                        Text("None").tag(Letter?.none)
                        ForEach(Letter.allCases, id: \.self) { Text($0.rawValue).tag(Letter?.some($0)) }
                    }
                    if item.priority == .D {
                        TextField("Who will do it?", text: $item.delegateTo)
                    }
                } footer: {
                    if let l = item.priority { Text(l.meaning) }
                }

                Section {
                    Toggle("Date", isOn: Binding(get: { item.date != nil }, set: { item.date = $0 ? (item.date ?? store.today) : nil }))
                    if let d = item.date {
                        DatePicker("On", selection: Binding(get: { Fmt.date(d) }, set: { item.date = WilListCore.today($0) }), displayedComponents: .date)
                        Toggle("Time", isOn: Binding(get: { item.time != nil }, set: { item.time = $0 ? (item.time ?? "09:00") : nil }))
                        if let t = item.time {
                            DatePicker("At", selection: Binding(
                                get: { Calendar.current.date(bySettingHour: (timeToMin(t) ?? 540) / 60, minute: (timeToMin(t) ?? 540) % 60, second: 0, of: .now) ?? .now },
                                set: { item.time = minToTime(nowMinutes($0)) }), displayedComponents: .hourAndMinute)
                        }
                    }
                    if let r = item.recur {
                        LabeledContent("Repeats", value: Fmt.recur(r))
                        Button("Stop repeating", role: .destructive) { item.recur = nil }
                    }
                    if item.type == .event {
                        Stepper("Lasts \(Fmt.minutes(item.durationMin ?? 60))", value: Binding(get: { item.durationMin ?? 60 }, set: { item.durationMin = $0 }), in: 5...600, step: 5)
                    }
                    TextField("Course or project", text: Binding(get: { item.course ?? "" }, set: { item.course = $0.isEmpty ? nil : $0 }))
                }

                if planned {
                    Section {
                        Stepper("Prep \(Fmt.minutes(item.effortMin))", value: $item.effortMin, in: 0...6000, step: 30)
                        if let w = item.weightPct { LabeledContent("Share of grade", value: "\(w.formatted())%") }
                        ForEach(item.sessions) { s in
                            HStack {
                                Image(systemName: s.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(s.done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.label)
                                    Text("\(Fmt.day(s.date, store.today)), \(Fmt.minutes(s.minutes))")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Study plan")
                    } footer: {
                        if item.shortfallMin > 0 {
                            Text("There isn't enough time before it for all of this: \(Fmt.minutes(item.shortfallMin)) short. Start now, or raise your daily study time in More.")
                        } else if item.sessions.isEmpty && item.effortMin > 0 {
                            Text("Save to plan the study sessions.")
                        } else if !item.sessions.isEmpty {
                            Text("Spread back from the date, around everything else you have on.")
                        }
                    }
                }

                Section("Notes") {
                    TextField("Anything to remember", text: $item.notes, axis: .vertical).lineLimit(2...8)
                }

                Section {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle(item.type.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(item)
                        dismiss()
                    }
                    .disabled(item.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \u{201C}\(item.title)\u{201D}?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(item.id)
                    dismiss()
                }
            }
        }
    }
}
