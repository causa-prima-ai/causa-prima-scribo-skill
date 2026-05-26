# EN 16931 Tax Category Codes

Scribo never infers the tax category code. The user picks one per line item. This guide helps the LLM ask the right clarifying question and surface the rule violations Scribo's validator will raise if the wrong code is picked.

| Code | Name | Typical use | Schematron constraints |
|---|---|---|---|
| `S` | Standard rated | Normal domestic sale, full VAT rate applies (e.g. DE 19%, FR 20%, ES 21%) | Requires `tax_rate > 0`. Requires sender VAT ID. |
| `Z` | Zero rated | Sale taxable in principle but at 0% (rare; e.g. some UK exports pre-Brexit, some food categories) | Requires `tax_rate == 0`. Requires sender VAT ID. |
| `E` | Exempt | Sale exempt from VAT under a specific statute (e.g. medical, education, financial services). Use **only** when domestic law explicitly exempts the supply. | Requires `tax_rate == 0`. Requires `notes` or item-level note citing the exemption clause for some jurisdictions. |
| `AE` | Reverse charge | Intra-EU B2B services where the recipient self-accounts for VAT (most common cross-border B2B EU services) | Requires recipient VAT ID. Requires `tax_rate == 0`. Sender and recipient must be in different EU member states (or domestic reverse-charge regime applies). |
| `K` | Intra-community supply | Goods (not services) shipped between EU member states under the intra-community simplification | Requires recipient VAT ID. Requires `tax_rate == 0`. Recipient must be in a different EU member state. |
| `G` | Free export | Goods exported outside the EU (proof of export required) | Requires `tax_rate == 0`. |
| `O` | Outside scope | Services that fall outside the scope of VAT entirely (e.g. some B2B services to non-EU customers, certain insurance/financial transactions) | Requires `tax_rate == 0`. |

## Decision flow

Ask the user, in order:

1. Is the supply **domestic** (sender and recipient in the same country)?
   - Yes, normal rate → `S` with the country's standard rate.
   - Yes, special 0% category → `Z`.
   - Yes, statutorily exempt → `E`.
2. Is the supply **intra-EU B2B**?
   - **Goods** crossing an EU border, recipient has a valid VAT ID → `K`.
   - **Services** crossing an EU border, recipient has a valid VAT ID → `AE`.
3. Is the supply **exported outside the EU**?
   - Goods → `G`.
   - Services → `O` (in most cases — confirm with tax advisor).

If the user picks `AE` or `K` without a recipient VAT ID, Invopop's validator returns a schematron error and Scribo's response has `validator_summary.valid == false`. Surface the rule and ask the user for the VAT ID before retrying.

## What Scribo does *not* do

- No tax-rate inference. The user supplies the percentage.
- No exemption-clause lookup. If the user picks `E`, they're responsible for citing the statute in `notes`.
- No advice on VOEC/IOSS, OSS, MOSS, or any other special-scheme regime. Those are out of scope for v1.

Always remind the user: **"verify with your tax advisor"** when the picked code is cross-border or non-`S`.
