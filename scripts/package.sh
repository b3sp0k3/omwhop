#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(jq -r '.version' "$ROOT/manifest.json")}"
ARCHIVE="omwhop-v${VERSION}"
DIST="$ROOT/dist"
ARCHIVE_PATH="$DIST/$ARCHIVE.tar.gz"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v gzip >/dev/null 2>&1 || fail "gzip is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
  || fail "invalid release version: $VERSION"
[[ "$(jq -r '.version' "$ROOT/manifest.json")" == "$VERSION" ]] \
  || fail "requested version does not match manifest.json"

git -C "$ROOT" diff --quiet || fail "working tree has unstaged changes"
git -C "$ROOT" diff --cached --quiet || fail "working tree has staged changes"

tag="v$VERSION"
if git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  tag_commit="$(git -C "$ROOT" rev-list -n1 "$tag")"
  head_commit="$(git -C "$ROOT" rev-parse HEAD)"
  [[ "$tag_commit" == "$head_commit" ]] || fail "$tag does not point at HEAD"
fi

rm -rf -- "$DIST"
mkdir -p -- "$DIST"

git -C "$ROOT" archive \
  --format=tar \
  --prefix="$ARCHIVE/" \
  HEAD | gzip -9n >"$ARCHIVE_PATH"

(
  cd "$DIST"
  sha256sum "$(basename -- "$ARCHIVE_PATH")" >"$(basename -- "$CHECKSUM_PATH")"
)

tar -tzf "$ARCHIVE_PATH" | grep -q "^$ARCHIVE/manifest.json$" \
  || fail "release archive is missing manifest.json"
tar -tzf "$ARCHIVE_PATH" | grep -q "^$ARCHIVE/install.sh$" \
  || fail "release archive is missing install.sh"
tar -tzf "$ARCHIVE_PATH" | grep -q "^$ARCHIVE/scripts/omwhop$" \
  || fail "release archive is missing scripts/omwhop"
tar -tzf "$ARCHIVE_PATH" | grep -q "^$ARCHIVE/skill/omwhop/SKILL.md$" \
  || fail "release archive is missing the OmWhop skill"

(
  cd "$DIST"
  sha256sum --check "$(basename -- "$CHECKSUM_PATH")"
)

printf 'Created %s\n' "$ARCHIVE_PATH"
printf 'Created %s\n' "$CHECKSUM_PATH"
