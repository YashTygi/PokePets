import AppKit

// PokePets app icon: a Poké Ball–split squircle with front-facing pixel Pikachu standing on its button.
// Run from anywhere:  swift bin/make-icon.swift   (writes every size straight into AppIcon.appiconset)
// Optional: swift bin/make-icon.swift some-other-walk-sheet.png
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()            // …/PokePets/bin
let sheetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : here.appendingPathComponent("pikachu-walk-8dir.png").path
let iconSet = here.appendingPathComponent("../PokePets/Assets.xcassets/AppIcon.appiconset").standardized
let sheet = NSImage(contentsOfFile: sheetPath)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let sprite = sheet.cropping(to: CGRect(x: 0, y: 0, width: 32, height: 40))!   // row 0 (facing camera), frame 0

let N = 1024, W = CGFloat(N)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

// macOS icon grid: 824×824 body centred in 1024, continuous-ish corner radius ≈ 185.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(shape); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()

// Top half: red with a soft vertical gradient. Bottom half: warm white.
let midY: CGFloat = 400                              // belt sits low: room for Pikachu above it
let red = CGGradient(colorsSpace: cs, colors: [rgb(0xFF5A4E), rgb(0xD8202A)] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: midY, width: W, height: W))
ctx.drawLinearGradient(red, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: midY), options: [])
ctx.restoreGState()
let white = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF), rgb(0xE6E9F0)] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: midY))
ctx.drawLinearGradient(white, start: CGPoint(x: 0, y: midY), end: CGPoint(x: 0, y: body.minY), options: [])
ctx.restoreGState()

// Glossy highlight on the red half.
ctx.setFillColor(rgb(0xFFFFFF, 0.18))
ctx.fillEllipse(in: CGRect(x: 150, y: 740, width: 170, height: 90))

// The black belt across the middle.
let belt: CGFloat = 46
ctx.setFillColor(rgb(0x1E1E26))
ctx.fill(CGRect(x: 0, y: midY - belt / 2, width: W, height: belt))

// Pixel Pikachu, nearest-neighbour, standing on the belt the way it stands on your Dock.
// Find the opaque bounds of the frame so it's centred exactly.
let data = CGContext(data: nil, width: sprite.width, height: sprite.height, bitsPerComponent: 8, bytesPerRow: 0,
                     space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
data.draw(sprite, in: CGRect(x: 0, y: 0, width: sprite.width, height: sprite.height))
let bytes = data.data!.assumingMemoryBound(to: UInt8.self)
var minX = 99, maxX = -1, minY = 99   // minY in bitmap rows from the BOTTOM (CG context memory is top-down)
for y in 0..<sprite.height { for x in 0..<sprite.width where bytes[(y * data.bytesPerRow) + x * 4 + 3] > 20 {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, sprite.height - 1 - y)
}}
// The ball's button, centred on the belt: Pikachu stands on top of it like a little stage.
let c = CGPoint(x: body.midX, y: midY)
let ring: CGFloat = 132, inner: CGFloat = 100
ctx.setFillColor(rgb(0x1E1E26)); ctx.fillEllipse(in: CGRect(x: c.x - ring, y: c.y - ring, width: 2 * ring, height: 2 * ring))
ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillEllipse(in: CGRect(x: c.x - inner, y: c.y - inner, width: 2 * inner, height: 2 * inner))
ctx.setFillColor(rgb(0xDCE0EA)); ctx.fillEllipse(in: CGRect(x: c.x - inner + 22, y: c.y - inner + 22, width: 2 * (inner - 22), height: 2 * (inner - 22)))

let px: CGFloat = 13                                   // one sprite pixel = 17×17 icon pixels
let w = CGFloat(sprite.width) * px, h = CGFloat(sprite.height) * px
let artCenter = (CGFloat(minX + maxX + 1) / 2) * px
let feetY = c.y + inner - 6                          // standing on the button's white face
let spriteRect = CGRect(x: body.midX - artCenter, y: feetY - CGFloat(minY) * px, width: w, height: h)
ctx.interpolationQuality = .none
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: px * 0.6, height: -px * 0.6), blur: 0, color: rgb(0x000000, 0.25))   // hard pixel shadow
ctx.draw(sprite, in: spriteRect)
ctx.restoreGState()

ctx.restoreGState()

// Thin inner stroke for definition on light wallpapers.
ctx.addPath(shape); ctx.setStrokeColor(rgb(0x000000, 0.10)); ctx.setLineWidth(3); ctx.strokePath()

// Save every size macOS needs (smooth downscaling of the 1024 master).
let master = ctx.makeImage()!
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let small = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    small.interpolationQuality = .high
    small.draw(master, in: CGRect(x: 0, y: 0, width: size, height: size))
    let url = iconSet.appendingPathComponent("icon_\(size).png")
    try! NSBitmapImageRep(cgImage: small.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
    print("wrote", url.path)
}
