#!/usr/bin/env bash
# Fetch a previously generated invoice's metadata + a fresh signed download URL.
#
# Usage:
#   get_invoice.sh INVOICE_ID
#
# Prints the JSON response to stdout.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$script_dir/_common.sh"

scribo_require curl jq

if [ $# -lt 1 ] || [ -z "$1" ]; then
  printf 'scribo: usage: get_invoice.sh INVOICE_ID\n' >&2
  exit 64
fi

invoice_id="$1"
scribo_request GET "/v1/invoices/$invoice_id"
