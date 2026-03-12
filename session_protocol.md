# Autonomous Session Protocol — universalhex.org research loop
# Executed via: claude --print "$(cat session_protocol.md)"
# CLIs required: airgen-cli, uht-substrate
# SESSION_PROTOCOL_VERSION: 4.1

---

## Environment

The following environment variables must be set on the VPS. Verify
with `airgen projects list $TENANT` and `uht-substrate info` at session start.

```
AIRGEN_API_URL=https://airgen.studio/api
AIRGEN_EMAIL=<email>
AIRGEN_PASSWORD=<password>

UHT_API_URL=https://substrate.universalhex.org/api
UHT_TOKEN=<token>
UHT_API_KEY=<token>
```

Aliases used throughout:
- `TENANT` = `uht-bot`
- `PROJECT` = `uht-research`

---

## Two Systems, Two Roles

**UHT Substrate** — the research engine and queryable knowledge base.
Three layers of data:

1. **Entity graph** — every classified entity with its hex code.
   Populated automatically by `classify`. Currently 2900+ entities.
2. **Research facts** — structured findings stored as subject-predicate-object
   triples in the `RESEARCH` namespace. Queryable by predicate, enabling
   future sessions to build on prior discoveries.
3. **Operational facts** — session counters, timestamps, directives in
   the `CLAUDE` namespace. Ephemeral. Overwritten freely.

**AIRGen** — persistent knowledge store. Every hypothesis, result,
observation, corpus entry, and trait proposal is a versioned requirement
in a structured document with trace links. This is the accumulating
research record. The loop reads AIRGen to build on prior work and writes
AIRGen to record new findings.

### Entity Graph

Every `uht-substrate classify` call automatically stores the entity
in the knowledge graph. Use these commands to explore it:

- `uht-substrate entities list [--name <filter>] [--hex <pattern>] [--limit N] [--format pretty]`
  Browse entities. Filter by name substring or hex pattern. Use `--format pretty`
  for readable output with short UUIDs, hex codes, and description previews.
- `uht-substrate entities find-similar <entity> [--min-traits N] [--limit N]`
  Find entities sharing the most traits. Default min-traits: 20.
- `uht-substrate entities explore <entity> [--metric embedding|hamming|hybrid] [--limit N]`
  Explore semantic neighborhood. Embedding metric finds conceptual
  neighbors; hamming finds hex-code neighbors.
- `uht-substrate entities search-traits [--<trait-name>] [--no-<trait-name>]`
  Search by trait pattern. Find all entities with specific traits on/off.
- `uht-substrate traits [--format pretty]` — list all 32 trait definitions
  with version info.
- `uht-substrate trait-prompts [--format pretty] [--bit N]` — view the
  classification prompt spec, or the full prompt for a specific trait bit.

### Research Facts

When a session discovers a notable relationship between entities, store
it as a fact in the `RESEARCH` namespace. This makes findings queryable
by future sessions — not just recorded as prose in AIRGen.

**Predicates to use:**

| Predicate | Subject | Object | When |
|-----------|---------|--------|------|
| `HEX_COLLISION` | entity A ↔ entity B | hex code | Two entities share identical (or near-identical ≤2 bit) hex code despite different meanings |
| `CROSS_DOMAIN_ANALOG` | entity A ↔ entity B | Jaccard: N.NNN, domains: X ↔ Y | Entities from different domains with Jaccard >= 0.70 |
| `TRAIT_OUTLIER` | entity | trait name | Entity activates a trait none of its domain peers share |
| `NULL_HEX` | entity | domain | Entity classified as 00000000 |
| `CLASSIFICATION_DRIFT` | entity | old_hex → new_hex | Re-classification produced different hex code |
| `FUNCTIONAL_ARCHETYPE` | archetype label | entity1, entity2, ... | Multiple cross-domain entities converging on same functional role |

**Important:** `upsert` keys on subject+predicate, so the same subject
can only have one fact per predicate. For relationship facts
(`HEX_COLLISION`, `CROSS_DOMAIN_ANALOG`), use a composite subject with
`↔` separator: `"entity A ↔ entity B"`. This allows multiple
relationships per entity.

**Creating a research fact:**
```bash
uht-substrate facts upsert "<entity-A> ↔ <entity-B>" CROSS_DOMAIN_ANALOG \
  "Jaccard: 0.XXX, domains: <domain-A> ↔ <domain-B>" --namespace RESEARCH
```

**Querying research facts:**
```bash
# All hex collisions found so far
uht-substrate facts query --predicate HEX_COLLISION --namespace RESEARCH

# All cross-domain analogs
uht-substrate facts query --predicate CROSS_DOMAIN_ANALOG --namespace RESEARCH

# All null-hex entities
uht-substrate facts query --predicate NULL_HEX --namespace RESEARCH
```

**Rules:**
- Always use the `RESEARCH` namespace (not `CLAUDE`) for research findings
- Use composite `↔` subjects for pairwise relationships
- Only store findings that meet thresholds (Jaccard >= 0.70, same hex
  or ≤2 bit distance, drift > 2 bits). Do not store routine similarities.
- Check existing research facts before storing to avoid duplicates:
  query by predicate before upserting

### AIRGen Project Structure (uht-bot / uht-research)

| Document         | Code | Purpose                                           |
|------------------|------|---------------------------------------------------|
| `hypotheses`     | HYP  | Falsifiable claims with confirmation/refutation criteria |
| `results`        | RES  | Experimental outcomes linked back to hypotheses    |
| `observations`   | OBS  | Trace gap findings, drift, orphan analyses         |
| `corpus-log`     | COR  | Entities added to UHT corpus with classification data |
| `trait-proposals` | TRT | Proposed trait extensions motivated by results     |

### Document Sections

Every requirement MUST be assigned to a section via `--section <id>`.
Requirements not in sections will not be found by trace linksets.

