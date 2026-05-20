# Troubleshooting

All Scribo errors share the envelope:

```json
{
  "error": {
    "code": "...",
    "message": "...",
    "details": {} | []
  }
}
```

The helper scripts exit with sysexits-style codes:

| Exit code | Meaning |
|---|---|
| `0` | OK |
| `64` | Invalid input (4xx with `code` in `invalid_input` family) |
| `65` | Data validation failed (`validator_failed`) |
| `70` | Server error (5xx) |
| `75` | Rate-limited (429) |

## `rate_limited` (429)

Response body:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Rate limit exceeded",
    "retry_after_seconds": 3600,
    "reset_at": "2026-05-11T15:00:00Z",
    "limit_code": "ip" | "tenant" | "email_domain"
  }
}
```

What to tell the user:

- `limit_code: "ip"` — too many requests from this network. Wait `retry_after_seconds` or try from a different network.
- `limit_code: "tenant"` — this sender email has generated 50 invoices in the last 24h. Wait or contact support.
- `limit_code: "email_domain"` — the sender's email domain has hit the soft-block threshold. Use a different domain or contact support.

## `turnstile_required` (403)

The Scribo API requires a Cloudflare Turnstile token on the first generate from a given IP each hour. The helper scripts cannot solve the CAPTCHA. Tell the user:

> "The first invoice from this network this hour needs to go through the web UI at https://scribo.causaprima.ai. Once you've completed one invoice there, subsequent calls from this terminal will work for the next hour."

Subsequent calls within the hour from the same IP do not need the token.

## `idempotency_key_mismatch` (422)

The script auto-mints `Idempotency-Key` from a SHA-256 of the payload, so same-payload retries return the cached response. If the user supplied an `--idempotency-key` explicitly and the payload changed, you'll see:

```json
{
  "error": {
    "code": "idempotency_key_mismatch",
    "message": "Idempotency key already used with different inputs",
    "details": { "diff": [ { "path": "...", "old": "...", "new": "..." } ] }
  }
}
```

Either keep the original payload, or use a fresh idempotency key (or let the script auto-mint one).

## `validator_failed` (400 or 201 with `valid: false`)

Two shapes:

1. **Pre-generation rejection** (400) — required field missing or format-specific constraint violated before Invopop is even called.
2. **Schematron failure** (201, but `validator_summary.valid == false`) — Invopop generated the invoice but the validator flagged rule violations. The PDF/XML is still returned but **the recipient's tax authority may reject it**. The `validator_summary.errors` array has `[ { path, rule, message } ]`.

Common rules:

| Rule | Trigger | Fix |
|---|---|---|
| `BR-CO-09` | Sender VAT ID country prefix doesn't match `sender.country_code` | Correct the prefix or the country code |
| `BR-CO-27` | Sum of line totals doesn't match `unit_price * quantity - discount` | Recompute the line totals client-side |
| `BR-AE-01..10` | `AE` (reverse charge) without recipient VAT ID, or other AE constraints | Provide recipient VAT ID; verify both parties are EU-registered |
| `BR-IC-01..12` | `K` (intra-community) constraints violated | Recipient must be in a different EU member state with valid VAT ID |
| `BR-S-08` | `S` line total tax amount doesn't match the BT-118 grouped tax breakdown | Float precision; the script forwards strings — make sure unit_price is a decimal string |

Surface the `path` and `rule` to the user verbatim. Don't try to rewrite the payload silently — the user needs to know which field they got wrong.

## `unsupported_jurisdiction` (400)

The country chain didn't resolve to a supported jurisdiction. Call `list_jurisdictions.sh` to confirm what's available and re-ask the user.

## `payload_too_large` (413)

More than 500 line items. Split the invoice.

## Generic 5xx

`error.code: "internal_error"`. Retry with the same idempotency key. If it persists, the response includes a `correlation_id` — pass it to support.
