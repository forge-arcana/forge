#!/usr/bin/env bash
# wawa-status.sh — Git state snapshot for /wawa
# Usage: wawa-status.sh [project-path]
set -euo pipefail

PROJECT="${1:-.}"

echo "## Git State"
echo ""

echo "### Status"
echo '```'
git -C "$PROJECT" status
echo '```'
echo ""

echo "### Recent Commits"
echo '```'
git -C "$PROJECT" log --oneline -5
echo '```'
echo ""

echo "### Uncommitted Changes"
echo '```'
git -C "$PROJECT" diff --stat
echo '```'
