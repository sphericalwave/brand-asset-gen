# brand-asset-gen

Generates iOS app icon + launch screen assets from a brand color and a PDF glyph.
One command. No design tools.

**Outputs:**
| Asset | What it is |
|-------|------------|
| `AppIcon.appiconset/icon-{16,32,64,128,256,512,1024}.png` | App icon at every required size (opaque, brand-color bg or gradient) |
| `LaunchLogo.imageset/LaunchLogo@{1,2,3}x.png` | Transparent splash logo (icon + app name) |
| `AccentColor.colorset/Contents.json` | Tint color, light + dark mode |
| `LaunchBackground.colorset/Contents.json` | Splash background (matches brand color) |

---

## Quick start

```sh
# Run directly from the package (no install needed)
swift run --package-path ~/Documents/apps/brand-asset-gen brand-gen \
  --name MyApp \
  --brand-color 2A0A3D \
  --dark-color  9B5CDB \
  --glyph-pdf   Assets/icon.pdf \
  --output      MyApp/Assets.xcassets
```

Or build once and install:

```sh
cd ~/Documents/apps/brand-asset-gen
swift build -c release
cp .build/release/brand-gen /usr/local/bin/brand-gen

# Then from any project root:
brand-gen --name MyApp --brand-color 2A0A3D --glyph-pdf Assets/icon.pdf \
          --output MyApp/Assets.xcassets
```

### Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--name` | ✓ | — | App name text shown below the icon on the splash screen |
| `--brand-color` | ✓ | — | Brand hex, no `#` (e.g. `2A0A3D`). Sets AppIcon bg + LaunchBackground |
| `--dark-color` | | brand-color | Lighter tint for dark mode AccentColor |
| `--brand-color2` | | — | Second hex. When set, the AppIcon background becomes a top→bottom gradient brand-color → brand-color2 (LaunchBackground stays flat brand-color) |
| `--glyph-pdf` | | — | Path to PDF for the icon glyph. Omit (with `--sf-symbol` also omitted) to write JSON files only |
| `--sf-symbol` | | — | SF Symbol name to use as the icon glyph instead of `--glyph-pdf`. If both are supplied, `--sf-symbol` wins |
| `--glyph-color` | | `FFFFFF` | Tint applied to the glyph |
| `--output` | | `./Assets.xcassets` | Path to your app's `Assets.xcassets` directory |
| `--belt` | | — | Belt rank (`white`/`blue`/`purple`/`brown`/`black`/`red`): colours a belt glyph PDF as that rank on the icon + launch logo. The glyph's largest enclosed hole becomes the rank bar |
| `--launch-belt` | | `--belt` | Belt rank for the launch logo only (primary icon unchanged) |
| `--launch-stripes` | | `0` | Stripes (0–4) on the launch logo's rank bar. Icons never show stripes |
| `--belt-alternate-icons` | | — | Also writes `AppIcon-<rank>.appiconset` (iOS alternate icon, 1024 only) for every rank. List them in the target's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` and switch with `UIApplication.setAlternateIconName("AppIcon-<rank>")` |

Belt colours (sRGB): white `F4F1EA`, blue `1A3FA8`, purple `6B2D8F`, brown `6B3E1F`, black `161616`, red `C8102E`.
Bar: black `161616` (white/blue/purple/brown), red `C8102E` (black), white `F4F1EA` (red). Stripe tape `F4F1EA`, black on the red belt's white bar.

---

## New project setup

### 1. Create the asset catalog folders

Inside your app's `Assets.xcassets`, create these four folders (Xcode: *New Folder* → rename):

```
Assets.xcassets/
  AppIcon.appiconset/
  LaunchLogo.imageset/
  AccentColor.colorset/
  LaunchBackground.colorset/
```

The tool writes `Contents.json` into each folder and the PNGs into `AppIcon.appiconset/` and `LaunchLogo.imageset/`.

### 2. Run the generator

```sh
brand-gen \
  --name MyApp \
  --brand-color 1A3C5E \
  --dark-color  6BA3F5 \
  --glyph-pdf   Assets/icon.pdf \
  --output      MyApp/Assets.xcassets
```

### 3. Wire up the splash screen in `Info.plist`

