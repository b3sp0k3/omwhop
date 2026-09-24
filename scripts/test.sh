#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v omarchy >/dev/null 2>&1 || fail "omarchy is required"

python3 -m py_compile "$ROOT/scripts/omwhop"
rm -rf -- "$ROOT/scripts/__pycache__"
pass "adapter Python syntax"

[[ -x "$ROOT/scripts/omwhop" ]] || fail "adapter is not executable"
"$ROOT/scripts/omwhop" --help >/dev/null
pass "adapter CLI"

jq -e '
  .schemaVersion == 1 and
  .id == "local.omwhop" and
  .license == "MIT" and
  .kinds == ["bar-widget"] and
  .entryPoints.barWidget == "BarWidget.qml" and
  .barWidget.allowMultiple == false and
  .barWidget.defaultSection == "right"
' "$ROOT/manifest.json" >/dev/null || fail "manifest does not satisfy the Omarchy bar-widget development contract"
pass "Omarchy bar-widget manifest contract"

module_names="$(grep -h 'moduleName: "local.omwhop"' "$ROOT/BarWidget.qml" "$ROOT/Panel.qml" | wc -l)"
[[ "$module_names" -eq 2 ]] || fail "BarWidget.qml and Panel.qml must share moduleName local.omwhop"
pass "shared bar-widget module identity"

for lifecycle in opened open close toggle closeForPopoutSwitch; do
  grep -Eq "(property|function) (bool )?$lifecycle\\b|function $lifecycle\\(" "$ROOT/BarWidget.qml" \
    || fail "BarWidget.qml does not forward the required $lifecycle lifecycle member"
done
pass "bar-widget panel lifecycle forwarding"

ipc_targets="$(grep -R --include='*.qml' -c 'target: "local.omwhop"' "$ROOT" | awk -F: '{ total += $2 } END { print total + 0 }')"
[[ "$ipc_targets" -eq 1 ]] || fail "expected exactly one local.omwhop IpcHandler, found $ipc_targets"
pass "single IPC target"

adapter_output="$($ROOT/scripts/omwhop status)"
jq -e '
  .schemaVersion == 1 and
  (.installed | type == "boolean") and
  (.loggedIn | type == "boolean") and
  (.counts | type == "object") and
  (.countsAreLowerBounds | type == "object") and
  (.recommendations | type == "array") and
  (.warnings | type == "array")
' <<<"$adapter_output" >/dev/null || fail "adapter status output has an invalid shape"
pass "adapter status JSON"

if command -v whop >/dev/null 2>&1; then
  jq -e '.installed == true and (.cliVersion | length > 0)' <<<"$adapter_output" >/dev/null \
    || fail "adapter did not detect the installed Whop CLI"
  pass "Whop CLI detection"
else
  jq -e '.installed == false' <<<"$adapter_output" >/dev/null \
    || fail "adapter should report a missing Whop CLI"
  pass "missing Whop CLI handling"
fi

omarchy plugin validate "$ROOT" >/dev/null || fail "Omarchy manifest validation"
pass "Omarchy manifest"

QMLLINT="$(command -v qmllint || true)"
[[ -n "$QMLLINT" ]] || QMLLINT="/usr/lib/qt6/bin/qmllint"
[[ -x "$QMLLINT" ]] || fail "qmllint is required (install qt6-tools or use its full path)"

# Omarchy's documented `-I "$OMARCHY_PATH/shell"` works in the shell runtime but
# not in standalone qmllint on some Qt releases because `qs.*` modules live two
# directories below that root. Give qmllint an import root that mirrors `qs/`.
import_root="$(mktemp -d)"
trap 'rm -rf -- "$import_root"' EXIT
mkdir -p "$import_root/qs"
ln -s "$OMARCHY_PATH/shell/Ui" "$import_root/qs/Ui"
ln -s "$OMARCHY_PATH/shell/Commons" "$import_root/qs/Commons"

"$QMLLINT" -I "$import_root" \
  "$ROOT/BarWidget.qml" \
  "$ROOT/Panel.qml" || fail "qmllint rejected the QML"
pass "qmllint"

[[ "$(id -u)" -ne 0 ]] || fail "tests should not run as root"
pass "non-root test context"

printf '\nAll OmWhop tests passed.\n'
