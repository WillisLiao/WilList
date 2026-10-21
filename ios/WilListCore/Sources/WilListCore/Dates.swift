import Foundation

/// A local calendar day as "YYYY-MM-DD", and times as "HH:MM", exactly as the web app stored
/// them: plain strings never drift between time zones, and old data loads unchanged.
public typealias Day = String

// Days since 1970-01-01 for a civil date, and back (Howard Hinnant's algorithms).
func dayNumber(_ y: Int, _ m: Int, _ d: Int) -> Int {
    let y2 = m <= 2 ? y - 1 : y
    let era = (y2 >= 0 ? y2 : y2 - 399) / 400
    let yoe = y2 - era * 400
    let doy = (153 * ((m + 9) % 12) + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
}

func civil(_ n: Int) -> (y: Int, m: Int, d: Int) {
    let z = n + 719468
    let era = (z >= 0 ? z : z - 146096) / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let m = mp < 10 ? mp + 3 : mp - 9
    return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, doy - (153 * mp + 2) / 5 + 1)
}

public func pad(_ n: Int) -> String { n < 10 && n >= 0 ? "0\(n)" : "\(n)" }

func dayParts(_ iso: Day) -> (y: Int, m: Int, d: Int) {
    let p = iso.split(separator: "-").map { Int($0) ?? 0 }
    return p.count == 3 ? (p[0], p[1], p[2]) : (1970, 1, 1)
}

func dayNumber(_ iso: Day) -> Int {
    let p = dayParts(iso)
    return dayNumber(p.y, p.m, p.d)
}

func day(_ n: Int) -> Day {
    let c = civil(n)
    return "\(c.y)-\(pad(c.m))-\(pad(c.d))"
}

/// A valid date, or nil for things like February 30.
public func makeDay(_ y: Int, _ m: Int, _ d: Int) -> Day? {
    guard (1...12).contains(m), (1...31).contains(d) else { return nil }
    let c = civil(dayNumber(y, m, d))
    return c.m == m && c.d == d ? "\(y)-\(pad(m))-\(pad(d))" : nil
}

public func isValidDay(_ s: String) -> Bool {
    let p = s.split(separator: "-")
    guard s.count == 10, p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
          let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else { return false }
    return makeDay(y, m, d) == s
}

public func addDays(_ iso: Day, _ n: Int) -> Day { day(dayNumber(iso) + n) }

/// Whole days from a to b (positive when b is later).
public func diffDays(_ a: Day, _ b: Day) -> Int { dayNumber(b) - dayNumber(a) }

/// 0 = Sunday … 6 = Saturday.
public func weekday(_ iso: Day) -> Int { ((dayNumber(iso) % 7) + 7 + 4) % 7 }

/// Monday of the week containing iso.
public func weekStart(_ iso: Day) -> Day {
    let wd = weekday(iso)
    return addDays(iso, wd == 0 ? -6 : 1 - wd)
}

public func timeToMin(_ hhmm: String?) -> Int? {
    guard let hhmm else { return nil }
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return p.count == 2 ? p[0] * 60 + p[1] : nil
}

public func minToTime(_ min: Int) -> String {
    let m = ((min % 1440) + 1440) % 1440
    return "\(pad(m / 60)):\(pad(m % 60))"
}

public func today(_ now: Date = .now, calendar: Calendar = .current) -> Day {
    let c = calendar.dateComponents([.year, .month, .day], from: now)
    return "\(c.year!)-\(pad(c.month!))-\(pad(c.day!))"
}

public func nowMinutes(_ now: Date = .now, calendar: Calendar = .current) -> Int {
    let c = calendar.dateComponents([.hour, .minute], from: now)
    return c.hour! * 60 + c.minute!
}
