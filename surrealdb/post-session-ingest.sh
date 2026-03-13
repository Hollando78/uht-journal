#!/usr/bin/env bash
# Post-session ingestion: ingest a single session's journal entry,
# AIRGen requirements, and Substrate facts into SurrealDB.
#
# Called by the dispatcher after each successful session build.
# Idempotent — safe to re-run (all writes use PUT/upsert).
#
# Usage: bash /opt/uht-loop/surrealdb/post-session-ingest.sh <session_number> <journal_file>

set -euo pipefail

SESSION_N="${1:?Usage: post-session-ingest.sh <session_number> <journal_file>}"
JOURNAL_FILE="${2:?Usage: post-session-ingest.sh <session_number> <journal_file>}"

SURREAL_URL="http://127.0.0.1:8787"
SURREAL_NS="uht"
SURREAL_DB="research"
AUTH="root:uht-research-graph"

# Load env for AIRGen / Substrate CLIs
source /opt/uht-loop/.env 2>/dev/null || true
export $(grep -v '^#' /opt/uht-loop/.env | xargs) 2>/dev/null

# --- Helpers ---

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] post-session-ingest: $*"
}

sql() {
  curl -s -X POST "$SURREAL_URL/sql" \
    -u "$AUTH" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$1"
}

put_record() {
  local table="$1" id="$2" payload="$3"
  curl -s -X PUT "$SURREAL_URL/key/${table}/${id}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $SURREAL_NS" \
    -H "surreal-db: $SURREAL_DB" \
    -d "$payload" > /dev/null
}

# ============================================================
# Phase 1: Ingest the journal entry
# ============================================================
log "Phase 1: Ingesting session $SESSION_N from $JOURNAL_FILE"

if [ ! -s "$JOURNAL_FILE" ]; then
  log "ERROR: journal file missing or empty: $JOURNAL_FILE"
  exit 1
fi

# Extract front matter fields
title=$(sed -n 's/^title: *"\(.*\)"/\1/p' "$JOURNAL_FILE" | head -1)
date_field=$(sed -n 's/^date: *"\(.*\)"/\1/p' "$JOURNAL_FILE" | head -1)
time_field=$(sed -n 's/^time: *"\(.*\)"/\1/p' "$JOURNAL_FILE" | head -1)
session_type=$(sed -n 's/^session_type: *\(.*\)/\1/p' "$JOURNAL_FILE" | head -1)
task_class=$(sed -n 's/^task_class: *\(.*\)/\1/p' "$JOURNAL_FILE" | head -1)

# Extract body (everything after second ---)
body=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) next} c>=2{print}' "$JOURNAL_FILE")

# Determine record ID
local_id="s${SESSION_N}"
if [[ "${session_type:-}" == "human" ]]; then
  local_id="op${SESSION_N}"
fi