| Document         | Section                | Section ID                |
|------------------|------------------------|---------------------------|
| `hypotheses`     | Active Hypotheses      | `section-1773068408469`   |
| `hypotheses`     | Closed Hypotheses      | `section-1773068409161`   |
| `results`        | Calibration Results    | `section-1773068409701`   |
| `observations`   | Research Gaps          | `section-1773068410280`   |
| `observations`   | Structural Findings    | `section-1773068410898`   |
| `corpus-log`     | Domain Expansions      | `section-1773068411382`   |
| `trait-proposals` | Proposed Traits       | `section-1773068412170`   |

New hypotheses go in "Active Hypotheses". When a result confirms or
refutes a hypothesis, move it to "Closed Hypotheses" via
`airgen reqs update $TENANT $PROJECT <ref> --section section-1773068409161`.

### Trace Linksets

- `hypotheses` → `results` (derives)
- `results` → `trait-proposals` (derives)
- `observations` → `hypotheses` (derives)

When creating a trace link, use full IDs (not bare refs):
`airgen trace create $TENANT $PROJECT
--source "uht-bot:uht-research:<SOURCE-REF>" --target "uht-bot:uht-research:<TARGET-REF>" --type derives`.

### Reading Prior Work

Before formulating new hypotheses or observations, **always** read what
already exists:

```bash
# Hot tier — active research items (hypotheses, results, proposals, trace-gap obs)
cat /tmp/active_reqs.json

# Cold tier — corpus coverage index (refs + tags only, no full text)
cat /tmp/corpus_index.json
```

Read `/tmp/active_reqs.json` to check existing hypotheses and results
before formulating new ones. Read `/tmp/corpus_index.json` to check
domain coverage. This prevents duplicate hypotheses and lets the session
build on prior findings without consuming context on archived prose.

---

## Phase 1: Initialise

```bash
# ── CLI Smoke Test ──
# These commands MUST succeed with expected output shapes.
# If any fail, STOP and write a journal entry describing the failure.
# Do NOT suppress errors with 2>/dev/null during this block.

SMOKE_FAIL=0

# 1. Substrate returns JSON with .facts array
SMOKE_SUB=$(uht-substrate facts query --predicate SESSION_COUNT --namespace CLAUDE 2>&1)
if ! echo "$SMOKE_SUB" | jq -e '.facts' > /dev/null 2>&1; then
  echo "SMOKE FAIL: uht-substrate output is not {facts:[...]}"
  echo "Got: $SMOKE_SUB"
  SMOKE_FAIL=1
fi

# 2. AIRGen returns project list for tenant
SMOKE_AG=$(airgen projects list $TENANT 2>&1)
if ! echo "$SMOKE_AG" | grep -q "uht-research"; then
  echo "SMOKE FAIL: airgen projects list does not contain uht-research"
  echo "Got: $SMOKE_AG"
  SMOKE_FAIL=1
fi

# 3. AIRGen reqs list returns JSON with .data array
SMOKE_REQS=$(airgen reqs list $TENANT $PROJECT --json --limit 200 2>&1)
if ! echo "$SMOKE_REQS" | jq -e '.data' > /dev/null 2>&1; then
  echo "SMOKE FAIL: airgen reqs list --json is not {data:[...]}"
  echo "Got: $(echo "$SMOKE_REQS" | head -5)"
  SMOKE_FAIL=1
fi

# 4. Substrate field name is .object (not .object_value)
SMOKE_FIELD=$(echo "$SMOKE_SUB" | jq -r '.facts[0].object // "MISSING"')
if [ "$SMOKE_FIELD" = "MISSING" ] || [ -z "$SMOKE_FIELD" ]; then
  echo "SMOKE FAIL: .facts[0].object field missing — check if field name has changed"
  SMOKE_FAIL=1
fi

# 5. Entity graph is populated and queryable
SMOKE_ENT=$(uht-substrate entities list --limit 1 2>&1)
if ! echo "$SMOKE_ENT" | jq -e '.entities[0].hex_code' > /dev/null 2>&1; then
  echo "SMOKE FAIL: entities list returned no entities"
  echo "Got: $(echo "$SMOKE_ENT" | head -3)"
  SMOKE_FAIL=1
fi

if [ "$SMOKE_FAIL" = "1" ]; then
  echo "CLI smoke test failed. Aborting session."
  # Write a minimal journal entry about the failure and exit
fi
# ── End Smoke Test ──

# Load operational state from Substrate
PREV=$(uht-substrate facts query --predicate SESSION_COUNT \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // "0"')
SESSION_N=$((${PREV:-0} + 1))

uht-substrate facts upsert "autonomous-loop" SESSION_COUNT "$SESSION_N" \
  --namespace CLAUDE
uht-substrate facts upsert "autonomous-loop" LAST_SESSION_START \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE

# Check for pending directive (set via Telegram bot)
DIRECTIVE=$(uht-substrate facts query --predicate PENDING_DIRECTIVE \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')
DIRECTIVE_ID=$(uht-substrate facts query --predicate PENDING_DIRECTIVE \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].uuid // ""')
[ -n "$DIRECTIVE_ID" ] && [ "$DIRECTIVE_ID" != "null" ] && \
  uht-substrate facts delete "$DIRECTIVE_ID"

# Check for integrity alert
ALERT=$(uht-substrate facts query --predicate INTEGRITY_ALERT \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

# Load existing AIRGen requirements — two-tier split to manage context
# Full dump goes to disk; session reads hot tier (active items) and
# cold tier (corpus-log refs only, no full text)
airgen reqs list $TENANT $PROJECT --json --limit 100 2>/dev/null | jq '.data // []' > /tmp/all_reqs.json
EXISTING_COUNT=$(jq 'length' /tmp/all_reqs.json 2>/dev/null || echo 0)

# Hot tier: hypotheses, results, trait proposals, trace-gap observations (full text)
jq '[.[] | select(.tags // [] | any(. == "hypothesis" or . == "result" or . == "trait-proposal" or . == "trace-gap"))]' \
  /tmp/all_reqs.json > /tmp/active_reqs.json
ACTIVE_COUNT=$(jq 'length' /tmp/active_reqs.json 2>/dev/null || echo 0)

# Cold tier: corpus-log and structural findings (refs + tags only, no text)
jq '[.[] | select(.tags // [] | any(. == "corpus-expansion" or . == "structural-finding" or . == "integrity")) | {ref, tags, title}]' \
  /tmp/all_reqs.json > /tmp/corpus_index.json
ARCHIVE_COUNT=$(jq 'length' /tmp/corpus_index.json 2>/dev/null || echo 0)

echo "AIRGen: $EXISTING_COUNT total, $ACTIVE_COUNT active (full text), $ARCHIVE_COUNT archived (refs only)"

# Load entity graph stats
ENTITY_COUNT=$(uht-substrate entities list --limit 1 2>/dev/null | \
  jq -r '.total // 0')
echo "Entity graph contains $ENTITY_COUNT entities"

# Load research facts (queryable findings from prior sessions)
uht-substrate facts query --namespace RESEARCH 2>/dev/null | \
  jq '.facts // []' > /tmp/research_facts.json
RESEARCH_FACT_COUNT=$(jq 'length' /tmp/research_facts.json 2>/dev/null || echo 0)
echo "Research knowledge base contains $RESEARCH_FACT_COUNT facts"
```

