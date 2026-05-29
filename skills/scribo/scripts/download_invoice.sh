#!/usr/bin/env bash
# Download an invoice's bytes.
#
# Usage:
#   download_invoice.sh INVOICE_ID [-o FILE]
#
# What you get depends on the invoice's resolved format:
#   - ZUGFeRD COMFORT / BASIC -> PDF/A-3 with EN 16931 CII XML embedded
#     (the legally binding artifact is the PDF; the XML lives inside it)
#   - XRechnung UBL / CII     -> raw UBL/CII XML (KoSIT / Peppol / federal
#     procurement consume the XML directly; no PDF is returned)
#   - plain_pdf               -> bare PDF
#
# Writes to FILE (default: invoice-INVOICE_ID.pdf — rename to .xml after
# download if the invoice is XRechnung) and prints the absolute path of
# the written file to stdout.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$script_dir/_common.sh"

scribo_require curl jq

invoice_id=""
output_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)
      output_file="${2:-}"
      shift 2 ;;
    --output=*)
      output_file="${1#--output=}"
      shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*)
      printf 'scribo: unknown argument: %s\n' "$1" >&2
      exit 64 ;;
    *)
      if [ -z "$invoice_id" ]; then
        invoice_id="$1"
      else
        printf 'scribo: unexpected positional argument: %s\n' "$1" >&2
        exit 64
      fi
      shift ;;
  esac
done

if [ -z "$invoice_id" ]; then
  printf 'scribo: usage: download_invoice.sh INVOICE_ID [-o FILE]\n' >&2
  exit 64
fi

if [ -z "$output_file" ]; then
  output_file="invoice-${invoice_id}.pdf"
fi

body_file="$(mktemp)"
status_file="$(mktemp)"
trap 'rm -f "$body_file" "$status_file"' EXIT

declare -a headers=()
if [ -n "$SCRIBO_API_KEY" ]; then
  headers+=(-H "Authorization: Bearer $SCRIBO_API_KEY")
fi

set +e
# "${headers[@]+...}" guard: expanding an empty array as "${headers[@]}" under
# `set -u` is an "unbound variable" error on bash 3.2 (the macOS default). The
# guard expands to nothing when no API key set a header.
curl -sS \
  "${headers[@]+"${headers[@]}"}" \
  -o "$body_file" \
  -w '%{http_code}' \
  "${SCRIBO_BASE_URL}/api/v1/invoices/${invoice_id}/download" \
  >"$status_file"
curl_exit=$?
set -e

if [ "$curl_exit" -ne 0 ]; then
  printf 'scribo: curl failed (exit %s)\n' "$curl_exit" >&2
  exit 70
fi

status="$(cat "$status_file")"

if [ "${status:0:1}" != "2" ]; then
  scribo_print_error "$status" "$body_file"
  rc=0
  scribo_exit_for_error "$status" "$body_file" || rc=$?
  exit "$rc"
fi

mv "$body_file" "$output_file"
trap 'rm -f "$status_file"' EXIT

if command -v realpath >/dev/null 2>&1; then
  realpath "$output_file"
else
  printf '%s\n' "$output_file"
fi
