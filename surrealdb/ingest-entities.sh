#!/usr/bin/env bash
# Ingest all UHT Substrate entities and traits into SurrealDB,
# creating entity->has_trait->trait edges from hex codes.
#
# Usage: bash /opt/uht-loop/surrealdb/ingest-entities.sh

set -euo pipefail

SURREAL_URL="http://127.0.0.1:8787"
AUTH="root:uht-research-graph"
NS="uht"
DB="research"

# Trait definitions (bit number -> name)
declare -A TRAITS=(
  [1]="Physical Object"
  [2]="Synthetic"
  [3]="Biological/Biomimetic"
  [4]="Powered"
  [5]="Structural"
  [6]="Observable"
  [7]="Physical Medium"
  [8]="Active"
  [9]="Intentionally Designed"
  [10]="Outputs Effect"
  [11]="Processes Signals/Logic"
  [12]="State-Transforming"
  [13]="Human-Interactive"
  [14]="System-integrated"
  [15]="Functionally Autonomous"
  [16]="System-Essential"
  [17]="Symbolic"
  [18]="Signalling"
  [19]="Rule-governed"
  [20]="Compositional"
  [21]="Normative"
  [22]="Meta"
  [23]="Temporal"
  [24]="Digital/Virtual"
  [25]="Social Construct"
  [26]="Institutionally Defined"
  [27]="Identity-Linked"
  [28]="Regulated"
  [29]="Economically Significant"
  [30]="Politicised"
  [31]="Ritualised"
  [32]="Ethically Significant"
)

declare -A TRAIT_GROUPS=(
  [1]="physical" [2]="physical" [3]="physical" [4]="physical"
  [5]="physical" [6]="physical" [7]="physical" [8]="physical"
  [9]="functional" [10]="functional" [11]="functional" [12]="functional"
  [13]="functional" [14]="functional" [15]="functional" [16]="functional"
  [17]="abstract" [18]="abstract" [19]="abstract" [20]="abstract"
  [21]="abstract" [22]="abstract" [23]="abstract" [24]="abstract"
  [25]="social" [26]="social" [27]="social" [28]="social"
  [29]="social" [30]="social" [31]="social" [32]="social"
)

sql() {
  curl -s -X POST "$SURREAL_URL/sql" \
    -u "$AUTH" \
    -H "Accept: application/json" \
    -H "surreal-ns: $NS" \
    -H "surreal-db: $DB" \
    -d "$1"
}

put_record() {
  curl -s -X PUT "$SURREAL_URL/key/${1}/${2}" \
    -u "$AUTH" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "surreal-ns: $NS" \
    -H "surreal-db: $DB" \
    -d "$3" > /dev/null
}

# ============================================================
# Phase 0: Define trait table and has_trait relation
# ============================================================
echo "=== Setting up schema ==="

sql "DEFINE TABLE OVERWRITE trait TYPE NORMAL SCHEMAFULL PERMISSIONS FOR select FULL, FOR create, update, delete NONE;
DEFINE FIELD bit ON trait TYPE int;
DEFINE FIELD name ON trait TYPE string;
DEFINE FIELD group_name ON trait TYPE string;
DEFINE FIELD description ON trait TYPE option<string>;
DEFINE INDEX idx_trait_bit ON trait FIELDS bit UNIQUE;
DEFINE TABLE OVERWRITE has_trait TYPE RELATION PERMISSIONS FOR select FULL, FOR create, update, delete NONE;" > /dev/null

echo "  Schema ready"

# ============================================================
# Phase 1: Create 32 trait nodes
# ============================================================
echo "=== Phase 1: Creating 32 trait nodes ==="

for bit in $(seq 1 32); do
  name="${TRAITS[$bit]}"
  group="${TRAIT_GROUPS[$bit]}"
  safe_name=$(echo "$name" | tr ' /' '__' | tr '[:upper:]' '[:lower:]')

  payload=$(jq -n \
    --argjson bit "$bit" \
    --arg name "$name" \
    --arg group_name "$group" \
    '{bit: $bit, name: $name, group_name: $group_name}')

  put_record "trait" "t${bit}" "$payload"
done
echo "  32 traits created"

# ============================================================
# Phase 2: Ingest entities in batches
# ============================================================
echo "=== Phase 2: Ingesting entities ==="

TOTAL=$(uht-substrate entities list --limit 1 2>/dev/null | jq -r '.total // 0')
echo "  Total entities: $TOTAL"

BATCH_SIZE=50
OFFSET=0
ENTITY_COUNT=0
EDGE_COUNT=0

