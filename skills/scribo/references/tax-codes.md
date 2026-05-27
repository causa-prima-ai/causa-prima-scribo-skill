# EN 16931 Tax Category Codes

Scribo never infers the tax category code. The user picks one per line item. This guide helps the LLM ask the right clarifying question and surface the rule violations Scribo's validator will raise if the wrong code is picked.

| Code | Name | Typical use | Schematron constraints |
|---|---|---|---|
| `S` | Standard rated | Normal domestic sale, full VAT rate applies (e.g. DE 19%, FR 20%, ES 21%). | Requires `tax_rate > 0` and `tax_rate ≤ 100`. Requires sender VAT ID. |
| `Z` | Zero rated | Sale taxable in principle but at 0% (rare; some food categories, some UK exports pre-Brexit). | Requires `tax_rate == 0` (Scribo cross-field check). Requires sender VAT ID. |
| `E` | Exempt | Sale exempt from VAT under a specific statute (medical, education, financial services, **Kleinunternehmer § 19 UStG**). | Requires `tax_rate == 0`. **Requires `tax_exemption_code`** (VATEX-EU-* per line) — EN 16931 BR-E-10 + GOBL TAX-COMBO-06 reject the document without it. Optional `tax_exemption_reason` (free-form BT-120 note). |
| `AE` | Reverse charge | Intra-EU B2B services where the recipient self-accounts (most common cross-border case) AND **§ 13b UStG domestic** reverse charge (construction, scrap metal, mobile-phone / chip wholesale, building cleaning, gold, electricity/gas, real-estate). | Requires recipient VAT ID. Requires `tax_rate == 0`. **Scribo auto-applies `VATEX-EU-AE`** — only set `tax_exemption_code` to override. |
| `K` | Intra-community supply | Goods (not services) shipped between EU member states under the intra-community simplification. | Requires recipient VAT ID. Requires `tax_rate == 0`. **Scribo auto-applies `VATEX-EU-IC`**. Recipient must be in a different EU member state. |
| `G` | Free export | Goods exported outside the EU (proof of export required). | Requires `tax_rate == 0`. **Scribo auto-applies `VATEX-EU-G`**. |
| `O` | Outside scope | Services that fall outside the scope of VAT entirely (some B2B services to non-EU customers, certain insurance/financial transactions). | Requires `tax_rate == 0`. **Scribo auto-applies `VATEX-EU-O`**. All-`O` invoices are stripped of every party's VAT identifier per BR-O-02. **XRechnung rejects all-`O` invoices** (BR-DE-14 unrepresentable — switch to AE or G, or drop the leitweg/xrechnung_* override). |

## VATEX codes for category E (the only category that needs a caller-supplied code)

| VATEX code | Use |
|---|---|
| `VATEX-EU-79-C` | **Kleinunternehmer § 19 UStG** (small-business exemption — most common pick for German freelancers + tiny GmbHs). The sender does NOT need a VAT ID for this. |
| `VATEX-EU-132` | Article 132 of the EU VAT Directive — healthcare, education, social services, religious services. |
| `VATEX-EU-143` | Article 143 — importation exemption. |
| `VATEX-EU-148` | Article 148 — intra-Community supply of goods. |
| `VATEX-EU-159` | Article 159. |

The full list is in the [CEF Catalogue](https://docs.peppol.eu/poacc/billing/3.0/codelist/vatex/). Pick by legal basis — Scribo doesn't validate the legal correctness, only that the code matches the VATEX shape.

## Decision flow

Ask the user, in order:

1. Is the user a **Kleinunternehmer** under § 19 UStG (German small business with prior-year turnover ≤ €22,000)?
   - Yes → every line uses `tax_category_code: "E"` with `tax_exemption_code: "VATEX-EU-79-C"`. The sender does not need a VAT ID.
2. Is the supply **domestic** (sender and recipient in the same country)?
   - Yes, normal rate → `S` with the country's standard rate.
   - Yes, special 0% category → `Z`.
   - Yes, statutorily exempt (medical / education / Art. 132) → `E` with `tax_exemption_code: "VATEX-EU-132"`.
   - Yes, but it's a **§ 13b UStG** reverse-charge supply (construction / scrap / mobile-phone wholesale / building cleaning / gold / energy / real estate) → `AE` (Scribo auto-applies `VATEX-EU-AE`). The buyer's VAT ID is still required.
3. Is the supply **intra-EU B2B**?
   - **Goods** crossing an EU border, recipient has a valid VAT ID → `K`.
   - **Services** crossing an EU border, recipient has a valid VAT ID → `AE`.
4. Is the supply **exported outside the EU**?
   - Goods → `G`.
   - Services → `O` (in most cases — confirm with tax advisor). Note: an all-`O` XRechnung is rejected; use `G` if it's goods or `AE` if it's a reverse-charge service.

If the user picks `AE` or `K` without a recipient VAT ID, Invopop's validator returns a schematron error and Scribo's response has `validator_summary.valid == false`. Surface the rule and ask the user for the VAT ID before retrying.

## Payment instructions (BR-DE-1)

For any **XRechnung**-resolved invoice (Leitweg-ID present or `format_override` in `{xrechnung_ubl, xrechnung_cii}`), the request body MUST include `payment_means`:

```json
"payment_means": {
  "type": "credit_transfer",
  "iban": "DE89370400440532013000",
  "bic": "COBADEFFXXX",
  "account_name": "Acme GmbH"
}
```

`bic` and `account_name` are optional; the IBAN is mandatory. ZUGFeRD / plain PDF flows accept `payment_means` too but don't require it.

## What Scribo does *not* do

- No tax-rate inference. The user supplies the percentage.
- No exemption-clause lookup. If the user picks `E`, they pick the matching `VATEX-EU-*` code (the decision flow above lists the common ones).
- No advice on VOEC / IOSS / OSS / MOSS or other special-scheme regimes. Those are out of scope for v1.

Always remind the user: **"verify with your tax advisor"** when the picked code is cross-border or non-`S`.
