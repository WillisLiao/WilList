import AppIntents
import SwiftUI
import WidgetKit
import WilListCore

// The widgets' faces. They live here, not in the extension, so the app's debug gallery can show
// them at their real sizes (`-gallery` on launch).

/// "Do this first": the day's A1 with Mark done on it; the medium size adds the next two.
struct FirstWidgetView: View {
    let glance: Glance
    let family: WidgetFamily

    private var solid: Bool { Look.current.filled }
    private var field: Color { CourseColor.of(glance.first?.color) }
    private var ink: Color { solid ? .white : .primary }
    private var grey: Color { solid ? .white : .secondary }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(glance.first.map { "\($0.label ?? "A1"): \($0.title)" } ?? "Nothing to do first")
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium.environment(\.colorScheme, .light).environment(\.field, field)
        default:
            small.environment(\.colorScheme, .light).environment(\.field, field)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = glance.first {
                header(first)
                Spacer(minLength: 6)
                title(first.title, lines: 3, size: .title3)
                Spacer(minLength: 8)
                doneButton(first, wide: true)
            } else {
                nothingFirst
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = glance.first {
                HStack(alignment: .center) {
                    header(first)
                    Spacer(minLength: 8)
                    doneButton(first, wide: false)
                }
                title(first.title, lines: glance.next.isEmpty ? 2 : 1, size: .title3)
                    .padding(.top, 8)
                // With rows to follow there's room for the title alone; without, say what it's about.
                if glance.next.isEmpty, let detail = first.detail {
                    Text(detail).font(.footnote).foregroundStyle(grey).lineLimit(2).padding(.top, 2)
                }
                Spacer(minLength: 8)
                ForEach(glance.next.prefix(2)) { nextRow($0) }
            } else {
                nothingFirst
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(glance.first.map { "\($0.label ?? "A1")  Do this first" } ?? "Do this first")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Text(glance.first?.title ?? "Nothing yet. Give something an A.")
                .font(.headline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: pieces

    private func header(_ first: Glance.Line) -> some View {
        HStack(spacing: 6) {
            LetterMark(letter: first.letter, label: first.label, onBrand: solid)
                .widgetAccentable()
            Text(first.overdue ? "Overdue" : "Do this first")
                .font(.caption.weight(.semibold))
                .foregroundStyle(first.overdue && !solid ? Color.red : grey)
                .lineLimit(1)
        }
    }

    private func title(_ text: String, lines: Int, size: Font.TextStyle = .headline) -> some View {
        Text(text)
            .font(.system(size, design: Look.current.titles, weight: .semibold))
            .foregroundStyle(ink)
            .lineLimit(lines)
            .minimumScaleFactor(0.85)
            .background {
                if Look.current.hero == .outline {
                    RoundedRectangle(cornerRadius: 3).fill(Color.brand.opacity(0.2)).padding(.horizontal, -3)
                }
            }
    }

    private func doneButton(_ first: Glance.Line, wide: Bool) -> some View {
        Button(intent: FinishRowIntent(key: first.id)) {
            Label(first.done ? "Done" : "Mark done", systemImage: first.done ? "checkmark.circle.fill" : "checkmark")
                .contentTransition(.symbolEffect(.replace))
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(solid ? field : Color.white)
                .padding(.horizontal, wide ? 0 : 14)
                .frame(maxWidth: wide ? .infinity : nil, minHeight: 34)
                .background(solid ? Color.white : Color.brand, in: Capsule())
        }
        .buttonStyle(.plain)
        .widgetAccentable()
    }

    private func nextRow(_ line: Glance.Line) -> some View {
        HStack(spacing: 8) {
            Button(intent: FinishRowIntent(key: line.id)) {
                Image(systemName: line.done ? Look.current.box.done : Look.current.box.empty)
                    .font(.body)
                    .foregroundStyle(line.done ? (solid ? Color.white : Color.brand) : (solid ? Color.white.opacity(0.7) : Color(.tertiaryLabel)))
                    .contentTransition(.symbolEffect(.replace))
                    .widgetAccentable(line.done)
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(line.done ? "\(line.title), done" : "Mark \(line.title) done")
            // A widget drops a strikethrough given its own colour, so the words turn grey instead.
            Text(line.title)
                .font(.subheadline)
                .foregroundStyle(line.done ? grey : ink)
                .strikethrough(line.done)
                .lineLimit(1)
            Spacer(minLength: 4)
            LetterMark(letter: line.letter, label: line.label, onBrand: solid)
        }
    }

    /// Nothing lettered for today: finished, or not planned yet.
    private var nothingFirst: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Image(systemName: glance.doneToday > 0 ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(solid ? Color.white : field)
                .widgetAccentable()
            Text(glance.doneToday > 0 ? "All done for today" : "Nothing to do first")
                .font(.headline)
                .fontDesign(Look.current.titles)
                .foregroundStyle(ink)
            Text(glance.doneToday > 0 ? "\(glance.doneToday) finished." : "Give something an A in WilList.")
                .font(.footnote)
                .foregroundStyle(grey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

/// "Today": the open to-dos with a tick box each, and + to add one.
struct TodayWidgetView: View {
    let glance: Glance
    let family: WidgetFamily

    private var large: Bool { family == .systemLarge }

    var body: some View {
        if family == .accessoryCircular {
            circular
        } else {
            list.environment(\.colorScheme, .light)
        }
    }

    private var list: some View {
        // A line just ticked off stays a moment, done, but no longer counts.
        let left = glance.todos.filter { !$0.done }.count
        return VStack(alignment: .leading, spacing: large ? 8 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.date(glance.today).formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                    .fontDesign(Look.current.titles)
                if left > 0 {
                    Text("\(left) to do").font(.footnote).foregroundStyle(.secondary).contentTransition(.numericText(value: Double(left)))
                }
                Spacer(minLength: 0)
                Link(destination: URL(string: "willist://add")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brand)
                        .widgetAccentable()
                }
                .accessibilityLabel("New to-do")
            }
            if glance.todos.isEmpty {
                allClear
            } else {
                ForEach(glance.todos.prefix(large ? 7 : 3)) { row($0) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ todo: Glance.Line) -> some View {
        HStack(spacing: 10) {
            Button(intent: TickTodoIntent(todo: todo.id)) {
                Image(systemName: todo.done ? Look.current.box.done : Look.current.box.empty)
                    .font(.title3)
                    .foregroundStyle(todo.done ? Color.brand : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
                    .widgetAccentable(todo.done)
                    .frame(width: 26, height: large ? 36 : 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.done ? "\(todo.title), done" : "Mark \(todo.title) done")
            VStack(alignment: .leading, spacing: 1) {
                Text(todo.title).font(.subheadline).foregroundStyle(todo.done ? .secondary : .primary).strikethrough(todo.done).lineLimit(1)
                if large, let detail = todo.detail {
                    Text(detail).font(.caption).foregroundStyle(todo.overdue ? Color.red : Color.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if !large && todo.overdue {
                Text("Overdue").font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var allClear: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            if glance.todosDone > 0 {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color.brand).widgetAccentable()
            }
            Text(glance.todosDone > 0 ? "All clear" : "Nothing on your list").font(.headline)
            Text(glance.todosDone > 0 ? "\(glance.todosDone) done today." : "Tap + to add a to-do.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    /// The Lock Screen: to-dos left, ringed by how much of today's list is done.
    private var circular: some View {
        Gauge(value: Double(glance.todosDone), in: 0...Double(max(1, glance.todosDone + glance.todos.count))) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(glance.todos.count)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("\(glance.todos.count) to-dos left")
    }
}

extension Look {
    /// The A1 card's ground, filling a widget: its course's colour, pale, or plain white
    /// (Notebook's outline is the widget's own edge).
    @ViewBuilder static func heroGround(_ glance: Glance) -> some View {
        switch current.hero {
        case .poster, .solid: CourseColor.of(glance.first?.color)
        case .outline: Color.white
        case .pale: ZStack { Color.white; Color.brand.opacity(0.09) }
        }
    }
}
