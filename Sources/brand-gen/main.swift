import Foundation
import AppKit
import BrandGenCore

// MARK: - Arg parsing

func arg(_ flag: String) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

guard let appName  = arg("--name"),
      let brandHex = arg("--brand-color") else {
    print("""
usage: brand-gen --name <AppName> --brand-color <RRGGBB> [options]

  --dark-color   <RRGGBB>  dark-mode accent tint (default: same as brand-color)
  --brand-color2 <RRGGBB>  second color; app icon bg becomes a top→bottom gradient
                           brand-color → brand-color2 (LaunchBackground stays flat brand-color)
  --glyph-pdf    <path>    PDF for the icon glyph; omit to skip PNG generation
  --sf-symbol    <name>    SF Symbol name for the icon glyph instead of --glyph-pdf
  --glyph-color  <RRGGBB>  tint applied to the glyph (default: FFFFFF)
  --output       <path>    output Assets.xcassets dir (default: ./Assets.xcassets)

  family style (sphericalwave blue suite):
  --background-pdf <path>  image aspect-filling the icon bg; also writes a LaunchGradient
                           imageset for a full-screen gradient launch screen
  --launch-background-pdf <path>  full-screen launch image (e.g. 1320x2868), rendered at its own
                           size; overrides the square LaunchGradient made from --background-pdf
  --overlay-pdf    <path>  shared layer between background and glyph (e.g. vector equilibrium)
  --overlay-opacity <0-1>  overlay opacity (default: 0.5)
  --overlay-scale  <0-1>   overlay size as a fraction of the icon (default: 0.86)
  --glyph-scale    <0-1>   glyph size as a fraction of the icon (default: 0.70 PDF, 0.60 SF Symbol)
  --shadow                 one soft drop shadow under overlay + glyph
  --launch-style   glyph|tile  launch logo is overlay + glyph only (default) or the full icon tile
  --no-launch-name         omit the app name under the launch logo
  --launch-size    <pt>    launch logo icon size in points (default: 170)
  --no-launch-gradient     skip the LaunchGradient imageset (apps whose UILaunchScreen plist
                           dict uses LaunchBackground + LaunchLogo, not a storyboard)

examples:
  brand-gen --name MyApp --brand-color 2A0A3D --dark-color 9B5CDB --glyph-pdf icon.pdf
  brand-gen --name MyApp --brand-color 1A3C5E --output ./MyApp/Assets.xcassets
  brand-gen --name MyApp --brand-color 0B4FA3 --brand-color2 2E86F5 --sf-symbol figure.gymnastics
""")
    exit(1)
}

let darkHex     = arg("--dark-color") ?? brandHex
let brandHex2   = arg("--brand-color2")
let glyphPDF    = arg("--glyph-pdf").map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) }
let sfSymbol    = arg("--sf-symbol")
let glyphHex    = arg("--glyph-color") ?? "FFFFFF"
let outputPath  = arg("--output") ?? "./Assets.xcassets"
let cwdURL         = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let backgroundPDF  = arg("--background-pdf").map { URL(fileURLWithPath: $0, relativeTo: cwdURL) }
let launchBackgroundPDF = arg("--launch-background-pdf").map { URL(fileURLWithPath: $0, relativeTo: cwdURL) }
let overlayPDF     = arg("--overlay-pdf").map { URL(fileURLWithPath: $0, relativeTo: cwdURL) }
let overlayOpacity = arg("--overlay-opacity").flatMap(Double.init).map { CGFloat($0) } ?? 0.5
let overlayScale   = arg("--overlay-scale").flatMap(Double.init).map { CGFloat($0) } ?? 0.86
let glyphScale     = arg("--glyph-scale").flatMap(Double.init).map { CGFloat($0) }
let shadow         = CommandLine.arguments.contains("--shadow")
let launchTile     = arg("--launch-style") == "tile"
let launchName     = CommandLine.arguments.contains("--no-launch-name") ? "" : appName
let launchSize     = arg("--launch-size").flatMap(Double.init).map { CGFloat($0) } ?? 170
let launchGradient = !CommandLine.arguments.contains("--no-launch-gradient")

let outputURL  = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let appIconDir = outputURL.appendingPathComponent("AppIcon.appiconset")
let launchDir  = outputURL.appendingPathComponent("LaunchLogo.imageset")
let accentDir  = outputURL.appendingPathComponent("AccentColor.colorset")
let bgDir      = outputURL.appendingPathComponent("LaunchBackground.colorset")
let gradientDir = outputURL.appendingPathComponent("LaunchGradient.imageset")

// MARK: - Helpers

