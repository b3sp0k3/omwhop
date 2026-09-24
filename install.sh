#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="local.omwhop"
WHOP_INSTALLER_URL="${OMWHOP_WHOP_INSTALLER_URL:-https://whop.com/install.sh}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DEST="${OMWHOP_PLUGIN_DEST:-$HOME/.config/omarchy/plugins/$PLUGIN_ID}"
SKILL_DEST="${OMWHOP_SKILL_DEST:-$HOME/.agents/skills/omwhop}"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

SKIP_CLI=0
SKIP_WHOP_SKILL=0
SKIP_PLUGIN=0
SKIP_OMWHOP_SKILL=0
NO_ENABLE=0
DRY_RUN=0
PLACEMENT="right"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install the Whop CLI, official Whop agent skill, OmWhop Omarchy plugin,
and the small OmWhop integration skill.

Options:
  --skip-cli             Do not install or update the Whop CLI
  --skip-whop-skill       Do not run `whop skills add`
  --skip-plugin           Do not install the Omarchy plugin
  --skip-omwhop-skill     Do not install the OmWhop integration skill
  --no-enable             Install the plugin but do not add it to the bar
  --placement SECTION     Bar placement: left, center, or right (default: right)
  --dry-run               Print actions without changing files or configuration
  -h, --help              Show this help

Environment overrides:
  OMWHOP_PLUGIN_DEST      Plugin destination directory
  OMWHOP_SKILL_DEST       OmWhop skill destination directory
  OMWHOP_WHOP_INSTALLER_URL
                          Official installer URL (default: https://whop.com/install.sh)
EOF
}

while (($#)); do
  case "$1" in
    --skip-cli) SKIP_CLI=1 ;;
    --skip-whop-skill) SKIP_WHOP_SKILL=1 ;;
    --skip-plugin) SKIP_PLUGIN=1 ;;
    --skip-omwhop-skill) SKIP_OMWHOP_SKILL=1 ;;
    --no-enable) NO_ENABLE=1 ;;
    --placement)
      [[ $# -ge 2 ]] || { echo "error: --placement requires a value" >&2; exit 2; }
      PLACEMENT="$2"
      shift
      ;;
    --placement=*) PLACEMENT="${1#*=}" ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$PLACEMENT" in
  left|center|right) ;;
  *) echo "error: placement must be left, center, or right" >&2; exit 2 ;;
esac

log() {
  printf '==> %s\n' "$*"
}

run() {
  if ((DRY_RUN)); then
    printf '    $'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

copy_tree() {
  local source="$1"
  local destination="$2"
  local staging
  staging="$(mktemp -d "${TMPDIR:-/tmp}/omwhop-stage.XXXXXX")"

  run mkdir -p "$(dirname -- "$destination")"
  run cp -a -- "$source/." "$staging/"

  if [[ -e "$destination" || -L "$destination" ]]; then
    local backup="${destination}.backup.$(date +%Y%m%d%H%M%S)"
    run mv -- "$destination" "$backup"
    log "Backed up $destination to $backup"
  fi

  run mv -- "$staging" "$destination"
}

install_cli() {
  if ((SKIP_CLI)); then
    log "Skipping Whop CLI installation"
    return
  fi

  if command -v whop >/dev/null 2>&1; then
    log "Whop CLI is already installed; checking it"
  else
    log "Installing the official Whop CLI"
    if ((DRY_RUN)); then
      printf '    $ curl -fsSL %q | sh\n' "$WHOP_INSTALLER_URL"
    else
      command -v curl >/dev/null 2>&1 || {
        echo "error: curl is required to install Whop" >&2
        exit 1
      }
      curl -fsSL "$WHOP_INSTALLER_URL" | sh
    fi
  fi

  export PATH="$HOME/.local/bin:$PATH"
  if ! ((DRY_RUN)); then
    command -v whop >/dev/null 2>&1 || {
      echo "error: Whop was installed but is not on PATH; open a new terminal and rerun" >&2
      exit 1
    }
    whop --version
  fi
}

install_whop_skill() {
  if ((SKIP_WHOP_SKILL)); then
    log "Skipping the official Whop agent skill"
    return
  fi

  log "Installing or refreshing the official Whop agent skill"
  if ! command -v whop >/dev/null 2>&1 && ((DRY_RUN)); then
    printf '    $ whop skills add\n'
  else
    run whop skills add
  fi
}

install_plugin() {
  if ((SKIP_PLUGIN)); then
    log "Skipping the Omarchy plugin"
    return
  fi

  if ! ((DRY_RUN)); then
    command -v omarchy >/dev/null 2>&1 || {
      echo "error: Omarchy is required to install the plugin" >&2
      exit 1
    }
    [[ -f "$REPO_ROOT/manifest.json" ]] || {
      echo "error: run this installer from the OmWhop repository" >&2
      exit 1
    }
    omarchy plugin validate "$REPO_ROOT"
  fi

  log "Installing the OmWhop plugin at $PLUGIN_DEST"
  copy_tree "$REPO_ROOT" "$PLUGIN_DEST"

  if ((DRY_RUN)); then
    printf '    $ omarchy-shell shell rescanPlugins\n'
    if ((!NO_ENABLE)); then
      printf '    $ omarchy plugin enable %q %q\n' "$PLUGIN_ID" "$PLACEMENT"
    fi
    return
  fi

  run omarchy-shell shell rescanPlugins
  if ((NO_ENABLE)); then
    log "Plugin installed but not enabled"
  else
    run omarchy plugin enable "$PLUGIN_ID" "$PLACEMENT"
  fi
}

install_omwhop_skill() {
  if ((SKIP_OMWHOP_SKILL)); then
    log "Skipping the OmWhop integration skill"
    return
  fi

  if [[ ! -f "$REPO_ROOT/skill/omwhop/SKILL.md" ]]; then
    echo "error: bundled OmWhop skill is missing" >&2
    exit 1
  fi

  log "Installing the OmWhop integration skill at $SKILL_DEST"
  copy_tree "$REPO_ROOT/skill/omwhop" "$SKILL_DEST"
}

install_cli
install_whop_skill
install_omwhop_skill
install_plugin

log "OmWhop installation complete"
cat <<'EOF'

Next steps:
  1. If Whop is not signed in:  whop login --method oauth --format jsonl
  2. If no business is selected: whop quickstart
  3. Click the OmWhop bar icon to open the panel.

OmWhop is read-only in this release. Use the official Whop CLI or agent skill
for business changes.
EOF
