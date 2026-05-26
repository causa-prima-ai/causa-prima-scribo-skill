#!/usr/bin/env bash
# Generate a Scribo invoice via POST /mcp (JSON-RPC tools/call create_invoice).
#
# Routes through the streamable-http MCP bridge because the public
# POST /api/v1/invoices endpoint gates the first request per IP per hour
# behind a Cloudflare Turnstile challenge that a bash script can't solve.
# The /mcp bridge attaches the trusted internal secret server-side and
# the api skips Turnstile for those callers; per-IP rate limits still
# bind via x-causa-client-ip.
#
# Usage:
#   create_invoice.sh [--from FILE] [--idempotency-key KEY]
#
# Reads a JSON payload from stdin by default, or from FILE if --from is given.
# Prints the (unwrapped) JSON response to stdout. Sets exit code by sysexits:
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
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      printf 'scribo: unknown argument: %s\n' "$1" >&2
      exit 64 ;;
  esac
done

payload_file="$(mktemp)"
envelope_file="$(mktemp)"
response_file="$(mktemp)"
status_file="$(mktemp)"
trap 'rm -f "$payload_file" "$envelope_file" "$response_file" "$status_file"' EXIT

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

# Wrap the CreateInvoiceInput in a JSON-RPC tools/call envelope. The
# server-side scribo-mcp tool schema accepts the same field shape as the
# public /api/v1/invoices request body, plus a top-level idempotency_key
# (the public surface takes it as the Idempotency-Key header instead).
jq --arg ik "$idempotency_key" '{
  jsonrpc: "2.0",
  id: 1,
  method: "tools/call",
  params: {
    name: "create_invoice",
    arguments: (. + { idempotency_key: $ik })
  }
}' <"$payload_file" >"$envelope_file"

# POST to /mcp directly — bypass `scribo_request` because we need the MCP
# JSON-RPC response shape, not the public REST envelope.
auth_header=()
if [ -n "$SCRIBO_API_KEY" ]; then
  auth_header=(-H "Authorization: Bearer $SCRIBO_API_KEY")
fi

set +e
curl -sS \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  ${auth_header[@]+"${auth_header[@]}"} \
  --data-binary "@$envelope_file" \
  -o "$response_file" \
  -w '%{http_code}' \
  "${SCRIBO_BASE_URL}/mcp" \
  >"$status_file"
curl_exit=$?
set -e

if [ "$curl_exit" -ne 0 ]; then
  printf 'scribo: curl failed (exit %s) calling POST /mcp\n' "$curl_exit" >&2
  exit 70
fi
http_status="$(cat "$status_file")"

# Transport-level failure (proxy outage, malformed CORS preflight, etc.).
# MCP servers return JSON-RPC errors with HTTP 200, so a non-2xx here is
# something else.
if [ "${http_status:0:1}" != "2" ]; then
  scribo_print_error "$http_status" "$response_file"
  rc=0
  scribo_exit_for_error "$http_status" "$response_file" || rc=$?
  exit "$rc"
fi

# JSON-RPC error frame. scribo-mcp wraps upstream failures here with the
# api's error.code in the message (e.g. "Invopop validator rejected the
# document (3 issue(s))"). Synthesise a public-API-shaped envelope so the
# shared printer / exit-code mapper Just Work.
if jq -e '.error' <"$response_file" >/dev/null 2>&1; then
  err_code="$(jq -r '.error.code // -32603' <"$response_file")"
  err_message="$(jq -r '.error.message // "MCP tool returned an error."' <"$response_file")"

  case "$err_message" in
    *"validator rejected"*|*"validator_failed"*) code="validator_failed"; status="400" ;;
    *"Rate limit"*|*"rate_limited"*)             code="rate_limited";   status="429" ;;
    *"unsupported_jurisdiction"*)                 code="unsupported_jurisdiction"; status="400" ;;
    *)                                           code="mcp_${err_code}"; status="500" ;;
  esac

  synth_file="$(mktemp)"
  trap 'rm -f "$payload_file" "$envelope_file" "$response_file" "$status_file" "$synth_file"' EXIT
  jq -n --arg code "$code" --arg message "$err_message" '{ error: { code: $code, message: $message } }' >"$synth_file"

  scribo_print_error "$status" "$synth_file"
  rc=0
  scribo_exit_for_error "$status" "$synth_file" || rc=$?
  exit "$rc"
fi

# Tool-level error (post-fix scribo-mcp shape): result.isError + a JSON
# envelope on content[0].text.
if jq -e '.result.isError == true' <"$response_file" >/dev/null 2>&1; then
  tool_envelope_file="$(mktemp)"
  trap 'rm -f "$payload_file" "$envelope_file" "$response_file" "$status_file" "$tool_envelope_file"' EXIT
  jq -r '.result.content[0].text // empty' <"$response_file" >"$tool_envelope_file"

  if jq -e '.error' <"$tool_envelope_file" >/dev/null 2>&1; then
    # Already in public-API envelope shape — print and exit.
    scribo_print_error 400 "$tool_envelope_file"
    rc=0
    scribo_exit_for_error 400 "$tool_envelope_file" || rc=$?
    exit "$rc"
  fi
  if jq -e '.ok == false' <"$tool_envelope_file" >/dev/null 2>&1; then
    # ok=false shape: re-pack into the public envelope.
    synth_file="$(mktemp)"
    trap 'rm -f "$payload_file" "$envelope_file" "$response_file" "$status_file" "$tool_envelope_file" "$synth_file"' EXIT
    jq '{ error: { code: (.error_code // "tool_error"), message: (.error // "Tool returned an error."), details: .validator_details, retry_after_seconds: .retry_after_seconds } | with_entries(select(.value != null)) }' <"$tool_envelope_file" >"$synth_file"
    code="$(jq -r '.error.code' <"$synth_file")"
    case "$code" in
      validator_failed)            http_status=400 ;;
      rate_limited)                http_status=429 ;;
      unsupported_jurisdiction)    http_status=400 ;;
      *)                           http_status=400 ;;
    esac
    scribo_print_error "$http_status" "$synth_file"
    rc=0
    scribo_exit_for_error "$http_status" "$synth_file" || rc=$?
    exit "$rc"
  fi

  printf 'scribo: tool returned isError with no recognised envelope\n' >&2
  head -c 2000 <"$tool_envelope_file" >&2
  printf '\n' >&2
  exit 70
fi

# Success: unwrap result.content[0].text and print as plain JSON, matching
# the shape callers of the previous /api/v1/invoices flow expect.
jq -r '.result.content[0].text // empty' <"$response_file"
