import Compression
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Any file someone has, as something Claude can read: PDFs and photos go as they are, Word,
// PowerPoint and Excel files are unzipped to their text, everything else is read as text.

public enum FileError: LocalizedError, Equatable {
    case tooBig, damaged, empty, picture
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .tooBig: "That file is over 20 MB. Split it or export just the schedule pages."
        case .damaged: "That file looks damaged."
        case .empty: "That file has no text in it."
        case .picture: "Could not open that picture. Save it as JPEG or PDF and try again."
        case .unsupported(let ext): "WilList can’t read \(ext.isEmpty ? "this kind of" : ".\(ext)") files. Save it as PDF and try again."
        }
    }
}

private let maxBytes = 20 * 1024 * 1024 // the API takes 32 MB per request; base64 adds a third

// MARK: zip (Office files)

private func inflate(_ src: [UInt8], size: Int) throws -> [UInt8] {
    guard size > 0 else { return [] }
    guard size <= 64 * 1024 * 1024 else { throw FileError.damaged }
    var dst = [UInt8](repeating: 0, count: size)
    let n = compression_decode_buffer(&dst, size, src, src.count, nil, COMPRESSION_ZLIB) // raw DEFLATE
    guard n > 0 else { throw FileError.damaged }
    return Array(dst.prefix(n))
}

/// The entries of a zip whose names pass `wanted`, as (name, text), in archive order.
func unzipText(_ data: Data, wanted: (String) -> Bool) throws -> [(name: String, text: String)] {
    let b = [UInt8](data)
    func u16(_ o: Int) -> Int { o >= 0 && o + 2 <= b.count ? Int(b[o]) | Int(b[o + 1]) << 8 : 0 }
    func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
    var end = b.count - 22
    while end >= 0 && u32(end) != 0x0605_4b50 { end -= 1 }
    guard end >= 0 else { throw FileError.damaged }
    var p = u32(end + 16)
    var out: [(String, String)] = []
    for _ in 0..<u16(end + 10) {
        guard u32(p) == 0x0201_4b50 else { throw FileError.damaged }
        let method = u16(p + 10), size = u32(p + 20), rawSize = u32(p + 24), nameLen = u16(p + 28)
        let local = u32(p + 42)
        guard p + 46 + nameLen <= b.count else { throw FileError.damaged }
        let name = String(decoding: b[(p + 46)..<(p + 46 + nameLen)], as: UTF8.self)
        p += 46 + nameLen + u16(p + 30) + u16(p + 32)
        guard wanted(name) else { continue }
        let start = local + 30 + u16(local + 26) + u16(local + 28)
        guard start + size <= b.count else { throw FileError.damaged }
        let raw = Array(b[start..<(start + size)])
        out.append((name, String(decoding: method == 8 ? try inflate(raw, size: rawSize) : raw, as: UTF8.self)))
    }
    return out
}

private let entities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]

