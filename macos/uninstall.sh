#!/bin/bash
set -euo pipefail

APP="${QQ_APP_PATH:-/Applications/QQ.app}"
CONTAINER="$HOME/Library/Containers/com.tencent.qq/Data/Documents"
LL="$CONTAINER/LiteLoaderQQNT"
LAUNCHER="$APP/Contents/Resources/app/app_launcher"

if pgrep -x QQ >/dev/null 2>&1; then
    echo "Quit QQ (Command-Q) before uninstalling" >&2
    exit 1
fi

for file in launcher.node ll-inject-v8-13.node ll-inject-v8-14.node; do
    if [ -e "$LAUNCHER/$file" ]; then
        if [ -w "$LAUNCHER" ]; then rm -f "$LAUNCHER/$file"; else sudo rm -f "$LAUNCHER/$file"; fi
        echo "removed $file"
    fi
done
rm -f "$CONTAINER/ll-bootstrap.js"

if [ "${1:-}" = "--purge" ]; then
    rm -rf "$LL"
    echo "removed $LL"
else
    echo "kept $LL (plugins/data preserved); use --purge to remove it"
fi
