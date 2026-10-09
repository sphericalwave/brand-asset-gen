import AppKit
import CoreGraphics

/// A BJJ belt rank: belt colour, the colour of the rank bar near the tip, and the stripe tape
/// colour on that bar. Hexes are IBJJF-ish (no official values exist).
public struct Belt {
    public let name: String
    public let color: NSColor
    public let bar: NSColor
    public let stripe: NSColor
    /// Contrast outline drawn around the belt glyph so it separates from the family-blue background.
    public let keyline: NSColor

    public static let white  = Belt(name: "white",  color: hex(0xF4F1EA), bar: hex(0x161616), stripe: hex(0xF4F1EA), keyline: hex(0x0E2F66))
    public static let blue   = Belt(name: "blue",   color: hex(0x1A3FA8), bar: hex(0x161616), stripe: hex(0xF4F1EA), keyline: hex(0xFFFFFF))
    public static let purple = Belt(name: "purple", color: hex(0x6B2D8F), bar: hex(0x161616), stripe: hex(0xF4F1EA), keyline: hex(0xFFFFFF))
    public static let brown  = Belt(name: "brown",  color: hex(0x6B3E1F), bar: hex(0x161616), stripe: hex(0xF4F1EA), keyline: hex(0xFFFFFF))
    public static let black  = Belt(name: "black",  color: hex(0x161616), bar: hex(0xC8102E), stripe: hex(0xF4F1EA), keyline: hex(0xFFFFFF))
    public static let red    = Belt(name: "red",    color: hex(0xC8102E), bar: hex(0xF4F1EA), stripe: hex(0x161616), keyline: hex(0xFFFFFF))

    public static let all: [Belt] = [white, blue, purple, brown, black, red]
    public static func named(_ name: String) -> Belt? { all.first { $0.name == name.lowercased() } }

