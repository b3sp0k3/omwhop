# OmWhop

[![CI](https://github.com/b3sp0k3/omwhop/actions/workflows/ci.yml/badge.svg)](https://github.com/b3sp0k3/omwhop/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

OmWhop is a read-only Whop status widget for the [Omarchy](https://omarchy.org/) shell. It uses the official `whop` CLI as its data source and does not replace or rewrite Whop's CLI.

The first release provides:

- Whop CLI installation and version detection
- Authentication and selected-business status
- Product, plan, active-membership, and app counts (with `+` when the first page is capped)
- Ready Economic Intelligence recommendations when available
- Links to common Whop dashboard areas
- A separate, small `omwhop` integration skill for agents
- The official Whop skill through `whop skills add`

## Requirements

- Omarchy 4.0.4 or another compatible Quattro-based Omarchy installation
- Linux on `x86_64`, `amd64`, `aarch64`, or `arm64`
- `bash`, `curl`, `python3`, and standard Arch user tools
- `qt6-tools` for the local QML test suite
- Git if the project will later be published as an Omarchy plugin repository

The Whop CLI is installed to `~/.local/bin` by Whop's official installer. No `sudo` is used.

## Install

For a local checkout, use the full installer:

```bash
./install.sh
```

For the published repository, install the Omarchy plugin through Omarchy's supported Git flow:

```bash
omarchy plugin add https://github.com/b3sp0k3/omwhop.git --enable
```

Plugin-only installation does not install the Whop CLI or either agent skill. Install those separately when needed:

```bash
curl -fsSL https://whop.com/install.sh | sh
whop skills add
```

For the complete setup, clone the repository and run the bundled installer:

```bash
git clone https://github.com/b3sp0k3/omwhop.git
cd omwhop
./install.sh
```

The full local installer is safe to rerun. It:

1. Installs the official Whop CLI with `https://whop.com/install.sh` when needed.
2. Runs `whop skills add` to install or refresh Whop's official agent skill.
3. Installs the small `omwhop` integration skill under `~/.agents/skills/omwhop`.
4. Validates and installs the plugin under `~/.config/omarchy/plugins/io.github.b3sp0k3.omwhop`.
5. Enables the bar widget in the right section and asks the running shell to rescan plugins.
6. Stores replacement backups under `${XDG_STATE_HOME:-~/.local/state}/omwhop/backups`, outside directories scanned for plugins or skills.

Preview every action without changing anything:

```bash
./install.sh --dry-run
```

Install selected stages only:

```bash
./install.sh --skip-cli
./install.sh --skip-whop-skill
./install.sh --skip-plugin
./install.sh --skip-omwhop-skill
./install.sh --no-enable
./install.sh --placement center
./install.sh --keep-legacy
./install.sh --local-plugin
```

Use `./install.sh --help` for the complete option list. The default full-installer path installs the public plugin with `omarchy plugin add`, so it remains Git-managed and supports `omarchy plugin update`. Maintainers can pass `--local-plugin` to install the current checkout instead.

## Authentication

The installer intentionally does not sign in or change the selected business. Complete those interactive steps separately:

```bash
whop login --method oauth --format jsonl
whop quickstart
```

Open the emitted authorization URL in the browser when requested. OmWhop never handles OAuth secrets.

## Omarchy plugin contract

OmWhop follows the [Omarchy plugin development guide](https://plugins.omarchy.org/develop.html) and the installed Quattro shell reference:

- `manifest.json` is at the repository root and declares only the `bar-widget` kind.
- The ID is permanently namespaced (`io.github.b3sp0k3.omwhop`) and does not use the reserved `omarchy.*` namespace.
- `entryPoints.barWidget` points to `BarWidget.qml`.
- `BarWidget.qml` loads `Panel.qml` internally; the nested panel is not declared as a second plugin kind.
- Both QML files use the same `moduleName`.
- The bar entry point forwards `opened`, `open()`, `close()`, `toggle()`, and `closeForPopoutSwitch()` to the nested panel.
- `KeyboardPanel` anchors to the bar button and `PanelKeyCatcher` handles Escape and panel switching.
- The plugin declares `MIT` licensing, includes this README and `LICENSE`, and has no symlinks.
- No second Quickshell process, privileged operation, network listener, or packaged Omarchy modification is used.

The local installer stages copies outside the live plugin directory, removes source `.git` metadata, validates the checkout, then moves it into the user-owned plugin directory and enables it through Omarchy IPC. Staging and backups remain outside plugin and skill discovery directories, preventing partial copies or old versions from being rediscovered. It does not modify `/usr/share/omarchy/`. Published users should prefer `omarchy plugin add https://github.com/b3sp0k3/omwhop.git --enable`, which keeps the plugin Git-managed and supports `omarchy plugin update`.

### Migrating from the pre-release ID

Earlier development installations used `local.omwhop`. The full installer enables the permanent plugin first and then removes the superseded pre-release plugin through `omarchy plugin remove`. Use `--keep-legacy` to retain it temporarily, or remove it manually after confirming the permanent widget works:

```bash
omarchy plugin remove local.omwhop --yes
```

## Security and mutation boundary

OmWhop is intentionally read-only in version 0.1.0. Its Python adapter invokes only these Whop reads:

- `auth status`
- `products list`
- `plans list`
- `memberships list`
- `apps list`
- `economic-intelligence list`

Arguments are passed as an array, never interpolated into a shell command. The adapter normalizes output before it reaches QML and does not return identity emails, credentials, or tokens.

Future product, plan, checkout, membership, refund, payout, transfer, and dispute actions must not be added without explicit confirmation UI and agent confirmation rules.

## Development

Run all local checks:

```bash
./scripts/test.sh
```

The test script checks:

- Python syntax and adapter CLI behavior
- Normalized status JSON
- Installed or missing Whop CLI handling
- The guide's `bar-widget` manifest contract and MIT declaration
- Shared `moduleName` and required panel lifecycle forwarding
- Exactly one `io.github.b3sp0k3.omwhop` IPC target
- The official Omarchy manifest validator
- QML syntax against the installed `qs.Ui` and `qs.Commons` modules

To test a local plugin checkout without enabling it globally, validate it directly:

```bash
omarchy plugin validate .
./scripts/test.sh
./scripts/omwhop status
```

`qmllint` is included in Arch's `qt6-tools` package. This Omarchy image keeps its binary at `/usr/lib/qt6/bin/qmllint`, so the test script discovers both that path and a normal `qmllint` on `PATH`.

## Runtime inspection and lifecycle checks

After installation, verify discovery and enabled state as described by Omarchy:

```bash
omarchy plugin list --json \
  | jq --arg id "io.github.b3sp0k3.omwhop" '.[] | select(.id == $id)'
```

Exercise the same bar-widget routes Quattro uses:

```bash
omarchy-shell shell summon io.github.b3sp0k3.omwhop '{}'
omarchy-shell shell hide io.github.b3sp0k3.omwhop
```

Before publishing, also test pointer click, Escape, disable, re-enable, shell restart, and removal. Runtime errors are available from:

```bash
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

## Uninstall

Disable and remove the plugin:

```bash
omarchy plugin remove io.github.b3sp0k3.omwhop --yes
```

Remove the integration skill manually if desired:

```bash
rm -rf ~/.agents/skills/omwhop
```

The official Whop CLI and official Whop skill are managed separately and are not removed by OmWhop.

## Files

```text
omwhop/
├── manifest.json          # Omarchy plugin contract
├── BarWidget.qml          # Bar icon, panel lifecycle, adapter process
├── Panel.qml              # Read-only status and safe actions
├── Model.js               # JSON parsing and display helpers
├── install.sh             # Idempotent full installer and legacy migration
├── CHANGELOG.md           # Release history
├── SECURITY.md            # Security boundary and reporting
├── scripts/
│   ├── omwhop             # Allow-listed Python CLI adapter
│   ├── package.sh         # Deterministic release archive and checksum
│   ├── scan-secrets.sh    # Tracked-content secret scan
│   └── test.sh            # Local validation suite
└── skill/omwhop/SKILL.md  # OmWhop-specific agent guidance
```

## Release

The first public release is `v0.1.0`. Release archives are deterministic and include a SHA-256 checksum:

```bash
./scripts/package.sh 0.1.0
(cd dist && sha256sum --check omwhop-v0.1.0.tar.gz.sha256)
```

GitHub releases attach:

- `omwhop-v0.1.0.tar.gz`
- `omwhop-v0.1.0.tar.gz.sha256`

## References

- [Omarchy shell plugins](https://omarchy.org/manual/shell-plugins)
- [Develop a custom Omarchy plugin](https://plugins.omarchy.org/develop.html)
- [Whop CLI installer](https://whop.com/install.sh)
- [Whop Agent Mode](https://docs.whop.com/cli/agent-mode)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