---

## Phase 2: Select Task Class

```bash
LAST_TASK=$(uht-substrate facts query --predicate LAST_TASK_CLASS \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

LAST_TG=$(uht-substrate facts query --predicate LAST_TRACE_GAP_RUN \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

LAST_CAL=$(uht-substrate facts query --predicate LAST_CALIBRATION_RUN \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

LAST_APP=$(uht-substrate facts query --predicate LAST_APPLICATION_RUN \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

LAST_CORPUS=$(uht-substrate facts query --predicate LAST_CORPUS_RUN \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')

# Check for queued hypothesis — forces CALIBRATION
OPEN_HYP=$(uht-substrate facts query --predicate OPEN_HYPOTHESIS \
  --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')

# Helper: compute hours elapsed since an ISO timestamp
hours_since() {
  local ts="$1"
  [ -z "$ts" ] && echo "9999" && return
  local then_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
  local now_epoch=$(date +%s)
  echo $(( (now_epoch - then_epoch) / 3600 ))
}

TG_HOURS=$(hours_since "$LAST_TG")
CAL_HOURS=$(hours_since "$LAST_CAL")
APP_HOURS=$(hours_since "$LAST_APP")
CORPUS_HOURS=$(hours_since "$LAST_CORPUS")
```

If `$DIRECTIVE` contains `TASK:<class>`, use that class. If `$DIRECTIVE`
contains `PAUSE`, write a minimal journal entry and exit.

Otherwise, select the first matching class in priority order:

1. **CALIBRATION** — if `$OPEN_HYP` is non-empty (queued hypothesis waiting)
2. **INTEGRITY** — if `$ALERT` non-empty, OR `$SESSION_N % 20 == 0`
3. **CALIBRATION** — if `$LAST_TASK != CALIBRATION` AND `$CAL_HOURS >= 3`
4. **APPLICATION** — if `$LAST_TASK != APPLICATION` AND `$APP_HOURS >= 6`
5. **TRACE_GAP** — if `$LAST_TASK != TRACE_GAP` AND `$TG_HOURS >= 8`
6. **CORPUS_EXPANSION** — if `$LAST_TASK != CORPUS_EXPANSION` AND `$CORPUS_HOURS >= 12`
7. **CALIBRATION** — default fallback

**Current research phase: FALSIFICATION.** The corpus contains 2900+
entities across 20+ domains. The priority is now testing hypotheses,
not adding more entities. Prefer CALIBRATION and APPLICATION over
CORPUS_EXPANSION. When CORPUS_EXPANSION does run, select domains that
would stress-test existing hypotheses rather than exploring new ground.

**Open hypotheses requiring testing:**
- HYP-008: Requirements deduplication via hex distance (duplicate of HYP-009, test once)
- HYP-011: Null-hex entities are specifically process-dependent/context-embedded
- HYP-040: Trait correlation (phi > 0.70 for 3+ pairs) — valid, worth testing
- HYP-041: Drift convergence — CLOSED (pre-empted by v4.1 context fix; drift was caused by missing context, not classifier non-determinism)
- HYP-006 is now CLOSED (refuted, session 49)

**Classification instability — resolved in v4.1:**
Prior sessions (v4.0 and earlier) classified entities with bare names and
no `--context` description. This caused stochastic results for polysemous
terms (e.g. "Compression" oscillated between 3 unrelated hex codes across
sessions). This is NOT a system defect — it is the expected behavior when
the classifier receives an ambiguous name with no description to anchor
trait evaluation. As of protocol v4.1 and CLI v0.4.5, all classify calls
require `--context` with a rich description, and drift checks use
`--force-refresh`. Treat prior drift findings (HYP-041, session 78
observations) as artifacts of missing context, not evidence of classifier
non-determinism. Do NOT spend sessions investigating classification
instability for entities classified without context.

**Remaining open questions:**
- 25 entities classify as 00000000 — is this a trait-set gap or correct?
- Failure modes show systematic trait deficit vs constructive counterparts
  — does this hold outside software engineering?

**Classification behavior — caching, context, and force-refresh:**
The Substrate API caches classifications by entity name. A cached entity
returns its stored hex code on subsequent `classify` calls. Key flags:

- `--context "<description>"` — provides a 1-2 sentence description that
  is injected as `{{entity_description}}` into each of the 32 trait
  evaluation prompts. This enriches classification quality for new entities
  and sets the stored description. **Always provide context when classifying.**
- `--force-refresh` — bypasses the cache and forces fresh reclassification.
  Use this when you need to re-evaluate an existing entity (e.g. drift checks).

