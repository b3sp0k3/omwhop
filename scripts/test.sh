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
  .id == "io.github.b3sp0k3.omwhop" and
  .version == "0.1.0" and
  .author == "b3sp0k3" and
  .license == "MIT" and
  .kinds == ["bar-widget"] and
  .entryPoints.barWidget == "BarWidget.qml" and
  .barWidget.allowMultiple == false and
  .barWidget.defaultSection == "right"
' "$ROOT/manifest.json" >/dev/null || fail "manifest does not satisfy the Omarchy bar-widget development contract"
pass "Omarchy bar-widget manifest contract"

module_names="$(grep -h 'moduleName: "io.github.b3sp0k3.omwhop"' "$ROOT/BarWidget.qml" "$ROOT/Panel.qml" | wc -l)"
[[ "$module_names" -eq 2 ]] || fail "BarWidget.qml and Panel.qml must share moduleName io.github.b3sp0k3.omwhop"
pass "shared bar-widget module identity"

for lifecycle in opened open close toggle closeForPopoutSwitch; do
  grep -Eq "(property|function) (bool )?$lifecycle\\b|function $lifecycle\\(" "$ROOT/BarWidget.qml" \
    || fail "BarWidget.qml does not forward the required $lifecycle lifecycle member"
done
pass "bar-widget panel lifecycle forwarding"

ipc_targets="$(grep -R --include='*.qml' -c 'target: "io.github.b3sp0k3.omwhop"' "$ROOT" | awk -F: '{ total += $2 } END { print total + 0 }')"
[[ "$ipc_targets" -eq 1 ]] || fail "expected exactly one io.github.b3sp0k3.omwhop IpcHandler, found $ipc_targets"
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

bash -n install.sh scripts/*.sh
staging_before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'omwhop-stage.*' -printf '%f\n' | sort)"
"$ROOT/install.sh" --dry-run >/dev/null
staging_after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'omwhop-stage.*' -printf '%f\n' | sort)"
[[ "$staging_before" == "$staging_after" ]] || fail "installer dry-run created staging directories"
grep -Fq 'run rm -rf -- "$staging/.git"' "$ROOT/install.sh" \
  || fail "local plugin install does not strip source .git metadata"
grep -Fq 'omarchy plugin add "$REPOSITORY_URL" --enable --yes' "$ROOT/install.sh" \
  || fail "public installer does not use Omarchy's Git-managed plugin flow"
pass "installer staging safety"

[[ -f "$ROOT/CHANGELOG.md" ]] || fail "CHANGELOG.md is missing"
[[ -f "$ROOT/SECURITY.md" ]] || fail "SECURITY.md is missing"
[[ -x "$ROOT/scripts/package.sh" ]] || fail "scripts/package.sh is not executable"
[[ -x "$ROOT/scripts/scan-secrets.sh" ]] || fail "scripts/scan-secrets.sh is not executable"
grep -Fq 'https://github.com/b3sp0k3/omwhop.git' "$ROOT/README.md" \
  || fail "README.md is missing the published repository URL"
pass "release metadata"

legacy_refs="$(git -C "$ROOT" grep -l 'local\.omwhop' -- ':!README.md' ':!install.sh' ':!scripts/test.sh' ':!CHANGELOG.md' ':!skill/**' 2>/dev/null || true)"
[[ -z "$legacy_refs" ]] || fail "legacy plugin ID remains in active release files: $legacy_refs"
pass "permanent release identity"

[[ "$(id -u)" -ne 0 ]] || fail "tests should not run as root"
pass "non-root test context"

printf '\nAll OmWhop tests passed.\n'
