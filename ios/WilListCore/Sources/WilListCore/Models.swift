import Foundation

// The data, field for field as the web app saved it ("willist.v1"), so a planner moved over
// from the old app decodes unchanged. Decoding is forgiving: a missing or odd field takes its
// default, and a broken row is dropped instead of failing the whole file.

public enum ItemType: String, Codable, Sendable, CaseIterable, Identifiable {
    /// `study` is a study block: a set time to study something, added by hand, maybe every week.
    case task, deadline, exam, presentation, reading, event, study

    public init(from decoder: Decoder) throws {
        self = ItemType(rawValue: (try? decoder.singleValueContainer().decode(String.self)) ?? "") ?? .task
    }

    public var id: Self { self }

    /// A block of time on the calendar (a class, a study block), not a line of the lettered list.
    public var isBlock: Bool { self == .event || self == .study }
}

public enum Letter: String, Codable, Sendable, CaseIterable, Comparable {
    case A, B, C, D, E

    var rank: Int { Letter.allCases.firstIndex(of: self)! }
    public static func < (a: Letter, b: Letter) -> Bool { a.rank < b.rank }
}

public struct Recur: Codable, Equatable, Sendable {
    public enum Freq: String, Codable, Sendable { case daily, weekdays, weekly, biweekly, monthly, yearly }
    public var freq: Freq
    /// Weekdays for weekly repeats, 0 = Sunday.
    public var days: [Int]?
    public var until: Day?
    /// Every so many days, weeks, months or years; missing means every one.
    public var interval: Int?

    public init(_ freq: Freq, days: [Int]? = nil, until: Day? = nil, interval: Int? = nil) {
        self.freq = freq
        self.days = days
        self.until = until
        self.interval = interval
    }

    /// How many units between repeats: biweekly is weekly every two.
    public var every: Int { freq == .biweekly ? 2 : max(1, interval ?? 1) }
}

/// One step of a task, ticked off on its own.
public struct Step: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var done = false

    public init(id: String, title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        done = c.get(.done, false)
    }
}

public struct Session: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var date: Day
    public var minutes: Int
    public var label: String
    public var done = false
    public var doneAt: Day?

    public init(id: String, date: Day, minutes: Int, label: String, done: Bool = false, doneAt: Day? = nil) {
        self.id = id
        self.date = date
        self.minutes = minutes
        self.label = label
        self.done = done
        self.doneAt = doneAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Day.self, forKey: .date)
        minutes = c.int(.minutes) ?? 50
        label = c.get(.label, "Study")
        done = c.get(.done, false)
        doneAt = c.get(.doneAt)
    }
}

public struct Item: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var type: ItemType = .task
    public var course: String?
    public var date: Day?
    public var time: String?
    public var durationMin: Int?
    public var recur: Recur?
    public var skips: [Day] = []
    public var externalId: String?
    public var weightPct: Double?
    public var priority: Letter?
    public var order: Double = 0
    public var delegateTo = ""
    public var notes = ""
    public var effortMin = 0
    public var sessions: [Session] = []
    public var startBy: Day?
    public var shortfallMin = 0
    public var plan: Day?
    public var done = false
    public var doneAt: Day?
    public var doneDates: [Day] = []
    public var goalId: String?
    public var createdAt: Day?
    /// When to be reminded, "YYYY-MM-DDTHH:MM" in local time.
    public var remindAt: String?
    public var steps: [Step] = []
    /// The day it was added to Today; it shows there on that day only.
    public var myDay: Day?

    public init(id: String, title: String, type: ItemType = .task) {
        self.id = id
        self.title = title
        self.type = type
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        type = c.get(.type, .task)
        course = c.get(.course)
        date = c.get(.date)
        time = c.get(.time)
        durationMin = c.int(.durationMin)
        recur = c.get(.recur)
        skips = c.get(.skips, [])
        externalId = c.get(.externalId)
        weightPct = c.get(.weightPct)
        priority = c.get(.priority)
        order = c.get(.order, 0)
        delegateTo = c.get(.delegateTo, "")
        notes = c.get(.notes, "")
        effortMin = c.int(.effortMin) ?? 0
        sessions = c.list(.sessions)
        startBy = c.get(.startBy)
        shortfallMin = c.int(.shortfallMin) ?? 0
        plan = c.get(.plan)
        done = c.get(.done, false)
        doneAt = c.get(.doneAt)
        doneDates = c.get(.doneDates, [])
        goalId = c.get(.goalId)
        createdAt = c.get(.createdAt)
        remindAt = c.get(.remindAt)
        steps = c.list(.steps)
        myDay = c.get(.myDay)
    }
}

public struct Goal: Codable, Equatable, Sendable, Identifiable {
    public enum Area: String, Codable, Sendable, CaseIterable { case academic, personal, `self` }
    public var id: String
    public var title: String
    public var area: Area = .academic
    public var horizon = "90d"
    public var deadline = ""
    public var why = ""
    public var rock = ""
    public var knowledge = ""
    public var people = ""
    public var reward = ""
    public var createdAt: Day?

    public init(id: String, title: String, area: Area = .academic) {
        self.id = id
        self.title = title
        self.area = area
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        area = c.get(.area, .academic)
        horizon = c.get(.horizon, "90d")
        deadline = c.get(.deadline, "")
        why = c.get(.why, "")
        rock = c.get(.rock, "")
        knowledge = c.get(.knowledge, "")
        people = c.get(.people, "")
        reward = c.get(.reward, "")
        createdAt = c.get(.createdAt)
    }
}

