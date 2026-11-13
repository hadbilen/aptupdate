#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/org/kde/plasma/plasmoid"
SRC="$PLUGIN_DIR/plasmoid_mock_plugin.cpp"
OUT="$PLUGIN_DIR/libplasmoidmockplugin.so"

if [[ -f "$OUT" ]] && [[ "$OUT" -nt "$SRC" ]] && [[ "${1:-}" != "--force" ]]; then
    exit 0
fi

MOC_BIN="$(command -v moc || true)"
if [[ -z "$MOC_BIN" ]] && command -v qmake6 >/dev/null 2>&1; then
    MOC_BIN="$(qmake6 -query QT_HOST_LIBEXECS)/moc"
fi
if [[ ! -x "$MOC_BIN" ]]; then
    MOC_BIN="/usr/lib/qt6/libexec/moc"
fi
if [[ ! -x "$MOC_BIN" ]]; then
    echo "ERROR: Qt6 moc not found" >&2
    exit 1
fi

TMP_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMP_BUILD"' EXIT

QT_FLAGS="$(pkg-config --cflags --libs Qt6Qml Qt6Quick)"
"$MOC_BIN" "$SRC" -o "$TMP_BUILD/plasmoid_mock_plugin.moc"
g++ -std=c++17 -O2 -Wall -Wextra -Werror -shared -fPIC -I"$TMP_BUILD" $QT_FLAGS "$SRC" -o "$OUT"
