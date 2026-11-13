#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_SRC="$ROOT_DIR/hadbilen.aptupdate.plasmoid"
META_FILE="$PKG_SRC/metadata.json"

if [[ ! -f "$META_FILE" ]]; then
    echo "ERROR: metadata.json not found at $META_FILE" >&2
    exit 1
fi

META_RAW="$(python3 - "$META_FILE" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
kplugin = data.get("KPlugin") or {}
pid = str(kplugin.get("Id") or "").strip()
ver = str(kplugin.get("Version") or "").strip()
if not pid or not ver:
    sys.stderr.write("ERROR: metadata.json missing KPlugin.Id or KPlugin.Version\n")
    sys.exit(1)
print(pid)
print(ver)
PY
)"
mapfile -t META <<<"$META_RAW"
PLUGIN_ID="${META[0]:-}"
VERSION="${META[1]:-}"
if [[ -z "$PLUGIN_ID" ]] || [[ -z "$VERSION" ]]; then
    echo "ERROR: Invalid plugin metadata in $META_FILE" >&2
    exit 1
fi
OUT_DIR="${1:-$ROOT_DIR/dist}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
OUT_FILE="$OUT_DIR/${PLUGIN_ID}-v${VERSION}.plasmoid"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -a "$PKG_SRC" "$STAGE/$PLUGIN_ID"
find "$STAGE/$PLUGIN_ID" \( -name '*.bak' -o -name '*.orig' -o -name '*.rej' -o -name '.DS_Store' -o -name '__pycache__' \) -prune -exec rm -rf {} +

rm -f "$OUT_FILE"
(
    cd "$STAGE/$PLUGIN_ID"
    zip -rqX "$OUT_FILE" . -x '*.git*' 'tests/*' 'docs/*'
)

unzip -tq "$OUT_FILE" >/dev/null

# Verify expected entries and absence of development/governance files
LISTING="$(unzip -Z1 "$OUT_FILE")"
for req in "metadata.json" "contents/ui/main.qml" "contents/service/CommandBuilder.js" "contents/config/main.xml"; do
    if ! grep -qx "$req" <<<"$LISTING"; then
        echo "ERROR: Packaged archive missing required entry: $req" >&2
        exit 1
    fi
done
if grep -qE '(^|/)\.git(/|$)|^tests/|^docs/|^(tasks|HANDOFF|MISTAKES)\.md$' <<<"$LISTING"; then
    echo "ERROR: Packaged archive contains non-release files" >&2
    exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    VERIFY_ROOT="$STAGE/kpkg_verify"
    mkdir -p "$VERIFY_ROOT"
    kpackagetool6 --type Plasma/Applet --packageroot "$VERIFY_ROOT" --install "$OUT_FILE" >/dev/null
    kpackagetool6 --type Plasma/Applet --packageroot "$VERIFY_ROOT" --show "$PLUGIN_ID" >/dev/null
else
    echo "WARNING: kpackagetool6 not found; skipped Plasma package verification" >&2
fi

echo "PACKAGED_OK: $OUT_FILE"
