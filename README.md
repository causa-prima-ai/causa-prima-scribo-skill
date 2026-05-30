# Scribo Skill for Claude & Codex

Generate EN 16931-compliant e-invoices (XRechnung, ZUGFeRD, Factur-X, Peppol BIS UBL, Spanish Facturae) or a clean US plain PDF from Claude.ai, Claude Code, Claude Desktop, Cowork, or the OpenAI Codex CLI.

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

### Claude.ai, Claude Desktop & Cowork — `.zip` upload

One upload per account covers Claude.ai web chat, Claude Desktop, and Cowork sessions across any repo:

1. Download `scribo-skill.zip` from the [latest release](https://github.com/causa-prima-ai/scribo-skill/releases/latest).
2. Open **Settings → Customize → Skills** and click **Upload skill**.
3. Select `scribo-skill.zip`; the skill is enabled for new chats / sessions on that account.

The release zip packages the skill under a top-level `scribo/` directory (so `scribo/SKILL.md` sits at the zip root, which is what the Skills uploader expects). Build the same artifact locally with `scripts/release-zip.sh`.

### OpenAI Codex CLI / manual `git clone`

Codex CLI reads skills from `~/.codex/skills/`, not from the Claude plugin registry. Clone once, then copy the **inner** `skills/scribo` directory to the destination for your surface — `SKILL.md` must land at `…/scribo/SKILL.md`, so never clone the repo root straight into a skills directory:

```sh
git clone https://github.com/causa-prima-ai/scribo-skill /tmp/scribo-skill
cp -r /tmp/scribo-skill/skills/scribo ~/.codex/skills/scribo     # Codex CLI
# or .claude/skills/scribo      (Claude Code project / Cowork repo-baked)
# or ~/.claude/skills/scribo    (Claude Code user-global)
```

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `SCRIBO_BASE_URL` | `https://scribo.causaprima.ai` | Override for staging or self-hosted |
| `SCRIBO_API_KEY` | _(unset)_ | Forward-compat partner key; not required at v1 |

## Verify install

After installing (any method above), ask Claude in any session:

> Generate a test invoice for ACME GmbH (DE) billing Beispiel GmbH (DE) for 3 hours of consulting at €120/h, 19% VAT.

Claude should walk you through the missing fields and call `create_invoice.sh`. For a direct check, the underlying helper script is at `~/.claude/plugins/scribo-skill/skills/scribo/scripts/list_jurisdictions.sh`.

## First-time verification

Before Scribo generates the first invoice for a sender email, it proves you own that address. The assistant handles this for you:

1. It builds the invoice and runs `create_invoice.sh`. With no token, the script asks Scribo to email a 6-digit code to your `sender.contact_email` and reports that verification is needed. **The verification email is expected — it's not phishing.** It comes from `verify@scribo.causaprima.ai` and contains a link plus a 6-digit code.
2. The assistant asks you for the code; you paste it back.
3. It redeems the code for a short-lived token and generates the invoice.

The code expires in 15 minutes. One verification covers about 30 minutes of invoices for the same sender, so you won't be re-prompted on every invoice. See the **Verification** section of `skills/scribo/SKILL.md` for the full flow.

## Repo layout

```
.claude-plugin/
  plugin.json                     # plugin manifest (name, version, description, …)
skills/scribo/
  SKILL.md                        # prompt fragment Claude loads on invoice intent
  scripts/
    _common.sh                    # shared bash helpers (auto-mint idempotency key)
    create_invoice.sh             # POST /api/v1/invoices (takes --verification-token)
    request_verification.sh       # POST /api/v1/scribo/email-verifications
    redeem_verification.sh        # POST /api/v1/scribo/email-verifications/:id/redeem
    get_invoice.sh                # GET  /api/v1/invoices/:id
    download_invoice.sh           # GET  /api/v1/invoices/:id/download
    list_jurisdictions.sh         # GET  /api/v1/jurisdictions
  references/
    jurisdictions.md              # format priority chain
    tax-codes.md                  # EN 16931 S/Z/E/AE/K/G/O picker guidance
    troubleshooting.md            # verification, rate limits, Turnstile, idempotency, validator errors
  tests/                          # mock-server.py + smoke.sh (CI only; excluded from the release zip)
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
