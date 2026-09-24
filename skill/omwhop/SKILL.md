---
name: omwhop
description: "Operate and troubleshoot the OmWhop Omarchy shell plugin. Use when the user mentions OmWhop, the OmWhop bar widget or panel, io.github.b3sp0k3.omwhop, Whop status in Omarchy, refreshing or opening OmWhop, or diagnosing the plugin. For general Whop business operations, use the official whop skill."
requires_bin: whop
---

# OmWhop

OmWhop is a read-only Omarchy bar widget backed by the official `whop` CLI. Use the official `whop` skill for business operations; use this skill for the desktop integration.

## Safety boundary

- OmWhop's first release is read-only. It must not create, update, publish, cancel, refund, pay out, transfer, or otherwise mutate Whop data.
- The plugin's `scripts/omwhop` adapter is the only component that should invoke the Whop CLI from the plugin UI.
- Keep command arguments in an allow list. Do not expose a generic `run arbitrary Whop command` IPC method.
- Do not display API keys, OAuth tokens, identity emails, or raw error output that may contain secrets.
- Open Whop links with the user's browser; do not fetch action, checkout, authorization, deposit, or session URLs from an agent.

## Architecture

```text
Omarchy bar
  -> BarWidget.qml
  -> Panel.qml
  -> scripts/omwhop status
  -> allow-listed `whop ... --format json` reads
  -> normalized JSON status
```

`BarWidget.qml` owns the adapter process and panel lifecycle. `Panel.qml` renders normalized data and launches read-only browser or terminal actions. `Model.js` contains parsing and display helpers.

## Development workflow

1. Change plugin files in the project checkout.
2. Run `./scripts/test.sh`.
3. Install or refresh the local development copy only when the user asks.
4. Force rediscovery with `omarchy-shell shell rescanPlugins` if hot reload does not apply.
5. Inspect runtime errors with `qs log -p "$OMARCHY_PATH/shell" --tail 100`.

## Troubleshooting order

1. Run `~/.config/omarchy/plugins/io.github.b3sp0k3.omwhop/scripts/omwhop status` directly and inspect its normalized JSON. The plugin invokes this bundled adapter; it is not a global executable. Pre-release installations used `local.omwhop`; migrate with the repository's `install.sh` before troubleshooting the permanent ID.
2. Run `command -v whop && whop --version`.
3. Run `whop auth status --format json`.
4. Confirm the selected business with `whop auth account --list true --format json`.
5. Run `omarchy plugin validate <plugin-directory>`.
6. Run `./scripts/test.sh` in the source checkout, or run `qmllint` with an import root that mirrors Omarchy's `qs/Ui` and `qs/Commons` modules.
7. Check `omarchy plugin list --json` for `io.github.b3sp0k3.omwhop`.
8. Check Quickshell logs for QML or process errors.

## IPC contract

The plugin exposes `io.github.b3sp0k3.omwhop` with read-only lifecycle methods:

- `open`, `close`, `show`, `hide`, `toggle`
- `refresh`
- `status`

Do not add mutating Whop methods to this IPC surface in the read-only release.

## Source of truth

- Whop CLI behavior: live `whop --help`, command-specific `--help`, and `--schema`
- Omarchy plugin lifecycle and config: the installed `$OMARCHY_PATH/shell/README.md`
- Official Whop agent guidance: the `whop` skill synced by `whop skills add`