func hexColor(_ hex: String) -> NSColor {
    let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let r = CGFloat(UInt8(h.prefix(2), radix: 16) ?? 0) / 255.0
    let g = CGFloat(UInt8(h.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
    let b = CGFloat(UInt8(h.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

func writeText(_ s: String, to dir: URL, name: String) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try! s.data(using: .utf8)!.write(to: dir.appendingPathComponent(name))
    print("wrote \(dir.appendingPathComponent(name).path)")
}

// MARK: - Asset JSON

// AccentColor: light + optional dark variant
writeText(colorsetJSON(lightHex: brandHex, darkHex: darkHex), to: accentDir, name: "Contents.json")
// LaunchBackground: always brand color (no dark variant — solid bg behind splash logo)
writeText(colorsetJSON(lightHex: brandHex), to: bgDir, name: "Contents.json")
// Contents.json stubs (PNGs written below if --glyph-pdf supplied)
writeText(appIconContentsJSON,    to: appIconDir, name: "Contents.json")
writeText(launchLogoContentsJSON, to: launchDir,  name: "Contents.json")

// MARK: - PNGs

if glyphPDF != nil, sfSymbol != nil {
    print("warning: both --glyph-pdf and --sf-symbol supplied; using --sf-symbol")
}

if glyphPDF != nil || sfSymbol != nil {
    let brandColor = hexColor(brandHex)
    let glyphColor = hexColor(glyphHex)
    let drawer: GlyphDrawer
    if let symbol = sfSymbol {
        drawer = sfSymbolGlyphDrawer(name: symbol, tint: glyphColor, scale: glyphScale ?? 0.60)
    } else {
        drawer = pdfGlyphDrawer(url: glyphPDF!, tint: glyphColor, scale: glyphScale ?? 0.70)
    }

    // Foreground = optional overlay under the glyph, optionally casting one shared shadow.
    var foreground = drawer
    if let overlay = overlayPDF {
        let overlayDrawer = faded(pdfGlyphDrawer(url: overlay, tint: glyphColor, scale: overlayScale), opacity: overlayOpacity)
        foreground = layered([overlayDrawer, drawer])
    }
    if shadow { foreground = shadowed(foreground) }

    let backgroundDrawer = backgroundPDF.map { imageFillDrawer(url: $0) }
    let iconDrawer = layered([backgroundDrawer, foreground].compactMap { $0 })
    // Tile launch logo: the whole icon as a rounded square, inset so its shadow isn't cropped.
    let launchDrawer: GlyphDrawer = launchTile
        ? { rect, ctx in shadowed(tiled(iconDrawer))(rect.insetBy(dx: rect.width * 0.06, dy: rect.width * 0.06), ctx) }
        : foreground

    for size in [16, 32, 64, 128, 256, 512, 1024] {
        let iconPNG: Data
        if backgroundDrawer != nil {
            iconPNG = render(size: CGFloat(size), background: brandColor, glyphDrawer: iconDrawer)
        } else if let hex2 = brandHex2 {
            iconPNG = render(size: CGFloat(size), backgroundGradient: (top: brandColor, bottom: hexColor(hex2)), glyphDrawer: drawer)
        } else {
            iconPNG = render(size: CGFloat(size), background: brandColor, glyphDrawer: drawer)
        }
        write(iconPNG, to: appIconDir, name: "icon-\(size).png")
    }
    write(renderLaunchLogo(circleSize: launchSize, appName: launchName, glyphColor: glyphColor, glyphDrawer: launchDrawer),
          to: launchDir, name: "LaunchLogo.png")
    write(renderLaunchLogo(circleSize: launchSize * 2, appName: launchName, glyphColor: glyphColor, glyphDrawer: launchDrawer),
          to: launchDir, name: "LaunchLogo@2x.png")
    write(renderLaunchLogo(circleSize: launchSize * 3, appName: launchName, glyphColor: glyphColor, glyphDrawer: launchDrawer),
          to: launchDir, name: "LaunchLogo@3x.png")

    // Launch screen image: a dedicated launch background at its own size, else the icon
    // background as a square. The launch storyboard aspect-fills it either way.
    if !launchGradient {
        // UILaunchScreen plist apps: LaunchBackground colorset + LaunchLogo only.
    } else if let launchBackground = launchBackgroundPDF, let image = NSImage(contentsOf: launchBackground) {
        writeText(launchGradientContentsJSON, to: gradientDir, name: "Contents.json")
        write(renderImage(width: image.size.width, height: image.size.height, drawer: imageFillDrawer(url: launchBackground)),
              to: gradientDir, name: "LaunchGradient.png")
    } else if let background = backgroundPDF {
        writeText(launchGradientContentsJSON, to: gradientDir, name: "Contents.json")
        write(renderImage(width: 1500, height: 1500, drawer: imageFillDrawer(url: background)), to: gradientDir, name: "LaunchGradient.png")
    }
} else {
    print("note: neither --glyph-pdf nor --sf-symbol supplied; skipping PNG generation. Add icon PNGs manually.")
}

print("\ndone — \(outputURL.standardizedFileURL.path)")
