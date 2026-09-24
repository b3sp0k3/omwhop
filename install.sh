#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="io.github.b3sp0k3.omwhop"
LEGACY_PLUGIN_ID="local.omwhop"
REPOSITORY_URL="${OMWHOP_REPOSITORY_URL:-https://github.com/b3sp0k3/omwhop.git}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DEST="${OMWHOP_PLUGIN_DEST:-$HOME/.config/omarchy/plugins/$PLUGIN_ID}"
SKILL_DEST="${OMWHOP_SKILL_DEST:-$HOME/.agents/skills/omwhop}"
BACKUP_ROOT="${OMWHOP_BACKUP_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/omwhop/backups}"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

SKIP_CLI=0
SKIP_WHOP_SKILL=0
SKIP_PLUGIN=0
SKIP_OMWHOP_SKILL=0
NO_ENABLE=0
KEEP_LEGACY=0
DRY_RUN=0
LOCAL_PLUGIN=0
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
  --keep-legacy           Keep a detected local.omwhop installation after migration
  --local-plugin          Install this checkout instead of cloning the public repo
  -h, --help              Show this help

Environment overrides:
  OMWHOP_REPOSITORY_URL   Git URL used by the published plugin flow
  OMWHOP_PLUGIN_DEST      Plugin destination directory
  OMWHOP_SKILL_DEST       OmWhop skill destination directory
  OMWHOP_BACKUP_ROOT      Backup root outside discovery directories
EOF
}

while (($#)); do
  case "$1" in
    --skip-cli) SKIP_CLI=1 ;;
    --skip-whop-skill) SKIP_WHOP_SKILL=1 ;;
    --skip-plugin) SKIP_PLUGIN=1 ;;
    --skip-omwhop-skill) SKIP_OMWHOP_SKILL=1 ;;
    --no-enable) NO_ENABLE=1 ;;
    --keep-legacy) KEEP_LEGACY=1 ;;
    --local-plugin) LOCAL_PLUGIN=1 ;;
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
  if ((DRY_RUN)); then
    staging="${TMPDIR:-/tmp}/omwhop-stage.dry-run.$$"
  else
    staging="$(mktemp -d "${TMPDIR:-/tmp}/omwhop-stage.XXXXXX")"
  fi

  run mkdir -p "$(dirname -- "$destination")"
  run cp -a -- "$source/." "$staging/"
  run rm -rf -- "$staging/.git"

  if [[ -e "$destination" || -L "$destination" ]]; then
    local component
    local backup
    component="$(basename -- "$destination")"
    backup="$BACKUP_ROOT/$component.$(date +%Y%m%d%H%M%S).$$"
    run mkdir -p -- "$BACKUP_ROOT"
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
    log "Installing the official Whop CLI through npm"
    if ((DRY_RUN)); then
      printf '    $ npm install --global @whop/cli\n'
    else
      command -v npm >/dev/null 2>&1 || {
        echo "error: npm is required to install @whop/cli" >&2
        exit 1
      }
      npm install --global @whop/cli
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
  fi

  if ((LOCAL_PLUGIN)); then
    if ! ((DRY_RUN)); then
      [[ -f "$REPO_ROOT/manifest.json" ]] || {
        echo "error: run this installer from the OmWhop repository" >&2
        exit 1
      }
      omarchy plugin validate "$REPO_ROOT"
    fi

    log "Installing the local OmWhop checkout at $PLUGIN_DEST"
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
    return
  fi

  if ((DRY_RUN)); then
    if [[ -d "$PLUGIN_DEST/.git" ]]; then
      printf '    $ omarchy plugin update %q --yes\n' "$PLUGIN_ID"
    else
      printf '    $ omarchy plugin add %q --enable --yes\n' "$REPOSITORY_URL"
    fi
    return
  fi

  if [[ -d "$PLUGIN_DEST/.git" ]]; then
    log "Updating the Git-managed OmWhop plugin"
    run omarchy plugin update "$PLUGIN_ID" --yes
  elif [[ -e "$PLUGIN_DEST" || -L "$PLUGIN_DEST" ]]; then
    log "Replacing the non-Git OmWhop plugin with the public Git checkout"
    omarchy plugin remove "$PLUGIN_ID" --yes
    run omarchy plugin add "$REPOSITORY_URL" --enable --yes
  elif ((NO_ENABLE)); then
    log "Installing the OmWhop plugin without enabling it"
    run omarchy plugin add "$REPOSITORY_URL" --yes
  else
    log "Installing the OmWhop plugin from $REPOSITORY_URL"
    run omarchy plugin add "$REPOSITORY_URL" --enable --yes
  fi

  if ((!NO_ENABLE)); then
    run omarchy plugin enable "$PLUGIN_ID" "$PLACEMENT"
  fi
}

migrate_legacy_plugin() {
  local legacy_dest="$HOME/.config/omarchy/plugins/$LEGACY_PLUGIN_ID"
  local shell_config="$HOME/.config/omarchy/shell.json"

  if [[ ! -e "$legacy_dest" && ! -L "$legacy_dest" ]]; then
    return
  fi

  log "Detected pre-release plugin $LEGACY_PLUGIN_ID"
  if ((KEEP_LEGACY)); then
    log "Keeping $LEGACY_PLUGIN_ID; disable or remove it manually to avoid duplicate widgets"
    return
  fi

  if ((DRY_RUN)); then
    printf '    $ omarchy plugin remove %q --yes\n' "$LEGACY_PLUGIN_ID"
    return
  fi

  if ! command -v omarchy >/dev/null 2>&1; then
    log "Omarchy is unavailable; keeping $LEGACY_PLUGIN_ID for manual migration"
    return
  fi

  if [[ -f "$shell_config" ]] && command -v jq >/dev/null 2>&1; then
    if ! jq -e --arg id "$PLUGIN_ID" '.bar.layout | to_entries | any(.value[]?; .id == $id)' "$shell_config" >/dev/null 2>&1; then
      log "Permanent plugin is not enabled yet; keeping $LEGACY_PLUGIN_ID until migration completes"
      return
    fi
  fi

  log "Removing the superseded $LEGACY_PLUGIN_ID plugin"
  omarchy plugin remove "$LEGACY_PLUGIN_ID" --yes
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
migrate_legacy_plugin

log "OmWhop installation complete"
cat <<'EOF'

Next steps:
  1. If Whop is not signed in:  whop login --method oauth --format jsonl
  2. If no business is selected: whop quickstart
  3. Click the OmWhop bar icon to open the panel.
  4. Update later with:         omarchy plugin update io.github.b3sp0k3.omwhop

OmWhop is read-only in this release. Use the official Whop CLI or agent skill
for business changes.
EOF
