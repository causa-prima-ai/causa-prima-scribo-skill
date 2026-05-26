# Scribo Skill for Claude & Codex

Generate EN 16931-compliant e-invoices (XRechnung, ZUGFeRD, Factur-X, Peppol BIS UBL, Spanish Facturae) or a clean US plain PDF from Claude Code, Claude Desktop, or the OpenAI Codex CLI.

This skill calls the public Scribo HTTP API at `https://scribo.causaprima.ai` directly via small `curl` + `jq` helpers. No MCP server, no npm install, no signup ceremony — the sender's email is the login.

## Requirements

- `bash` (4+), `curl`, `jq`
- Optional: `openssl` (for the auto-minted idempotency key; the script falls back to `sha256sum` or `shasum` if `openssl` is missing)

## Install

### Claude Code (recommended)

```sh
/plugin marketplace add causa-prima-ai/scribo-skill
/plugin install scribo-skill@scribo-skill
# or, when the name is unambiguous across your installed marketplaces:
/plugin install scribo-skill
```

The skill activates as `/scribo-skill:scribo` and triggers automatically when you ask Claude to draft or generate an invoice.

### Claude Desktop / claude.ai (coming soon)

We're submitting `scribo-skill` to Anthropic's hosted plugin registry. Once approved, install with one click from the in-app plugin browser.

### OpenAI Codex CLI

Codex CLI reads skills from `~/.codex/skills/`, not from the Claude plugin registry. Clone and copy the inner skill directory:

```sh
git clone https://github.com/causa-prima-ai/scribo-skill /tmp/scribo-skill
cp -r /tmp/scribo-skill/skills/scribo ~/.codex/skills/scribo
```

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `SCRIBO_BASE_URL` | `https://scribo.causaprima.ai` | Override for staging or self-hosted |
| `SCRIBO_API_KEY` | _(unset)_ | Forward-compat partner key; not required at v1 |

## Verify install

After `/plugin install scribo-skill`, ask Claude in any session:

> Generate a test invoice for ACME GmbH (DE) billing Beispiel GmbH (DE) for 3 hours of consulting at €120/h, 19% VAT.

Claude should walk you through the missing fields and call `create_invoice.sh`. For a direct check, the underlying helper script is at `~/.claude/plugins/scribo-skill/skills/scribo/scripts/list_jurisdictions.sh`.

## Repo layout

```
.claude-plugin/
  plugin.json                     # plugin manifest (name, version, description, …)
skills/scribo/
  SKILL.md                        # prompt fragment Claude loads on invoice intent
  scripts/
    _common.sh                    # shared bash helpers (auto-mint idempotency key)
    create_invoice.sh             # POST /api/v1/invoices
    get_invoice.sh                # GET  /api/v1/invoices/:id
    download_invoice.sh           # GET  /api/v1/invoices/:id/download
    list_jurisdictions.sh         # GET  /api/v1/jurisdictions
  references/
    jurisdictions.md              # format priority chain
    tax-codes.md                  # EN 16931 S/Z/E/AE/K/G/O picker guidance
    troubleshooting.md            # rate limits, Turnstile, idempotency, validator errors
```

## Alternative: hosted MCP endpoint

For clients that speak MCP natively (Claude Desktop, Cursor, Cline, ChatGPT App), point at the hosted Scribo MCP server instead of installing this skill:

```json
{
  "mcpServers": {
    "scribo": {
      "transport": "http",
      "url": "https://scribo.causaprima.ai/mcp"
    }
  }
}
```

Both paths talk to the same `/api/v1/*` API.

## License

MIT.
