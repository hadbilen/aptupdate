#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_QML="$ROOT_DIR/tests/helpers/ExportCommandsTest.qml"
MOCKS_DIR="$ROOT_DIR/tests/mocks"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT" /tmp/aptupdate-export-logdir' EXIT

EXPORT_OUT="$TMP_ROOT/exports.txt"
export XDG_CACHE_HOME="$TMP_ROOT/xdg_cache"
export XDG_RUNTIME_DIR="$TMP_ROOT/xdg_runtime"
mkdir -p "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

if ! QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import "$MOCKS_DIR" -input "$EXPORT_QML" >"$EXPORT_OUT" 2>&1; then
    cat "$EXPORT_OUT"
    echo "FAIL: ExportCommandsTest.qml failed to export commands from QML components"
    exit 1
fi

get_cmd() {
    local key="$1"
    python3 - "$EXPORT_OUT" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
prefix = f"EXPORT_CMD|{key}|"
with open(path, "r", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        idx = line.find(prefix)
        if idx != -1:
            print(json.loads(line[idx + len(prefix):].strip()))
            sys.exit(0)
sys.exit(1)
PY
}

FAILURES=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Test 1 (AC-1): Reboot command must never fall back to systemctl reboot when qdbus is missing and D-Bus fails
mkdir -p "$TMP_ROOT/bin1" "$TMP_ROOT/log1"
for b in bash sh rm mkdir mkdir chmod cat env timeout grep awk fuser pgrep; do
    if command -v "$b" >/dev/null 2>&1; then
        ln -sf "$(command -v "$b")" "$TMP_ROOT/bin1/$b"
    fi
done
cat >"$TMP_ROOT/bin1/systemctl" <<EOF
#!/usr/bin/env bash
echo "SYSTEMCTL_INVOKED:\$*" >"$TMP_ROOT/systemctl_called"
exit 0
EOF
cat >"$TMP_ROOT/bin1/qdbus6" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin1/dbus-send" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin1/gdbus" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin1/busctl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TMP_ROOT/bin1/systemctl" "$TMP_ROOT/bin1/qdbus6" "$TMP_ROOT/bin1/dbus-send" "$TMP_ROOT/bin1/gdbus" "$TMP_ROOT/bin1/busctl"

REBOOT_CMD="$(get_cmd reboot)"
set +e
PATH="$TMP_ROOT/bin1" bash -c "$REBOOT_CMD" >/dev/null 2>&1
REBOOT_RC=$?
set -e
if [[ -e "$TMP_ROOT/systemctl_called" ]] || [[ "$REBOOT_RC" -eq 0 ]]; then
    fail "AC-1 reboot command invoked systemctl reboot or succeeded despite absent/failing D-Bus (rc=$REBOOT_RC, cmd=$REBOOT_CMD)"
else
    pass "AC-1 reboot command exited non-zero without invoking systemctl"
fi

# Test 2 (AC-2): buildSilentWrapper preserves innerScript non-zero exit when log file is empty
SILENT_EMPTY_CMD="$(get_cmd silent_empty_fail)"
set +e
bash -c "$SILENT_EMPTY_CMD" >/dev/null 2>&1
WRAP_RC=$?
set -e
if [[ "$WRAP_RC" -ne 7 ]]; then
    fail "AC-2 buildSilentWrapper masked empty-log failure exit 7 as rc=$WRAP_RC"
else
    pass "AC-2 buildSilentWrapper preserved empty-log failure exit 7"
fi

# Test 3 (AC-2): pkexec exit 127 must not misattribute failure to both apt and snap bitmasks; 126 maps to CANCELLED
mkdir -p "$TMP_ROOT/bin3"
cp -a "$TMP_ROOT/bin1/." "$TMP_ROOT/bin3/" 2>/dev/null || true
cat >"$TMP_ROOT/bin3/pkexec" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
chmod +x "$TMP_ROOT/bin3/pkexec"
rm -rf /tmp/aptupdate-export-logdir "$XDG_RUNTIME_DIR/aptupdate" "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs"
SILENT_BOTH_CMD="$(get_cmd silent_apt_snap)"
set +e
PATH="$TMP_ROOT/bin3:/usr/bin:/bin" bash -c "$SILENT_BOTH_CMD" >/dev/null 2>&1
PK127_RC=$?
set -e
LOG_PATH=""
for candidate in \
    "$XDG_RUNTIME_DIR/aptupdate/aptupdate_last_error_all.log" \
    "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_last_error_all.log" \
    "/tmp/aptupdate-export-logdir/aptupdate_last_error_all.log" \
    "$XDG_RUNTIME_DIR/aptupdate/aptupdate_last_error.log" \
    "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_last_error.log" \
    "/tmp/aptupdate-export-logdir/aptupdate_last_error.log"; do
    if [[ -f "$candidate" ]]; then
        LOG_PATH="$candidate"
        break
    fi
done
LOG_CONTENT=""
if [[ -n "$LOG_PATH" ]]; then
    LOG_CONTENT="$(cat "$LOG_PATH")"
fi
if [[ -z "$LOG_PATH" ]] || [[ "$PK127_RC" -eq 0 ]] || ! grep -q '\[PKEXEC_FAILED\]' <<<"$LOG_CONTENT" || (grep -q '\[FAILED\] apt' <<<"$LOG_CONTENT" && grep -q '\[FAILED\] snap' <<<"$LOG_CONTENT"); then
    fail "AC-2 pkexec exit 127 misattributed failure or missing [PKEXEC_FAILED] marker (rc=$PK127_RC, log_path='$LOG_PATH', log='$LOG_CONTENT')"
else
    pass "AC-2 pkexec exit 127 logged [PKEXEC_FAILED] and separated from apt/snap bitmask (rc=$PK127_RC)"
fi

# Also test pkexec exit 126 -> exit 126 + [CANCELLED]
cat >"$TMP_ROOT/bin3/pkexec" <<'EOF'
#!/usr/bin/env bash
exit 126
EOF
chmod +x "$TMP_ROOT/bin3/pkexec"
set +e
PATH="$TMP_ROOT/bin3:/usr/bin:/bin" bash -c "$SILENT_BOTH_CMD" >/dev/null 2>&1
PK126_RC=$?
set -e
LOG_126=""
if [[ -n "$LOG_PATH" ]] && [[ -f "$LOG_PATH" ]]; then
    LOG_126="$(cat "$LOG_PATH")"
fi
if [[ "$PK126_RC" -ne 126 ]] || ! grep -q '\[CANCELLED\]' <<<"$LOG_126"; then
    fail "AC-2 pkexec exit 126 failed cancellation contract (rc=$PK126_RC, log='$LOG_126')"
else
    pass "AC-2 pkexec exit 126 preserved [CANCELLED] and exit 126"
fi

# Test 4 (AC-2): Silent APT command runs with conffile options + env + closed stdin (< /dev/null)
SILENT_APT_CMD="$(get_cmd silent_apt_only)"
cat >"$TMP_ROOT/bin3/pkexec" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$TMP_ROOT/pkexec_argv"
if [ -t 0 ]; then
    echo "STDIN_IS_TTY" >"$TMP_ROOT/pkexec_stdin"
else
    stdin_bytes=\$(cat | wc -c)
    echo "STDIN_BYTES=\$stdin_bytes" >"$TMP_ROOT/pkexec_stdin"
fi
exit 0
EOF
chmod +x "$TMP_ROOT/bin3/pkexec"
set +e
printf 'fake_stdin_payload\n' | PATH="$TMP_ROOT/bin3:/usr/bin:/bin" bash -c "$SILENT_APT_CMD" >/dev/null 2>&1
set -e
PK_ARGS="$(cat "$TMP_ROOT/pkexec_argv" 2>/dev/null || true)"
PK_STDIN="$(cat "$TMP_ROOT/pkexec_stdin" 2>/dev/null || true)"
if [[ "$PK_ARGS" != *"--force-confdef"* ]] || [[ "$PK_ARGS" != *"--force-confold"* ]] || [[ "$PK_ARGS" != *"APT_LISTCHANGES_FRONTEND=none"* ]] || [[ "$PK_ARGS" != *"NEEDRESTART_MODE=a"* ]] || [[ "$PK_STDIN" != "STDIN_BYTES=0" ]]; then
    fail "AC-2 silent APT missing conffile/env/stdin guards (args='$PK_ARGS', stdin='$PK_STDIN')"
else
    pass "AC-2 silent APT enforced Dpkg::Options, env vars, and </dev/null"
fi

# Test 5 (AC-2): notCloseCommand preserves inner exit code instead of masking it with suffix exit 0
TERM_FAIL_CMD="$(get_cmd term_notclose_fail)"
set +e
bash -c "$TERM_FAIL_CMD" >/dev/null 2>&1
TERM_RC=$?
set -e
if [[ "$TERM_RC" -ne 1 ]]; then
    fail "AC-2 notCloseCommand masked inner failure exit 1 as rc=$TERM_RC (cmd=$TERM_FAIL_CMD)"
else
    pass "AC-2 notCloseCommand preserved inner failure exit 1"
fi

# Test 6 (AC-3): getListFlatpakCmd outputs 6 tab-separated fields ending with branch
mkdir -p "$TMP_ROOT/bin6"
cat >"$TMP_ROOT/bin6/flatpak" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    printf 'org.gnome.Platform\t46\t46\n'
    printf 'org.gnome.Platform\t47\t47\n'
else
    printf 'org.gnome.Platform\tGNOME Platform\t46\t46\n'
    printf 'org.gnome.Platform\tGNOME Platform\t47\t47\n'
fi
EOF
chmod +x "$TMP_ROOT/bin6/flatpak"
FLATPAK_CMD="$(get_cmd list_flatpak)"
FLATPAK_OUT="$(PATH="$TMP_ROOT/bin6:/usr/bin:/bin" bash -c "$FLATPAK_CMD" || true)"
if ! grep -q $'^org\.gnome\.Platform\tGNOME Platform\tflatpak\t46\t46\t46$' <<<"$FLATPAK_OUT" || ! grep -q $'^org\.gnome\.Platform\tGNOME Platform\tflatpak\t47\t47\t47$' <<<"$FLATPAK_OUT"; then
    fail "AC-3 getListFlatpakCmd missing 6th branch field (out='$FLATPAK_OUT')"
else
    pass "AC-3 getListFlatpakCmd outputs 6 fields including branch"
fi

# Test 7 (AC-3): checkLock detects active PackageKit D-Bus transaction while ignoring idle packagekitd
mkdir -p "$TMP_ROOT/bin7"
for b in bash sh awk grep echo; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin7/$b"
done
cat >"$TMP_ROOT/bin7/fuser" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin7/ps" <<'EOF'
#!/usr/bin/env bash
echo "packagekitd     /usr/libexec/packagekitd"
EOF
cat >"$TMP_ROOT/bin7/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TMP_ROOT/bin7/gdbus" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"GetTransactionList"* ]]; then
    echo "(['/123_abc'],)"
    exit 0
