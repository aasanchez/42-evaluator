#!/usr/bin/env bash
# update-leaderboard.sh — Upserts a team's score into LEADERBOARD.md
# Usage: bash scoring/update-leaderboard.sh results.json [LEADERBOARD.md]

set -euo pipefail

RESULTS_FILE="${1:-results.json}"
LEADERBOARD="${2:-LEADERBOARD.md}"

if [ ! -f "$RESULTS_FILE" ]; then
  echo "Error: $RESULTS_FILE not found"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is required"
  exit 1
fi

# Extract data from results
TEAM=$(jq -r '.team' "$RESULTS_FILE")
TOTAL=$(jq -r '.summary.total' "$RESULTS_FILE")
MAX_TOTAL=$(jq -r '.summary.maxTotal' "$RESULTS_FILE")
BONUS=$(jq -r '.summary.bonus' "$RESULTS_FILE")
GRAND=$(jq -r '.summary.grandTotal' "$RESULTS_FILE")
COMPLETED=$(jq -r '.completedAt' "$RESULTS_FILE")
DATE=$(echo "$COMPLETED" | cut -d'T' -f1)

# Extract per-trial scores
T1=$(jq -r '.trials[] | select(.trial=="I") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T2=$(jq -r '.trials[] | select(.trial=="II") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T3=$(jq -r '.trials[] | select(.trial=="III") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T4=$(jq -r '.trials[] | select(.trial=="IV") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T5=$(jq -r '.trials[] | select(.trial=="V") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T6=$(jq -r '.trials[] | select(.trial=="VI") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")
T7=$(jq -r '.trials[] | select(.trial=="VII") | .score' "$RESULTS_FILE" 2>/dev/null || echo "0")

# Initialize leaderboard if it doesn't exist
HEADER="# Leaderboard

> Auto-updated by the evaluator.

| Rank | Team | Score | Max | Bonus | Total | I | II | III | IV | V | VI | VII | Last Run |
|------|------|-------|-----|-------|-------|---|----|----|----|----|-----|------|----------|"

if [ ! -f "$LEADERBOARD" ]; then
  echo "$HEADER" > "$LEADERBOARD"
fi

# Build the new row (without rank — we'll add it after sorting)
NEW_ROW="| - | $TEAM | $TOTAL | $MAX_TOTAL | $BONUS | $GRAND | $T1 | $T2 | $T3 | $T4 | $T5 | $T6 | $T7 | $DATE |"

# Create a temp file with all data rows
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# Extract existing data rows (skip header lines), remove the team if it already exists
grep "^|" "$LEADERBOARD" | grep -v "^| Rank" | grep -v "^|---" | grep -v "| $TEAM |" > "$TMPFILE" 2>/dev/null || true

# Add new row
echo "$NEW_ROW" >> "$TMPFILE"

# Sort by Total (column 6) descending and re-rank
# Parse each row, sort by the 6th pipe-delimited field (Total)
SORTED=$(sort -t'|' -k7 -rn "$TMPFILE")

# Rebuild leaderboard
{
  echo "$HEADER"
  RANK=1
  echo "$SORTED" | while IFS= read -r row; do
    if [ -z "$row" ]; then continue; fi
    # Replace the rank placeholder with actual rank
    echo "$row" | sed "s/| [0-9-]* |/| $RANK |/1"
    RANK=$((RANK + 1))
  done
} > "$LEADERBOARD"

echo "Leaderboard updated: $TEAM — $GRAND/$MAX_TOTAL (bonus: $BONUS)"
