#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NextUp"

rm -rf NextUp.app
mkdir -p NextUp.app/Contents/MacOS NextUp.app/Contents/Resources
cp "$BIN" NextUp.app/Contents/MacOS/NextUp
cp Resources/Info.plist NextUp.app/Contents/Info.plist
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns NextUp.app/Contents/Resources/AppIcon.icns
fi

codesign --force --sign - NextUp.app

pkill -x NextUp 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x NextUp >/dev/null || break
    sleep 0.3
done

rm -rf /Applications/NextUp.app
cp -R NextUp.app /Applications/NextUp.app
open /Applications/NextUp.app
