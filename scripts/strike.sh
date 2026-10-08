#!/bin/zsh
# Regenerates strike's app icon + launch assets (red, not the blue family).
#
#   scripts/strike.sh
#
# Layers live in Brand/strike/ (glyph.pdf, ve.pdf, background.pdf), drawn by the strike repo's
# icons/strike-layers.swift. strike launches from the UILaunchScreen dict in its project.yml
# (LaunchBackground + LaunchLogo), so no storyboard, LaunchGradient or wire_launch.py here.
set -euo pipefail

REPO=${0:A:h:h}
BRAND=${BRAND_DIR:-$REPO/Brand}
APPS_ROOT=${APPS_ROOT:-$HOME/Documents/apps}
assets=${STRIKE_ASSETS:-$APPS_ROOT/jits/strike/Resources/Assets.xcassets}

swift build -c release --package-path $REPO >/dev/null

# The generator owns these folders; clear old PNGs so renamed files don't linger.
rm -f $assets/AppIcon.appiconset/*.png(N) $assets/LaunchLogo.imageset/*.png(N)

$REPO/.build/release/brand-gen --name strike --brand-color C62828 --dark-color EF5454 \
  --glyph-pdf $BRAND/strike/glyph.pdf --glyph-scale 0.58 \
  --background-pdf $BRAND/strike/background.pdf \
  --overlay-pdf $BRAND/strike/ve.pdf --overlay-scale 0.82 --overlay-opacity 0.3 \
  --no-launch-name --launch-size 300 --no-launch-gradient \
  --output $assets >/dev/null

print "✓ strike → ${assets:h}"