fi
echo "(<false>,)"
EOF
chmod +x "$TMP_ROOT/bin7/fuser" "$TMP_ROOT/bin7/ps" "$TMP_ROOT/bin7/pgrep" "$TMP_ROOT/bin7/gdbus"
LOCK_CMD="$(get_cmd check_lock)"
LOCK_ACTIVE="$(PATH="$TMP_ROOT/bin7:/usr/bin:/bin" bash -c "$LOCK_CMD" || true)"

cat >"$TMP_ROOT/bin7/gdbus" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"GetTransactionList"* ]]; then
    echo "(@ao [],)"
    exit 0
fi
echo "(<false>,)"
EOF
chmod +x "$TMP_ROOT/bin7/gdbus"
LOCK_IDLE="$(PATH="$TMP_ROOT/bin7:/usr/bin:/bin" bash -c "$LOCK_CMD" || true)"

if [[ "$LOCK_ACTIVE" != "1" ]] || [[ "$LOCK_IDLE" != "0" ]]; then
    fail "AC-3 checkLock PackageKit D-Bus detection failed (active='$LOCK_ACTIVE', idle='$LOCK_IDLE')"
else
    pass "AC-3 checkLock detects active PackageKit D-Bus lock and ignores idle packagekitd"
fi

# Test 8 (AC-3): connectivityCmd supports split-tunnel VPN (ip route get succeeds when default route is empty)
mkdir -p "$TMP_ROOT/bin8"
for b in bash sh grep echo; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin8/$b"
done
cat >"$TMP_ROOT/bin8/ip" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"route get"* ]]; then
    echo "1.1.1.1 dev tun0 src 10.8.0.2 uid 1000"
    exit 0
