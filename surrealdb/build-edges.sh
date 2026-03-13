#!/usr/bin/env bash
# Build graph edges between sessions, hypotheses, results, etc.
set -euo pipefail

SURREAL_URL="http://127.0.0.1:8787"
AUTH="root:uht-research-graph"
NS="uht"
DB="research"

source /opt/uht-loop/.env 2>/dev/null || true
export $(grep -v '^#' /opt/uht-loop/.env | xargs) 2>/dev/null

sql() {
  curl -s -X POST "$SURREAL_URL/sql" \
    -u "$AUTH" \
    -H "Accept: application/json" \
    -H "surreal-ns: $NS" \
    -H "surreal-db: $DB" \
    -d "$1"
}

ALL_REQS=$(airgen reqs list uht-bot uht-research --json --limit 300 2>/dev/null || echo '{"data":[]}')

BATCH=""

# Session -> Hypothesis edges
echo "Building session -> hypothesis edges..."
while IFS= read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  session_num=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1 | grep -oP '\d+$' || echo "")
  safe_ref=$(echo "$ref" | tr '-' '_')
  [ -n "$session_num" ] && BATCH="${BATCH}RELATE session:s${session_num} -> produced -> hypothesis:${safe_ref};"
done < <(echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("HYP-"))')

# Session -> Result edges + Hypothesis -> Result edges
echo "Building session -> result and hypothesis -> result edges..."
while IFS= read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  session_num=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1 | grep -oP '\d+$' || echo "")
  safe_ref=$(echo "$ref" | tr '-' '_')
  hyp_ref=$(echo "$text" | grep -oP 'HYP-[A-Z]+-\d+' | head -1 || echo "")

  [ -n "$session_num" ] && BATCH="${BATCH}RELATE session:s${session_num} -> produced -> result:${safe_ref};"

  if [ -n "$hyp_ref" ]; then
    safe_hyp=$(echo "$hyp_ref" | tr '-' '_')
    BATCH="${BATCH}RELATE hypothesis:${safe_hyp} -> confirmed_by -> result:${safe_ref};"
  fi
done < <(echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("RES-"))')

# Session -> Trait proposal edges
echo "Building session -> trait_proposal edges..."
while IFS= read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  session_num=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1 | grep -oP '\d+$' || echo "")
  safe_ref=$(echo "$ref" | tr '-' '_')
  [ -n "$session_num" ] && BATCH="${BATCH}RELATE session:s${session_num} -> proposed_trait -> trait_proposal:${safe_ref};"
done < <(echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("TRT-"))')

# Session -> Observation edges
echo "Building session -> observation edges..."
while IFS= read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  session_num=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1 | grep -oP '\d+$' || echo "")
  safe_ref=$(echo "$ref" | tr '-' '_')
  [ -n "$session_num" ] && BATCH="${BATCH}RELATE session:s${session_num} -> produced -> observation:${safe_ref};"
done < <(echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("OBS-"))')

echo "Executing $(echo "$BATCH" | tr -cd ';' | wc -c) RELATE statements..."
RESULT=$(sql "$BATCH")
ERRORS=$(echo "$RESULT" | jq '[.[] | select(.status == "ERR")] | length')
echo "  Errors: $ERRORS"

# Verify
echo ""
echo "=== Edge counts ==="
sql "SELECT count() AS total FROM produced GROUP ALL;
     SELECT count() AS total FROM confirmed_by GROUP ALL;
     SELECT count() AS total FROM proposed_trait GROUP ALL;" | jq -r '
  .[0].result[0].total as $p |
  .[1].result[0].total as $c |
  .[2].result[0].total as $t |
  "  produced: \($p)\n  confirmed_by: \($c)\n  proposed_trait: \($t)"'

echo ""
echo "=== Sample query: What did session 117 produce? ==="
sql "SELECT ->produced->hypothesis.ref AS hypotheses, ->produced->result.ref AS results FROM session:s117;" | jq '.[0].result[0]'