while [ "$OFFSET" -lt "$TOTAL" ]; do
  # Fetch batch
  BATCH=$(uht-substrate entities list --limit $BATCH_SIZE --offset $OFFSET 2>/dev/null)
  COUNT=$(echo "$BATCH" | jq '.entities | length')

  [ "$COUNT" -eq 0 ] && break

  # Process each entity
  RELATE_BATCH=""

  echo "$BATCH" | jq -c '.entities[]' | while IFS= read -r ent; do
    name=$(echo "$ent" | jq -r '.name')
    hex=$(echo "$ent" | jq -r '.hex_code')
    uuid=$(echo "$ent" | jq -r '.uuid')
    desc=$(echo "$ent" | jq -r '.description // ""')

    # Safe ID from UUID
    safe_id=$(echo "$uuid" | tr '-' '_')

    # Count active bits (popcount)
    dec=$((16#${hex}))
    popcount=0
    tmp=$dec
    while [ "$tmp" -gt 0 ]; do
      popcount=$(( popcount + (tmp & 1) ))
      tmp=$(( tmp >> 1 ))
    done

    # Upsert entity
    payload=$(jq -n \
      --arg name "$name" \
      --arg hex "$hex" \
      --arg description "$desc" \
      --argjson popcount "$popcount" \
      '{name: $name, hex: $hex, description: $description, popcount: $popcount}')

    put_record "entity" "e${safe_id}" "$payload"

    # Build has_trait RELATE batch from hex code
    for bit in $(seq 1 32); do
      # Bit numbering: bit 1 = MSB of first hex char
      byte_index=$(( (bit - 1) / 8 ))
      bit_in_byte=$(( 7 - ((bit - 1) % 8) ))
      hex_pair="${hex:$((byte_index * 2)):2}"
      byte_val=$((16#${hex_pair}))

      if (( (byte_val >> bit_in_byte) & 1 )); then
        echo "RELATE entity:e${safe_id} -> has_trait -> trait:t${bit};"
      fi
    done
  done > /tmp/surreal_trait_edges.txt

  # Execute trait edges in batch
  if [ -s /tmp/surreal_trait_edges.txt ]; then
    EDGE_LINES=$(wc -l < /tmp/surreal_trait_edges.txt)
    # Process in chunks of 200 to avoid huge payloads
    split -l 200 /tmp/surreal_trait_edges.txt /tmp/surreal_chunk_
    for chunk in /tmp/surreal_chunk_*; do
      sql "$(cat "$chunk")" > /dev/null
      rm -f "$chunk"
    done
    EDGE_COUNT=$((EDGE_COUNT + EDGE_LINES))
  fi

  ENTITY_COUNT=$((ENTITY_COUNT + COUNT))
  OFFSET=$((OFFSET + BATCH_SIZE))
  echo "  Processed $ENTITY_COUNT / $TOTAL entities ($EDGE_COUNT trait edges)"
done

# ============================================================
# Phase 3: Create entity<->entity edges from research facts
# ============================================================
echo "=== Phase 3: Entity relationship edges from research facts ==="

FACTS=$(uht-substrate facts query --namespace RESEARCH 2>/dev/null || echo '{"facts":[]}')
FACT_EDGES=""

echo "$FACTS" | jq -c '.facts[] | select(.predicate == "HEX_COLLISION" or .predicate == "CROSS_DOMAIN_ANALOG")' | while IFS= read -r f; do
  pred=$(echo "$f" | jq -r '.predicate')
  subject=$(echo "$f" | jq -r '.subject')
  object=$(echo "$f" | jq -r '.object')

  # Subject contains "entity A ↔ entity B"
  entity_a=$(echo "$subject" | sed 's/ ↔ .*//')
  entity_b=$(echo "$subject" | sed 's/.* ↔ //')

  # Look up entity UUIDs
  uuid_a=$(uht-substrate entities list --name "$entity_a" --limit 1 2>/dev/null | jq -r '.entities[0].uuid // empty')
  uuid_b=$(uht-substrate entities list --name "$entity_b" --limit 1 2>/dev/null | jq -r '.entities[0].uuid // empty')

  if [ -n "$uuid_a" ] && [ -n "$uuid_b" ]; then
    safe_a=$(echo "$uuid_a" | tr '-' '_')
    safe_b=$(echo "$uuid_b" | tr '-' '_')

    if [ "$pred" = "HEX_COLLISION" ]; then
      echo "  HEX_COLLISION: $entity_a <-> $entity_b"
      sql "RELATE entity:e${safe_a} -> hex_collision -> entity:e${safe_b} SET hex = '$object';" > /dev/null
    else
      jaccard=$(echo "$object" | grep -oP 'Jaccard: \K[0-9.]+' || echo "0")
      echo "  CROSS_DOMAIN_ANALOG: $entity_a <-> $entity_b (J=$jaccard)"
      sql "RELATE entity:e${safe_a} -> cross_domain_analog -> entity:e${safe_b} SET jaccard = $jaccard;" > /dev/null
    fi
  fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Summary ==="
sql "SELECT count() as total FROM entity GROUP ALL;
     SELECT count() as total FROM trait GROUP ALL;
     SELECT count() as total FROM has_trait GROUP ALL;
     SELECT count() as total FROM hex_collision GROUP ALL;
     SELECT count() as total FROM cross_domain_analog GROUP ALL;" | jq -r '
  .[0].result[0].total as $e |
  .[1].result[0].total as $t |
  .[2].result[0].total as $ht |
  .[3].result[0].total as $hc |
  .[4].result[0].total as $ca |
  "  Entities: \($e)\n  Traits: \($t)\n  has_trait edges: \($ht)\n  hex_collision edges: \($hc)\n  cross_domain_analog edges: \($ca)"'

echo ""
echo "Done."