**Disambiguation rules:**
- `classify "crane (bird)"` → AF520200, different from `classify "crane"` → DEC40018
- For polysemous concepts, always disambiguate in the entity name AND provide
  a rich `--context` description.
- Example:
  ```bash
  uht-substrate classify "spring (mechanical)" \
    --context "A coiled elastic device that stores mechanical energy. Physical, synthetic, structural component used in engineering."
  ```

```bash
uht-substrate facts upsert "autonomous-loop" CURRENT_TASK_CLASS \
  "$TASK_CLASS" --namespace CLAUDE
```

---

## Phase 3: Execute Task

---

### TASK CLASS: INTEGRITY

Purpose: verify the scientific integrity of the research record —
classification stability, cross-entry consistency, and hypothesis
validity. This is a research task, not a DevOps audit.

1. **Structural preamble (quick, silent):**
   ```bash
   airgen docs list $TENANT $PROJECT
   airgen trace linksets list $TENANT $PROJECT
   ```
   Verify 5 documents and 3 linksets exist. If anything is missing,
   recreate it silently and move on. Do NOT write about structural
   checks in the journal — they are housekeeping, not findings.

   **Known issue:** `airgen bl list` always returns empty due to an API
   bug. Do NOT check baselines via bl list. Baseline refs are stored
   in Substrate (LAST_BASELINE_REF) and should be trusted there.

2. **Classification drift check:**
   Pick 3-5 entities from older corpus-log entries in `/tmp/corpus_index.json`
   (use refs to look up full text if needed via `airgen reqs get`).
   Re-classify each with `--force-refresh` to bypass cache:
   ```bash
   uht-substrate classify "<entity>" --force-refresh \
     --context "<1-2 sentence description of the concept's meaning and domain>"
   ```
   Compare the new hex code to the hex code recorded in the corpus-log
   entry. Compute Hamming distance (count differing bits). If any entity
   drifts by > 2 bits, store a research fact and investigate:
   ```bash
   uht-substrate facts upsert "<entity>" CLASSIFICATION_DRIFT \
     "<old-hex> → <new-hex>" --namespace RESEARCH
   ```

3. **Cross-entry consistency via entity graph:**
   ```bash
   uht-substrate entities search-traits --<dominant-trait> --limit 20
   ```
   Pick a trait that appeared significant in recent sessions. Check
   whether the entities sharing that trait form a semantically coherent
   group. Look for outliers — entities that activate the trait but
   don't belong conceptually. These are potential misclassifications
   or trait definition issues.

4. **Hypothesis-result consistency:**
   Pick a confirmed or refuted hypothesis from `/tmp/active_reqs.json`.
   Check whether corpus data added since the hypothesis was tested
   supports or contradicts the conclusion. Use `entities find-similar`
   to find new entities related to the hypothesis topic:
   ```bash
   uht-substrate entities find-similar "<hypothesis-related entity>" \
     --min-traits 15 --limit 10
   ```

5. **Record result:**
   If clean:
   ```bash
   uht-substrate facts upsert "integrity" LAST_CLEAN_CHECK \
     "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
   ```

**Flag if:** drift > 2 bits on any entity, or hypothesis contradicted by new data → urgency `high`

---

### TASK CLASS: TRACE_GAP

Purpose: identify gaps in the research record and convert observations
into testable hypotheses. This session MUST produce at least one new
observation→hypothesis trace link.

1. **Read baseline refs from Substrate** (bl list has an API bug):
   ```bash
   BL_LATEST=$(uht-substrate facts query --predicate LAST_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   BL_PREV=$(uht-substrate facts query --predicate PREV_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   ```
   If both refs exist, diff them:
   ```bash
   airgen bl compare $TENANT $PROJECT \
     --from $BL_PREV --to $BL_LATEST --json > /tmp/diff.json
   ```
   If only one or zero refs exist, skip the diff and instead analyse
   the current requirements for coverage gaps.

2. **Analyse gaps:**
   - Are there hypotheses without matching results?
   - Are there results without trace links to hypotheses?
   - Are there observations that haven't motivated any hypothesis?
   - Are there corpus-log entries for domains not yet tested by calibration?
   - Use entity graph to find research-worthy gaps:
     ```bash
     uht-substrate entities search-traits --limit 20
     ```
     Look for traits with very few entities (under-explored) or traits
     with many entities but no calibration hypothesis testing them.

3. **Record findings as observations in AIRGen:**
   ```bash
   OBS_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "The research record SHALL address the following gap: \
   <description of gap>. [Identified by baseline diff ${BL_PREV}..${BL_LATEST}, \
   session autonomous-$SESSION_N.]" \
     --document observations \
     --section section-1773068410280 \
     --tags trace-gap,session-$SESSION_N 2>&1)
   OBS_REF=$(echo "$OBS_JSON" | jq -r '.requirement.ref // empty')
   ```

4. **MANDATORY: Create at least one OBS→HYP trace link.**
   Every TRACE_GAP session must convert at least one observation into
   a testable hypothesis. If existing observations suggest hypotheses,
   create the hypothesis and link it. If no observations exist, create
   one from entity graph exploration, then derive a hypothesis from it.
   ```bash
   HYP_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "The UHT SHALL <testable claim derived from observation>. \
   [Confirmed by: <criterion>. Refuted by: <criterion>. \
   Derived from: $OBS_REF.]" \
     --document hypotheses \
     --section section-1773068408469 \
     --tags hypothesis,session-$SESSION_N 2>&1)
   HYP_REF=$(echo "$HYP_JSON" | jq -r '.requirement.ref // empty')

   airgen trace create $TENANT $PROJECT \
     --source "uht-bot:uht-research:$OBS_REF" \
     --target "uht-bot:uht-research:$HYP_REF" --type derives
   ```