func xmlText(_ xml: String, breaks: String? = nil) -> String {
    var t = breaks.map { replacing(xml, $0, with: "\n") } ?? xml
    t = replacing(t.replacingOccurrences(of: "<w:tab/>", with: "\t"), "<[^>]+>", with: "")
    var decoded = ""
    var rest = t[...]
    for m in allMatches(t, #"&(#[xX]?[0-9a-fA-F]+|\w+);"#) {
        let whole = m[0]!, e = m[1]!
        guard let r = rest.range(of: whole) else { continue }
        decoded += rest[..<r.lowerBound]
        let hex = e.hasPrefix("#x") || e.hasPrefix("#X")
        let code = e.hasPrefix("#") ? UInt32(e.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10) : nil
        decoded += code.flatMap(Unicode.Scalar.init).map { String($0) } ?? entities[e] ?? whole
        rest = rest[r.upperBound...]
    }
    decoded += rest
    return replacing(decoded, #"\n{3,}"#, with: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func number(_ name: String) -> Int { match(name, #"(\d+)\.xml$"#).flatMap { Int($0[1]!) } ?? 0 }

func officeText(_ data: Data, kind: String) throws -> String {
    switch kind {
    case "docx":
        return try unzipText(data) { matches($0, #"^word/(document|footnotes|endnotes)\.xml$"#) }
            .map { xmlText($0.text, breaks: "</w:p>") }.joined(separator: "\n\n")
    case "pptx":
        return try unzipText(data) { matches($0, #"^ppt/slides/slide\d+\.xml$"#) }
            .sorted { number($0.name) < number($1.name) }
            .enumerated().map { "Slide \($0.offset + 1)\n\(xmlText($0.element.text, breaks: "</a:p>"))" }
            .joined(separator: "\n\n")
    default: // xlsx: each row as tab-separated cells, shared strings looked up by index
        let parts = try unzipText(data) { $0 == "xl/sharedStrings.xml" || matches($0, #"^xl/worksheets/sheet\d+\.xml$"#) }
        let shared = allMatches(parts.first { $0.name == "xl/sharedStrings.xml" }?.text ?? "", #"<si>([\s\S]*?)</si>"#).map { xmlText($0[1]!) }
        let sheets = parts.filter { $0.name != "xl/sharedStrings.xml" }.sorted { number($0.name) < number($1.name) }.map { sheet in
            allMatches(sheet.text, #"<row[^>]*>([\s\S]*?)</row>"#).map { row in
                allMatches(row[1]!, #"<c([^>]*?)(?:/>|>([\s\S]*?)</c>)"#).map { c in
                    let body = c[2] ?? ""
                    let val = match(body, #"<v>([\s\S]*?)</v>"#)?[1] ?? match(body, #"<t[^>]*>([\s\S]*?)</t>"#)?[1] ?? ""
                    return matches(c[1]!, #"t="s""#) ? Int(val).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? "" : xmlText(val)
                }.joined(separator: "\t")
            }.joined(separator: "\n")
        }
        return "Spreadsheet. Numbers between 30000 and 60000 in date columns are Excel dates (days since 1899-12-30).\n\n" + sheets.joined(separator: "\n\n")
    }
}

// MARK: content blocks

private func base64Block(_ type: String, _ mediaType: String, _ data: Data) -> [String: JSONValue] {
    ["type": .string(type), "source": .object(["type": "base64", "media_type": .string(mediaType), "data": .string(data.base64EncodedString())])]
}

// Photos are re-encoded as JPEG no larger than 2000 px: iPhone HEIC photos aren't accepted as
// they are, and a smaller picture reads just as well for less.
private func photo(_ data: Data) throws -> Data {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true,
              kCGImageSourceThumbnailMaxPixelSize: 2000,
          ] as CFDictionary) else { throw FileError.picture }
    let out = NSMutableData()
    guard let dst = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { throw FileError.picture }
    CGImageDestinationAddImage(dst, img, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    guard CGImageDestinationFinalize(dst) else { throw FileError.picture }
    return out as Data
}

private let passThrough: [String: String] = ["jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "gif": "image/gif", "webp": "image/webp"]

/// Content blocks for one file, ready to send with a request.
public func fileBlocks(_ data: Data, name: String) throws -> [JSONValue] {
    guard data.count <= maxBytes else { throw FileError.tooBig }
    let ext = (name as NSString).pathExtension.lowercased()
    let type = UTType(filenameExtension: ext)
    if ext == "pdf" || data.starts(with: Array("%PDF".utf8)) {
        var block = base64Block("document", "application/pdf", data)
        block["title"] = .string(name)
        return [.object(block)]
    }
    if type?.conforms(to: .image) == true {
        if let media = passThrough[ext], data.count < 3_500_000 { return [.object(base64Block("image", media, data))] }
        return [.object(base64Block("image", "image/jpeg", try photo(data)))]
    }
    let text: String
    if ["docx", "pptx", "xlsx"].contains(ext) {
        text = try officeText(data, kind: ext)
    } else if ["doc", "ppt", "xls", "pages", "numbers", "key"].contains(ext) {
        throw FileError.unsupported(ext)
    } else {
        guard !data.prefix(4000).contains(0) else { throw FileError.unsupported(ext) }
        text = String(decoding: data, as: UTF8.self)
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FileError.empty }
    return [.object(["type": "text", "text": .string("\(name)\n\n\(text)")])]
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
