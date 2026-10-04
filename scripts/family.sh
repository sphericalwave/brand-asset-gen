#!/bin/zsh
# Regenerates the app icon + launch screen for the sphericalwave blue app family.
#
#   scripts/family.sh            # every app below
#   scripts/family.sh MFR suit   # just these
#
# Shared layers live in Brand/family/ (background.pdf, launch-background.pdf, ve.pdf);
# per-app glyphs in Brand/glyphs/. Each run overwrites the app's AppIcon, LaunchLogo,
# LaunchGradient, AccentColor and LaunchBackground assets plus its LaunchScreen.storyboard,
# then runs wire_launch.py so the app target(s) launch from that storyboard.
set -euo pipefail

REPO=${0:A:h:h}
BRAND=${BRAND_DIR:-$REPO/Brand}
APPS_ROOT=${APPS_ROOT:-$HOME/Documents/apps}

# app -> "<Assets.xcassets path>|<glyph>|<.xcodeproj path>", paths relative to APPS_ROOT
# glyph: sf:<SF Symbol name>, or a file name in Brand/glyphs/
typeset -A APPS=(
  MFR          "fitness/MFR/MFR/Assets.xcassets|sf:figure.rolling|fitness/MFR/MFR.xcodeproj"
  alfred       "alfred/alfred/Assets.xcassets|sf:dog.fill|alfred/alfred.xcodeproj"
  backwardsMan "fitness/backwardsMan/backwardsMan/Assets.xcassets|sf:figure.walk|fitness/backwardsMan/backwardsMan.xcodeproj"
  bounce       "fitness/bounce/bounce/Assets.xcassets|sf:figure.step.training|fitness/bounce/bounce.xcodeproj"
  breathe      "fitness/breathe/breathe/Assets.xcassets|sf:lungs.fill|fitness/breathe/breathe.xcodeproj"
  clubs        "fitness/clubs/clubs/Assets.xcassets|clubs.pdf|fitness/clubs/clubs.xcodeproj"
  flow         "fitness/softwork/flow/Assets.xcassets|sf:bolt.heart.fill|fitness/softwork/flow.xcodeproj"
  fuel         "fitness/fitwrench/fitWrench/Assets/Assets.xcassets|sf:bolt.fill|fitness/fitwrench/fuel.xcodeproj"
  groundWerk   "fitness/groundwork/Groundwerk/Assets.xcassets|sf:figure.kickboxing|fitness/groundwork/Groundwerk.xcodeproj"
  kettlebell   "fitness/kettlebell/kettlebell/Assets.xcassets|kettlebell.pdf|fitness/kettlebell/kettlebell.xcodeproj"
  kundalini    "fitness/kundalini/kundalini/Assets.xcassets|kundalini.png|fitness/kundalini/kundalini.xcodeproj"
  mindMap      "mindMap/mindMap/Assets.xcassets|sf:point.3.connected.trianglepath.dotted|mindMap/mindMap.xcodeproj"
  pH           "fitness/pH/pH/Assets.xcassets|sf:drop.fill|fitness/pH/pH.xcodeproj"
  rings        "fitness/rings/rings/Assets.xcassets|sf:figure.gymnastics|fitness/rings/rings.xcodeproj"
  shodan       "jits/shodan/shodan/Assets.xcassets|jiujitsu.pdf|jits/shodan/shodan.xcodeproj"
  skullptor    "fitness/skullptor/skullptor/Assets.xcassets|skullptor.pdf|fitness/skullptor/skullptor.xcodeproj"
  sleep        "fitness/sleep/sleep/Assets.xcassets|sf:bed.double.fill|fitness/sleep/sleep.xcodeproj"
  splits       "fitness/splits/splits/Assets.xcassets|sf:figure.flexibility|fitness/splits/splits.xcodeproj"
  suit         "fitness/suit/suit/Assets.xcassets|sf:figure|fitness/suit/suit.xcodeproj"
  torque       "fitness/torque/torque/Assets.xcassets|sf:figure.strengthtraining.traditional|fitness/torque/torque.xcodeproj"
  wealth       "wealth/wealth/Assets.xcassets|sf:dollarsign|wealth/wealth.xcodeproj"
)

# Glyphs drawn on a full icon-sized page (positioned against the overlay themselves) render
# at 1.0 instead of the cropped-glyph default.
typeset -A GLYPH_SCALE=(
  shodan 1.0
)

swift build -c release --package-path $REPO >/dev/null
GEN=$REPO/.build/release/brand-gen

for app in ${@:-${(ko)APPS}}; do
  entry=${APPS[$app]:-}
  [[ -n $entry ]] || { print -u2 "unknown app: $app"; exit 1 }
  parts=(${(s:|:)entry})
  assets=$APPS_ROOT/${parts[1]}
  glyph=${parts[2]}
  project=$APPS_ROOT/${parts[3]}
  if [[ $glyph == sf:* ]]; then
    glyphArgs=(--sf-symbol ${glyph#sf:})
  else
    # Custom glyphs are cropped tight, so they need a smaller scale to match SF Symbols.
    glyphArgs=(--glyph-pdf $BRAND/glyphs/$glyph --glyph-scale ${GLYPH_SCALE[$app]:-0.56})
  fi

  # The generator owns these folders; clear old PNGs so renamed files don't linger.
  rm -f $assets/AppIcon.appiconset/*.png(N) $assets/LaunchLogo.imageset/*.png(N)

  $GEN --name $app --brand-color 1E5BBA $glyphArgs \
    --background-pdf $BRAND/family/background.pdf \
    --launch-background-pdf $BRAND/family/launch-background.pdf \
    --overlay-pdf $BRAND/family/ve.pdf --overlay-scale 0.94 --overlay-opacity 0.4 \
    --shadow --no-launch-name --launch-size 300 \
    --output $assets >/dev/null

  cp $REPO/templates/LaunchScreen.storyboard ${assets:h}/LaunchScreen.storyboard
  plists=(${assets:h}/Info.plist(N))
  python3 $REPO/scripts/wire_launch.py $project $plists >/dev/null
  print "✓ $app → ${assets:h}"
done
