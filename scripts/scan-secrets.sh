#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v rg >/dev/null 2>&1 || fail "ripgrep is required"

patterns=(
  'gh[pousr]_[A-Za-z0-9_]{20,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'whop_(live|test)_[A-Za-z0-9_-]{16,}'
  'sk-[A-Za-z0-9_-]{20,}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
)

for pattern in "${patterns[@]}"; do
  if git -C "$ROOT" grep -nE "$pattern" HEAD -- . ':!scripts/scan-secrets.sh' >/dev/null 2>&1; then
    git -C "$ROOT" grep -nE "$pattern" HEAD -- . ':!scripts/scan-secrets.sh' >&2
    fail "possible secret detected"
  fi
done

if git -C "$ROOT" grep -nE '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' HEAD -- \
  ':!LICENSE' ':!README.md' ':!skill/**' ':!scripts/scan-secrets.sh' >/dev/null 2>&1; then
  git -C "$ROOT" grep -nE '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' HEAD -- \
    ':!LICENSE' ':!README.md' ':!skill/**' ':!scripts/scan-secrets.sh' >&2
  fail "possible personal email address detected"
fi

printf 'PASS: no common secrets or personal email addresses found in tracked release content\n'