fi
exit 0
EOF
cat >"$TMP_ROOT/bin8/nmcli" <<'EOF'
#!/usr/bin/env bash
echo "none"
EOF
chmod +x "$TMP_ROOT/bin8/ip" "$TMP_ROOT/bin8/nmcli"
CONN_CMD="$(get_cmd connectivity)"
CONN_VPN="$(PATH="$TMP_ROOT/bin8:/usr/bin:/bin" bash -c "$CONN_CMD" || true)"
if [[ "$CONN_VPN" != "1" ]]; then
    fail "AC-3 connectivityCmd failed split-tunnel VPN detection (got='$CONN_VPN')"
else
    pass "AC-3 connectivityCmd detected split-tunnel VPN connectivity"
fi

# Test 9 (AC-4): sendNotify falls back cleanly to org.freedesktop.Notifications D-Bus when notify-send is absent
mkdir -p "$TMP_ROOT/bin9"
for b in bash sh echo env; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin9/$b"
done
cat >"$TMP_ROOT/bin9/gdbus" <<EOF
#!/usr/bin/env bash
echo "GDBUS_NOTIFY:\$*" >"$TMP_ROOT/notify_fallback"
exit 0
EOF
chmod +x "$TMP_ROOT/bin9/gdbus"
NOTIFY_CMD="$(get_cmd send_notify)"
set +e
PATH="$TMP_ROOT/bin9" bash -c "$NOTIFY_CMD" >/dev/null 2>&1
NOTIFY_RC=$?
set -e
if [[ "$NOTIFY_RC" -ne 0 ]] || ! grep -q "org.freedesktop.Notifications.Notify" "$TMP_ROOT/notify_fallback" 2>/dev/null; then
    fail "AC-4 sendNotify D-Bus fallback failed when notify-send is absent (rc=$NOTIFY_RC)"
else
    pass "AC-4 sendNotify D-Bus fallback succeeded when notify-send is absent"
fi

# Test 10 (AC-4): Debug.qml writes debug.log under $XDG_CACHE_HOME with 0700 dir / 0600 file and 200-line cap
cat >"$TMP_ROOT/tst_debug_disk.qml" <<'EOF'
import QtQuick
import QtTest
import org.kde.plasma.plasmoid as PlasmoidMod

Item {
    width: 64
    height: 64
    property var plasmoid: QtObject {
        property string id: "test-debug"
        property var configuration: PlasmoidMod.Plasmoid.configuration
    }
    TestCase {
        name: "DebugDisk"
        when: windowShown
        function test_200_line_cap_and_permissions() {
            var comp = Qt.createComponent("file://__ROOT_DIR__/hadbilen.aptupdate.plasmoid/contents/service/Debug.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var d = comp.createObject(parent)
            verify(d !== null)
            for (var i = 1; i <= 215; i++) {
                d.log("line-" + i, false)
            }
            d.flushNow()
            var waited = 0
            while (d.isFlushing && waited < 4000) {
                wait(50)
                waited += 50
            }
            wait(100)
            verify(!d.isFlushing, "Debug flush timed out")
            d.destroy()
        }
    }
}
EOF
python3 - "$TMP_ROOT/tst_debug_disk.qml" "$ROOT_DIR" <<'PY'
import sys
p, root = sys.argv[1], sys.argv[2]
txt = open(p, "r", encoding="utf-8").read().replace("__ROOT_DIR__", root)
open(p, "w", encoding="utf-8").write(txt)
PY

rm -rf "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid"
if ! QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import "$MOCKS_DIR" -input "$TMP_ROOT/tst_debug_disk.qml" >"$TMP_ROOT/debug_test.out" 2>&1; then
    fail "AC-4 Debug.qml disk flush test runner failed: $(cat "$TMP_ROOT/debug_test.out")"
else
    DBG_DIR="$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid"
    DBG_FILE="$DBG_DIR/debug.log"
    if [[ ! -f "$DBG_FILE" ]]; then
        fail "AC-4 Debug.qml did not create $DBG_FILE"
    else
        DIR_MODE="$(stat -c '%a' "$DBG_DIR")"
        FILE_MODE="$(stat -c '%a' "$DBG_FILE")"
        LINE_COUNT="$(wc -l < "$DBG_FILE")"
        if [[ "$DIR_MODE" != "700" ]] || [[ "$FILE_MODE" != "600" ]] || [[ "$LINE_COUNT" -ne 200 ]] || grep -q 'line-1$' "$DBG_FILE" || ! grep -q 'line-215$' "$DBG_FILE"; then
            fail "AC-4 Debug.qml violated permissions/200-line cap (dir=$DIR_MODE file=$FILE_MODE lines=$LINE_COUNT)"
        else
            pass "AC-4 Debug.qml enforces 0700 dir, 0600 file, and 200-line cap under XDG_CACHE_HOME"
        fi
    fi
fi

# Test 11 (AC-3): count_apt & list_apt awk filter matches live apt-get -s --with-new-pkgs upgrade output
mkdir -p "$TMP_ROOT/bin11"
for b in bash sh awk tail cat rm mktemp grep; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin11/$b"
done
cat >"$TMP_ROOT/bin11/apt-get" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be upgraded:
  bash libssl3t64
Inst bash [5.2-1ubuntu1] (5.2-2ubuntu1 Ubuntu:24.04/noble-updates [amd64])
Inst libssl3t64 [3.0.13-0ubuntu3.4] (3.0.13-0ubuntu3.5 Ubuntu:24.04/noble-security [amd64])
Conf bash (5.2-2ubuntu1 Ubuntu:24.04/noble-updates [amd64])
Conf libssl3t64 (3.0.13-0ubuntu3.5 Ubuntu:24.04/noble-security [amd64])
OUT
EOF
chmod +x "$TMP_ROOT/bin11/apt-get"
COUNT_APT_CMD="$(get_cmd count_apt)"
LIST_APT_CMD="$(get_cmd list_apt)"
APT_CNT_OUT="$(PATH="$TMP_ROOT/bin11:/usr/bin:/bin" bash -c "$COUNT_APT_CMD" || true)"
APT_LST_OUT="$(PATH="$TMP_ROOT/bin11:/usr/bin:/bin" bash -c "$LIST_APT_CMD" || true)"
if [[ "$APT_CNT_OUT" != "2" ]] || ! grep -q '^bash 5.2-1ubuntu1 -> 5.2-2ubuntu1 Ubuntu:24.04/noble-updates amd64$' <<<"$APT_LST_OUT" || ! grep -q '^libssl3t64 3.0.13-0ubuntu3.4 -> 3.0.13-0ubuntu3.5 Ubuntu:24.04/noble-security amd64$' <<<"$APT_LST_OUT"; then
    fail "AC-3 buildCountArchCmd/buildListArchCmd awk filter mismatch (cnt='$APT_CNT_OUT', list='$APT_LST_OUT')"
else
    pass "AC-3 buildCountArchCmd and buildListArchCmd awk filters match apt-get -s output cleanly"
fi

# Test 12 (AC-1): buildRebootPromptCmd positive tests (qdbus6 & dbus-send --print-reply) without systemctl
mkdir -p "$TMP_ROOT/bin12a" "$TMP_ROOT/bin12b"
for b in bash sh; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin12a/$b"
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin12b/$b"
done
cat >"$TMP_ROOT/bin12a/systemctl" <<EOF
#!/usr/bin/env bash
touch "$TMP_ROOT/systemctl_pos_called"
exit 0
EOF
cat >"$TMP_ROOT/bin12a/qdbus6" <<EOF
#!/usr/bin/env bash
echo "\$*" >"$TMP_ROOT/qdbus6_reboot_args"
exit 0
EOF
chmod +x "$TMP_ROOT/bin12a/systemctl" "$TMP_ROOT/bin12a/qdbus6"
if ! PATH="$TMP_ROOT/bin12a" bash -c "$REBOOT_CMD" >/dev/null 2>&1 || [[ -e "$TMP_ROOT/systemctl_pos_called" ]] || ! grep -q "org.kde.LogoutPrompt /LogoutPrompt promptReboot" "$TMP_ROOT/qdbus6_reboot_args" 2>/dev/null; then
    fail "AC-1 buildRebootPromptCmd qdbus6 positive invocation failed"
else
    pass "AC-1 buildRebootPromptCmd invokes qdbus6 LogoutPrompt cleanly without systemctl"
fi

cat >"$TMP_ROOT/bin12b/dbus-send" <<EOF
#!/usr/bin/env bash
echo "\$*" >"$TMP_ROOT/dbus_send_args"
exit 0
EOF
chmod +x "$TMP_ROOT/bin12b/dbus-send"
if ! PATH="$TMP_ROOT/bin12b" bash -c "$REBOOT_CMD" >/dev/null 2>&1 || ! grep -q -- "--print-reply" "$TMP_ROOT/dbus_send_args" 2>/dev/null; then
    fail "AC-1 buildRebootPromptCmd dbus-send fallback missing --print-reply"
else
    pass "AC-1 buildRebootPromptCmd dbus-send fallback enforces --print-reply"
fi

# Test 13 (AC-2): apt-get exit 100 under silent_apt_only logs [FAILED] apt (NOT [PKEXEC_FAILED])
SILENT_APT_CMD="$(get_cmd silent_apt_only)"
mkdir -p "$TMP_ROOT/bin13"
for b in bash sh grep rm mktemp mv chmod stat cat tail env; do
    if command -v "$b" >/dev/null 2>&1; then
        ln -sf "$(command -v "$b")" "$TMP_ROOT/bin13/$b"
    fi
done
cat >"$TMP_ROOT/bin13/pkexec" <<'EOF'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "bash" ]] && [[ "${2:-}" == "-c" ]]; then
        shift
        exec bash "$@"
    fi
    shift
