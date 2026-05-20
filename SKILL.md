---
name: scribo
description: Generate EN 16931-compliant e-invoices (XRechnung, ZUGFeRD, Factur-X, Peppol BIS UBL, Spanish Facturae) or a clean US plain PDF via the public Scribo HTTP API. No signup; the sender's email is the login.
allowed-tools:
  - Read
  - Bash
---

# Scribo — Compliant E-Invoicing

Use Scribo when a user asks to generate, draft, or "create" an invoice. Scribo emits structured machine-readable invoices that satisfy EU mandates (German B2B / Federal B2G, French Factur-X, Spanish Facturae, Belgian Peppol BIS) and can also produce a plain US PDF when no XML is needed.

This skill talks to the public Scribo HTTP API at `https://scribo.causaprima.ai` via small `curl` + `jq` helper scripts. No MCP server or npm install required. Override the base URL with `SCRIBO_BASE_URL` for dev/staging.

## When to use

- "Make me an invoice for …"
- "Generate a ZUGFeRD invoice"
- "I need to bill X for Y hours of work"
- "Create an XRechnung for this German B2G client"
- "Draft a Factur-X for my French client"

## When NOT to use

- Reading existing invoices / OCR / extracting data from a PDF — different tool.
- Tax advice. Scribo does **not** infer the right tax category code; it asks the user to pick one (S/Z/E/AE/K/G/O per EN 16931). See `references/tax-codes.md` only if the user is unsure.
- Sending the invoice to the recipient. The MVP returns a download URL only; the user delivers it themselves.

## Workflow

1. **Collect the six required fields** from the user in a brief conversational pass:
   - **Sender** — legal name, full address, country code (ISO 3166 alpha-2), tax/VAT ID (with country prefix, e.g. `DE123456789`), contact email. The email is the user's login for return visits.
   - **Recipient** — legal name, address, country code; tax/VAT ID optional; `leitweg_id` if it's a German federal B2G recipient (forces XRechnung CII).
   - **Line items** — description, quantity, unit price, tax rate (percent), tax category code. Optional line-level `discount` (`{ type: 'percent' | 'amount', value, reason? }`).
   - **Currency** — ISO 4217 (e.g. `EUR`, `USD`).
   - *Optional* — `jurisdiction` override, `format_override`, `notes` (≤ 1000 chars).
   - *Optional* — `idempotency_key`. If not supplied, the script auto-mints one from a SHA-256 of the payload so accidental retries don't double-bill.
2. **If the user is unsure of the tax category code**, read `references/tax-codes.md` once and offer the right pick. Never guess.
3. **Build the JSON payload** and invoke `scripts/create_invoice.sh` (passes payload on stdin).
4. **Hand the user the result** — `download_url` (signed, 15-minute TTL), the resolved `format`, and the fact that a magic link was emailed to the sender so they can come back later.
5. **On a 4xx/5xx response**, surface the `error.code` and `error.message` from the response envelope. Read `references/troubleshooting.md` if the error is one of: `rate_limited`, `turnstile_required`, `idempotency_key_mismatch`, `validator_failed`.

## Tools

### `scripts/create_invoice.sh` — POST `/api/v1/invoices`

Reads a JSON payload on stdin (or via `--from FILE`). Example:

```sh
cat <<'JSON' | skills/scribo/scripts/create_invoice.sh
{
  "sender": {
    "legal_name": "Causa Prima Germany GmbH",
    "country_code": "DE",
    "address_line1": "Example Allee 1",
    "postcode": "10115",
    "city": "Berlin",
    "tax_id": "DE123456789",
    "contact_email": "billing@causaprima.ai"
  },
  "recipient": {
    "legal_name": "Acme GmbH",
    "country_code": "DE",
    "address_line1": "Hauptstrasse 1",
    "postcode": "10117",
    "city": "Berlin",
    "tax_id": "DE987654321"
  },
  "line_items": [
    {
      "description": "Consulting, 3 days",
      "quantity": "3",
      "unit_code": "DAY",
      "unit_price": "1200.00",
      "tax_rate": "19",
      "tax_category_code": "S"
    }
  ],
  "currency": "EUR"
}
JSON
```

Returns `{ invoice_id, document_id, format, download_url, download_url_expires_at, validator_summary, magic_link_sent }`. The download URL expires after 15 minutes; the magic link arrives at the sender's email and lets them sign back in to re-download later.

Format is picked from the priority chain (UI override → Leitweg-ID → recipient country → recipient tax-ID prefix → sender country → sender tax-ID prefix). See `references/jurisdictions.md` for the full table.

### `scripts/get_invoice.sh INVOICE_ID` — GET `/api/v1/invoices/:id`

Fetch metadata + a fresh signed download URL for a previously generated invoice. Tenant-scoped (the caller's session must own it).

### `scripts/download_invoice.sh INVOICE_ID [-o FILE]` — GET `/api/v1/invoices/:id/download`

Streams the PDF bytes to `-o FILE` (default `invoice-<id>.pdf`).

### `scripts/list_jurisdictions.sh` — GET `/api/v1/jurisdictions`

Returns `[{ jurisdiction, formats, default_format }]`. Useful to confirm a country is supported before collecting recipient data.

## Tax category codes (EN 16931)

User picks; Scribo never infers. One-liners only — read `references/tax-codes.md` for when each applies and which schematron rules it triggers.

- `S` — Standard rated
- `Z` — Zero rated
- `E` — Exempt
- `AE` — Reverse charge (intra-EU B2B services)
- `K` — Intra-community supply
- `G` — Free export, item outside the scope of VAT
- `O` — Services outside the scope of tax

## Format defaults (quick reference)

| Sender→Recipient | Default format |
|---|---|
| DE → DE B2B | ZUGFeRD COMFORT |
| DE → DE B2G (Leitweg-ID present) | XRechnung CII |
| FR → \* | Factur-X |
| ES → \* | Facturae |
| BE → \* | Peppol BIS UBL |
| US → \* | Plain PDF |

Full table and priority chain in `references/jurisdictions.md`.

## Limits

- One generated invoice per call.
- ≤ 500 line items.
- Plain PDF output only for US, IT, MX, BR, and other jurisdictions where the regulatory submission path isn't yet supported (those receive a banner: "this country requires submission via certified provider").
- Negative line amounts → use `discount` instead.
- Total ≤ 0 → rejected (credit notes are a separate document type, deferred).
- Rate limits: 50 invoices/24h per tenant, 200/hour per IP. First generate per IP per hour requires a Cloudflare Turnstile token — only obtainable through the web UI at `scribo.causaprima.ai`. The CLI scripts will surface a `turnstile_required` error in that case and the user should fall back to the web UI for that one call.

## Setup

End-user install instructions live in `README.md`. Three paths: Claude Code project / user skills directory, Claude Desktop via the MCP package, and Codex CLI under `~/.codex/skills/scribo/`.
