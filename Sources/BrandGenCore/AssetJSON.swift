import Foundation

// MARK: - Contents.json templates

/// `AppIcon.appiconset/Contents.json` — iOS-only, single 1024 universal entry.
public let appIconContentsJSON = """
{
  "images": [
    { "filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
"""

/// `LaunchLogo.imageset/Contents.json`
public let launchLogoContentsJSON = """
{
  "images": [
    { "filename": "LaunchLogo.png",    "idiom": "universal", "scale": "1x" },
    { "filename": "LaunchLogo@2x.png", "idiom": "universal", "scale": "2x" },
    { "filename": "LaunchLogo@3x.png", "idiom": "universal", "scale": "3x" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
"""

// MARK: - Colorset JSON

/// Generates `Contents.json` for a colorset.
/// - Parameters:
///   - lightHex: Brand color hex, e.g. `"2A0A3D"` (no `#`). Used for light mode and the app icon.
///   - darkHex: Optional dark-mode variant. Defaults to `lightHex` (same color both modes).
///     Pass a lighter shade for better readability on dark backgrounds.
public func colorsetJSON(lightHex: String, darkHex: String? = nil) -> String {
    func comps(_ raw: String) -> String {
        let h = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        let r = String(h.prefix(2)).uppercased()
        let g = String(h.dropFirst(2).prefix(2)).uppercased()
        let b = String(h.dropFirst(4).prefix(2)).uppercased()
        return #""alpha": "1.000", "red": "0x\#(r)", "green": "0x\#(g)", "blue": "0x\#(b)""#
    }

    let lightEntry = """
    {
      "color": { "color-space": "srgb", "components": { \(comps(lightHex)) } },
      "idiom": "universal"
    }
"""
    guard let dark = darkHex, dark.lowercased() != lightHex.lowercased() else {
        return "{\n  \"colors\": [\n\(lightEntry)\n  ],\n  \"info\": { \"author\": \"xcode\", \"version\": 1 }\n}"
    }

    let darkEntry = """
    {
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "color": { "color-space": "srgb", "components": { \(comps(dark)) } },
      "idiom": "universal"
    }
"""
    return "{\n  \"colors\": [\n\(lightEntry),\n\(darkEntry)\n  ],\n  \"info\": { \"author\": \"xcode\", \"version\": 1 }\n}"
}
