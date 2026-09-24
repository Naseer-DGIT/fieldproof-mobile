#!/usr/bin/env bash
# Refuse to commit on develop or main.
set -euo pipefail
branch=$(git branch --show-current)
case "$branch" in
  develop|main)
    echo "refusing: do not commit directly to $branch"
    echo "switch to sprint/* first"
    exit 1
    ;;
esac
echo "branch ok: $branch"
