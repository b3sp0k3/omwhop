# Changelog

All notable changes to OmWhop are documented in this file.

## [0.1.0] - 2026-09-24

### Added

- Read-only Omarchy bar widget and panel for Whop business status.
- Selected-business authentication indicator.
- Product, plan, active-membership, and app inventory summaries.
- Ready Whop Economic Intelligence recommendation summaries.
- Safe links to common Whop dashboard areas.
- Official Whop CLI and agent-skill installation through the full installer.
- Separate `omwhop` agent skill for plugin operation and troubleshooting.
- Deterministic release archive and SHA-256 checksum tooling.
- Migration support from the pre-release `local.omwhop` plugin ID.

### Security

- The plugin does not mutate Whop data.
- The adapter invokes an allow-listed set of read-only commands.
- Credentials, identity email addresses, and OAuth tokens are not returned to QML.
- Installation and replacement backups remain outside Omarchy and agent discovery directories.
