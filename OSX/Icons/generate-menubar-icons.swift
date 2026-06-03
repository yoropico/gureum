import AppKit

// System input-source menu icons (Info.plist tsInputModeMenuIconFileKey) — monochrome TEMPLATE,
// NO inner text. Korean modes get a FILLED cloud (SF Symbol "icloud.fill"); English/roman modes
// get an OUTLINE cloud ("icloud"). The menu bar only needs Korean-vs-English at a glance.
//
// That slot is a FIXED SQUARE, so a wide image is aspect-distorted into it. The cloud is wider
// than tall, so we aspect-fit it (tight bounds) into a SQUARE tile and LETTERBOX it (transparent
// above/below) — undistorted, just a bit shorter than the tile. (The big, wide, undistorted cloud
// lives in the NSStatusItem, which has a width-flexible slot — see GureumAppDelegate.swift. That
// status item draws the same SF Symbol directly, so it needs no PNG here.)
//
// Rendered to static PNGs at generation time. High-res master -> downscaled for crisp edges.
// Re-run:  swift OSX/Icons/generate-menubar-icons.swift [path/to/Assets.xcassets]

let MASTER = 256                 // high-res square master; downscaled to 16 / 32
let BASE = 16                    // @1x tile side in px (square); @2x = 32 (menu-bar native)
let MARGIN: CGFloat = 0.06       // keep the silhouette off the tile edge

let filled = "icloud.fill"       // Korean
let outline = "icloud"           // English/roman

func makeSymbol(_ name: String) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: CGFloat(MASTER), weight: .regular)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
}

func squareRep(_ side: Int) -> NSBitmapImageRep {
    return NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

// Tight opaque bounds of a symbol as fractions of its intrinsic size (fy from the TOP).
func tightFractions(_ name: String) -> (fx: CGFloat, fy: CGFloat, fw: CGFloat, fh: CGFloat) {
    let sym = makeSymbol(name)
    let isz = sym.size
    let W = Int(ceil(isz.width)), H = Int(ceil(isz.height))
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)!
    sym.draw(in: NSRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H)))
    NSGraphicsContext.restoreGraphicsState()
    var minX = W, minY = H, maxX = -1, maxY = -1
    for y in 0..<H { for x in 0..<W where (r.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    } }
    let bw = CGFloat(maxX - minX + 1), bh = CGFloat(maxY - minY + 1)
    return (CGFloat(minX) / CGFloat(W), CGFloat(minY) / CGFloat(H), bw / CGFloat(W), bh / CGFloat(H))
}

// Render the symbol as an opaque black template, tight bounds aspect-fit (letterboxed) into a
// MASTER x MASTER square.
func renderMaster(_ name: String) -> NSBitmapImageRep {
    let s = CGFloat(MASTER)
    let rep = squareRep(MASTER)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.shouldAntialias = true
    let f = tightFractions(name)
    let sym = makeSymbol(name)
    let isz = sym.size
    let target = s * (1 - 2 * MARGIN)
    let scale = min(target / (f.fw * isz.width), target / (f.fh * isz.height))
    let Dw = isz.width * scale, Dh = isz.height * scale
    let cx = (f.fx + f.fw / 2) * Dw
    let cyFromBottom = (1 - (f.fy + f.fh / 2)) * Dh
    sym.draw(in: NSRect(x: s / 2 - cx, y: s / 2 - cyFromBottom, width: Dw, height: Dh))
    // normalize antialiased symbol pixels to opaque black (alpha preserved -> template mask)
    ctx.compositingOperation = .sourceAtop
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func downscale(_ master: NSBitmapImageRep, _ side: Int) -> NSBitmapImageRep {
    let img = NSImage(size: NSSize(width: master.pixelsWide, height: master.pixelsHigh))
    img.addRepresentation(master)
    let out = squareRep(side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)!
    NSGraphicsContext.current!.imageInterpolation = .high
    img.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    return out
}

let assetsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "OSX/Assets.xcassets"

// Korean (ko) -> filled cloud; English/roman (en) -> outline cloud. Per Info.plist
// TISIntendedLanguage. All ko imagesets share filled artwork; both en share the outline.
let icons: [(name: String, symbol: String)] = [
    ("eng", outline), ("qwerty", outline),
    ("han", filled), ("han2", filled), ("han3", filled),
    ("han390", filled), ("han3final", filled), ("hanroman", filled),
]

var masters: [String: NSBitmapImageRep] = [:]
func master(_ symbol: String) -> NSBitmapImageRep {
    if let m = masters[symbol] { return m }
    let m = renderMaster(symbol); masters[symbol] = m; return m
}

for (name, symbol) in icons {
    let m = master(symbol)
    for (suffix, side) in [("", BASE), ("@2x", BASE * 2)] {
        let rep = downscale(m, side)
        guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png fail") }
        let path = "\(assetsDir)/\(name).imageset/\(name)\(suffix).png"
        try! data.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)  [\(symbol)]  \(side)x\(side)")
    }
}
print("done: \(icons.count) imagesets x 2 scales")
