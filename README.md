# Scribo Skill for Claude

Generate EN 16931-compliant e-invoices (XRechnung, ZUGFeRD, Factur-X, Peppol BIS UBL, Spanish Facturae) or a clean US plain PDF from any Claude-powered assistant.

This skill calls the public Scribo HTTP API at `https://scribo.causaprima.ai` directly via small `curl` + `jq` helpers. No MCP server, no npm install, no signup ceremony — the sender's email is the login.

## Requirements

- `bash` (4+), `curl`, `jq`
- Optional: `openssl` (for the auto-minted idempotency key; the script falls back to `sha256sum` or `shasum` if `openssl` is missing)

## Install

### Claude Code (project)

```sh
git clone https://github.com/causaprimaai/scribo-skill .claude/skills/scribo
```

Claude Code auto-discovers any directory under `.claude/skills/` whose `SKILL.md` has frontmatter. Restart your session and ask for an invoice.

### Claude Code (user-global)

```sh
git clone https://github.com/causaprimaai/scribo-skill ~/.claude/skills/scribo
```

### Codex CLI

```sh
git clone https://github.com/causaprimaai/scribo-skill ~/.codex/skills/scribo
```

### Claude Desktop (MCP alternative)

If you prefer the MCP integration over HTTP scripts, install the companion MCP server instead:

```sh
npx @smithery/cli install @causaprima/scribo-mcp --client claude-desktop
```

Or add to `claude_desktop_config.json` manually:

```json
{
  "mcpServers": {
    "scribo": {
      "command": "npx",
      "args": ["-y", "@causaprima/scribo-mcp"]
    }
  }
}
```

Both paths talk to the same `/v1/*` API.

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `SCRIBO_BASE_URL` | `https://scribo.causaprima.ai` | Override for staging or self-hosted |
| `SCRIBO_API_KEY` | _(unset)_ | Forward-compat partner key; not required at v1 |

## Verify install

From any directory:

```sh
~/.claude/skills/scribo/scripts/list_jurisdictions.sh | jq '.[].jurisdiction'
```

Expect a JSON array of supported country codes.

## What's in this skill

- `SKILL.md` — the prompt fragment Claude loads when an invoice request is detected
- `scripts/create_invoice.sh` — POST `/v1/invoices`, auto-mints `Idempotency-Key`
- `scripts/get_invoice.sh` — GET `/v1/invoices/:id`
- `scripts/download_invoice.sh` — GET `/v1/invoices/:id/download`
- `scripts/list_jurisdictions.sh` — GET `/v1/jurisdictions`
- `references/tax-codes.md` — EN 16931 S/Z/E/AE/K/G/O picker guidance
- `references/jurisdictions.md` — Format priority chain + per-country defaults
- `references/troubleshooting.md` — Rate limits, Turnstile, idempotency, validator errors

## License

MIT.
