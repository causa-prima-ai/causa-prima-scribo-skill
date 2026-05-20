#!/usr/bin/env bash
# Generate a Scribo invoice via POST /api/v1/invoices.
#
# Usage:
#   create_invoice.sh [--from FILE] [--idempotency-key KEY]
#
# Reads a JSON payload from stdin by default, or from FILE if --from is given.
# Prints the JSON response to stdout. Sets exit code by sysexits:
#   0  ok
#   64 invalid input / 4xx (other than validator_failed and rate_limited)
#   65 validator_failed (Invopop schematron rejected the invoice)
#   70 server error / network error
#   75 rate-limited (429)

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$script_dir/_common.sh"

scribo_require curl jq

input_file=""
idempotency_key=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      input_file="${2:-}"
      shift 2 ;;
    --from=*)
      input_file="${1#--from=}"
      shift ;;
    --idempotency-key)
      idempotency_key="${2:-}"
      shift 2 ;;
    --idempotency-key=*)
      idempotency_key="${1#--idempotency-key=}"
      shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      printf 'scribo: unknown argument: %s\n' "$1" >&2
      exit 64 ;;
  esac
done

payload_file="$(mktemp)"
trap 'rm -f "$payload_file"' EXIT

if [ -n "$input_file" ]; then
  if [ ! -r "$input_file" ]; then
    printf 'scribo: cannot read --from file: %s\n' "$input_file" >&2
    exit 64
  fi
  cp "$input_file" "$payload_file"
else
  cat >"$payload_file"
fi

if ! jq -e . <"$payload_file" >/dev/null 2>&1; then
  printf 'scribo: payload is not valid JSON\n' >&2
  exit 64
fi

if [ -z "$idempotency_key" ]; then
  idempotency_key="$(jq -cS . <"$payload_file" | scribo_sha256)"
fi

scribo_request POST /api/v1/invoices \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $idempotency_key" \
  --data-binary "@$payload_file"
