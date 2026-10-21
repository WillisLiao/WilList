import Foundation

// Optional: Claude reads any file or pasted text and maps out the dated things in it, for a
// semester, a job, a project or anything else. It runs on the person's own Anthropic API key,
// and requests go straight from the phone to Anthropic.

public enum AIError: LocalizedError, Equatable {
    case noKey, badKey, notAllowed, busy, offline, declined, tooLong, unreadable
    case rejected(String)
    case server(Int)

    public var errorDescription: String? {
        switch self {
        case .noKey: "Add your Anthropic API key first, in More."
        case .badKey: "Anthropic rejected that API key. Check it in More."
        case .notAllowed: "This API key is not allowed to use Claude Opus 5.5."
        case .busy: "Too many requests right now. Wait a minute and try again."
        case .offline: "Could not reach Anthropic. Check your connection."
        case .declined: "Claude declined to read that. Try just the schedule part."
        case .tooLong: "That was too long to read in one go. Split it in two."
        case .unreadable: "Claude's answer could not be read. Try again."
        case .rejected(let why): "Anthropic could not process that: \(why)"
        case .server(let status): "Anthropic returned an error (\(status)). Try again shortly."
        }
    }
}

public struct Extracted: Sendable {
    public var items: [Item]
    public var costUSD: Double
}