done
exit 127
EOF
cat >"$TMP_ROOT/bin13/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 100
EOF
chmod +x "$TMP_ROOT/bin13/pkexec" "$TMP_ROOT/bin13/apt-get"
rm -f "$XDG_RUNTIME_DIR/aptupdate/aptupdate_last_error_all.log" "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_last_error_all.log"
set +e
PATH="$TMP_ROOT/bin13:/usr/bin:/bin" bash -c "$SILENT_APT_CMD" >/dev/null 2>&1
APT100_RC=$?
set -e
LOG13="$XDG_RUNTIME_DIR/aptupdate/aptupdate_last_error_all.log"
[[ -f "$LOG13" ]] || LOG13="$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_last_error_all.log"
if [[ "$APT100_RC" -eq 0 ]] || ! grep -q '\[FAILED\] apt' "$LOG13" 2>/dev/null || grep -q '\[PKEXEC_FAILED\]' "$LOG13" 2>/dev/null; then
    fail "AC-2 apt-get exit 100 misclassified (rc=$APT100_RC log=$(cat "$LOG13" 2>/dev/null || true))"
else
    pass "AC-2 apt-get exit 100 logs [FAILED] apt cleanly instead of [PKEXEC_FAILED]"
fi

# Test 14 (AC-2): multi-repo silent_all_three with pkexec=127 + flatpak fail preserves [FAILED] flatpak
SILENT_ALL_THREE_CMD="$(get_cmd silent_all_three)"
mkdir -p "$TMP_ROOT/bin14"
cp -a "$TMP_ROOT/bin13/." "$TMP_ROOT/bin14/" 2>/dev/null || true
cat >"$TMP_ROOT/bin14/pkexec" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
cat >"$TMP_ROOT/bin14/flatpak" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TMP_ROOT/bin14/pkexec" "$TMP_ROOT/bin14/flatpak"
rm -f "$XDG_RUNTIME_DIR/aptupdate/aptupdate_all_pk_fp.log" "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_all_pk_fp.log"
set +e
PATH="$TMP_ROOT/bin14:/usr/bin:/bin" bash -c "$SILENT_ALL_THREE_CMD" >/dev/null 2>&1
PKFP_RC=$?
set -e
LOG14="$XDG_RUNTIME_DIR/aptupdate/aptupdate_all_pk_fp.log"
[[ -f "$LOG14" ]] || LOG14="$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/aptupdate_all_pk_fp.log"
if [[ "$PKFP_RC" -eq 0 ]] || ! grep -q '\[PKEXEC_FAILED\]' "$LOG14" 2>/dev/null || ! grep -q '\[FAILED\] flatpak' "$LOG14" 2>/dev/null; then
    fail "AC-2 multi-repo pkexec=127 + flatpak fail lost [FAILED] flatpak (rc=$PKFP_RC log=$(cat "$LOG14" 2>/dev/null || true))"