5. **Baseline** (store ref in Substrate since bl list is broken):
   ```bash
   BL_OLD=$(uht-substrate facts query --predicate LAST_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   [ -n "$BL_OLD" ] && uht-substrate facts upsert "autonomous-loop" \
     PREV_BASELINE_REF "$BL_OLD" --namespace CLAUDE
   NEW_BL=$(airgen bl create $TENANT $PROJECT \
     --label "TRACE-GAP-$(date +%Y-%m-%d)" 2>&1 | \
     jq -r '.baseline.ref // empty')
   [ -n "$NEW_BL" ] && uht-substrate facts upsert "autonomous-loop" \
     LAST_BASELINE_REF "$NEW_BL" --namespace CLAUDE
   ```

```bash
uht-substrate facts upsert "autonomous-loop" LAST_TRACE_GAP_RUN \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
```

**Flag if:** untested hypotheses > 3, or unlinked results found → urgency `medium`

---

### TASK CLASS: CALIBRATION

Purpose: formulate and test a falsifiable UHT hypothesis. Record both
hypothesis and result as traced requirements in AIRGen.

1. **Check for queued hypotheses:**
   ```bash
   uht-substrate facts query --predicate OPEN_HYPOTHESIS \
     --namespace CLAUDE > /tmp/open_hyp.json
   QUEUED=$(jq -r '.facts[0].object // ""' /tmp/open_hyp.json)
   QUEUED_ID=$(jq -r '.facts[0].uuid // ""' /tmp/open_hyp.json)
   ```

2. **Check for untested hypotheses in AIRGen:**
   ```bash
   jq '[.[] | select(.tags // [] | any(. == "hypothesis"))]' /tmp/active_reqs.json \
     > /tmp/hyp_reqs.json
   jq '[.[] | select(.tags // [] | any(. == "result"))]' /tmp/active_reqs.json \
     > /tmp/res_reqs.json
   ```
   Look for hypothesis requirements that have no corresponding result
   (by checking trace links or matching tags). Prefer testing an
   existing untested hypothesis over creating a new one.

3. **If no queued or untested hypothesis exists**, generate one from:
   - *UHT-embedding divergence*: Select concept pairs where UHT
     similarity and expected embedding similarity disagree. High
     UHT / low embedding = ontological twins in distant domains.
     Low UHT / high embedding = co-occurring concepts that are
     categorically different. Both are discoveries, not failures.
   - *Entity graph exploration*: Run `entities explore` on a recent
     entity to discover unexpected neighbors. Run `entities find-similar`
     to find high-similarity cross-domain pairs. Run `entities search-traits`
     to find unusual trait combinations.
     ```bash
     uht-substrate entities explore "<recent entity>" \
       --metric embedding --limit 10
     uht-substrate entities find-similar "<entity>" \
       --min-traits 20 --limit 5
     uht-substrate entities search-traits --<trait> --no-<other-trait> \
       --limit 10
     ```
   - *Cross-domain clustering*: Do concepts from different domains that
     share a semantic role cluster tighter in UHT space than concepts
     from the same domain?
   - *Orphan signal*: Do orphaned requirements differ systematically
     from well-traced ones in UHT space?
   - *Layer entropy*: Which UHT layer shows highest variance across
     a sampled corpus?

4. **Create hypothesis in AIRGen and capture ref:**
   ```bash
   HYP_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "The UHT SHALL <claim being tested> when applied to <context>. \
   [Confirmed by: <criterion>. Refuted by: <criterion>. \
   Rationale: <why worth testing>.]" \
     --document hypotheses \
     --section section-1773068408469 \
     --tags hypothesis,session-$SESSION_N 2>&1)
   HYP_REF=$(echo "$HYP_JSON" | jq -r '.requirement.ref // empty')
   ```

5. **Execute test** — budget: 20 classify/compare/batch-compare calls.
   Use `uht-substrate classify` (always with `--context`),
   `uht-substrate compare`, `uht-substrate batch-compare` as needed.
   When classifying new entities, provide a rich `--context` description.
   When reclassifying existing entities, add `--force-refresh`.

6. **Create result in AIRGen and capture ref:**
   ```bash
   RES_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "Analysis of $HYP_REF SHALL record result: \
   <confirmed|refuted|inconclusive>. <Summary with data.> \
   [Session: autonomous-$SESSION_N. Sample size: <n>.]" \
     --document results \
     --section section-1773068409701 \
     --tags result,session-$SESSION_N 2>&1)
   RES_REF=$(echo "$RES_JSON" | jq -r '.requirement.ref // empty')

   # Trace link: hypothesis → result
   airgen trace create $TENANT $PROJECT \
     --source "uht-bot:uht-research:$HYP_REF" \
     --target "uht-bot:uht-research:$RES_REF" --type derives
   ```

7. **Store research facts for notable findings:**
   If the test reveals cross-domain analogs, hex collisions, or
   functional archetypes, store them:
   ```bash
   # Cross-domain entities with Jaccard >= 0.70
   uht-substrate facts upsert "<entity-A> ↔ <entity-B>" CROSS_DOMAIN_ANALOG \
     "Jaccard: 0.XXX, domains: <domain-A> ↔ <domain-B>" --namespace RESEARCH

   # If multiple entities from different domains converge
   uht-substrate facts upsert "<archetype-label>" FUNCTIONAL_ARCHETYPE \
     "<entity1>, <entity2>, <entity3>" --namespace RESEARCH
   ```

8. **If result motivates a trait proposal:**
   ```bash
   TRT_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "The UHT trait set SHALL be extended with '<trait>': \
   <definition>. [Motivation: $RES_REF shows <finding>. \
   Expected impact: <effect>. Reclassification burden: ~<n> entities.]" \
     --document trait-proposals \
     --section section-1773068412170 \
     --tags trait-proposal,session-$SESSION_N 2>&1)
   TRT_REF=$(echo "$TRT_JSON" | jq -r '.requirement.ref // empty')

   # Trace from result to proposal
   airgen trace create $TENANT $PROJECT \
     --source "uht-bot:uht-research:$RES_REF" \
     --target "uht-bot:uht-research:$TRT_REF" --type derives
   ```

