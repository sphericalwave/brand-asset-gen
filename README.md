# brand-asset-gen

Swift Package that generates iOS app icon + launch screen assets from a PDF glyph and brand color.

Produces:
- `AppIcon.appiconset/` — 1024×1024 PNG + Contents.json
- `LaunchLogo.imageset/` — 1x/2x/3x transparent PNGs + Contents.json
- `AccentColor.colorset/` — light + dark mode
- `LaunchBackground.colorset/` — matches brand color (transparent launch logo composites over this)

No design tools. Regenerate in one command.

---

## Usage

### CLI tool

```sh
# Build once
swift build -c release --package-path /path/to/brand-asset-gen
cp .build/release/brand-gen /usr/local/bin/brand-gen   # optional: install to PATH

# Run from your project root
brand-gen \
  --name MyApp \
  --brand-color 2A0A3D \
  --dark-color 9B5CDB \
  --glyph-pdf Assets/icon.pdf \
  --glyph-color FFFFFF \
  --output MyApp/Assets.xcassets
```

Or run without installing:

```sh
swift run --package-path /path/to/brand-asset-gen brand-gen \
  --name MyApp --brand-color 2A0A3D --glyph-pdf icon.pdf \
  --output MyApp/Assets.xcassets
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name` | ✓ | — | App name shown below the icon on the splash |
| `--brand-color` | ✓ | — | Brand hex (no `#`). Used for AppIcon bg + LaunchBackground |
| `--dark-color` | | brand-color | Lighter accent tint for dark mode |
| `--glyph-pdf` | | — | PDF for icon glyph. Omit to generate JSON only |
| `--glyph-color` | | `FFFFFF` | Tint applied to the PDF glyph |
| `--output` | | `./Assets.xcassets` | Output Assets.xcassets directory |

### Library (hand-drawn glyph)

Add as a local package dependency and use `BrandGenCore` directly when you draw your glyph with CoreGraphics:

```swift
// generate_icons.swift
import BrandGenCore

let brandFill = NSColor(srgbRed: 0x2A/255, green: 0x0A/255, blue: 0x3D/255, alpha: 1)

func myGlyph(clearCutouts: Bool) -> GlyphDrawer {
    return { rect, ctx in
        ctx.setFillColor(NSColor.white.cgColor)
        // ... draw shape ...
        if clearCutouts { ctx.setBlendMode(.clear) } else { ctx.setFillColor(brandFill.cgColor) }
        // ... draw cutouts ...
    }
}

write(render(size: 1024, background: brandFill, glyphDrawer: myGlyph(clearCutouts: false)),
      to: appIconDir, name: "icon-1024.png")
write(renderLaunchLogo(circleSize: 170, appName: "MyApp", glyphDrawer: myGlyph(clearCutouts: true)),
      to: launchDir, name: "LaunchLogo.png")
```

---

## Info.plist

Wire the assets in `Info.plist` (no storyboard needed):

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchBackground</string>
    <key>UIImageName</key>
    <string>LaunchLogo</string>
    <key>UIImageRespectsSafeAreaInsets</key>
    <true/>
</dict>
```

If your target has `INFOPLIST_KEY_UILaunchScreen_Generation = YES`, disable it for the iOS SDKs so the explicit dict wins:

```
"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]" = NO;
"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = NO;
```

---

## Design notes

- **LaunchLogo is transparent** — the PNG has no background fill. `LaunchBackground` colorset fills the screen at runtime. This keeps the logo background-agnostic and prevents color seams.
- **`brandFill` == `LaunchBackground`** — the CLI sets them to the same hex. App icon background and splash background always match.
- **PDF tinting** — the PDF is rendered into a scratch bitmap, tinted via `sourceAtop` (preserves transparent holes), then composited. Transparent areas in the PDF (e.g. eye sockets) remain transparent on both the launch logo and over the app icon background.
