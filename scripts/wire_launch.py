#!/usr/bin/env python3
"""Point every iOS app target in an Xcode project at LaunchScreen.storyboard.

    scripts/wire_launch.py path/to/App.xcodeproj [path/to/Info.plist ...]

- Removes competing launch settings: INFOPLIST_KEY_UILaunchScreen_* build settings and
  any existing INFOPLIST_KEY_UILaunchStoryboardName lines.
- Adds UILaunchStoryboardName = LaunchScreen + UILaunchScreen_Generation = NO to each
  build configuration that sets ASSETCATALOG_COMPILER_APPICON_NAME and isn't watchOS
  (i.e. iOS app targets; extensions and watch apps are left alone).
- Deletes the UILaunchScreen dict from each given Info.plist (it would override the storyboard)
  and sets UILaunchStoryboardName there too (needed when GENERATE_INFOPLIST_FILE = NO).
Idempotent: running it twice produces the same file.
"""
import re
import subprocess
import sys

pbx_path = sys.argv[1].rstrip("/") + "/project.pbxproj"
lines = open(pbx_path).read().split("\n")

drop = re.compile(r'^\s*"?INFOPLIST_KEY_(UILaunchScreen_\w+|UILaunchStoryboardName)(\[[^\]]*\])?"?\s*=')
lines = [l for l in lines if not drop.match(l)]

out, wired, i = [], 0, 0
while i < len(lines):
    line = lines[i]
    out.append(line)
    m = re.match(r'^(\s*)buildSettings = \{$', line)
    if m:
        end = lines.index(m.group(1) + "};", i)
        block = "\n".join(lines[i + 1:end])
        is_app = "ASSETCATALOG_COMPILER_APPICON_NAME" in block
        is_watch = "SDKROOT = watchos" in block or "WATCHOS_DEPLOYMENT_TARGET" in block
        if is_app and not is_watch:
            indent = m.group(1) + "\t"
            out.append(f"{indent}INFOPLIST_KEY_UILaunchScreen_Generation = NO;")
            out.append(f"{indent}INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;")
            wired += 1
    i += 1

open(pbx_path, "w").write("\n".join(out))
print(f"{pbx_path}: wired {wired} build configuration(s)")

def plist_has(plist, key):
    return subprocess.run(["/usr/libexec/PlistBuddy", "-c", f"Print :{key}", plist],
                          capture_output=True).returncode == 0

for plist in sys.argv[2:]:
    if plist_has(plist, "UILaunchScreen"):
        subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Delete :UILaunchScreen", plist], check=True)
        print(f"{plist}: removed UILaunchScreen dict")
    # Targets with GENERATE_INFOPLIST_FILE = NO ignore INFOPLIST_KEY_* build settings,
    # so set the storyboard name in the plist itself too.
    if not plist_has(plist, "UILaunchStoryboardName"):
        subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Add :UILaunchStoryboardName string LaunchScreen", plist], check=True)
        print(f"{plist}: added UILaunchStoryboardName")