else
    pass "AC-2 multi-repo silent update preserves both [PKEXEC_FAILED] and [FAILED] flatpak"
fi

# Test 15 (AC-2): default '; exec $SHELL' with failing innerCmd writes rc=1 while outer exits 0; notClose=false fails with 7
TERM_EXEC_SHELL_CMD="$(get_cmd term_exec_shell)"
TERM_PAUSE_FAIL_CMD="$(get_cmd term_pause_fail)"
mkdir -p "$TMP_ROOT/bin15"
for b in bash sh env mktemp mv chmod mkdir test rm cat printf; do
    if command -v "$b" >/dev/null 2>&1; then
        ln -sf "$(command -v "$b")" "$TMP_ROOT/bin15/$b"
    fi
done
cat >"$TMP_ROOT/bin15/konsole" <<'EOF'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -e) shift; exec "$@" ;;
        *) shift ;;
    esac
done
exit 127
EOF
chmod +x "$TMP_ROOT/bin15/konsole"
rm -f "$XDG_RUNTIME_DIR/aptupdate/term_rc_exec"
set +e
SHELL=/bin/true PATH="$TMP_ROOT/bin15:/usr/bin:/bin" bash -c "$TERM_EXEC_SHELL_CMD" >/dev/null 2>&1
EXEC_SHELL_OUTER_RC=$?
set -e
RC_EXEC_FILE="$XDG_RUNTIME_DIR/aptupdate/term_rc_exec"
[[ -f "$RC_EXEC_FILE" ]] || RC_EXEC_FILE="$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/logs/term_rc_exec"
RC_VAL="$(cat "$RC_EXEC_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
set +e
printf '\n' | PATH="$TMP_ROOT/bin15:/usr/bin:/bin" bash -c "$TERM_PAUSE_FAIL_CMD" >/dev/null 2>&1
PAUSE_FAIL_RC=$?
set -e
if [[ "$EXEC_SHELL_OUTER_RC" -ne 0 ]] || [[ "$RC_VAL" != "1" ]] || [[ "$PAUSE_FAIL_RC" -ne 7 ]]; then
    fail "AC-2 terminal rc preservation failed (execShellOuter=$EXEC_SHELL_OUTER_RC rcVal='$RC_VAL' pauseRc=$PAUSE_FAIL_RC)"
else
    pass "AC-2 '; exec \$SHELL' preserves failing exit code 1 in rcFile and pause mode returns 7"
fi

# Test 16 (AC-3): setsid -w PGID tracking and buildSafeKillPgidAndRemoveCmd cleanup
PGID_WRAP_CMD="$(get_cmd silent_pgid_wrap)"
KILL_PGID_CMD="$(get_cmd kill_pgid_cmd)"
KILL_PGID_CMD="${KILL_PGID_CMD//__RUNTIME_DIR__/$XDG_RUNTIME_DIR}"
rm -f "$XDG_RUNTIME_DIR/aptupdate/test.pgid"
timeout 10 bash -c "$PGID_WRAP_CMD" >/dev/null 2>&1 &
PGID_BG_PID=$!
WAITED_PG=0
while [[ ! -s "$XDG_RUNTIME_DIR/aptupdate/test.pgid" ]] && [[ "$WAITED_PG" -lt 40 ]]; do
    sleep 0.05
    WAITED_PG=$((WAITED_PG + 1))
done
TRACKED_PGID="$(cat "$XDG_RUNTIME_DIR/aptupdate/test.pgid" 2>/dev/null | tr -cd '0-9' || true)"
if [[ -z "$TRACKED_PGID" ]] || [[ "$TRACKED_PGID" -le 1 ]]; then
    kill "$PGID_BG_PID" >/dev/null 2>&1 || true
    fail "AC-3 silent_pgid_wrap did not record valid PGID in test.pgid"
else
    bash -c "$KILL_PGID_CMD" >/dev/null 2>&1
    wait "$PGID_BG_PID" >/dev/null 2>&1 || true
    if [[ -e "$XDG_RUNTIME_DIR/aptupdate/test.pgid" ]] || kill -0 -- "-$TRACKED_PGID" 2>/dev/null; then
        fail "AC-3 kill_pgid_cmd left pgid file or live process group (-$TRACKED_PGID)"
    else
        pass "AC-3 setsid -w records PGID and buildSafeKillPgidAndRemoveCmd terminates group and deletes file"
    fi
fi

# Test 17 (AC-4): Symlink logDir refusal + Debug.qml dangling debug.log refusal & clear()
SYM_TARGET="$TMP_ROOT/sym_target"
SYM_LINK="$TMP_ROOT/sym_logdir"
mkdir -p "$SYM_TARGET"
ln -s "$SYM_TARGET" "$SYM_LINK"
TERM_SYM_CMD="$(get_cmd term_symlink_logdir)"
TERM_SYM_CMD="${TERM_SYM_CMD//__SYMLINK_LOGDIR__/$SYM_LINK}"
set +e
bash -c "$TERM_SYM_CMD" >/dev/null 2>&1
TERM_SYM_RC=$?
set -e
if [[ -e "$SYM_TARGET/term_rc_sym" ]] || [[ -n "$(ls -A "$SYM_TARGET")" ]]; then
    fail "AC-4 terminal command wrote into symlinked logDir (rc=$TERM_SYM_RC)"
else
    pass "AC-4 buildTerminalCommand refuses symlinked logDir cleanly"
fi

mkdir -p "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid"
rm -f "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/debug.log" "$TMP_ROOT/victim_canary"
ln -s "$TMP_ROOT/victim_canary" "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/debug.log"
cat >"$TMP_ROOT/tst_debug_sym_clear.qml" <<'EOF'
import QtQuick
import QtTest
import org.kde.plasma.plasmoid as PlasmoidMod

