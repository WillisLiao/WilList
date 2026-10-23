import Foundation

/// Two copies of one plan, changed apart (this device's and the one in iCloud), made one again
/// against the copy both last agreed on. It works on the saved JSON (`willist.v1`), so it knows
/// nothing of what the fields mean and keeps working as fields are added:
/// - what only one side changed is kept, down to a single field of a single to-do;
/// - lists whose entries have an `id` (items, to-dos, goals, steps, sessions, calendar links) are
///   matched by it: what either side added comes in where that side put it, what one side deleted
///   goes unless the other changed it meanwhile, and a reorder on one side is kept;
/// - other lists (done dates, the focus log) are bags: what one side removed goes, and what either
///   side added comes in once;
/// - a field both sides changed keeps this device's change, which then goes up to iCloud. With
///   nothing to compare against (the first sync), a value beats an empty one.
/// ponytail: matching by id is quadratic in a list's length; fine for a student's plan of hundreds.
public enum PlanMerge {
    public static func merge(base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = JSONDecoder()
        let base = try base.map { try decoder.decode(JSONValue.self, from: $0) }
        let merged = merge(base, try decoder.decode(JSONValue.self, from: local), try decoder.decode(JSONValue.self, from: remote))
        return try JSONEncoder().encode(merged)
    }

    static func merge(_ base: JSONValue?, _ local: JSONValue, _ remote: JSONValue) -> JSONValue {
        if local == remote || remote == base { return local }
        if local == base { return remote }
        switch (local, remote) {
        case (.object(let l), .object(let r)):
            return .object(mergeObjects(base?.object, l, r))
        case (.array(let l), .array(let r)):
            let b = base?.array ?? []
            return .array(keyed([b, l, r]) ? mergeByID(b, l, r) : mergeBags(b, l, r))
        default:
            return base == nil && local.isEmpty ? remote : local
        }
    }

    private static func mergeObjects(_ base: [String: JSONValue]?, _ l: [String: JSONValue], _ r: [String: JSONValue]) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for key in Set(l.keys).union(r.keys) {
            if let kept = mergeEntry(base?[key], l[key], r[key]) { out[key] = kept }
        }
        return out
    }

    /// One field of an object, or one entry of a list matched by id; nil when it was deleted (or,
    /// for a field, cleared) on one side and left alone on the other.
    private static func mergeEntry(_ base: JSONValue?, _ local: JSONValue?, _ remote: JSONValue?) -> JSONValue? {
        switch (local, remote) {
        case let (l?, r?): merge(base, l, r)
        case let (l?, nil): base == l ? nil : l
        case let (nil, r?): base == r ? nil : r
        case (nil, nil): nil
        }
    }

    /// Lists of entries that each have an `id`, in at least one of the three copies.
    private static func keyed(_ lists: [[JSONValue]]) -> Bool {
        lists.contains { !$0.isEmpty } && lists.allSatisfy { $0.allSatisfy { $0.id != nil } }
    }

    private static func mergeByID(_ b: [JSONValue], _ l: [JSONValue], _ r: [JSONValue]) -> [JSONValue] {
        func byID(_ list: [JSONValue]) -> [String: JSONValue] {
            Dictionary(list.map { ($0.id!, $0) }, uniquingKeysWith: { first, _ in first })
        }
        let bm = byID(b), lm = byID(l), rm = byID(r)
        var kept: [String: JSONValue] = [:]
        for id in Set(lm.keys).union(rm.keys) {
            if let entry = mergeEntry(bm[id], lm[id], rm[id]) { kept[id] = entry }
        }
        // The order: this device's if it moved anything, otherwise the other copy's; then what the other
        // side added goes in after the entry it followed there.
        let lOrder = l.map { $0.id! }, rOrder = r.map { $0.id! }, bOrder = b.map { $0.id! }
        let moved = lOrder.filter { bm[$0] != nil } != bOrder.filter { lm[$0] != nil }
        let (lead, follow) = moved ? (lOrder, rOrder) : (rOrder, lOrder)
        var order = lead.filter { kept[$0] != nil }
        for (i, id) in follow.enumerated() where kept[id] != nil && !order.contains(id) {
            let after = follow[..<i].last { order.contains($0) }
            order.insert(id, at: after.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
        return order.compactMap { kept[$0] }
    }

    private static func mergeBags(_ b: [JSONValue], _ l: [JSONValue], _ r: [JSONValue]) -> [JSONValue] {
        var out: [JSONValue] = [], lAdded = l, rAdded = r
        for entry in b {
            let li = lAdded.firstIndex(of: entry), ri = rAdded.firstIndex(of: entry)
            if let li { lAdded.remove(at: li) }
            if let ri { rAdded.remove(at: ri) }
            if li != nil && ri != nil { out.append(entry) }
        }
        out += lAdded
        for entry in rAdded {
            if let both = lAdded.firstIndex(of: entry) { lAdded.remove(at: both) } else { out.append(entry) }
        }
        return out
    }
}

extension JSONValue {
    var object: [String: JSONValue]? { if case .object(let o) = self { o } else { nil } }
    public var array: [JSONValue]? { if case .array(let a) = self { a } else { nil } }

    /// An entry's `id`, when it is an object that has one.
    var id: String? { if case .string(let s)? = object?["id"] { s } else { nil } }

    /// Nothing written yet: null, false, nothing, or an empty list or object.
    var isEmpty: Bool {
        switch self {
        case .null: true
        case .bool(let b): !b
        case .number: false
        case .string(let s): s.isEmpty
        case .array(let a): a.isEmpty
        case .object(let o): o.isEmpty
        }
    }
}
