import AppKit

// Cloud silhouette (rounded base bar + three overlapping bumps), normalized to `rect`.
// Sized to fill most of the tile (~x[0.04,0.98], y[0.10,0.90]) so it reads at 16px.
func cloudPath(in rect: NSRect) -> NSBezierPath {
    func p(_ nx: CGFloat, _ ny: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + nx * rect.width, y: rect.minY + ny * rect.height) }
    func r(_ n: CGFloat) -> CGFloat { n * rect.width }
    let path = NSBezierPath()
    path.append(NSBezierPath(roundedRect: NSRect(x: p(0.05, 0.10).x, y: p(0, 0.10).y,
        width: r(0.90), height: r(0.36)), xRadius: r(0.17), yRadius: r(0.17)))
    func circle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat) {
        let c = p(cx, cy)
        path.append(NSBezierPath(ovalIn: NSRect(x: c.x - r(rad), y: c.y - r(rad),
            width: r(rad) * 2, height: r(rad) * 2))) }
    circle(0.29, 0.50, 0.23); circle(0.52, 0.58, 0.32); circle(0.75, 0.50, 0.23)
    path.windingRule = .nonZero
    return path
}

// Render one icon at `size`px as black+alpha template: opaque black cloud, label knocked out to alpha 0.
func renderIcon(size: Int, label: String?) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.shouldAntialias = true
    NSColor.black.setFill()
    cloudPath(in: NSRect(x: 0, y: 0, width: s, height: s)).fill()
    if let label = label, !label.isEmpty {
        ctx.compositingOperation = .destinationOut   // erase label region -> alpha 0
        let fs = s * (label.count >= 2 ? 0.34 : 0.50)
        let font = NSFont.systemFont(ofSize: fs, weight: .heavy)
        let str = NSAttributedString(string: label,
            attributes: [.font: font, .foregroundColor: NSColor.black])
        let sz = str.size()
        str.draw(at: NSPoint(x: s / 2 - sz.width / 2, y: s / 2 - sz.height / 2 - s * 0.03))
        ctx.compositingOperation = .sourceOver
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func alphaStats(_ rep: NSBitmapImageRep) -> (opaque: Int, transparent: Int) {
    var opaque = 0, transparent = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            let a = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
            if a > 0.5 { opaque += 1 } else { transparent += 1 }
        }
    }
    return (opaque, transparent)
}

// arg 1 (optional): path to Assets.xcassets (default assumes run from repo root)
let assetsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "OSX/Assets.xcassets"

let icons: [(String, String?)] = [
    ("eng", nil), ("han", "안"), ("han2", "2"), ("han3", "3"),
    ("han390", "9"), ("han3final", "F"), ("hanroman", "R"), ("qwerty", "Q"),
]

for (name, label) in icons {
    for (suffix, size) in [("", 16), ("@2x", 32)] {
        let rep = renderIcon(size: size, label: label)
        guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png fail") }
        let path = "\(assetsDir)/\(name).imageset/\(name)\(suffix).png"
        try! data.write(to: URL(fileURLWithPath: path))
        let st = alphaStats(rep)
        print("wrote \(path)  opaque=\(st.opaque) transparent=\(st.transparent)")
    }
}
print("done: \(icons.count) imagesets x 2 scales = \(icons.count * 2) png")