Item {
    width: 64
    height: 64
    property var plasmoid: QtObject {
        property string id: "test-debug-sym"
        property var configuration: PlasmoidMod.Plasmoid.configuration
    }
    TestCase {
        name: "DebugSymClear"
        when: windowShown
        function test_dangling_symlink_and_clear() {
            var comp = Qt.createComponent("file://__ROOT_DIR__/hadbilen.aptupdate.plasmoid/contents/service/Debug.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var d = comp.createObject(parent)
            verify(d !== null)
            d.log("should-not-follow-symlink", false)
            d.flushNow()
            var w = 0
            while (d.isFlushing && w < 3000) { wait(50); w += 50 }
            wait(80)
            d.destroy()
        }
    }
}
EOF
python3 - "$TMP_ROOT/tst_debug_sym_clear.qml" "$ROOT_DIR" <<'PY'
import sys
p, root = sys.argv[1], sys.argv[2]
txt = open(p, "r", encoding="utf-8").read().replace("__ROOT_DIR__", root)
open(p, "w", encoding="utf-8").write(txt)
PY
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import "$MOCKS_DIR" -input "$TMP_ROOT/tst_debug_sym_clear.qml" >/dev/null 2>&1 || true
if [[ -e "$TMP_ROOT/victim_canary" ]]; then
    fail "AC-4 Debug.qml followed dangling debug.log symlink!"
else
    pass "AC-4 Debug.qml refuses dangling debug.log symlink cleanly"
fi

rm -f "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/debug.log"
cat >"$TMP_ROOT/tst_debug_clear.qml" <<'EOF'
import QtQuick
import QtTest
import org.kde.plasma.plasmoid as PlasmoidMod

Item {
    width: 64
    height: 64
    property var plasmoid: QtObject {
        property string id: "test-debug-clear"
        property var configuration: PlasmoidMod.Plasmoid.configuration
    }
    TestCase {
        name: "DebugClear"
        when: windowShown
        function test_write_then_clear() {
            var comp = Qt.createComponent("file://__ROOT_DIR__/hadbilen.aptupdate.plasmoid/contents/service/Debug.qml")
            compare(comp.status, Component.Ready, comp.errorString())
            var d = comp.createObject(parent)
            verify(d !== null)
            d.log("entry-before-clear", false)
            d.flushNow()
            var w = 0
            while (d.isFlushing && w < 3000) { wait(50); w += 50 }
            wait(50)
            d.clear()
            w = 0
            while (d.isFlushing && w < 3000) { wait(50); w += 50 }
            wait(50)
            d.destroy()
        }
    }
}
EOF
python3 - "$TMP_ROOT/tst_debug_clear.qml" "$ROOT_DIR" <<'PY'
import sys
p, root = sys.argv[1], sys.argv[2]
txt = open(p, "r", encoding="utf-8").read().replace("__ROOT_DIR__", root)
open(p, "w", encoding="utf-8").write(txt)
PY
if ! QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import "$MOCKS_DIR" -input "$TMP_ROOT/tst_debug_clear.qml" >"$TMP_ROOT/dbg_clr.out" 2>&1 || [[ ! -f "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/debug.log" ]] || [[ -s "$XDG_CACHE_HOME/hadbilen.aptupdate.plasmoid/debug.log" ]]; then
    fail "AC-4 Debug.qml.clear() did not truncate debug.log to 0 bytes ($(cat "$TMP_ROOT/dbg_clr.out" 2>/dev/null || true))"
else
    pass "AC-4 Debug.qml.clear() empties debug.log with atomic rewrite"
fi

# Test 18 (Security): Double-quote & command substitution isolation in buildSafeReadAndRemoveCmd & buildSafeRemoveCmd
mkdir -p "$TMP_ROOT/payload_dir"
SAFE_READ_CMD="$(get_cmd safe_read_payload)"
SAFE_READ_CMD="${SAFE_READ_CMD//__PAYLOAD_DIR__/$TMP_ROOT/payload_dir}"
SAFE_RM_CMD="$(get_cmd safe_remove_payload)"
SAFE_RM_CMD="${SAFE_RM_CMD//__PAYLOAD_DIR__/$TMP_ROOT/payload_dir}"
WEIRD_READ_FILE="$TMP_ROOT/payload_dir/x\"\$(touch pwned_read)\"y.txt"
WEIRD_RM_FILE="$TMP_ROOT/payload_dir/x\"\$(touch pwned_rm)\"y.txt"
printf 'literal-safe-ok\n' >"$WEIRD_READ_FILE"
printf 'literal-rm-ok\n' >"$WEIRD_RM_FILE"
READ_PAYLOAD_OUT="$(cd "$TMP_ROOT/payload_dir" && bash -c "$SAFE_READ_CMD")"
(cd "$TMP_ROOT/payload_dir" && bash -c "$SAFE_RM_CMD")
if [[ "$READ_PAYLOAD_OUT" != "literal-safe-ok" ]] || [[ -e "$TMP_ROOT/payload_dir/pwned_read" ]] || [[ -e "$TMP_ROOT/payload_dir/pwned_rm" ]] || [[ -e "$WEIRD_READ_FILE" ]] || [[ -e "$WEIRD_RM_FILE" ]]; then
    fail "Security: safe read/remove payload isolation failed (out='$READ_PAYLOAD_OUT')"
else
    pass "Security: buildSafeReadAndRemoveCmd and buildSafeRemoveCmd treat quotes and \$() strictly literally"
fi

# Test 19 (AC-3): connectivityCmd rejects loopback 'dev lo' as offline '0'
mkdir -p "$TMP_ROOT/bin19"
for b in bash sh grep echo; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin19/$b"
done
cat >"$TMP_ROOT/bin19/ip" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"route get 1.1.1.1"* ]]; then
    echo "1.1.1.1 dev lo src 127.0.0.1 uid 1000"
    exit 0
fi
exit 1
EOF
cat >"$TMP_ROOT/bin19/nmcli" <<'EOF'
#!/usr/bin/env bash
echo "none"
EOF
chmod +x "$TMP_ROOT/bin19/ip" "$TMP_ROOT/bin19/nmcli"
CONN_LO="$(PATH="$TMP_ROOT/bin19:/usr/bin:/bin" bash -c "$CONN_CMD" || true)"
if [[ "$CONN_LO" != "0" ]]; then
    fail "AC-3 connectivityCmd treated loopback dev lo as online (got='$CONN_LO')"
else
    pass "AC-3 connectivityCmd treats loopback 'dev lo' as offline ('0')"
fi

