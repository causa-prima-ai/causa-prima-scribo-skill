# Jurisdictions and Format Selection

Scribo picks the document format from a deterministic priority chain. The LLM should generally let the priority chain do its work and only set `jurisdiction` or `format_override` when the user explicitly asks for a specific format.

> **Phase 1 scope.** Scribo currently emits invoices for **Germany (`DE`)** and the **United States (`US`)** only. The other rows in the per-country table are Phase 2 and reach the pipeline gate (`unsupported_jurisdiction`) before any document is generated. Call `scripts/list_jurisdictions.sh` for the live list.

## Priority chain

Scribo resolves the format by walking these in order, top-first match wins:

1. **`format_override`** in the request body — explicit user override.
2. **`recipient.leitweg_id`** present — auto-selects `xrechnung_ubl` (German federal B2G; broadest Peppol AccessPoint compatibility).
3. **`jurisdiction`** in the request body — explicit user override for the country resolution step.
4. **`sender.country_code`** — the issuer's jurisdiction (regulates the e-invoice flow).
5. **`sender.tax_id`** prefix — when `sender.country_code` is missing or generic.
6. **`recipient.country_code`** — fallback.
7. **`recipient.tax_id`** prefix — final fallback.

If none of these resolve to a supported jurisdiction, Scribo returns `400 invalid_input` with `error.code == "unsupported_jurisdiction"`.

## Per-country defaults

| Country | Default format | Supported alternatives | Phase |
|---|---|---|---|
| **DE** (Germany) | `zugferd_comfort` (B2B) / **`xrechnung_ubl`** (B2G, when `leitweg_id` set) | `zugferd_basic`, `xrechnung_cii` | **1 — live** |
| **US** | `plain_pdf` | — | **1 — live** |
| **FR** (France) | `factur_x` *(Phase 2 — coming soon)* | `peppol_bis_ubl` *(Phase 2)* | 2 |
| **ES** (Spain) | `facturae` *(Phase 2 — coming soon)* | `peppol_bis_ubl` *(Phase 2)* | 2 |
| **BE** (Belgium) | `peppol_bis_ubl` *(Phase 2 — coming soon)* | — | 2 |
| **NL, LU, AT** | `peppol_bis_ubl` *(Phase 2 — coming soon)* | — | 2 |
| **IT, MX, BR** | `plain_pdf` (with submission banner) | — | 2 |

Call `scripts/list_jurisdictions.sh` for the live list — the table above is a snapshot.

## Format reference

| Format | Profile | When you want it |
|---|---|---|
| `zugferd_comfort` | EN 16931 CII embedded in PDF/A-3 | German B2B; "hybrid" — humans see PDF, machines parse XML |
| `zugferd_basic` | Subset of EN 16931 CII in PDF/A-3 | German B2B where recipient accepts the smaller profile |
| `xrechnung_ubl` | German XRechnung in UBL syntax — **default for B2G** | Auto-selected when `leitweg_id` is set. Broadest Peppol compatibility. The download URL streams the UBL XML directly. |
| `xrechnung_cii` | German XRechnung in CII syntax | Only when the recipient procurement portal specifically requires CII (rare). Force via `format_override`; needs a CII workflow provisioned in the upstream Invopop tenant. |
| `peppol_bis_ubl` | Peppol BIS Billing 3.0 (UBL) | Cross-border EU B2B/B2G via the Peppol network — **Phase 2, coming soon** |
| `factur_x` | French Factur-X (= ZUGFeRD profile, French naming) | French B2B/B2G — **Phase 2, coming soon** |
| `facturae` | Spanish Facturae 3.2.2 | Spanish B2B/B2G — **Phase 2, coming soon** |
| `plain_pdf` | Non-structured PDF (no embedded XML) | US, or any jurisdiction without a structured mandate |

## Mandatory fields by format

All formats need everything in the base payload. Format-specific extras:

- **`xrechnung_ubl` / `xrechnung_cii`**: `payment_means` (IBAN, optional BIC + holder name) is mandatory per XRechnung BR-DE-1. Sender `contact_phone` and `contact_name` are required by BR-DE-5/6. `recipient.leitweg_id` is optional — its presence auto-selects UBL but XRechnung B2B between two German companies without a Leitweg-ID is also accepted.
- **Line items with `tax_category_code = E` (exempt)**: `tax_exemption_code` (VATEX-EU-*) is mandatory per BR-E-10. Pick the code by legal basis (VATEX-EU-79-C for Kleinunternehmer § 19 UStG, VATEX-EU-132 for Art. 132 health/education, etc.). AE / K / G / O have well-known VATEX defaults auto-applied server-side.
- **`facturae`** *(Phase 2 — coming soon)*: Sender tax ID must be a Spanish NIF/CIF (`ES…`). Recipient tax ID strongly recommended.
- **`zugferd_*`** / **`factur_x`** *(factur_x: Phase 2 — coming soon)*: Recipient address must be parseable (street, postcode, city) — Invopop validator rejects PO-box-only addresses.
- **`peppol_bis_ubl`** *(Phase 2 — coming soon)*: Both sender and recipient must have an electronic-address scheme (typically the VAT ID acts as it).

If a mandatory field is missing the response includes `validator_summary.errors` with `{ path, rule, message }`. Surface that to the user and ask for the missing field.
