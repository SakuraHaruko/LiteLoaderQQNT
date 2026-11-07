#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
APP="${QQ_APP_PATH:-/Applications/QQ.app}"
CONTAINER="$HOME/Library/Containers/com.tencent.qq/Data/Documents"
LL="$CONTAINER/LiteLoaderQQNT"
LAUNCHER="$APP/Contents/Resources/app/app_launcher"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$APP" ] || die "QQ.app not found: $APP"
[ -d "$LAUNCHER" ] || die "unsupported QQ.app layout: $LAUNCHER"
if pgrep -x QQ >/dev/null 2>&1; then
    die "Quit QQ (Command-Q) before installing"
fi

if [ ! -f "$HERE/build/launcher.node" ]; then
    bash "$HERE/build.sh"
fi

echo "==> installing LiteLoaderQQNT sources"
mkdir -p "$LL"
mkdir -p "$CONTAINER"
rsync -a "$ROOT/src" "$LL/"
cp "$ROOT/package.json" "$ROOT/LICENSE" "$LL/"

echo "==> installing bootstrap"
cp "$HERE/bootstrap/ll-bootstrap.js" "$CONTAINER/ll-bootstrap.js"

echo "==> installing native launcher"
if [ -w "$LAUNCHER" ]; then
    cp "$HERE/build/launcher.node" "$LAUNCHER/launcher.node"
    cp "$HERE/build/ll-inject-v8-13.node" "$LAUNCHER/ll-inject-v8-13.node"
    cp "$HERE/build/ll-inject-v8-14.node" "$LAUNCHER/ll-inject-v8-14.node"
else
    sudo cp "$HERE/build/launcher.node" "$LAUNCHER/launcher.node"
    sudo cp "$HERE/build/ll-inject-v8-13.node" "$LAUNCHER/ll-inject-v8-13.node"
    sudo cp "$HERE/build/ll-inject-v8-14.node" "$LAUNCHER/ll-inject-v8-14.node"
fi

xattr -dr com.apple.quarantine "$LL" "$CONTAINER/ll-bootstrap.js" 2>/dev/null || true

echo "==> installed"
echo "    LiteLoaderQQNT: $LL"
echo "    launcher:       $LAUNCHER/launcher.node"
echo "    restart QQ and check Settings > LiteLoaderQQNT"
