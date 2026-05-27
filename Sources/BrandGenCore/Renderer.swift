import AppKit
import CoreGraphics

/// Closure that draws a glyph into `rect` using `ctx`.
/// For launch logos: use `.clear` blend mode for cutouts so the background shows through.
/// For app icons: fill cutouts with the background color (canvas is already opaque).
public typealias GlyphDrawer = (CGRect, CGContext) -> Void

// MARK: - Render functions

/// Renders a square, fully-opaque AppIcon PNG.
/// `background` fills the entire square — must be opaque (App Store rejects alpha).
/// `glyphDrawer` draws the glyph over the background.
public func render(size: CGFloat, background: NSColor, glyphDrawer: GlyphDrawer) -> Data {
    let rep = makeBitmapRep(width: Int(size), height: Int(size))
    withContext(rep) { cg in
        let full = CGRect(x: 0, y: 0, width: size, height: size)
        cg.clear(full)
        cg.setFillColor(background.cgColor)
        cg.fill(full)
        glyphDrawer(full, cg)
    }
    return png(rep)
}

/// Renders a non-square launch logo PNG on a **transparent** canvas.
/// Layout: circular icon (top) + app name text (bottom).
/// LaunchBackground colorset supplies the background color at runtime — do not bake it here.
/// `glyphDrawer` should use `.clear` blend mode for any cutouts so the bg color shows through holes.
public func renderLaunchLogo(
    circleSize: CGFloat,
    appName: String,
    glyphColor: NSColor = .white,
    glyphDrawer: GlyphDrawer
) -> Data {
    let fontSize: CGFloat = circleSize * 0.22
    let gap: CGFloat      = circleSize * 0.09   // between circle bottom and text top
    let textPad: CGFloat  = circleSize * 0.06   // padding below text baseline

    let font  = NSFont.boldSystemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: glyphColor]
    let attrStr  = NSAttributedString(string: appName, attributes: attrs)
    let textSize = attrStr.size()

    let canvasW = max(circleSize, ceil(textSize.width) + circleSize * 0.10)
    let canvasH = circleSize + gap + ceil(textSize.height) + textPad

    let rep = makeBitmapRep(width: Int(canvasW), height: Int(canvasH))
    withContext(rep) { cg in
        cg.clear(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))

        // Icon rect: top of canvas. CG y=0 is bottom, so high y = top.
        let iconX    = (canvasW - circleSize) / 2
        let iconY    = ceil(textSize.height) + gap + textPad
        let iconRect = CGRect(x: iconX, y: iconY, width: circleSize, height: circleSize)

        glyphDrawer(iconRect, cg)

        // Text: bottom of canvas, centered. NSBitmapImageRep is unflipped (y=0 at bottom).
        let textX = (canvasW - textSize.width) / 2
        attrStr.draw(at: NSPoint(x: textX, y: textPad))
    }
    return png(rep)
}

// MARK: - PDF glyph drawer

/// Returns a `GlyphDrawer` that loads a PDF and renders it centered in the glyph rect.
///
/// - Parameters:
///   - url: Path to a PDF (or any format `NSImage` supports).
///   - tint: If provided, the image is tinted to this color via a separate bitmap so that
///     transparent areas (e.g. eye holes in a skull) remain transparent on both the launch logo
///     and the app icon background.
///   - scale: Fraction of the bounding rect to fill (default 0.70 gives comfortable padding).
public func pdfGlyphDrawer(url: URL, tint: NSColor? = nil, scale: CGFloat = 0.70) -> GlyphDrawer {
    return { rect, ctx in
        guard let image = NSImage(contentsOf: url) else {
            print("warning: could not load glyph at \(url.path)")
            return
        }
        let imgSize = image.size
        let s       = min(rect.width / imgSize.width, rect.height / imgSize.height) * scale
        let drawW   = imgSize.width  * s
        let drawH   = imgSize.height * s
        let drawRect = CGRect(
            x: rect.midX - drawW / 2,
            y: rect.midY - drawH / 2,
            width: drawW,
            height: drawH
        )

        if let tint = tint {
            // Render the PDF into a scratch bitmap, tint it with sourceAtop (preserves
            // transparent holes), then composite the tinted result onto the main canvas.
            let w   = Int(ceil(drawW))
            let h   = Int(ceil(drawH))
            let tmp = makeBitmapRep(width: w, height: h)
            withContext(tmp) { tmpCG in
                tmpCG.clear(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
                image.draw(in: CGRect(x: 0, y: 0, width: drawW, height: drawH))
                // sourceAtop: tint color × dest alpha — fills opaque glyph pixels, leaves
                // transparent holes at alpha=0 so they stay transparent.
                tmpCG.setBlendMode(.sourceAtop)
                tmpCG.setFillColor(tint.cgColor)
                tmpCG.fill(CGRect(x: 0, y: 0, width: drawW, height: drawH))
            }
            if let cgImg = tmp.cgImage {
                let tinted = NSImage(cgImage: cgImg, size: NSSize(width: drawW, height: drawH))
                tinted.draw(in: drawRect)
            }
        } else {
            image.draw(in: drawRect)
        }
    }
}

// MARK: - Write helper

public func write(_ data: Data, to dir: URL, name: String) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

// MARK: - Internal helpers

func makeBitmapRep(width: Int, height: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func withContext(_ rep: NSBitmapImageRep, body: (CGContext) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    body(gctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
}

func png(_ rep: NSBitmapImageRep) -> Data {
    rep.representation(using: .png, properties: [:])!
}
