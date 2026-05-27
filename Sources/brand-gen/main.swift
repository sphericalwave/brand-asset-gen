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

  --dark-color  <RRGGBB>   dark-mode accent tint (default: same as brand-color)
  --glyph-pdf   <path>     PDF for the icon glyph; omit to skip PNG generation
  --glyph-color <RRGGBB>   tint applied to PDF glyph (default: FFFFFF)
  --output      <path>     output Assets.xcassets dir (default: ./Assets.xcassets)

examples:
  brand-gen --name MyApp --brand-color 2A0A3D --dark-color 9B5CDB --glyph-pdf icon.pdf
  brand-gen --name MyApp --brand-color 1A3C5E --output ./MyApp/Assets.xcassets
""")
    exit(1)
}

let darkHex    = arg("--dark-color") ?? brandHex
let glyphPDF   = arg("--glyph-pdf").map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) }
let glyphHex   = arg("--glyph-color") ?? "FFFFFF"
let outputPath = arg("--output") ?? "./Assets.xcassets"

let outputURL  = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let appIconDir = outputURL.appendingPathComponent("AppIcon.appiconset")
let launchDir  = outputURL.appendingPathComponent("LaunchLogo.imageset")
let accentDir  = outputURL.appendingPathComponent("AccentColor.colorset")
let bgDir      = outputURL.appendingPathComponent("LaunchBackground.colorset")

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

if let pdfURL = glyphPDF {
    let brandColor = hexColor(brandHex)
    let glyphColor = hexColor(glyphHex)
    let drawer     = pdfGlyphDrawer(url: pdfURL, tint: glyphColor)

    write(render(size: 1024, background: brandColor, glyphDrawer: drawer),
          to: appIconDir, name: "icon-1024.png")
    write(renderLaunchLogo(circleSize: 170, appName: appName, glyphColor: glyphColor, glyphDrawer: drawer),
          to: launchDir, name: "LaunchLogo.png")
    write(renderLaunchLogo(circleSize: 340, appName: appName, glyphColor: glyphColor, glyphDrawer: drawer),
          to: launchDir, name: "LaunchLogo@2x.png")
    write(renderLaunchLogo(circleSize: 512, appName: appName, glyphColor: glyphColor, glyphDrawer: drawer),
          to: launchDir, name: "LaunchLogo@3x.png")
} else {
    print("note: --glyph-pdf not supplied; skipping PNG generation. Add icon PNGs manually.")
}

print("\ndone — \(outputURL.standardizedFileURL.path)")
