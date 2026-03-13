#!/usr/bin/env bash
# Ingest existing journal entries, AIRGen requirements, and Substrate
# research facts into the SurrealDB research knowledge graph.
#
# Usage: bash /opt/uht-loop/surrealdb/ingest.sh

set -euo pipefail

SURREAL_URL="http://127.0.0.1:8787"
SURREAL_NS="uht"
SURREAL_DB="research"
AUTH="root:uht-research-graph"

POSTS_DIR="/opt/uht-loop/journal/src/content/posts"

# Load env for AIRGen
source /opt/uht-loop/.env 2>/dev/null || true
export $(grep -v '^#' /opt/uht-loop/.env | xargs) 2>/dev/null

sql() {
  local response
  response=$(curl -s -X POST "$SURREAL_URL/sql" \
    -u "$AUTH" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$1")
  # Check for errors
  if echo "$response" | jq -e '.[0].status' 2>/dev/null | grep -q "ERR"; then
    echo "ERROR: $(echo "$response" | jq -r '.[0].result' 2>/dev/null)" >&2
  fi
}

echo "=== Phase 1: Ingest journal entries ==="

for post in "$POSTS_DIR"/*.md; do
  filename=$(basename "$post")

  # Extract front matter fields
  title=$(sed -n 's/^title: *"\(.*\)"/\1/p' "$post" | head -1)
  date=$(sed -n 's/^date: *"\(.*\)"/\1/p' "$post" | head -1)
  session=$(sed -n 's/^session: *\(.*\)/\1/p' "$post" | head -1)
  session_type=$(sed -n 's/^session_type: *\(.*\)/\1/p' "$post" | head -1)
  task_class=$(sed -n 's/^task_class: *\(.*\)/\1/p' "$post" | head -1)
  time_field=$(sed -n 's/^time: *"\(.*\)"/\1/p' "$post" | head -1)

  # Extract session number
  session_num=$(echo "$session" | grep -oP '\d+$' || echo "0")

  [ -z "$title" ] && continue

  # Use operator prefix for human sessions
  local_id="s${session_num}"
  if [[ "$session_type" == "human" ]]; then
    local_id="op${session_num}"
  fi

  # Extract body (everything after second ---)
  body=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) next} c>=2{print}' "$post")

  echo "  $session: $title"

  # Build JSON payload using jq for safe escaping
  payload=$(jq -n \
    --arg title "$title" \
    --arg date "$date" \
    --arg time "${time_field:-}" \
    --arg task_class "$task_class" \
    --arg session_type "$session_type" \
    --argjson number "$session_num" \
    --arg body "$body" \
    '{
      number: $number,
      title: $title,
      date: $date,
      time: $time,
      task_class: $task_class,
      session_type: $session_type,
      body: $body
    }')

  curl -s -X PUT "$SURREAL_URL/key/session/${local_id}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null
done

echo ""
echo "=== Phase 2: Ingest AIRGen requirements ==="

ALL_REQS=$(airgen reqs list uht-bot uht-research --json --limit 300 2>/dev/null || echo '{"data":[]}')
REQ_COUNT=$(echo "$ALL_REQS" | jq '.data | length')
echo "  Found $REQ_COUNT requirements"

# Hypotheses
echo "  -- Hypotheses --"
echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("HYP-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')
  session_tag=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1)
  session_num=$(echo "$session_tag" | grep -oP '\d+$' || echo "")
  section=$(echo "$req" | jq -r '.section // ""')

  status="active"
  [[ "$ref" == *"CLOSEDHYPOTHESES"* ]] && status="closed"

  safe_ref=$(echo "$ref" | tr '-' '_')
  echo "    $ref ($status)"

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --arg status "$status" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, status: $status, tags: $tags}')

  curl -s -X PUT "$SURREAL_URL/key/hypothesis/${safe_ref}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null

  # Link to session
  if [ -n "$session_num" ]; then
    sql "RELATE session:s${session_num} -> produced -> hypothesis:${safe_ref};"
  fi
done

# Results
echo "  -- Results --"
echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("RES-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')
  session_tag=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1)
  session_num=$(echo "$session_tag" | grep -oP '\d+$' || echo "")

  hyp_ref=$(echo "$text" | grep -oP 'HYP-[A-Z]+-\d+' | head -1 || echo "")

  safe_ref=$(echo "$ref" | tr '-' '_')
  echo "    $ref (session $session_num)"

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  curl -s -X PUT "$SURREAL_URL/key/result/${safe_ref}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null

  if [ -n "$session_num" ]; then
    sql "RELATE session:s${session_num} -> produced -> result:${safe_ref};"
  fi

  if [ -n "$hyp_ref" ]; then
    safe_hyp=$(echo "$hyp_ref" | tr '-' '_')
    sql "RELATE hypothesis:${safe_hyp} -> confirmed_by -> result:${safe_ref};"
  fi
done

# Trait proposals
echo "  -- Trait proposals --"
echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("TRT-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')
  session_tag=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1)
  session_num=$(echo "$session_tag" | grep -oP '\d+$' || echo "")

  safe_ref=$(echo "$ref" | tr '-' '_')
  echo "    $ref (session $session_num)"

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  curl -s -X PUT "$SURREAL_URL/key/trait_proposal/${safe_ref}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null

  if [ -n "$session_num" ]; then
    sql "RELATE session:s${session_num} -> proposed_trait -> trait_proposal:${safe_ref};"
  fi
done

# Observations
echo "  -- Observations --"
echo "$ALL_REQS" | jq -c '.data[] | select(.ref | startswith("OBS-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')
  session_tag=$(echo "$req" | jq -r '(.tags // [])[] | select(startswith("session-"))' 2>/dev/null | head -1)
  session_num=$(echo "$session_tag" | grep -oP '\d+$' || echo "")

  safe_ref=$(echo "$ref" | tr '-' '_')
  echo "    $ref (session $session_num)"

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  curl -s -X PUT "$SURREAL_URL/key/observation/${safe_ref}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null

  if [ -n "$session_num" ]; then
    sql "RELATE session:s${session_num} -> produced -> observation:${safe_ref};"
  fi
done

echo ""
echo "=== Phase 3: Ingest research facts ==="

FACTS=$(uht-substrate facts query --namespace RESEARCH 2>/dev/null || echo '{"facts":[]}')
FACT_COUNT=$(echo "$FACTS" | jq '.facts | length')
echo "  Found $FACT_COUNT research facts"

echo "$FACTS" | jq -c '.facts[]' | while read -r f; do
  subject=$(echo "$f" | jq -r '.subject')
  predicate=$(echo "$f" | jq -r '.predicate')
  object=$(echo "$f" | jq -r '.object')
  uuid=$(echo "$f" | jq -r '.uuid')

  safe_id=$(echo "$uuid" | tr '-' '_')
  echo "    $predicate: $subject"

  payload=$(jq -n \
    --arg subject "$subject" \
    --arg predicate "$predicate" \
    --arg object "$object" \
    '{subject: $subject, predicate: $predicate, object: $object}')

  curl -s -X PUT "$SURREAL_URL/key/fact/f${safe_id}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null
done

echo ""
echo "=== Phase 4: Summary ==="

SUMMARY=$(curl -s -X POST "$SURREAL_URL/sql" \
  -u "$AUTH" \
  -H "Accept: application/json" \
  -H "surreal-ns: $SURREAL_NS" \
  -H "surreal-db: $SURREAL_DB" \
  -d "SELECT count() as total FROM session GROUP ALL;
      SELECT count() as total FROM hypothesis GROUP ALL;
      SELECT count() as total FROM result GROUP ALL;
      SELECT count() as total FROM fact GROUP ALL;
      SELECT count() as total FROM trait_proposal GROUP ALL;
      SELECT count() as total FROM observation GROUP ALL;")

echo "  Sessions:        $(echo "$SUMMARY" | jq -r '.[0].result[0].total // 0')"
echo "  Hypotheses:      $(echo "$SUMMARY" | jq -r '.[1].result[0].total // 0')"
echo "  Results:          $(echo "$SUMMARY" | jq -r '.[2].result[0].total // 0')"
echo "  Research facts:  $(echo "$SUMMARY" | jq -r '.[3].result[0].total // 0')"
echo "  Trait proposals: $(echo "$SUMMARY" | jq -r '.[4].result[0].total // 0')"
echo "  Observations:    $(echo "$SUMMARY" | jq -r '.[5].result[0].total // 0')"

echo ""
echo "Ingestion complete."