Add this dict (no `LaunchScreen.storyboard` needed):

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

If your Xcode target has `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (SwiftUI templates
do this), turn it off for the iOS SDKs so the explicit dict above wins:

```
"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]"     = NO;
"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = NO;
```

### 4. Apply the accent color

In your root SwiftUI view:

```swift
.tint(.accentColor)   // picks up AccentColor.colorset automatically
```

### 5. Clean build folder

```
Cmd+Shift+K
```

iOS aggressively caches the launch screen snapshot. A clean build is required after
changing any splash assets or the `Info.plist` dict.

---

## Regenerating assets

Re-run the same `brand-gen` command from your project root whenever you change the
color or glyph. The tool overwrites all four asset folders in place.

---

## Using the library (hand-drawn glyph)

If your glyph is drawn in CoreGraphics rather than a PDF, add `BrandGenCore` as a
local package dependency and call the render functions directly from a standalone
script in your project:

**`Package.swift` dependency:**
```swift
.package(path: "~/Documents/apps/brand-asset-gen")
// and in your target:
.product(name: "BrandGenCore", package: "brand-asset-gen")
```

**`Tools/generate_icons.swift`:**
```swift
import BrandGenCore

let appIconDir = projectRoot.appendingPathComponent("MyApp/Assets.xcassets/AppIcon.appiconset")
let launchDir  = projectRoot.appendingPathComponent("MyApp/Assets.xcassets/LaunchLogo.imageset")

let brandFill = NSColor(srgbRed: 0x1A/255, green: 0x3C/255, blue: 0x5E/255, alpha: 1)

// clearCutouts: false → fill holes with brandFill (AppIcon, bg is already brandFill)
// clearCutouts: true  → punch holes to alpha   (LaunchLogo, bg comes from LaunchBackground)
func myGlyph(clearCutouts: Bool) -> GlyphDrawer {
    return { rect, ctx in
        let s = rect.width
        ctx.setFillColor(NSColor.white.cgColor)
        // ... draw your shape ...

        if clearCutouts {
            ctx.setBlendMode(.clear)
            ctx.setFillColor(NSColor.white.cgColor)  // color ignored; .clear erases to alpha
        } else {
            ctx.setFillColor(brandFill.cgColor)
        }
        // ... draw cutouts ...
    }
}

write(render(size: 1024, background: brandFill, glyphDrawer: myGlyph(clearCutouts: false)),
      to: appIconDir, name: "icon-1024.png")
write(renderLaunchLogo(circleSize: 170, appName: "MyApp", glyphDrawer: myGlyph(clearCutouts: true)),
      to: launchDir, name: "LaunchLogo.png")
write(renderLaunchLogo(circleSize: 340, appName: "MyApp", glyphDrawer: myGlyph(clearCutouts: true)),
      to: launchDir, name: "LaunchLogo@2x.png")
write(renderLaunchLogo(circleSize: 512, appName: "MyApp", glyphDrawer: myGlyph(clearCutouts: true)),
      to: launchDir, name: "LaunchLogo@3x.png")
```

Run from project root: `swift Tools/generate_icons.swift`

---

## How the splash screen is composed

```
┌──────────────────────────────────┐
│         LaunchBackground         │  ← colorset, same hex as brand color
│                                  │
│    ┌────────────────────────┐    │
│    │  LaunchLogo (centered) │    │  ← transparent PNG; icon disc + app name text
│    └────────────────────────┘    │
│                                  │
└──────────────────────────────────┘
```

The launch logo PNG has **no background fill**. The `LaunchBackground` colorset fills
the entire screen, and the logo composites over it. This means:

- No color seams if the exact hex drifts between assets
- The same logo works on any background color
- Holes in the glyph (e.g. eye sockets) show the background through

---

## PDF glyph notes

- Provide a PDF with a **transparent background** and your glyph shape as the fill
- Any color works — `--glyph-color` tints it (default white)
- Transparent areas in the PDF (holes, cutouts) remain transparent after tinting and
  reveal the brand color bg in the app icon, and the LaunchBackground in the splash
- SVG won't work directly — export to PDF first (Figma, Sketch, Illustrator all support this)
