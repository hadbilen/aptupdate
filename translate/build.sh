#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$DIR")"
DOMAIN="plasma_applet_hadbilen.aptupdate.plasmoid"

echo "Extracting strings to $DIR/template.pot..."
xgettext --from-code=UTF-8 -C --qt \
    --keyword=i18n \
    --keyword=i18nc:1c,2 \
    --keyword=i18np:1,2 \
    -o "$DIR/template.pot" \
    "$ROOT_DIR"/hadbilen.aptupdate.plasmoid/contents/ui/*.qml \
    "$ROOT_DIR"/hadbilen.aptupdate.plasmoid/contents/ui/components/*.qml \
    "$ROOT_DIR"/hadbilen.aptupdate.plasmoid/contents/ui/config/*.qml \
    "$ROOT_DIR"/hadbilen.aptupdate.plasmoid/contents/service/*.qml \
    "$ROOT_DIR"/hadbilen.aptupdate.plasmoid/contents/config/*.qml

for po in "$DIR"/*.po; do
    [ -f "$po" ] || continue
    lang=$(basename "$po" .po)
    echo "Updating $po..."
    msgmerge -U "$po" "$DIR/template.pot"
    out_dir="$ROOT_DIR/hadbilen.aptupdate.plasmoid/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$out_dir"
    echo "Compiling $po -> $out_dir/$DOMAIN.mo..."
    msgfmt -o "$out_dir/$DOMAIN.mo" "$po"
done

echo "Done!"
