import Compression
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import WilListCore

// A minimal zip writer, enough to build .docx, .pptx and .xlsx fixtures.
private func zip(_ files: [(name: String, text: String, deflate: Bool)]) -> Data {
    var out = Data(), central = Data()
    func le16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
    func le32(_ v: Int) -> Data { withUnsafeBytes(of: UInt32(v).littleEndian) { Data($0) } }
    for f in files {
        let raw = Array(f.text.utf8)
        var body = raw
        if f.deflate {
            var dst = [UInt8](repeating: 0, count: raw.count + 64)
            let n = compression_encode_buffer(&dst, dst.count, raw, raw.count, nil, COMPRESSION_ZLIB)
            body = Array(dst.prefix(n))
        }
        let name = Data(f.name.utf8), method = f.deflate ? 8 : 0
        let sizes = le32(body.count) + le32(raw.count)
        let entry: [Data] = [le32(0x0201_4b50), Data(count: 6), le16(method), Data(count: 8), sizes, le16(name.count), Data(count: 12), le32(out.count), name]
        central += entry.reduce(Data(), +)
        let local: [Data] = [le32(0x0403_4b50), Data(count: 4), le16(method), Data(count: 8), sizes, le16(name.count), le16(0), name, Data(body)]
        out += local.reduce(Data(), +)
    }
    let end: [Data] = [le32(0x0605_4b50), Data(count: 4), le16(files.count), le16(files.count), le32(central.count), le32(out.count), le16(0)]
    return out + central + end.reduce(Data(), +)
}

@Test func wordDocumentsBecomeParagraphs() throws {
    let doc = "<w:document><w:body><w:p><w:r><w:t>Midterm &amp; review</w:t></w:r></w:p><w:p><w:r><w:t>Nov 13</w:t><w:tab/><w:t>25%</w:t></w:r></w:p></w:body></w:document>"
    let data = zip([("[Content_Types].xml", "<Types/>", false), ("word/document.xml", doc, true)])
    #expect(try officeText(data, kind: "docx") == "Midterm & review\nNov 13\t25%")
    let blocks = try fileBlocks(data, name: "Syllabus.docx")
    #expect(blocks == [.object(["type": "text", "text": "Syllabus.docx\n\nMidterm & review\nNov 13\t25%"])])
}

@Test func spreadsheetsComeOutRowByRow() throws {
    let strings = "<sst><si><t>Essay 2</t></si><si><t>Due</t></si></sst>"
    let sheet = #"<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>1</v></c></row><row r="2"><c r="A2" t="s"><v>0</v></c><c r="B2"><v>46339</v></c></row></sheetData></worksheet>"#
    let text = try officeText(zip([("xl/sharedStrings.xml", strings, true), ("xl/worksheets/sheet1.xml", sheet, false)]), kind: "xlsx")
    #expect(text.contains("Excel dates"))
    #expect(text.hasSuffix("Due\nEssay 2\t46339"))
}

@Test func slidesKeepTheirOrder() throws {
    func slide(_ t: String) -> String { "<p:sld><a:p><a:r><a:t>\(t)</a:t></a:r></a:p></p:sld>" }
    let data = zip([("ppt/slides/slide10.xml", slide("Last"), true), ("ppt/slides/slide2.xml", slide("Week 2 &#8211; quiz"), true)])
    #expect(try officeText(data, kind: "pptx") == "Slide 1\nWeek 2 – quiz\n\nSlide 2\nLast")
    #expect(xmlText("<t>A &lt;B&gt; &#x41; &bogus;</t>") == "A <B> A &bogus;")
}

@Test func filesWeCannotRead() {
    #expect(throws: FileError.unsupported("pages")) { try fileBlocks(Data("x".utf8), name: "Plan.pages") }
    #expect(throws: FileError.unsupported("bin")) { try fileBlocks(Data([0, 1, 2]), name: "blob.bin") }
    #expect(throws: FileError.damaged) { try fileBlocks(Data("not a zip".utf8), name: "x.docx") }
    #expect(throws: FileError.empty) { try fileBlocks(Data("  \n".utf8), name: "notes.txt") }
    #expect(throws: FileError.tooBig) { try fileBlocks(Data(count: 21 * 1024 * 1024), name: "huge.pdf") }
}

private func png(width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.4, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let out = NSMutableData()
    let dst = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dst)
    return out as Data
}

