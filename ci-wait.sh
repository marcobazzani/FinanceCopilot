#!/usr/bin/env bash
# Wait for the latest GitHub Actions CI run to complete.
# Usage: ./ci-wait.sh [timeout_minutes]
# Default timeout: 20 minutes

set -euo pipefail

TIMEOUT_MIN="${1:-20}"
TIMEOUT_SEC=$((TIMEOUT_MIN * 60))
POLL_SEC=30

echo "Waiting for latest CI run (timeout: ${TIMEOUT_MIN}m)..."

# Find the latest run on main triggered by push
RUN_ID=$(gh run list --branch main --event push --limit 1 --json databaseId --jq '.[0].databaseId')
if [ -z "$RUN_ID" ]; then
  echo "No CI run found."
  exit 1
fi

echo "Run: https://github.com/$(gh repo view --json nameWithOwner --jq .nameWithOwner)/actions/runs/$RUN_ID"

ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT_SEC ]; do
  STATUS=$(gh run view "$RUN_ID" --json status,conclusion --jq '.status + ":" + (.conclusion // "")')
  case "$STATUS" in
    completed:success)
      echo ""
      gh run view "$RUN_ID" --json jobs --jq '.jobs[] | "  " + (.conclusion // "?") + "  " + .name'
      echo "CI passed in $((ELAPSED/60))m $((ELAPSED%60))s"
      exit 0
      ;;
    completed:*)
      echo ""
      gh run view "$RUN_ID" --json jobs --jq '.jobs[] | "  " + (.conclusion // "?") + "  " + .name'
      echo "CI failed: $STATUS"
      exit 1
      ;;
  esac
  printf "\r  %dm %ds elapsed..." $((ELAPSED/60)) $((ELAPSED%60))
  sleep $POLL_SEC
  ELAPSED=$((ELAPSED + POLL_SEC))
done

echo ""
echo "Timeout after ${TIMEOUT_MIN}m. Run still in progress."
exit 2
