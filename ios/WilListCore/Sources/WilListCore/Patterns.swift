import Foundation

// Regular expressions compiled once and shared. The parser's patterns are the web app's,
// unchanged, so both read typed text the same way.
final class Patterns: @unchecked Sendable {
    static let shared = Patterns()
    private let lock = NSLock()
    private var cache: [String: NSRegularExpression] = [:]

    func regex(_ pattern: String, ignoreCase: Bool) -> NSRegularExpression {
        let key = ignoreCase ? "i|\(pattern)" : pattern
        lock.lock()
        defer { lock.unlock() }
        if let r = cache[key] { return r }
        let r = try! NSRegularExpression(pattern: ascii(pattern), options: ignoreCase ? [.caseInsensitive] : [])
        cache[key] = r
        return r
    }
}

private let wordChar = "[A-Za-z0-9_]"

// JavaScript's \d, \w and \b only know ASCII; ICU's know every script, so "期中exam" would
// stop reading as an exam and "２" would match \d but not Int(). Keep the JavaScript meaning.
private func ascii(_ p: String) -> String {
    p.replacingOccurrences(of: #"\d"#, with: "[0-9]")
        .replacingOccurrences(of: #"\w"#, with: wordChar)
        .replacingOccurrences(of: #"\b"#, with: "(?:(?<=\(wordChar))(?!\(wordChar))|(?<!\(wordChar))(?=\(wordChar)))")
}

/// The first match: the whole match, then each group (nil where a group took no part).
func match(_ s: String, _ pattern: String, ignoreCase: Bool = false) -> [String?]? {
    let ns = s as NSString
    guard let m = Patterns.shared.regex(pattern, ignoreCase: ignoreCase).firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
    return (0..<m.numberOfRanges).map { i in
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
}

/// Every match, each as the whole match then its groups.
func allMatches(_ s: String, _ pattern: String) -> [[String?]] {
    let ns = s as NSString
    return Patterns.shared.regex(pattern, ignoreCase: false).matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
        (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }
}

func matches(_ s: String, _ pattern: String, ignoreCase: Bool = false) -> Bool {
    match(s, pattern, ignoreCase: ignoreCase) != nil
}

func replacing(_ s: String, _ pattern: String, with template: String, ignoreCase: Bool = false) -> String {
    Patterns.shared.regex(pattern, ignoreCase: ignoreCase)
        .stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
}
