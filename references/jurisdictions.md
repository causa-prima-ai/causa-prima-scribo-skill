# Jurisdictions and Format Selection

Scribo picks the document format from a deterministic priority chain. The LLM should generally let the priority chain do its work and only set `jurisdiction` or `format_override` when the user explicitly asks for a specific format.

## Priority chain

Scribo resolves the format by walking these in order, top-first match wins:

1. **`format_override`** in the request body — explicit user override.
2. **`recipient.leitweg_id`** present — forces `xrechnung_cii` (German federal B2G).
3. **`jurisdiction`** in the request body — explicit user override for the country resolution step.
4. **`recipient.country_code`** — country of the recipient.
5. **`recipient.tax_id`** prefix — first two letters of the tax ID (e.g. `DE…` → DE), used when `recipient.country_code` is missing or generic.
6. **`sender.country_code`** — fallback to the sender's country.
7. **`sender.tax_id`** prefix — final fallback.

If none of these resolve to a supported jurisdiction, Scribo returns `400 invalid_input` with `error.code == "unsupported_jurisdiction"`.

## Per-country defaults

| Country | Default format | Supported alternatives |
|---|---|---|
| **DE** (Germany) | `zugferd_comfort` (B2B) / `xrechnung_cii` (B2G, when `leitweg_id` set) | `zugferd_basic`, `xrechnung_ubl`, `peppol_bis_ubl` |
| **FR** (France) | `factur_x` | `peppol_bis_ubl` |
| **ES** (Spain) | `facturae` | `peppol_bis_ubl` |
| **BE** (Belgium) | `peppol_bis_ubl` | — |
| **NL, LU, AT, IT** | `peppol_bis_ubl` | — (IT: PDF only at MVP; SDI submission deferred) |
| **US** | `plain_pdf` | — |
| **MX, BR, IT** | `plain_pdf` (with submission banner) | — |

Call `scripts/list_jurisdictions.sh` for the live list — the table above is a snapshot.

## Format reference

| Format | Profile | When you want it |
|---|---|---|
| `zugferd_comfort` | EN 16931 CII embedded in PDF/A-3 | German B2B; "hybrid" — humans see PDF, machines parse XML |
| `zugferd_basic` | Subset of EN 16931 CII in PDF/A-3 | German B2B where recipient accepts the smaller profile |
| `xrechnung_cii` | German XRechnung in CII syntax | German B2G (federal) — **required** when `leitweg_id` present |
| `xrechnung_ubl` | German XRechnung in UBL syntax | German B2G where recipient prefers UBL |
| `peppol_bis_ubl` | Peppol BIS Billing 3.0 (UBL) | Cross-border EU B2B/B2G via the Peppol network |
| `factur_x` | French Factur-X (= ZUGFeRD profile, French naming) | French B2B/B2G |
| `facturae` | Spanish Facturae 3.2.2 | Spanish B2B/B2G |
| `plain_pdf` | Non-structured PDF (no embedded XML) | US, or any jurisdiction without a structured mandate |

## Mandatory fields by format

All formats need everything in the base payload. Format-specific extras:

- **`xrechnung_cii`**: `recipient.leitweg_id` mandatory.
- **`facturae`**: Sender tax ID must be a Spanish NIF/CIF (e.g. `ES…`). Recipient tax ID strongly recommended.
- **`zugferd_*`, `factur_x`**: Recipient address must be parseable (street, postcode, city) — Invopop validator rejects PO-box-only addresses.
- **`peppol_bis_ubl`**: Both sender and recipient must have an electronic-address scheme (typically the VAT ID acts as it).

If a mandatory field is missing the response includes `validator_summary.errors` with `{ path, rule, message }`. Surface that to the user and ask for the missing field.