9. **Consume queued hypothesis if used:**
   ```bash
   [ -n "$QUEUED_ID" ] && [ "$QUEUED_ID" != "null" ] && \
     uht-substrate facts delete "$QUEUED_ID"
   ```

10. **Baseline** (store ref in Substrate since bl list is broken):
   ```bash
   BL_OLD=$(uht-substrate facts query --predicate LAST_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   [ -n "$BL_OLD" ] && uht-substrate facts upsert "autonomous-loop" \
     PREV_BASELINE_REF "$BL_OLD" --namespace CLAUDE
   NEW_BL=$(airgen bl create $TENANT $PROJECT \
     --label "CALIBRATION-$(date +%Y-%m-%d)" 2>&1 | \
     jq -r '.baseline.ref // empty')
   [ -n "$NEW_BL" ] && uht-substrate facts upsert "autonomous-loop" \
     LAST_BASELINE_REF "$NEW_BL" --namespace CLAUDE
   ```

```bash
uht-substrate facts upsert "autonomous-loop" LAST_CALIBRATION_RUN \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
```

**Flag if:** result confirmed or refuted → urgency `medium`.
Trait proposal created → urgency `high`.

---

### TASK CLASS: CORPUS_EXPANSION

Purpose: classify new entities in a domain, widen UHT coverage, record
in AIRGen corpus-log.

1. **Check for queued expansion target:**
   ```bash
   TARGET=$(uht-substrate facts query --predicate EXPANSION_TARGET \
     --namespace CLAUDE 2>/dev/null | \
     jq -r '.facts[0].object // ""')
   TARGET_ID=$(uht-substrate facts query --predicate EXPANSION_TARGET \
     --namespace CLAUDE 2>/dev/null | \
     jq -r '.facts[0].uuid // ""')
   ```

2. **If no queued target**, select from the research frontier. Review
   existing corpus-log entries in `/tmp/corpus_index.json` to see which
   domains have been covered, then choose from these priority categories:

   **Trait-gap stress tests** (domains likely to expose classification limits):
   ecology, phenomenology, category theory, linguistics

   **Cross-domain bridges** (connect existing coverage areas):
   operations research, bioethics, systems engineering, cognitive science

   **Null-hex hunters** (abstract concepts that may produce 00000000):
   aesthetics, consciousness, paradox, semiotics

   Prefer domains not yet covered. Prefer domains adjacent to recent
   findings that would test whether observed patterns hold.

   **Domain rotation rule:** Do NOT expand the same domain as the
   previous CORPUS_EXPANSION session. Check the most recent corpus-log
   entry in `/tmp/corpus_index.json` for its domain tag and choose a
   different domain. Each session must explore a new domain — depth
   within a domain comes from CALIBRATION hypotheses, not repeated
   expansion.

3. **Check existing coverage via entity graph:**
   ```bash
   uht-substrate entities list --name "<keyword>" --limit 20
   ```
   See which entities from this domain already exist. Avoid
   re-classifying known entities.

4. **Identify 5-10 fundamental entities** not yet in the corpus.
   Classify each with a rich `--context` description. For polysemous terms,
   disambiguate in the entity name AND provide context:
   ```bash
   uht-substrate classify "<entity>" \
     --context "<1-2 sentence description: what it is, its domain, key properties>"
   # For ambiguous terms, disambiguate in the name:
   # uht-substrate classify "spring (mechanical)" \
   #   --context "A coiled elastic device that stores mechanical energy. Physical, synthetic, structural."
   ```

5. **Coherence check** — compare each new entity to its nearest
   neighbours:
   ```bash
   uht-substrate batch-compare "<entity>" "<neighbour1>" "<neighbour2>"
   ```

6. **Cross-domain discovery via entity graph:**
   After classifying, find cross-domain analogs for the most surprising
   entity:
   ```bash
   uht-substrate entities find-similar "<most-surprising-entity>" \
     --min-traits 15 --limit 10
   ```
   Use `entities search-traits` with the domain's dominant trait pattern
   to find existing entities sharing the same profile — these are
   potential cross-domain archetypes worth noting.

7. **Store research facts for notable findings:**
   For each finding that meets a threshold, create a research fact:
   ```bash
   # If two entities share the same hex code
   uht-substrate facts upsert "<entity-A> ↔ <entity-B>" HEX_COLLISION \
     "<hex-code>" --namespace RESEARCH

   # If cross-domain Jaccard >= 0.70
   uht-substrate facts upsert "<entity-A> ↔ <entity-B>" CROSS_DOMAIN_ANALOG \
     "Jaccard: 0.XXX, domains: <domain-A> ↔ <domain-B>" --namespace RESEARCH

   # If an entity activates a trait none of its domain peers share
   uht-substrate facts upsert "<entity>" TRAIT_OUTLIER \
     "<trait-name>" --namespace RESEARCH

   # If an entity classifies as 00000000
   uht-substrate facts upsert "<entity>" NULL_HEX \
     "$TARGET" --namespace RESEARCH
   ```
   Check existing facts first to avoid duplicates.

8. **Record in AIRGen corpus-log:**
   ```bash
   COR_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "The UHT corpus SHALL include the following $TARGET entities \
   as of $(date +%Y-%m-%d): <e1> (<hex1>), <e2> (<hex2>), ... \
   [Cross-domain analogies: <observation>. \
   Most surprising classification: <entity> at <hex> because <reason>.]" \
     --document corpus-log \
     --section section-1773068411382 \
     --tags corpus-expansion,$TARGET,session-$SESSION_N 2>&1)
   COR_REF=$(echo "$COR_JSON" | jq -r '.requirement.ref // empty')
   ```

9. **Consume queued target:**
   ```bash
   [ -n "$TARGET_ID" ] && [ "$TARGET_ID" != "null" ] && \
     uht-substrate facts delete "$TARGET_ID"
   ```

