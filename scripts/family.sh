#!/bin/zsh
# Regenerates the app icon + launch screen for the sphericalwave blue app family.
#
#   scripts/family.sh            # every app below
#   scripts/family.sh MFR suit   # just these
#
# Shared layers live in Brand/family/ (background.pdf, launch-background.pdf, ve.pdf);
# per-app glyphs in Brand/glyphs/. Each run overwrites the app's AppIcon, LaunchLogo,
# LaunchGradient, AccentColor and LaunchBackground assets plus its LaunchScreen.storyboard.
# The app target must point at the storyboard (INFOPLIST_KEY_UILaunchStoryboardName =
# LaunchScreen, INFOPLIST_KEY_UILaunchScreen_Generation = NO, no UILaunchScreen dict).
set -euo pipefail

REPO=${0:A:h:h}
BRAND=${BRAND_DIR:-$REPO/Brand}
APPS_ROOT=${APPS_ROOT:-$HOME/Documents/apps}

# app -> "<Assets.xcassets path relative to APPS_ROOT>|<glyph>"
# glyph: sf:<SF Symbol name>, or a file name in Brand/glyphs/
typeset -A APPS=(
  MFR "fitness/MFR/MFR/Assets.xcassets|sf:figure.rolling"
)

swift build -c release --package-path $REPO >/dev/null
GEN=$REPO/.build/release/brand-gen

for app in ${@:-${(ko)APPS}}; do
  entry=${APPS[$app]:-}
  [[ -n $entry ]] || { print -u2 "unknown app: $app"; exit 1 }
  assets=$APPS_ROOT/${entry%%|*}
  glyph=${entry#*|}
  if [[ $glyph == sf:* ]]; then
    glyphArgs=(--sf-symbol ${glyph#sf:})
  else
    glyphArgs=(--glyph-pdf $BRAND/glyphs/$glyph)
  fi

  # The generator owns these folders; clear old PNGs so renamed files don't linger.
  rm -f $assets/AppIcon.appiconset/*.png $assets/LaunchLogo.imageset/*.png

  $GEN --name $app --brand-color 1E5BBA $glyphArgs \
    --background-pdf $BRAND/family/background.pdf \
    --launch-background-pdf $BRAND/family/launch-background.pdf \
    --overlay-pdf $BRAND/family/ve.pdf --overlay-scale 0.94 --overlay-opacity 0.4 \
    --shadow --no-launch-name --launch-size 300 \
    --output $assets >/dev/null

  cp $REPO/templates/LaunchScreen.storyboard ${assets:h}/LaunchScreen.storyboard
  print "✓ $app → ${assets:h}"
done