# Test 20 (AC-3): checkLock ps -u 0 active vs -s simulation + PackageKit Locked=true across gdbus/busctl/qdbus6
mkdir -p "$TMP_ROOT/bin20"
for b in bash sh awk grep echo; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin20/$b"
done
cat >"$TMP_ROOT/bin20/fuser" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin20/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP_ROOT/bin20/ps" <<'EOF'
#!/usr/bin/env bash
echo "apt-get         apt-get -s --with-new-pkgs upgrade"
EOF
chmod +x "$TMP_ROOT/bin20/fuser" "$TMP_ROOT/bin20/pgrep" "$TMP_ROOT/bin20/ps"
PS_SIM="$(PATH="$TMP_ROOT/bin20:/usr/bin:/bin" bash -c "$LOCK_CMD" || true)"
cat >"$TMP_ROOT/bin20/ps" <<'EOF'
#!/usr/bin/env bash
echo "apt-get         apt-get upgrade"
EOF
chmod +x "$TMP_ROOT/bin20/ps"
PS_ACT="$(PATH="$TMP_ROOT/bin20:/usr/bin:/bin" bash -c "$LOCK_CMD" || true)"

cat >"$TMP_ROOT/bin20/ps" <<'EOF'
#!/usr/bin/env bash
echo "packagekitd     /usr/libexec/packagekitd"
EOF
cat >"$TMP_ROOT/bin20/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TMP_ROOT/bin20/gdbus" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"GetTransactionList"* ]]; then echo "(@ao [],)"; else echo "(<true>,)"; fi
EOF
chmod +x "$TMP_ROOT/bin20/ps" "$TMP_ROOT/bin20/pgrep" "$TMP_ROOT/bin20/gdbus"
PK_LOCK_GDBUS="$(PATH="$TMP_ROOT/bin20" bash -c "$LOCK_CMD" || true)"

rm -f "$TMP_ROOT/bin20/gdbus"
cat >"$TMP_ROOT/bin20/busctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"GetTransactionList"* ]]; then echo "ao 0"; else echo "b true"; fi
EOF
chmod +x "$TMP_ROOT/bin20/busctl"
PK_LOCK_BUSCTL="$(PATH="$TMP_ROOT/bin20" bash -c "$LOCK_CMD" || true)"

rm -f "$TMP_ROOT/bin20/busctl"
cat >"$TMP_ROOT/bin20/qdbus6" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"GetTransactionList"* ]]; then echo ""; else echo "true"; fi
EOF
chmod +x "$TMP_ROOT/bin20/qdbus6"
PK_LOCK_QDBUS6="$(PATH="$TMP_ROOT/bin20" bash -c "$LOCK_CMD" || true)"

if [[ "$PS_SIM" != "0" ]] || [[ "$PS_ACT" != "1" ]] || [[ "$PK_LOCK_GDBUS" != "1" ]] || [[ "$PK_LOCK_BUSCTL" != "1" ]] || [[ "$PK_LOCK_QDBUS6" != "1" ]]; then
    fail "AC-3 checkLock matrix failed (sim=$PS_SIM act=$PS_ACT gdbus=$PK_LOCK_GDBUS busctl=$PK_LOCK_BUSCTL qdbus6=$PK_LOCK_QDBUS6)"
else
    pass "AC-3 checkLock distinguishes ps -u 0 active vs -s and checks PackageKit Locked=true via gdbus/busctl/qdbus6"
fi

# Test 21 (AC-3): count_apt/list_apt pipefail exit 100 + new-dep exclusion + buildListSnapCmd formatting
mkdir -p "$TMP_ROOT/bin21"
for b in bash sh awk tail cat rm mktemp grep; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin21/$b"
done
cat >"$TMP_ROOT/bin21/apt-get" <<'EOF'
#!/usr/bin/env bash
echo "E: Could not open lock file" >&2
exit 100
EOF
chmod +x "$TMP_ROOT/bin21/apt-get"
set +e
PATH="$TMP_ROOT/bin21:/usr/bin:/bin" bash -c "$COUNT_APT_CMD" >/dev/null 2>&1
CNT_ERR_RC=$?
PATH="$TMP_ROOT/bin21:/usr/bin:/bin" bash -c "$LIST_APT_CMD" >/dev/null 2>&1
LST_ERR_RC=$?
set -e

cat >"$TMP_ROOT/bin21/apt-get" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Inst bash [5.2-1] (5.2-2 Ubuntu:24.04/noble-updates [amd64])
Inst libnewdep (1.0-1 Ubuntu:24.04/noble [amd64])
Conf libnewdep (1.0-1 Ubuntu:24.04/noble [amd64])
Conf bash (5.2-2 Ubuntu:24.04/noble-updates [amd64])
OUT
EOF
cat >"$TMP_ROOT/bin21/snap" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
Name     Version   Rev   Tracking       Publisher  Notes
firefox  130.0-1   5000  latest/stable  mozilla    -
OUT
EOF
chmod +x "$TMP_ROOT/bin21/apt-get" "$TMP_ROOT/bin21/snap"
NEWDEP_CNT="$(PATH="$TMP_ROOT/bin21:/usr/bin:/bin" bash -c "$COUNT_APT_CMD" || true)"
NEWDEP_LST="$(PATH="$TMP_ROOT/bin21:/usr/bin:/bin" bash -c "$LIST_APT_CMD" || true)"
SNAP_LIST_CMD="$(get_cmd list_snap)"
SNAP_LST_OUT="$(PATH="$TMP_ROOT/bin21:/usr/bin:/bin" bash -c "$SNAP_LIST_CMD" || true)"
if [[ "$CNT_ERR_RC" -ne 100 ]] || [[ "$LST_ERR_RC" -ne 100 ]] || [[ "$NEWDEP_CNT" != "1" ]] || grep -q "libnewdep" <<<"$NEWDEP_LST" || ! grep -q $'^firefox\tfirefox\tsnap\t130\.0-1\t130\.0-1$' <<<"$SNAP_LST_OUT"; then
    fail "AC-3 count/list pipefail or newdep/snap failed (cntRc=$CNT_ERR_RC lstRc=$LST_ERR_RC cnt='$NEWDEP_CNT' snap='$SNAP_LST_OUT')"
else
    pass "AC-3 count_apt/list_apt preserve pipefail exit 100, exclude new-install deps, and format list_snap"
fi

# Test 22 (AC-4): sendNotify '--' delimiter before leading-dash args in notify-send and gdbus
NOTIFY_DASH_CMD="$(get_cmd send_notify_dash)"
mkdir -p "$TMP_ROOT/bin22"
for b in bash sh echo env; do
    ln -sf "$(command -v "$b")" "$TMP_ROOT/bin22/$b"