public enum Claude {
    public static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let schema = try! JSONDecoder().decode(JSONValue.self, from: Data(#"""
    {"type": "object", "additionalProperties": false, "required": ["items"], "properties": {"items": {"type": "array", "items": {
      "type": "object", "additionalProperties": false,
      "required": ["title", "type", "date", "time", "course", "weightPct", "effortHours", "repeatDays", "durationMin"],
      "properties": {
        "title": {"type": "string", "description": "Short name in the source's own words, at most 60 characters."},
        "type": {"type": "string", "enum": ["exam", "deadline", "presentation", "reading", "event", "task"]},
        "date": {"type": "string", "description": "YYYY-MM-DD, or \"\" if the source gives none."},
        "time": {"type": "string", "description": "24-hour HH:MM, or \"\" if none."},
        "course": {"type": "string", "description": "Short label for the course, project or team, such as MATH201, or \"\"."},
        "weightPct": {"type": "number", "description": "Share of the final grade if stated, else 0."},
        "effortHours": {"type": "number", "description": "Realistic preparation hours for exams, deadlines, presentations and readings; 0 for classes, meetings and small tasks."},
        "repeatDays": {"type": "array", "items": {"type": "integer"}, "description": "For weekly classes, meetings or shifts: weekdays 0=Sun … 6=Sat. Otherwise empty."},
        "durationMin": {"type": "integer", "description": "Length of a class, meeting or shift in minutes, else 0."}
      }}}}}
    """#.utf8))

    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    static func system(_ today: Day) -> String {
        """
        You turn what someone shares into planner items. It can be anything with dates in it: a syllabus, a class or work timetable, a project plan, a shift roster, an event programme, an email, a photo of a whiteboard or a printed schedule, or a messy list.
        Today is \(weekdayNames[weekday(today)]) \(today).
        Rules:
        - One item per exam or test, deadline or deliverable, presentation, reading, recurring class, meeting or shift, appointment, or concrete to-do.
        - Leave out topics, holidays and "no class" days unless something is due.
        - Resolve relative or partial dates against today. Leave out anything that is already in the past.
        - Never invent items, dates or grade weights that the source does not support.
        - Recurring classes, meetings and shifts are type "event" with repeatDays, a time and durationMin.
        """
    }

    /// The request for pasted text or a file's content blocks.
    public static func extractRequest(_ content: [JSONValue], today: Day, key: String) -> URLRequest {
        var r = URLRequest(url: endpoint, timeoutInterval: 300)
        r.httpMethod = "POST"
        r.setValue(key, forHTTPHeaderField: "x-api-key")
        r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // A declined request is re-run on Anthropic's recommended fallback model instead of failing.
        r.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: JSONValue = .object([
            "model": .string(model),
            "max_tokens": .number(16000),
            "fallbacks": "default",
            "output_config": .object(["effort": "medium", "format": .object(["type": "json_schema", "schema": schema])]),
            "system": .string(system(today)),
            "messages": .array([.object(["role": "user", "content": .array(content)])]),
        ])
        r.httpBody = try? JSONEncoder().encode(body)
        return r
    }

    public static func textContent(_ text: String) -> [JSONValue] { [.object(["type": "text", "text": .string(text)])] }

    public static func fileContent(_ data: Data, name: String) throws -> [JSONValue] {
        try fileBlocks(data, name: name) + textContent("Turn this into planner items.")
    }

    /// Sends the request, retrying twice when Anthropic is busy, and returns item drafts.
    public static func extract(_ content: [JSONValue], today: Day, key: String, session: URLSession = .shared) async throws -> Extracted {
        guard !key.isEmpty else { throw AIError.noKey }
        var attempt = 0
        while true {
            let data: Data, status: Int
            do {
                let (d, resp) = try await session.data(for: extractRequest(content, today: today, key: key))
                (data, status) = (d, (resp as? HTTPURLResponse)?.statusCode ?? 0)
            } catch let e as URLError where e.code == .cancelled {
                throw CancellationError()
            } catch {
                throw AIError.offline
            }
            if (status == 429 || status >= 500) && attempt < 2 {
                attempt += 1
                try await Task.sleep(for: .seconds(attempt * 3))
                continue
            }
            return try extracted(data, status: status)
        }
    }

    private struct Response: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        struct Usage: Decodable {
            let input_tokens: Int?, output_tokens: Int?, cache_read_input_tokens: Int?, cache_creation_input_tokens: Int?
        }
        let content: [Block]
        let stop_reason: String?
        let usage: Usage?
    }

    private struct Found: Decodable {
        let title: String, type: String, date: String, time: String, course: String
        let weightPct: Double, effortHours: Double, repeatDays: [Int], durationMin: Int

        var draft: Item? {
            let type = ItemType(rawValue: type) ?? .task
            let date = isValidDay(date) ? date : nil
            if date == nil && type != .task { return nil }
            let days = Set(repeatDays.filter { (0...6).contains($0) }).sorted()
            var it = Item(id: "", title: String(title.prefix(80)), type: type)
            it.date = date
            it.time = matches(time, #"^\d{2}:\d{2}$"#) && timeToMin(time)! < 1440 ? time : nil
            it.course = course.isEmpty ? nil : course
            it.weightPct = weightPct > 0 ? weightPct : nil
            it.effortMin = effortHours > 0 ? Int((effortHours * 60).rounded()) : 0
            it.recur = type == .event && !days.isEmpty ? Recur(.weekly, days: days) : nil
            it.durationMin = type == .event && durationMin > 0 ? durationMin : nil
            return it
        }
    }

    /// Item drafts from Anthropic's reply, or what went wrong in plain words.
    public static func extracted(_ data: Data, status: Int) throws -> Extracted {
        guard (200..<300).contains(status) else {
            switch status {
            case 401: throw AIError.badKey
            case 403: throw AIError.notAllowed
            case 429: throw AIError.busy
            case 400, 413:
                struct Failure: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
                throw AIError.rejected((try? JSONDecoder().decode(Failure.self, from: data))?.error.message ?? "the request was not accepted.")
            default: throw AIError.server(status)
            }
        }
        guard let res = try? JSONDecoder().decode(Response.self, from: data) else { throw AIError.unreadable }
        if res.stop_reason == "refusal" { throw AIError.declined }
        if res.stop_reason == "max_tokens" { throw AIError.tooLong }
        // After a mid-answer fallback, only the part the fallback model wrote counts.
        let cut = res.content.lastIndex { $0.type == "fallback" }.map { $0 + 1 } ?? 0
        let text = res.content[cut...].compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard let found = try? JSONDecoder().decode([String: [Found]].self, from: Data(text.utf8))["items"] else { throw AIError.unreadable }
        let u = res.usage
        // Opus 5.5 per million tokens.
        let cost = (Double(u?.input_tokens ?? 0) * 4 + Double(u?.output_tokens ?? 0) * 20
            + Double(u?.cache_read_input_tokens ?? 0) * 0.2 + Double(u?.cache_creation_input_tokens ?? 0) * 5) / 1e6
        return Extracted(items: found.compactMap(\.draft), costUSD: cost)
    }
}