@Test func photosAndPDFs() throws {
    let small = png(width: 40, height: 30)
    guard case .object(let a) = try fileBlocks(small, name: "board.png")[0], case .object(let src) = a["source"] else { Issue.record(); return }
    #expect(src["media_type"] == "image/png")
    // An iPhone photo (HEIC, or anything large) is re-encoded as a JPEG no wider than 2000 px.
    guard case .object(let b) = try fileBlocks(png(width: 4000, height: 1000), name: "IMG_0001.heic")[0],
          case .object(let src2) = b["source"], case .string(let b64) = src2["data"] else { Issue.record(); return }
    #expect(src2["media_type"] == "image/jpeg")
    let jpeg = CGImageSourceCreateWithData(Data(base64Encoded: b64)! as CFData, nil)!
    let props = CGImageSourceCopyPropertiesAtIndex(jpeg, 0, nil) as! [CFString: Any]
    #expect(props[kCGImagePropertyPixelWidth] as? Int == 2000)
    guard case .object(let pdf) = try fileBlocks(Data("%PDF-1.7\n".utf8), name: "Schedule")[0] else { Issue.record(); return }
    #expect(pdf["type"] == "document" && pdf["title"] == "Schedule")
}

@Test func requestShape() throws {
    let r = Claude.extractRequest(Claude.textContent("Quiz fri"), today: "2026-10-20", key: "sk-test")
    #expect(r.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(r.value(forHTTPHeaderField: "x-api-key") == "sk-test")
    #expect(r.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(r.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
    let body = try JSONDecoder().decode([String: JSONValue].self, from: r.httpBody!)
    #expect(body["model"] == "claude-opus-5-5")
    #expect(body["fallbacks"] == "default")
    #expect(body["max_tokens"] == .number(16000))
    guard case .string(let system) = body["system"], case .object(let config) = body["output_config"] else { Issue.record(); return }
    #expect(system.contains("Today is Tuesday 2026-10-20."))
    #expect(config["effort"] == "medium")
    #expect(String(decoding: r.httpBody!, as: UTF8.self).contains(#""max_tokens":16000"#))
}

private func reply(_ items: String, before: [String] = [], stop: String = "end_turn") -> Data {
    let blocks = before + [#"{"type":"text","text":\#(String(decoding: try! JSONEncoder().encode(#"{"items":\#(items)}"#), as: UTF8.self))}"#]
    return Data(#"{"content":[\#(blocks.joined(separator: ","))],"stop_reason":"\#(stop)","usage":{"input_tokens":1000000,"output_tokens":50000}}"#.utf8)
}

@Test func repliesBecomeItemDrafts() throws {
    let items = #"""
    [{"title":"Midterm","type":"exam","date":"2026-11-13","time":"09:00","course":"HIST150","weightPct":25,"effortHours":8,"repeatDays":[],"durationMin":0},
     {"title":"Lecture","type":"event","date":"2026-10-21","time":"10:00","course":"","weightPct":0,"effortHours":0,"repeatDays":[3,1,1,9],"durationMin":50},
     {"title":"Undated reading","type":"reading","date":"","time":"","course":"","weightPct":0,"effortHours":2,"repeatDays":[],"durationMin":0},
     {"title":"Buy a lab coat","type":"task","date":"","time":"25:00","course":"","weightPct":0,"effortHours":0,"repeatDays":[],"durationMin":0}]
    """#
    let r = try Claude.extracted(reply(items), status: 200)
    #expect(r.items.map(\.title) == ["Midterm", "Lecture", "Buy a lab coat"])
    #expect(r.items[0].effortMin == 480 && r.items[0].weightPct == 25 && r.items[0].course == "HIST150")
    #expect(r.items[1].recur == Recur(.weekly, days: [1, 3]) && r.items[1].durationMin == 50 && r.items[1].course == nil)
    #expect(r.items[2].date == nil && r.items[2].time == nil)
    #expect(abs(r.costUSD - 5) < 0.0001)
    // After a fallback, only what the fallback model wrote is read.
    let half = #"{"type":"text","text":"{\"items\":[{\"ti"}"#
    let after = try Claude.extracted(reply("[]", before: [half, #"{"type":"fallback"}"#]), status: 200)
    #expect(after.items.isEmpty)
}

@Test func failuresInPlainWords() {
    #expect(throws: AIError.badKey) { try Claude.extracted(Data(), status: 401) }
    #expect(throws: AIError.busy) { try Claude.extracted(Data(), status: 429) }
    #expect(throws: AIError.server(529)) { try Claude.extracted(Data(), status: 529) }
    #expect(throws: AIError.rejected("prompt is too long")) {
        try Claude.extracted(Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long"}}"#.utf8), status: 400)
    }
    #expect(throws: AIError.declined) { try Claude.extracted(reply("[]", stop: "refusal"), status: 200) }
    #expect(throws: AIError.tooLong) { try Claude.extracted(reply("[]", stop: "max_tokens"), status: 200) }
    #expect(throws: AIError.unreadable) { try Claude.extracted(Data("<html>".utf8), status: 200) }
}