10. **Baseline** (store ref in Substrate since bl list is broken):
   ```bash
   BL_OLD=$(uht-substrate facts query --predicate LAST_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   [ -n "$BL_OLD" ] && uht-substrate facts upsert "autonomous-loop" \
     PREV_BASELINE_REF "$BL_OLD" --namespace CLAUDE
   NEW_BL=$(airgen bl create $TENANT $PROJECT \
     --label "CORPUS-$(date +%Y-%m-%d)-$TARGET" 2>&1 | \
     jq -r '.baseline.ref // empty')
   [ -n "$NEW_BL" ] && uht-substrate facts upsert "autonomous-loop" \
     LAST_BASELINE_REF "$NEW_BL" --namespace CLAUDE
   ```

```bash
uht-substrate facts upsert "autonomous-loop" LAST_CORPUS_RUN \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
```

**Flag if:** any entity has Jaccard < 0.30 to nearest neighbour → urgency `low`.
Null hex (00000000) classification → urgency `medium`.

---

### TASK CLASS: APPLICATION

Purpose: test whether UHT produces practically useful signals that
embeddings alone cannot.

**METHODOLOGICAL CORRECTION (mandatory reading):**
UHT similarity and embedding similarity are orthogonal measures.
UHT encodes explicit ontological properties — what a concept *is* in
terms of designed traits. Embeddings encode distributional proximity —
what concepts appear near each other in text. These will frequently
disagree, and the disagreements are the signal, not the failure.

Sessions 50, 33, and 32 benchmarked UHT against tasks where embeddings
excel (ontology alignment, analogy detection, cross-domain structural
correspondence) and concluded UHT fails because it does not replicate
embedding-style results. This conclusion is methodologically unsound.
A measure that simply reproduced embedding similarity would be
redundant. The value of UHT is precisely where it *diverges* from
embeddings.

**The correct evaluation framework is divergence analysis.** For any
pair of concepts, the interesting cases are disagreement:
- **High embedding similarity, low UHT similarity** = concepts that
  co-occur in text but are categorically different kinds of thing.
  Example: deadlock and concurrency control — distributionally
  inseparable but categorically opposed at the trait level.
- **Low embedding similarity, high UHT similarity** = concepts from
  distant domains sharing an identical ontological property profile.
  Example: Gibbs free energy and channel capacity at Jaccard 1.00 —
  distributionally distant but the same kind of abstract quantitative
  constraint. This class of finding is what UHT can produce that
  embeddings cannot.

**Do NOT evaluate UHT by asking "does it replicate what embeddings
do?" Instead ask: "what does UHT reveal that embeddings miss?"**

1. **Check for queued application topic:**
   ```bash
   uht-substrate facts query --predicate OPEN_HYPOTHESIS \
     --namespace CLAUDE > /tmp/open_hyp.json
   QUEUED=$(jq -r '.facts[0].object // ""' /tmp/open_hyp.json)
   QUEUED_ID=$(jq -r '.facts[0].uuid // ""' /tmp/open_hyp.json)
   ```
   The `/experiment` Telegram command queues topics here. If a queued
   topic describes an application use case, use it.

2. **If no queued topic**, select from the application frontier:

   **Divergence analysis (PRIORITY):** Select 20 concept pairs spanning
   a range of expected embedding similarities. Classify all 40 in UHT.
   For each pair, record UHT Jaccard and estimated embedding similarity
   (based on domain proximity and co-occurrence likelihood). Identify
   high-divergence pairs in both directions. Analyse whether the
   divergence is meaningful or artifactual.

   **Anomaly detection:** Can UHT trait profiles flag concepts that
   don't fit their stated category? Classify concepts with known
   miscategorizations and check if UHT trait distance separates them
   from their purported peers.

   **Requirements deduplication:** Do semantically duplicate requirements
   (same intent, different wording) produce similar hex codes? Classify
   paraphrases and measure Hamming distance. Note: this tests naming
   sensitivity, not embedding similarity.

   **Concept boundary detection:** Can UHT trait differences between
   two near-synonyms reveal where one concept ends and another begins?
   This is a task embeddings handle poorly (near-synonyms cluster)
   but where ontological trait differences may discriminate.

   Review `/tmp/active_reqs.json` to see which application topics have
   already been tested. Select one not yet explored.

3. **Formulate application hypothesis and capture ref:**
   ```bash
   HYP_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "UHT SHALL be effective as a <application> tool: \
   <specific testable claim>. \
   [Confirmed by: <criterion with threshold>. \
   Refuted by: <criterion with threshold>. \
   Rationale: <why this application is worth testing>.]" \
     --document hypotheses \
     --section section-1773068408469 \
     --tags hypothesis,application,session-$SESSION_N 2>&1)
   HYP_REF=$(echo "$HYP_JSON" | jq -r '.requirement.ref // empty')
   ```

4. **Execute test** — budget: 25 classify/compare/batch-compare calls.
   Design a controlled experiment:
   - Define positive examples (where UHT should succeed)
   - Define negative examples (where UHT should fail or show difference)
   - Classify all examples (always with `--context` descriptions)
   - Measure the discriminating metric (Jaccard, Hamming, trait overlap)
   - Report precision/recall or accuracy if applicable

5. **Create result in AIRGen and capture ref:**
   ```bash
   RES_JSON=$(airgen reqs create $TENANT $PROJECT \
     --text "Application test of $HYP_REF SHALL record: \
   <effective|ineffective|partially effective>. <Summary with data.> \
   [Session: autonomous-$SESSION_N. Sample size: <n>. \
   Discriminating metric: <metric> at threshold <t>. \
   Accuracy: <value> on <n> test pairs.]" \
     --document results \
     --section section-1773068409701 \
     --tags result,application,session-$SESSION_N 2>&1)
   RES_REF=$(echo "$RES_JSON" | jq -r '.requirement.ref // empty')

   # Trace link: hypothesis → result
   airgen trace create $TENANT $PROJECT \
     --source "uht-bot:uht-research:$HYP_REF" \
     --target "uht-bot:uht-research:$RES_REF" --type derives
   ```

