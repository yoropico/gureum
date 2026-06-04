import AppKit

// Menu-bar IME indicator icons — monochrome TEMPLATE, NO inner text, from the bomi-input BRAND
// glyphs. Korean = ㅂ (bieup); English/roman = B. Both extracted from the brand light icons
// (OSX/Icons/brand/{bomi-input,single-b}.png — off-white tile + black glyph) by thresholding the
// dark glyph to an opaque-black / transparent template mask, then aspect-fit into tiles.
//
// Two outputs per glyph:
//   • SQUARE imagesets (eng/qwerty/han/...): glyph letterboxed in a square tile (the system
//     input-source menu-icon slot is a FIXED SQUARE; non-square would distort). 16/32 px.
//   • TIGHT status imagesets (statusbomi_eng/statusbomi_han): glyph fills the tile height for the
//     NSStatusItem (width-flexible slot). The glyphs are taller than wide, so they read big.
//
// All template (black + alpha) so AppKit tints to the menu-bar appearance.
// Re-run:  swift OSX/Icons/generate-menubar-icons.swift [path/to/Assets.xcassets]

let BASE = 16                    // @1x square tile / menu-bar height (px); @2x = 32
let STATUS_H = 20                // @1x status glyph height (px) — bigger so it reads in the bar
let MARGIN_SQ: CGFloat = 0.10    // square letterbox margin (glyph off the edge)
let MARGIN_ST: CGFloat = 0.04    // status tight margin

let brandKO = "OSX/Icons/brand/bomi-input.png"   // ㅂ
let brandEN = "OSX/Icons/brand/single-b.png"     // B

func rep(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

// Threshold a brand light icon to a black+alpha glyph mask; return the tight-cropped glyph rep.
func glyphMask(_ path: String) -> NSBitmapImageRep {
    let src = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
    let W = src.pixelsWide, H = src.pixelsHigh
    let full = rep(W, H); let p = full.bitmapData!; let bpr = full.bytesPerRow
    var minX = W, minY = H, maxX = -1, maxY = -1
    for y in 0..<H { for x in 0..<W {
        let c = src.colorAt(x: x, y: y)!
        let luma = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        let a = max(0, min(1, (0.6 - luma) * 5)) * c.alphaComponent   // dark glyph -> opaque
        let o = y * bpr + x * 4
        p[o] = 0; p[o + 1] = 0; p[o + 2] = 0; p[o + 3] = UInt8(a * 255)
        if a > 0.4 { if x < minX { minX = x }; if x > maxX { maxX = x }; if y < minY { minY = y }; if y > maxY { maxY = y } }
    } }
    let bw = maxX - minX + 1, bh = maxY - minY + 1
    let out = rep(bw, bh); let dp = out.bitmapData!; let dbpr = out.bytesPerRow
    for y in 0..<bh { for x in 0..<bw {
        let so = (minY + y) * bpr + (minX + x) * 4, dO = y * dbpr + x * 4
        dp[dO] = p[so]; dp[dO + 1] = p[so + 1]; dp[dO + 2] = p[so + 2]; dp[dO + 3] = p[so + 3]
    } }
    return out
}

// Aspect-fit a glyph rep into a w×h tile, centered, with margin (high interpolation).
func tile(_ glyph: NSBitmapImageRep, _ w: Int, _ h: Int, _ margin: CGFloat) -> NSBitmapImageRep {
    let out = rep(w, h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)!
    NSGraphicsContext.current!.imageInterpolation = .high
    let gw = CGFloat(glyph.pixelsWide), gh = CGFloat(glyph.pixelsHigh)
    let s = min(CGFloat(w) * (1 - 2 * margin) / gw, CGFloat(h) * (1 - 2 * margin) / gh)
    let dw = gw * s, dh = gh * s
    let img = NSImage(size: NSSize(width: gw, height: gh)); img.addRepresentation(glyph)
    img.draw(in: NSRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh),
             from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    return out
}

func writePNG(_ r: NSBitmapImageRep, _ path: String, _ tag: String) {
    try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)  [\(tag)]  \(r.pixelsWide)x\(r.pixelsHigh)")
}

let assetsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "OSX/Assets.xcassets"
let ko = glyphMask(brandKO)   // ㅂ
let en = glyphMask(brandEN)   // B

// Korean (ko) -> ㅂ; English/roman (en) -> B. Per Info.plist TISIntendedLanguage.
let squareIcons: [(name: String, glyph: NSBitmapImageRep, tag: String)] = [
    ("eng", en, "B"), ("qwerty", en, "B"),
    ("han", ko, "ㅂ"), ("han2", ko, "ㅂ"), ("han3", ko, "ㅂ"),
    ("han390", ko, "ㅂ"), ("han3final", ko, "ㅂ"), ("hanroman", ko, "ㅂ"),
]
for (name, glyph, tag) in squareIcons {
    for (suffix, side) in [("", BASE), ("@2x", BASE * 2)] {
        writePNG(tile(glyph, side, side, MARGIN_SQ), "\(assetsDir)/\(name).imageset/\(name)\(suffix).png", "sq-\(tag)")
    }
}

// Tight status-bar glyphs: width = round(height * glyph-aspect); @2x = 2× @1x.
let statusIcons: [(name: String, glyph: NSBitmapImageRep, tag: String)] = [
    ("statusbomi_han", ko, "ㅂ"), ("statusbomi_eng", en, "B"),
]
for (name, glyph, tag) in statusIcons {
    let aspect = CGFloat(glyph.pixelsWide) / CGFloat(glyph.pixelsHigh)
    let w1 = max(1, Int((CGFloat(STATUS_H) * aspect).rounded()))
    for (suffix, mult) in [("", 1), ("@2x", 2)] {
        writePNG(tile(glyph, w1 * mult, STATUS_H * mult, MARGIN_ST),
                 "\(assetsDir)/\(name).imageset/\(name)\(suffix).png", "status-\(tag)")
    }
}
print("done: square \(squareIcons.count)x2 + status \(statusIcons.count)x2")
