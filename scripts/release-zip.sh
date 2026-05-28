#!/usr/bin/env bash
# Build scribo-skill.zip locally — matches what the release workflow ships.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p dist
# Package the skill folder (skills/scribo) under a top-level `scribo/` dir.
ln -sfn skills/scribo scribo
trap 'rm -f scribo' EXIT
zip -r dist/scribo-skill.zip scribo \
  -x "scribo/.git/*" "scribo/.github/*" "scribo/dist/*"
echo "→ dist/scribo-skill.zip ($(du -h dist/scribo-skill.zip | cut -f1))"