/// A plain to-do on Today: no letter, no date, no plan.
public struct Todo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var done = false
    public var doneAt: Day?
    /// Due date and, optionally, time ("HH:MM").
    public var date: Day?
    public var time: String?
    /// When to be reminded, "YYYY-MM-DDTHH:MM" in local time.
    public var remindAt: String?
    public var recur: Recur?
    public var steps: [Step] = []
    public var notes = ""
    public var starred = false
    public var createdAt: Day?

    public init(id: String, title: String, done: Bool = false, doneAt: Day? = nil) {
        self.id = id
        self.title = title
        self.done = done
        self.doneAt = doneAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        done = c.get(.done, false)
        doneAt = c.get(.doneAt)
        date = c.get(.date)
        time = c.get(.time)
        remindAt = c.get(.remindAt)
        recur = c.get(.recur)
        steps = c.list(.steps)
        notes = c.get(.notes, "")
        starred = c.get(.starred, false)
        createdAt = c.get(.createdAt)
    }
}

/// One focus session, for learning how long things really take.
public struct FocusLog: Codable, Equatable, Sendable {
    public var date: Day
    public var itemId: String
    public var type: ItemType
    public var title: String
    public var minutes: Int
    public var planned: Int?
    public var completed: Bool

    public init(date: Day, itemId: String, type: ItemType, title: String, minutes: Int, planned: Int?, completed: Bool) {
        self.date = date
        self.itemId = itemId
        self.type = type
        self.title = title
        self.minutes = minutes
        self.planned = planned
        self.completed = completed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Day.self, forKey: .date)
        itemId = c.get(.itemId, "")
        type = c.get(.type, .task)
        title = c.get(.title, "")
        minutes = c.int(.minutes) ?? 0
        planned = c.int(.planned)
        completed = c.get(.completed, false)
    }
}

/// A calendar link (Canvas, Moodle, Google…) that WilList re-reads to stay current.
public struct Feed: Codable, Equatable, Sendable, Identifiable {
    public var url: String
    public var name: String
    public var syncedAt: Date?
    public var error: String?
    public var id: String { url }

    public init(url: String, name: String) {
        self.url = url
        self.name = name
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var perDayMin = 120
    public var sessionMin = 50
    public var bufferDays = 1
    public var planTime = "20:30"
    public var dateOrder: String?
    public var tips = true
    public var notify = false
    public var reward = ""
    public var dayStart = "08:00"
    public var dayEnd = "22:00"
    public var taskMin = 25
    /// Per type: how long things really take compared with the plan, once you accept it.
    public var calib: [String: Double] = [:]
    /// Each course's colour, by its key (`AppState.courseKey`), as a number into the app's palette.
    public var courseColors: [String: Int] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perDayMin = c.int(.perDayMin) ?? 120
        sessionMin = c.int(.sessionMin) ?? 50
        bufferDays = c.int(.bufferDays) ?? 1
        planTime = c.get(.planTime, "20:30")
        dateOrder = c.get(.dateOrder)
        tips = c.get(.tips, true)
        notify = c.get(.notify, false)
        reward = c.get(.reward, "")
        dayStart = c.get(.dayStart, "08:00")
        dayEnd = c.get(.dayEnd, "22:00")
        taskMin = c.int(.taskMin) ?? 25
        calib = c.get(.calib, [:])
        courseColors = c.get(.courseColors, [:])
    }
}

public struct Meta: Codable, Equatable, Sendable {
    public var lastPlanned: Day?
    public var onboarded = false
    public var doneCount = 0
    /// Per day, the letter of the first thing finished ("-" when it had none).
    public var firstDone: [Day: String] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastPlanned = c.get(.lastPlanned)
        onboarded = c.get(.onboarded, false)
        doneCount = c.int(.doneCount) ?? 0
        firstDone = c.get(.firstDone, [:])
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var v = 1
    public var items: [Item] = []
    public var goals: [Goal] = []
    public var todos: [Todo] = []
    public var mdp = ""
    /// The seven goal questions' answers, keyed "0"…"6".
    public var exercise: [String: String] = [:]
    // Worry Buster and 20 Ideas pages, kept as they were written.
    public var worries: [JSONValue] = []
    public var storms: [JSONValue] = []
    /// The last coach conversation, exactly as sent.
    public var coach: JSONValue?
    public var log: [FocusLog] = []
    public var feeds: [Feed] = []
    public var settings = Settings()
    public var meta = Meta()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = c.list(.items)
        goals = c.list(.goals)
        todos = c.list(.todos)
        mdp = c.get(.mdp, "")
        exercise = c.get(.exercise, [:])
        worries = c.get(.worries, [])
        storms = c.get(.storms, [])
        coach = c.get(.coach)
        log = c.list(.log)
        feeds = c.list(.feeds)
        settings = c.get(.settings, Settings())
        meta = c.get(.meta, Meta())
        colorCourses() // a plan saved before courses had colours, or by the website
    }
}

/// Any JSON, carried through untouched.
public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

// MARK: forgiving decoding

private struct Maybe<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

extension KeyedDecodingContainer {
    func get<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    func get<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// A whole number, also when it was saved as 50.0.
    func int(_ key: Key) -> Int? {
        if let i: Int = get(key) { return i }
        if let d: Double = get(key), d.isFinite { return Int(d.rounded()) }
        return nil
    }

    /// The rows that decode; the rest are dropped.
    func list<T: Decodable>(_ key: Key) -> [T] {
        (get(key) as [Maybe<T>]?)?.compactMap(\.value) ?? []
    }
}
