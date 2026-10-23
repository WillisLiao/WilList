// Draws the iPhone app icon: the website's W that ends in a tick (app/icons/icon.svg), white on
// the app's teal, plus the dark and tinted versions iOS shows on a dark or tinted Home Screen.
//   swift scripts/app-icon.swift
import AppKit

let out = "ios/WilList/Assets.xcassets/AppIcon.appiconset"
let side = 1024

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The mark's two strokes from icon.svg (a 24-unit grid placed at 64 and scaled 16 on 512),
/// doubled for 1024: x = 128 + 32u.
let strokes: [[(Double, Double)]] = [
    [(2.5, 9.5), (6.5, 17.5), (11, 8.5)],
    [(11, 9.5), (13.5, 17.5), (21.5, 3.5)],
]

func draw(_ name: String, ground: (top: UInt32, bottom: UInt32)?, mark: CGColor) {
    let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: (ground == nil ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
    let s = CGFloat(side)
    if let ground {
        // A slight fall of light from the top, so the flat teal reads as a surface.
        let gradient = CGGradient(colorsSpace: nil, colors: [rgb(ground.top), rgb(ground.bottom)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: .zero, options: [])
    }
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setStrokeColor(mark)
    ctx.setLineWidth(80)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for stroke in strokes {
        let points = stroke.map { CGPoint(x: 128 + 32 * $0.0, y: 128 + 32 * $0.1) }
        ctx.addLines(between: points)
        ctx.strokePath()
    }
    let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    print("\(out)/\(name)")
}

// Light: white on the app's teal (#057785 at the middle of the gradient).
draw("AppIcon.png", ground: (0x078A99, 0x046471), mark: rgb(0xFFFFFF))
// Dark: iOS lays a transparent icon on its own dark ground; a lighter teal holds up on it.
draw("AppIcon-dark.png", ground: nil, mark: rgb(0x3CC8D8))
// Tinted: iOS colours a grey icon itself.
draw("AppIcon-tinted.png", ground: nil, mark: rgb(0xFFFFFF))
