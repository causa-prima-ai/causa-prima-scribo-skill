#!/usr/bin/env bash
# List supported jurisdictions and their default formats.
#
# Usage:
#   list_jurisdictions.sh
#
# Prints the JSON array to stdout.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$script_dir/_common.sh"

scribo_require curl jq

scribo_request GET /api/v1/jurisdictions
