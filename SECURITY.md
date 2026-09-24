# Security Policy

## Reporting

Please report security issues privately through GitHub's security-advisory feature for the `b3sp0k3/omwhop` repository. Do not include API keys, OAuth tokens, authorization URLs, or other credentials in a report.

## Security boundary

OmWhop `0.1.0` is a read-only Omarchy plugin:

- It runs inside the existing unsandboxed `omarchy-shell` process.
- It invokes only the allow-listed Whop reads documented in `README.md`.
- It does not create, update, publish, cancel, refund, transfer, pay out, or otherwise mutate Whop data.
- Its Python adapter receives arguments as arrays and does not use a shell.
- Normalized plugin output excludes identity email addresses, credentials, and tokens.
- The installer uses no `sudo` and does not modify `/usr/share/omarchy/`.
- Backups are stored outside plugin and agent-skill discovery directories.

Plugins are trusted local code with the permissions of the user running Omarchy. Review the source before installation and install only repositories you trust.