6. **If application is effective, create a trait proposal or observation:**
   If the test reveals UHT works well for this application, record
   the method as a reusable pattern. If it reveals a gap (e.g., works
   except when concepts lack trait X), create an observation linking
   to a trait proposal.

7. **Consume queued topic if used:**
   ```bash
   [ -n "$QUEUED_ID" ] && [ "$QUEUED_ID" != "null" ] && \
     uht-substrate facts delete "$QUEUED_ID"
   ```

8. **Baseline** (store ref in Substrate since bl list is broken):
   ```bash
   BL_OLD=$(uht-substrate facts query --predicate LAST_BASELINE_REF \
     --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
   [ -n "$BL_OLD" ] && uht-substrate facts upsert "autonomous-loop" \
     PREV_BASELINE_REF "$BL_OLD" --namespace CLAUDE
   NEW_BL=$(airgen bl create $TENANT $PROJECT \
     --label "APPLICATION-$(date +%Y-%m-%d)" 2>&1 | \
     jq -r '.baseline.ref // empty')
   [ -n "$NEW_BL" ] && uht-substrate facts upsert "autonomous-loop" \
     LAST_BASELINE_REF "$NEW_BL" --namespace CLAUDE
   ```

```bash
uht-substrate facts upsert "autonomous-loop" LAST_APPLICATION_RUN \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
```

**Flag if:** application effective → urgency `high` (operator wants to know).
Application reveals trait gap → urgency `medium`.

---

## Phase 4: Flag Findings

If significance threshold met, store a notification fact. The dispatcher
reads this after the session, sends the Telegram message, and deletes it.

```bash
uht-substrate facts upsert "telegram-notify" PENDING_NOTIFICATION \
  "$TASK_CLASS | $SUMMARY | $URGENCY" --namespace CLAUDE
```

Do not store the fact if no threshold was met.

---

## Phase 5: Write Journal Entry

First-person account of what happened. Not a log.

**Structure every entry with these four sections as markdown headings:**

## Observation
What was seen — the most surprising or notable finding first. If nothing
surprised you, say that explicitly and explain why the null result is
itself informative. State the question being pursued and why this session
chose it.

## Evidence
The data supporting the observation. Hex codes, Jaccard scores, counts,
comparisons, specific values. No command names or JSON keys — just the
numbers and what they describe.

## Interpretation
What the evidence means. What is now believed that wasn't before. What
changed in understanding. Be direct — no hedging unless genuine
uncertainty exists.

## Action
What happens next. What remains open. What the next session should
pursue. Any requirements created in AIRGen, trace links established,
or proposals made.

**Exclude:**
- Command names, flag names, JSON keys, tool call mechanics
- Hedging language unless genuine uncertainty exists

**Anti-navel-gazing rule:**
The journal entry MUST describe a finding about the Universal Hex
Taxonomy, not about the loop's own infrastructure. If an operational
issue was encountered, note it in Action as one sentence. The
Observation, Evidence, and Interpretation sections must contain UHT
research content — hex codes, trait patterns, classification results,
cross-domain comparisons. If the entire session was consumed by
infrastructure repair, perform at least one classification or entity
graph query and write about that finding instead.

**Constraints:**
- 300-600 words total across all four sections
- Lead the Observation section in media res — not "In this session, I..."
- The date field in front matter MUST be quoted: date: "YYYY-MM-DD"

**Output the entry as your final plain-text assistant message (no code
fences, no Bash echo/cat — the dispatcher only captures your text
response, not tool output):**

---
title: "<finding-focused title — not the task class name>"
date: "<YYYY-MM-DD>"
session: autonomous-<SESSION_N>
session_type: autonomous
task_class: <TASK_CLASS>
status: published
---

Write the full entry text with ## headings after the front matter.

---

## Phase 6: Close Session

```bash
uht-substrate facts upsert "autonomous-loop" LAST_SESSION_END \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE

uht-substrate facts upsert "autonomous-loop" LAST_TASK_CLASS \
  "$TASK_CLASS" --namespace CLAUDE
```

## CRITICAL OUTPUT RULE — READ THIS CAREFULLY

Your **very last message** in this conversation must be the journal entry
markdown, written as plain text — NOT inside a tool call.

**DO NOT** use echo, cat, printf, or any Bash tool to output it.
**DO NOT** write any commentary, summary, or explanation after it.
**DO NOT** reference background tasks or prior output.

The dispatcher runs `claude -p` which ONLY captures your final text
response. If your last message is anything other than the journal entry,
the session fails and no entry is published.

Your final message must look exactly like this (with real content):

---
title: "..."
date: "..."
session: autonomous-N
session_type: autonomous
task_class: TASK_CLASS
status: published
---

## Observation
...
## Evidence
...
## Interpretation
...
## Action
...

---

## Hard Constraints

**Budget:** 60 bash operations per session. At 50, abandon the current
task, write a brief journal entry noting the budget limit, and close.

**No silent overwrites:** Do not update or delete requirements created
by prior sessions. If a prior finding appears wrong, create a new
requirement in the `observations` document disputing it, and flag
for Telegram.

**Write access:** All writes go to `uht-bot/uht-research` only.
No writes to any other tenant or project.

**Network:** External requests permitted in CORPUS_EXPANSION only,
limited to `substrate.universalhex.org` and `airgen.studio/api`.

**Evaluation methodology:** Do NOT benchmark UHT by asking whether it
replicates embedding similarity. UHT encodes ontological properties;
embeddings encode distributional proximity. These are orthogonal
measures. A UHT result that disagrees with embedding similarity is not
a failure — it is the signal. Evaluate UHT by what it reveals that
embeddings miss (ontological twins in distant domains, categorical
differences between co-occurring concepts). See APPLICATION task class
for the correct divergence analysis framework.
