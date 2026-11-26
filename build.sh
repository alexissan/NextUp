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

# Sign with the local certificate from make-signing-cert.sh when there is one, so the calendar
# permission survives rebuilds. Otherwise sign ad hoc. NEXTUP_SIGN_IDENTITY overrides both.
IDENTITY="${NEXTUP_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && security find-certificate -c "NextUp Local Signing" >/dev/null 2>&1; then
    IDENTITY="NextUp Local Signing"
fi
codesign --force --sign "${IDENTITY:--}" NextUp.app

# What macOS checks a saved permission against: the certificate for a signed build, the exact build for an ad hoc one.
requirement() {
    codesign -d -r- "$1" 2>&1 | sed -n 's/^.*designated => //p'
}
PREVIOUS_REQUIREMENT=""
if [ -d /Applications/NextUp.app ]; then
    PREVIOUS_REQUIREMENT="$(requirement /Applications/NextUp.app)"
fi

pkill -x NextUp 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x NextUp >/dev/null || break
    sleep 0.3
done

rm -rf /Applications/NextUp.app
cp -R NextUp.app /Applications/NextUp.app

# When the new build no longer satisfies what the old permission was saved against (always the case
# between ad hoc builds), calendar access stops applying, yet System Settings would still show it
# switched on. Clearing it makes macOS ask again instead of leaving a switch that does nothing.
if [ -n "$PREVIOUS_REQUIREMENT" ] && [ "$PREVIOUS_REQUIREMENT" != "$(requirement /Applications/NextUp.app)" ]; then
    if tccutil reset Calendar dev.alexissantos.nextup >/dev/null 2>&1; then
        echo "NextUp was rebuilt, so its calendar permission was cleared. Allow it again when macOS asks."
    fi
fi

open /Applications/NextUp.app