payload=$(jq -n \
  --argjson number "$SESSION_N" \
  --arg title "${title:-}" \
  --arg date "${date_field:-}" \
  --arg time "${time_field:-}" \
  --arg task_class "${task_class:-}" \
  --arg session_type "${session_type:-}" \
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

put_record "session" "$local_id" "$payload"
log "  session:${local_id} upserted"

# ============================================================
# Phase 2: Ingest AIRGen requirements tagged with this session
# ============================================================
log "Phase 2: Querying AIRGen for session-${SESSION_N} requirements"

ALL_REQS=$(airgen reqs list uht-bot uht-research --json --limit 300 2>/dev/null || echo '{"data":[]}')

# Filter to requirements tagged with this session
SESSION_TAG="session-${SESSION_N}"
SESSION_REQS=$(echo "$ALL_REQS" | jq -c --arg tag "$SESSION_TAG" \
  '[.data[] | select((.tags // [])[] == $tag)]')
REQ_COUNT=$(echo "$SESSION_REQS" | jq 'length')
log "  Found $REQ_COUNT requirements tagged $SESSION_TAG"

EDGE_BATCH=""

# --- Hypotheses ---
echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("HYP-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')

  status="active"
  [[ "$ref" == *"CLOSEDHYPOTHESES"* ]] && status="closed"

  safe_ref=$(echo "$ref" | tr '-' '_')

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --arg status "$status" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, status: $status, tags: $tags}')

  put_record "hypothesis" "$safe_ref" "$payload"
  log "  hypothesis:${safe_ref} upserted"
done

# --- Results ---
echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("RES-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')

  safe_ref=$(echo "$ref" | tr '-' '_')

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  put_record "result" "$safe_ref" "$payload"
  log "  result:${safe_ref} upserted"
done

# --- Observations ---
echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("OBS-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')

  safe_ref=$(echo "$ref" | tr '-' '_')

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  put_record "observation" "$safe_ref" "$payload"
  log "  observation:${safe_ref} upserted"
done

# --- Trait proposals ---
echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("TRT-"))' | while read -r req; do
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  tags=$(echo "$req" | jq -c '.tags // []')

  safe_ref=$(echo "$ref" | tr '-' '_')

  payload=$(jq -n \
    --arg ref "$ref" \
    --arg text "$text" \
    --argjson tags "$tags" \
    '{ref: $ref, text: $text, tags: $tags}')

  put_record "trait_proposal" "$safe_ref" "$payload"
  log "  trait_proposal:${safe_ref} upserted"
done

# ============================================================
# Phase 3: Build RELATE edges for this session
# ============================================================
log "Phase 3: Building graph edges for session $SESSION_N"

EDGE_BATCH=""

# session->produced->hypothesis
while IFS= read -r req; do
  [ -z "$req" ] && continue
  ref=$(echo "$req" | jq -r '.ref')
  safe_ref=$(echo "$ref" | tr '-' '_')
  EDGE_BATCH="${EDGE_BATCH}RELATE session:s${SESSION_N} -> produced -> hypothesis:${safe_ref};"
done < <(echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("HYP-"))')

# session->produced->result + hypothesis->confirmed_by->result
while IFS= read -r req; do
  [ -z "$req" ] && continue
  ref=$(echo "$req" | jq -r '.ref')
  text=$(echo "$req" | jq -r '.text')
  safe_ref=$(echo "$ref" | tr '-' '_')
  EDGE_BATCH="${EDGE_BATCH}RELATE session:s${SESSION_N} -> produced -> result:${safe_ref};"

  hyp_ref=$(echo "$text" | grep -oP 'HYP-[A-Z]+-\d+' | head -1 || echo "")
  if [ -n "$hyp_ref" ]; then
    safe_hyp=$(echo "$hyp_ref" | tr '-' '_')
    EDGE_BATCH="${EDGE_BATCH}RELATE hypothesis:${safe_hyp} -> confirmed_by -> result:${safe_ref};"
  fi
done < <(echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("RES-"))')

# session->produced->observation
while IFS= read -r req; do
  [ -z "$req" ] && continue
  ref=$(echo "$req" | jq -r '.ref')
  safe_ref=$(echo "$ref" | tr '-' '_')
  EDGE_BATCH="${EDGE_BATCH}RELATE session:s${SESSION_N} -> produced -> observation:${safe_ref};"
done < <(echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("OBS-"))')

# session->proposed_trait->trait_proposal
while IFS= read -r req; do
  [ -z "$req" ] && continue
  ref=$(echo "$req" | jq -r '.ref')
  safe_ref=$(echo "$ref" | tr '-' '_')
  EDGE_BATCH="${EDGE_BATCH}RELATE session:s${SESSION_N} -> proposed_trait -> trait_proposal:${safe_ref};"
done < <(echo "$SESSION_REQS" | jq -c '.[] | select(.ref | startswith("TRT-"))')

if [ -n "$EDGE_BATCH" ]; then
  EDGE_COUNT=$(echo "$EDGE_BATCH" | tr -cd ';' | wc -c)
  sql "$EDGE_BATCH" > /dev/null
  log "  Created $EDGE_COUNT RELATE edges"
else
  log "  No edges to create"
fi

# ============================================================
# Phase 4: Ingest Substrate research facts
# ============================================================
log "Phase 4: Upserting Substrate RESEARCH facts"

FACTS=$(uht-substrate facts query --namespace RESEARCH 2>/dev/null || echo '{"facts":[]}')
FACT_COUNT=$(echo "$FACTS" | jq '.facts | length')
log "  Found $FACT_COUNT research facts"

FACT_EDGE_BATCH=""

echo "$FACTS" | jq -c '.facts[]' | while read -r f; do
  subject=$(echo "$f" | jq -r '.subject')
  predicate=$(echo "$f" | jq -r '.predicate')
  object=$(echo "$f" | jq -r '.object')
  uuid=$(echo "$f" | jq -r '.uuid')

  safe_id=$(echo "$uuid" | tr '-' '_')

  payload=$(jq -n \
    --arg subject "$subject" \
    --arg predicate "$predicate" \
    --arg object "$object" \
    '{subject: $subject, predicate: $predicate, object: $object}')

  put_record "fact" "f${safe_id}" "$payload"
done

log "  Facts upserted"

# ============================================================
# Summary
# ============================================================
log "Ingestion complete for session $SESSION_N"
