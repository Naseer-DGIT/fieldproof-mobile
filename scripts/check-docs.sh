#!/usr/bin/env bash
# Fail if any docs/security markdown file still contains placeholder text.
# Excludes the retrospective's own reference to the check.
set -euo pipefail
cd "$(dirname "$0")/.."
hits=$(grep -rnE '<[A-Z_]+>|TBD|PLACEHOLDER|FIXME' docs/security/*.md || true)
if [ -n "$hits" ]; then
  echo "Placeholder text found:"
  echo "$hits"
  exit 1
fi
echo "docs clean"
