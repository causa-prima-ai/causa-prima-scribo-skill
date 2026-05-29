#!/usr/bin/env bash
# Redeem a 6-digit verification code for a verification_token (Scribo-03).
#
# Usage:
#   redeem_verification.sh CHALLENGE_ID CODE
#
# POSTs to /api/v1/scribo/email-verifications/:challenge_id/redeem with the
# code the user copied from the verification email. On success prints the
# JSON { verification_token, expires_at } to stdout. Pass the
# verification_token to create_invoice.sh via --verification-token (or the
# SCRIBO_VERIFICATION_TOKEN env var). The token is reusable for ~30 minutes,
# so one redeem covers several invoices for the same sender email.
#
# All failure modes (wrong code, expired challenge, too many attempts,
# revoked) return a uniform 400 verification_invalid — there is no oracle on
# which one it was. After 5 wrong attempts the challenge is revoked; mint a
# fresh one with request_verification.sh (or re-run create_invoice.sh).
#
# Exit codes:
#   0  ok (verification_token returned)
#   11 wrong / expired / revoked code (verification_invalid) — re-prompt the
#      user for the code and retry (pairs with create_invoice.sh's exit 10)
#   64 bad usage (missing CHALLENGE_ID or CODE)
#   70 server / network error
#   75 rate-limited (429)

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$script_dir/_common.sh"

scribo_require curl jq

if [ $# -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  printf 'scribo: usage: redeem_verification.sh CHALLENGE_ID CODE\n' >&2
  exit 64
fi

challenge_id="$1"
code="$2"
request_body="$(jq -nc --arg code "$code" '{ code: $code }')"

scribo_request POST "/api/v1/scribo/email-verifications/$challenge_id/redeem" \
  -H "Content-Type: application/json" \
  --data-binary "$request_body"
