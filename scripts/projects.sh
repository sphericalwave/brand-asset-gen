#!/bin/zsh
# Regenerates the projects app's icon + launch assets (OmniFocus-style violet, not the blue family).
#
#   scripts/projects.sh
#
# Keeps the family's vector-equilibrium overlay (Brand/family/ve.pdf) and shadow so it still sits
# with the other sphericalwave icons, but swaps the blue background for a violet gradient.
# projects launches from the UILaunchScreen dict in its project.yml (LaunchBackground + LaunchLogo),
# so no storyboard, LaunchGradient or wire_launch.py here.
set -euo pipefail

REPO=${0:A:h:h}
BRAND=${BRAND_DIR:-$REPO/Brand}
APPS_ROOT=${APPS_ROOT:-$HOME/Documents/apps}
assets=${PROJECTS_ASSETS:-$APPS_ROOT/projects/Resources/Assets.xcassets}

swift build -c release --package-path $REPO >/dev/null

# The generator owns these folders; clear old PNGs so renamed files don't linger.
rm -f $assets/AppIcon.appiconset/*.png(N) $assets/LaunchLogo.imageset/*.png(N)

$REPO/.build/release/brand-gen --name projects --brand-color 9466DB --brand-color2 5A2FA0 \
  --dark-color A98BEA --sf-symbol checkmark.circle.fill \
  --overlay-pdf $BRAND/family/ve.pdf --overlay-scale 0.94 --overlay-opacity 0.4 \
  --shadow --no-launch-name --launch-size 300 --no-launch-gradient \
  --output $assets >/dev/null

# --brand-color is also the gradient's light top; the splash and tint use the mid violet instead.
for colorset in AccentColor LaunchBackground; do
  sed -i '' 's/"red": "0x94", "green": "0x66", "blue": "0xDB"/"red": "0x7B", "green": "0x4F", "blue": "0xC9"/' \
    $assets/$colorset.colorset/Contents.json
done

print "✓ projects → ${assets:h}"