    private static func hex(_ v: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

/// Draws a belt glyph PDF (white-on-transparent, like Brand/glyphs/jiujitsu.pdf) in `belt`'s colour.
/// The largest enclosed hole in the glyph is treated as the rank bar: it's filled with the bar
/// colour and gets `stripes` stripes, laid from the end nearest the belt tip. A `keyline` outline
/// (fraction of the rect width; 0 = none) separates the belt from the background.
public func beltGlyphDrawer(url: URL, belt: Belt, stripes: Int = 0, scale: CGFloat = 0.70, keyline: CGFloat = 0.010) -> GlyphDrawer {
    return { rect, ctx in
        guard let image = NSImage(contentsOf: url) else {
            print("warning: could not load glyph at \(url.path)")
            return
        }
        let s = min(rect.width / image.size.width, rect.height / image.size.height) * scale
        let w = Int(ceil(image.size.width * s)), h = Int(ceil(image.size.height * s))
        guard w > 0, h > 0 else { return }
        let size = CGRect(x: 0, y: 0, width: w, height: h)

        // Glyph alpha, to find the bar hole.
        let raw = makeBitmapRep(width: w, height: h)
        withContext(raw) { _ in image.draw(in: size) }
        let bar = largestHole(in: raw)

        // Belt = bar fill + stripes underneath, belt-coloured glyph on top (its AA edge blends over the bar).
        let tintedGlyph = tinted(image, size: size, color: belt.color)
        let composite = makeBitmapRep(width: w, height: h)
        withContext(composite) { c in
            if let bar {
                c.saveGState()
                c.clip(to: size, mask: bar.mask)
                c.setFillColor(belt.bar.cgColor)
                c.fill(size)
                c.setFillColor(belt.stripe.cgColor)
                for quad in bar.stripeQuads(count: stripes, height: CGFloat(h)) {
                    c.addLines(between: quad)
                    c.closePath()
                }
                c.fillPath()
                c.restoreGState()
            }
            if let g = tintedGlyph { c.draw(g, in: size) }
        }
        guard let beltImage = composite.cgImage else { return }

        let drawRect = CGRect(x: rect.midX - CGFloat(w) / 2, y: rect.midY - CGFloat(h) / 2, width: CGFloat(w), height: CGFloat(h))
        if keyline > 0, let outline = tinted(NSImage(cgImage: beltImage, size: size.size), size: size, color: belt.keyline) {
            let r = rect.width * keyline
            for i in 0..<24 {
                let a = CGFloat(i) / 24 * 2 * .pi
                ctx.draw(outline, in: drawRect.offsetBy(dx: cos(a) * r, dy: sin(a) * r))
            }
        }
        ctx.draw(beltImage, in: drawRect)
    }
}

// MARK: - Bar detection

struct BarHole {
    let mask: CGImage        // white where the bar is, image-space
    let centroid: CGPoint    // pixel coords, row 0 = top
    let axis: CGVector       // unit vector along the belt, pointing from the tip toward the knot
    let length: CGFloat
    let width: CGFloat

    /// Stripe quads in CG (y-up) coordinates.
    func stripeQuads(count: Int, height: CGFloat) -> [[CGPoint]] {
        guard count > 0 else { return [] }
        let stripeW = length * 0.11, gap = length * 0.075, start = length * 0.13
        let n = CGVector(dx: -axis.dy, dy: axis.dx)
        let tip = CGPoint(x: centroid.x - axis.dx * length / 2, y: centroid.y - axis.dy * length / 2)
        return (0..<min(count, 4)).map { i in
            let t0 = start + CGFloat(i) * (stripeW + gap), t1 = t0 + stripeW
            let half = width   // overshoot; the bar mask clips it
            return [(t0, -half), (t1, -half), (t1, half), (t0, half)].map { t, u in
                let p = CGPoint(x: tip.x + axis.dx * t + n.dx * u, y: tip.y + axis.dy * t + n.dy * u)
                return CGPoint(x: p.x, y: height - p.y)
            }
        }
    }
}

/// Finds the largest region of not-fully-opaque pixels not connected to the image border.
func largestHole(in rep: NSBitmapImageRep) -> BarHole? {
    let w = rep.pixelsWide, h = rep.pixelsHigh
    guard let data = rep.bitmapData else { return nil }
    let bpr = rep.bytesPerRow, spp = rep.samplesPerPixel
    var open = [Bool](repeating: false, count: w * h)
    for y in 0..<h { for x in 0..<w { open[y * w + x] = data[y * bpr + x * spp + 3] < 250 } }

    var label = [Int32](repeating: 0, count: w * h)   // -1 = outside, >0 = hole id
    var stack: [Int] = []
    func flood(_ seed: Int, _ id: Int32) -> [Int] {
        var members: [Int] = []
        stack = [seed]; label[seed] = id
        while let i = stack.popLast() {
            members.append(i)
            let x = i % w, y = i / w
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && ny >= 0 && nx < w && ny < h {
                let j = ny * w + nx
                if open[j] && label[j] == 0 { label[j] = id; stack.append(j) }
            }
        }
        return members
    }
    for x in 0..<w { for y in [0, h - 1] where open[y * w + x] && label[y * w + x] == 0 { _ = flood(y * w + x, -1) } }
    for y in 0..<h { for x in [0, w - 1] where open[y * w + x] && label[y * w + x] == 0 { _ = flood(y * w + x, -1) } }

    var best: [Int] = []
    var id: Int32 = 1
    for i in 0..<(w * h) where open[i] && label[i] == 0 {
        let m = flood(i, id); id += 1
        if m.count > best.count { best = m }
    }
    guard best.count >= 12 else { return nil }

    // PCA for the bar's long axis.
    let n = CGFloat(best.count)
    var mx: CGFloat = 0, my: CGFloat = 0
    for i in best { mx += CGFloat(i % w); my += CGFloat(i / w) }
    mx /= n; my /= n
    var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
    for i in best { let dx = CGFloat(i % w) - mx, dy = CGFloat(i / w) - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy }
    let theta = 0.5 * atan2(2 * sxy, sxx - syy)
    var axis = CGVector(dx: cos(theta), dy: sin(theta))
    // Point the axis away from the tip: the tip end is the one farther from the glyph centre.
    let toCentre = CGVector(dx: CGFloat(w) / 2 - mx, dy: CGFloat(h) / 2 - my)
    if axis.dx * toCentre.dx + axis.dy * toCentre.dy < 0 { axis = CGVector(dx: -axis.dx, dy: -axis.dy) }
    var lo = CGFloat.greatestFiniteMagnitude, hi = -lo, wlo = lo, whi = -lo
    for i in best {
        let dx = CGFloat(i % w) - mx, dy = CGFloat(i / w) - my
        let t = dx * axis.dx + dy * axis.dy, u = -dx * axis.dy + dy * axis.dx
        lo = min(lo, t); hi = max(hi, t); wlo = min(wlo, u); whi = max(whi, u)
    }
    let centre = CGPoint(x: mx + axis.dx * (lo + hi) / 2, y: my + axis.dy * (lo + hi) / 2)

    // Mask, dilated 1px so the bar runs under the glyph's anti-aliased edge.
    var bytes = [UInt8](repeating: 0, count: w * h)
    for i in best {
        let x = i % w, y = i / w
        for yy in max(0, y - 1)...min(h - 1, y + 1) { for xx in max(0, x - 1)...min(w - 1, x + 1) { bytes[yy * w + xx] = 255 } }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let mask = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return BarHole(mask: mask, centroid: centre, axis: axis, length: hi - lo, width: whi - wlo)
}

/// `image` recoloured to a flat `color`, keeping its alpha.
private func tinted(_ image: NSImage, size: CGRect, color: NSColor) -> CGImage? {
    let rep = makeBitmapRep(width: Int(size.width), height: Int(size.height))
    withContext(rep) { c in
        image.draw(in: size)
        c.setBlendMode(.sourceAtop)
        c.setFillColor(color.cgColor)
        c.fill(size)
    }
    return rep.cgImage
}
