# OmWhop

OmWhop is a read-only Whop status widget for the [Omarchy](https://omarchy.org/) shell. It uses the official `whop` CLI as its data source and does not replace or rewrite Whop's CLI.

The first release provides:

- Whop CLI installation and version detection
- Authentication and selected-business status
- Product, plan, active-membership, and app counts
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

From this repository:

```bash
./install.sh
```

The installer is safe to rerun. It:

1. Installs the official Whop CLI with `https://whop.com/install.sh` when needed.
2. Runs `whop skills add` to install or refresh Whop's official agent skill.
3. Installs the small `omwhop` integration skill under `~/.agents/skills/omwhop`.
4. Validates and installs the plugin under `~/.config/omarchy/plugins/local.omwhop`.
5. Enables the bar widget in the right section and asks the running shell to rescan plugins.

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
```

Use `./install.sh --help` for the complete option list.

## Authentication

The installer intentionally does not sign in or change the selected business. Complete those interactive steps separately:

```bash
whop login --method oauth --format jsonl
whop quickstart
```

Open the emitted authorization URL in the browser when requested. OmWhop never handles OAuth secrets.

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
- The official Omarchy manifest validator
- QML syntax with `qmllint -I "$OMARCHY_PATH/shell"`

To test a local plugin checkout without enabling it globally, validate it directly:

```bash
omarchy plugin validate .
./scripts/test.sh
./scripts/omwhop status
```

`qmllint` is included in Arch's `qt6-tools` package. This Omarchy image keeps its binary at `/usr/lib/qt6/bin/qmllint`, so the test script discovers both that path and a normal `qmllint` on `PATH`.

## Uninstall

Disable and remove the plugin:

```bash
omarchy plugin remove local.omwhop --yes
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
├── install.sh             # Idempotent dual installer
├── scripts/
│   ├── omwhop             # Allow-listed Python CLI adapter
│   └── test.sh            # Local validation suite
└── skill/omwhop/SKILL.md  # OmWhop-specific agent guidance
```

## References

- [Omarchy shell plugins](https://omarchy.org/manual/shell-plugins)
- [Develop a custom Omarchy plugin](https://plugins.omarchy.org/develop.html)
- [Whop CLI installer](https://whop.com/install.sh)
- [Whop Agent Mode](https://docs.whop.com/cli/agent-mode)