done
cat >"$TMP_ROOT/bin22/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$TMP_ROOT/notify_args"
exit 0
EOF
chmod +x "$TMP_ROOT/bin22/notify-send"
PATH="$TMP_ROOT/bin22" bash -c "$NOTIFY_DASH_CMD" >/dev/null 2>&1
if ! grep -q -- '-- ' <<<"$NOTIFY_CMD" || ! grep -Fxq -- "--" "$TMP_ROOT/notify_args" || ! grep -q -- "Notify -- 'APT Update Counter'" <<<"$NOTIFY_DASH_CMD"; then
    fail "AC-4 sendNotify missing '--' delimiter guard for notify-send or gdbus"
else
    pass "AC-4 sendNotify passes '--' delimiter before leading-dash arguments cleanly"
fi

# Test 23 (Packaging): scripts/package.sh with relative ./rel_out and __pycache__ pruning
mkdir -p "$TMP_ROOT/pkg_repo"
cp -a "$ROOT_DIR/scripts" "$TMP_ROOT/pkg_repo/"
cp -a "$ROOT_DIR/hadbilen.aptupdate.plasmoid" "$TMP_ROOT/pkg_repo/"
mkdir -p "$TMP_ROOT/pkg_repo/hadbilen.aptupdate.plasmoid/contents/__pycache__"
touch "$TMP_ROOT/pkg_repo/hadbilen.aptupdate.plasmoid/contents/__pycache__/junk.pyc"
(cd "$TMP_ROOT" && "$TMP_ROOT/pkg_repo/scripts/package.sh" ./rel_out >/dev/null 2>&1)
PKG_OUT_FILE="$(ls "$TMP_ROOT/rel_out"/*.plasmoid 2>/dev/null | head -n1 || true)"
if [[ -z "$PKG_OUT_FILE" ]] || ! unzip -tq "$PKG_OUT_FILE" >/dev/null 2>&1 || unzip -Z1 "$PKG_OUT_FILE" | grep -q "__pycache__"; then
    fail "Packaging relative OUT_DIR or __pycache__ exclusion failed (file='$PKG_OUT_FILE')"
else
    pass "Packaging supports relative ./rel_out and prunes __pycache__"
fi

# Test 24 (Milestone 56 AC-2): getListFlatpakCmd queries active/commit without download-size and emits 8-col output when commits exist
mkdir -p "$TMP_ROOT/bin24"
cat >"$TMP_ROOT/bin24/flatpak" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    printf 'org.blender.Blender\tstable\t5.2\tf97247d9e87d0000111122223333444455556666\n'
    printf 'org.blender.Blender.Codecs\tstable\t\t2bbd555a9031aaaabbbbccccddddeeeeffff0000\n'
    printf 'org.telegram.desktop\tstable\t7.4.3\t3da0f2a359b01111222233334444555566667777\n'
    printf 'org.gnome.Platform\t46\t46\taaa111122223333\n'
    printf 'org.gnome.Platform\t47\t47\tbbb222233334444\n'
else
    printf 'org.blender.Blender\tBlender\tstable\t5.2\t3e510e350730aaaabbbbccccddddeeeeffff1111\n'
    printf 'org.blender.Blender.Codecs\tCodecs\tstable\t\t102459c033d41111222233334444555566667777\n'
    printf 'org.telegram.desktop\tTelegram Desktop\tstable\t7.4.1\t9fe9eee3feec1111222233334444555566667777\n'
    printf 'org.gnome.Platform\tGNOME Platform\t46\t46\tddd444455556666\n'
    printf 'org.gnome.Platform\tGNOME Platform\t47\t47\tccc333344445555\n'
    printf 'org.remoteonly.App\tRemoteOnly\tstable\t2.0\teee555566667777\n'
fi
EOF
chmod +x "$TMP_ROOT/bin24/flatpak"
FLATPAK_COMMIT_CMD="$(get_cmd list_flatpak)"
FLATPAK_COMMIT_OUT="$(PATH="$TMP_ROOT/bin24:/usr/bin:/bin" bash -c "$FLATPAK_COMMIT_CMD" || true)"
if [[ "$FLATPAK_COMMIT_CMD" != *"--columns=application,branch,version,active"* ]] \
    || [[ "$FLATPAK_COMMIT_CMD" != *"--columns=application,name,branch,version,commit"* ]] \
    || [[ "$FLATPAK_COMMIT_CMD" == *"download-size"* ]] \
    || ! grep -q $'^org\.blender\.Blender\tBlender\tflatpak\t5\.2\t5\.2\tstable\tf97247d9e87d0000111122223333444455556666\t3e510e350730aaaabbbbccccddddeeeeffff1111$' <<<"$FLATPAK_COMMIT_OUT" \
    || ! grep -q $'^org\.blender\.Blender\.Codecs\tCodecs\tflatpak\tstable\tstable\tstable\t2bbd555a9031aaaabbbbccccddddeeeeffff0000\t102459c033d41111222233334444555566667777$' <<<"$FLATPAK_COMMIT_OUT" \
    || ! grep -q $'^org\.telegram\.desktop\tTelegram Desktop\tflatpak\t7\.4\.3\t7\.4\.1\tstable\t3da0f2a359b01111222233334444555566667777\t9fe9eee3feec1111222233334444555566667777$' <<<"$FLATPAK_COMMIT_OUT" \
    || ! grep -q $'^org\.gnome\.Platform\tGNOME Platform\tflatpak\t46\t46\t46\taaa111122223333\tddd444455556666$' <<<"$FLATPAK_COMMIT_OUT" \
    || ! grep -q $'^org\.gnome\.Platform\tGNOME Platform\tflatpak\t47\t47\t47\tbbb222233334444\tccc333344445555$' <<<"$FLATPAK_COMMIT_OUT" \
    || ! grep -q $'^org\.remoteonly\.App\tRemoteOnly\tflatpak\t-\t2\.0\tstable\t\teee555566667777$' <<<"$FLATPAK_COMMIT_OUT"; then
    fail "Milestone 56 AC-2 getListFlatpakCmd commit extraction or download-size exclusion failed (cmd='$FLATPAK_COMMIT_CMD', out='$FLATPAK_COMMIT_OUT')"
else
    pass "Milestone 56 AC-2 getListFlatpakCmd queries active/commit without download-size and preserves per-branch commits"
fi

if [[ "$FAILURES" -ne 0 ]]; then
    echo "TOTAL SHELL SEAM FAILURES: $FAILURES"
    exit 1
fi
echo "ALL SHELL SEAM CHECKS PASSED"
