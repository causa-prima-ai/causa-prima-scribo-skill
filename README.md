<img width="3840" height="1920" alt="A2 _ Claude Skill" src="https://github.com/user-attachments/assets/e3d5067e-b72f-41fe-bf2f-0c8584ac64f5" />

# Scribo Skill
> Free, AI-native e-invoicing — from Claude, ChatGPT & Codex.

## Contents

- [What is Scribo?](#what-is-scribo)
- [What is the Scribo skill?](#what-is-the-scribo-skill)
- [Getting started](#getting-started)
- [Usage](#usage)
- [Compliance](#compliance)
- [FAQ](#faq)
- [Resources](#resources)
- [License](#license)
- [Previous README](#previous-readme)

## What is Scribo?

Scribo is a free, conversational e-invoicing tool. Describe an invoice in plain language — "bill Acme GmbH €2,400 for May design work" — and it drafts a structured invoice for you to review, download and send directly.

Just ask your AI agent about Scribo: it ships as an MCP server, a CLI, and a Claude/Codex skill, alongside a public HTTP API and a web app. Free forever — no credit card. You just need a sender email.

**Built by Causa Prima** — Scribo is built by [**Causa Prima**](https://causaprima.ai/), a company building agentic AI for the CFO office. It's our first freely available skill — an early glimpse of what we're building.

## What is the Scribo skill?

The Scribo skill teaches your AI assistant to create invoices for you. Add it once, then just ask — _"draft an invoice for 3 days of consulting at €1,200/day"_ — and your assistant gathers the details and hands back a finished, compliant invoice in the chat, ready to download and send. No new app to learn, no forms to fill in.

It works wherever you already work: **Claude** (Claude.ai, Claude Code, Claude Desktop), **ChatGPT**, and the **OpenAI Codex CLI**. Free, no signup — your email is all you need.

### Demo

<!-- TODO: add demo video here -->
_🎥 Demo video coming soon._

## Getting started

### Quickstart

If you use **Claude Code**, you're two commands away:

```sh
/plugin marketplace add causa-prima-ai/causa-prima-scribo-skill
/plugin install scribo-skill@scribo-skill
```

Then just ask:

> Draft an invoice from Example GmbH to Acme GmbH for 3 days of consulting at €1,200/day, 19% VAT.

The skill triggers automatically, asks for anything it's missing, verifies your sender email once (a 6-digit code arrives by email), and returns a downloadable invoice.

On Claude.ai, Claude Desktop, ChatGPT, or Codex CLI instead? Use the matching install method below.

### Setup & prerequisites

**Prerequisites.** Hosted assistants (Claude.ai, Claude Desktop, ChatGPT) need nothing installed. For local installs (Claude Code, Codex CLI) you'll need `bash` 4+, `curl`, and `jq` on your machine (`openssl` optional).

Pick the method that matches how you run your assistant:

| Method | Works with |
|---|---|
| **Plugin install** | Claude Code |
| **`.zip` upload** | Claude.ai, Claude Desktop, ChatGPT |
| **`git clone`** | OpenAI Codex CLI, manual Claude Code |

**Plugin install — Claude Code**

```sh
/plugin marketplace add causa-prima-ai/causa-prima-scribo-skill
/plugin install scribo-skill@scribo-skill
```

The skill activates as `/scribo-skill:scribo` and triggers automatically when you ask to draft an invoice.

**`.zip` upload — Claude.ai, Claude Desktop, ChatGPT**

1. Download `scribo-skill.zip` from the [latest release](https://github.com/causa-prima-ai/causa-prima-scribo-skill/releases/latest).
2. Upload it:
   - **Claude.ai / Claude Desktop** — Settings → Customize → Skills → **Upload skill**.
   - **ChatGPT** — **New skill → Upload from your computer**.

One upload covers new chats on that account.

**`git clone` — Codex CLI, manual Claude Code**

Clone once, then copy the inner `skills/scribo` folder into your assistant's skills directory:

```sh
git clone https://github.com/causa-prima-ai/causa-prima-scribo-skill /tmp/scribo-skill
cp -r /tmp/scribo-skill/skills/scribo ~/.codex/skills/scribo     # Codex CLI
# or  .claude/skills/scribo     (Claude Code — this project)
# or  ~/.claude/skills/scribo   (Claude Code — all projects)
```

`SKILL.md` must end up at `…/scribo/SKILL.md`. Restart your assistant afterward.

**Verify.** Ask your assistant: _"list the jurisdictions Scribo supports."_ You should get back a list of supported countries.

Full install detail (Cowork, team installs, troubleshooting): [scribo.causaprima.ai/docs/skill](https://scribo.causaprima.ai/docs/skill).

## Usage

> 🚧 Being migrated — current usage details are in **[Previous README](#previous-readme)** below.

## Compliance

Scribo emits invoices conforming to **EN 16931**, the European e-invoicing standard, with the relevant national CIUS. Every invoice is validated against the **Invopop**-hosted EN 16931 validator at generate-time — output that fails the rule set never reaches the user.

**Supported formats**

| Jurisdiction | Format | Status |
|---|---|---|
| Germany (B2B) | **ZUGFeRD** COMFORT (PDF/A-3 hybrid + CII XML) | ✅ Live |
| Germany (B2G) | **XRechnung** (UBL / CII) | ✅ Live |
| United States | Plain PDF (no XML, no e-invoice claim) | ✅ Live |
| France | **Factur-X** EN 16931 | 🔜 Coming soon |
| Spain | **Facturae** | 🔜 Coming soon |
| Belgium | **Peppol BIS 3.0** UBL | 🔜 Coming soon |

*Disclaimer: Scribo generates and validates compliant invoice documents. It is **not tax or legal advice** — Scribo does not determine your tax obligations, VAT treatment, or filing requirements.*

## FAQ

<details>
<summary><strong>Is Scribo really free?</strong></summary>

Yes — free forever. No credit card, no subscription, no paywall before your first invoice. You just need a sender email.

</details>

<details>
<summary><strong>Do I need an account or signup?</strong></summary>

No signup form. Scribo uses a magic-link login: you provide a sender email (which the invoice needs anyway), confirm via a one-time link, and you're in.

</details>

<details>
<summary><strong>Which countries and formats are supported?</strong></summary>

Live today: **Germany** — ZUGFeRD (B2B) and XRechnung (B2G) — and the **United States** (plain PDF). Coming next: **France** (Factur-X), **Spain** (Facturae), and **Belgium** (Peppol BIS 3.0).

</details>

<details>
<summary><strong>What does "EN 16931-compliant" actually mean here?</strong></summary>

Every invoice is validated against the **EN 16931-1:2017** rule set (via the Invopop-hosted validator) before it's returned. Output that fails validation never reaches you.

</details>

<details>
<summary><strong>Is the US version compliant?</strong></summary>

Yes. There is no US e-invoicing mandate, so Scribo produces a fully compliant plain PDF.

</details>

<details>
<summary><strong>Does Scribo give tax or legal advice?</strong></summary>

No. Scribo generates and validates compliant invoice *documents*. It does not determine your tax obligations, VAT treatment, or filing requirements.

</details>

<details>
<summary><strong>How do AI agents / LLMs use Scribo?</strong></summary>

Scribo is built to be operated by an agent. It ships as an **MCP server**, a **CLI**, and a **Claude/Codex skill**, plus a public **HTTP API** and a **web app** — all on the same backend. An agent can discover Scribo, create an invoice, and return the file on a user's behalf.

</details>

<details>
<summary><strong>Who builds Scribo?</strong></summary>

[Causa Prima](https://causaprima.ai/) — a company building agentic AI for the CFO office. Operated by Causa Prima Germany GmbH, Munich.

</details>

## Resources

- **Web app** — [scribo.causaprima.ai](https://scribo.causaprima.ai)
- **Documentation** — [scribo.causaprima.ai/docs](https://scribo.causaprima.ai/docs)
- **Compliance & trust** — [scribo.causaprima.ai/compliance](https://scribo.causaprima.ai/compliance)
- **Causa Prima** — [causaprima.ai](https://causaprima.ai)

**Other Scribo surfaces**

- Skill (Claude / Codex) — [`causa-prima-scribo-skill`](https://github.com/causa-prima-ai/causa-prima-scribo-skill) · [docs](https://scribo.causaprima.ai/docs/skill)
- MCP server — [`causa-prima-scribo-mcp`](https://github.com/causa-prima-ai/causa-prima-scribo-mcp) · [docs](https://scribo.causaprima.ai/docs/mcp)
- CLI — [`causa-prima-scribo-cli`](https://github.com/causa-prima-ai/causa-prima-scribo-cli) · [docs](https://scribo.causaprima.ai/docs/cli)
- HTTP API — [`causa-prima-scribo-api-docs`](https://github.com/causa-prima-ai/causa-prima-scribo-api-docs) · [docs](https://scribo.causaprima.ai/docs/api)
- Brand hub — [`causa-prima-scribo`](https://github.com/causa-prima-ai/causa-prima-scribo)

## License

Proprietary — `UNLICENSED`. © Causa Prima Germany GmbH. All rights reserved. Distributed for use against the public Scribo API; not open-source.

---

## Previous README

> **Note:** This repo's README is being migrated to Scribo's shared structure (consistent title, shared sections, and per-surface sections). The content below is the previous README, preserved verbatim — minus the header visual, which now sits at the top of this page. The sections above are being filled in from it.

<details>
<summary>Show previous README</summary>

# Scribo Skill for Claude, ChatGPT & Codex

Generate EN 16931-compliant e-invoices (XRechnung, ZUGFeRD, Factur-X, Peppol BIS UBL, Spanish Facturae) or a clean US plain PDF from Claude.ai, Claude Code, Claude Desktop, Cowork, ChatGPT, or the OpenAI Codex CLI.

This skill calls the public Scribo HTTP API at `https://scribo.causaprima.ai` directly via small `curl` + `jq` helpers. No MCP server, no npm install, no signup ceremony — the sender's email is the login.

## Requirements

- `bash` (4+), `curl`, `jq`
- Optional: `openssl` (for the auto-minted idempotency key; the script falls back to `sha256sum` or `shasum` if `openssl` is missing)

## Install

### Claude Code (recommended)

```sh
/plugin marketplace add causa-prima-ai/causa-prima-scribo-skill
/plugin install scribo-skill@scribo-skill
# or, when the name is unambiguous across your installed marketplaces:
/plugin install scribo-skill
```

The skill activates as `/scribo-skill:scribo` and triggers automatically when you ask Claude to draft or generate an invoice.

### Claude.ai, Claude Desktop, Cowork & ChatGPT — `.zip` upload

Upload the packaged skill once per account; it then works in new chats / sessions across any repo.

1. Download `scribo-skill.zip` from the [latest release](https://github.com/causa-prima-ai/causa-prima-scribo-skill/releases/latest).
2. Add it in your assistant:
   - **Claude.ai / Claude Desktop / Cowork** — **Settings → Customize → Skills → Upload skill** (one upload covers all three on the account).
   - **ChatGPT** — **New skill → Upload from your computer** (see [Skills in ChatGPT](https://help.openai.com/en/articles/20001066-skills-in-chatgpt)); ChatGPT scans the upload before it goes live.
3. Select `scribo-skill.zip`.

The release zip packages the skill as a single top-level `scribo/` directory (so `scribo/SKILL.md` is at the folder root) — exactly the shape both Claude's and ChatGPT's skill uploaders expect. Build the same artifact locally with `scripts/release-zip.sh`.

### OpenAI Codex CLI / manual `git clone`

Codex CLI reads skills from `~/.codex/skills/`, not from the Claude plugin registry. Clone once, then copy the **inner** `skills/scribo` directory to the destination for your surface — `SKILL.md` must land at `…/scribo/SKILL.md`, so never clone the repo root straight into a skills directory:

```sh
git clone https://github.com/causa-prima-ai/causa-prima-scribo-skill /tmp/scribo-skill
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

## License

`UNLICENSED` — proprietary. © Causa Prima Germany GmbH. All rights reserved. Distributed for use against the public Scribo API; not open-source.

</details>