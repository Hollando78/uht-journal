# Autonomous Session Protocol — universalhex.org research loop
# Executed via: claude --print "$(cat session_protocol.md)"
# CLIs required: airgen-cli, uht-substrate
# SESSION_PROTOCOL_VERSION: 3.0

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

**UHT Substrate** — operational state only. Session counters, timestamps,
directives, notifications, and pause flags. Ephemeral. Overwritten freely.

**AIRGen** — persistent knowledge store. Every hypothesis, result,
observation, corpus entry, and trait proposal is a versioned requirement
in a structured document with trace links. This is the accumulating
research record. The loop reads AIRGen to build on prior work and writes
AIRGen to record new findings.

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
airgen reqs list $TENANT $PROJECT --json | jq '.data // []' > /tmp/all_reqs.json
```

This prevents duplicate hypotheses and lets the session build on prior
findings rather than starting from zero each time.

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
SMOKE_REQS=$(airgen reqs list $TENANT $PROJECT --json 2>&1)
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

# Load existing AIRGen requirements (the accumulated research record)
airgen reqs list $TENANT $PROJECT --json 2>/dev/null | jq '.data // []' > /tmp/all_reqs.json
EXISTING_COUNT=$(jq 'length' /tmp/all_reqs.json 2>/dev/null || echo 0)
echo "Loaded $EXISTING_COUNT existing requirements from AIRGen"
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
```

If `$DIRECTIVE` contains `TASK:<class>`, use that class. If `$DIRECTIVE`
contains `PAUSE`, write a minimal journal entry and exit.

Otherwise, select the first matching class in priority order:

1. **INTEGRITY** — if `$ALERT` non-empty, OR `$SESSION_N % 10 == 0`,
   OR `$SESSION_N == 1`
2. **TRACE_GAP** — if `$LAST_TASK != TRACE_GAP` AND `$LAST_TG` is empty
   or > 24h ago
3. **CALIBRATION** — if `$LAST_TASK != CALIBRATION` AND `$LAST_CAL` is
   empty or > 48h ago
4. **CORPUS_EXPANSION** — default

```bash
uht-substrate facts upsert "autonomous-loop" CURRENT_TASK_CLASS \
  "$TASK_CLASS" --namespace CLAUDE
```

---

## Phase 3: Execute Task

---

### TASK CLASS: INTEGRITY

Purpose: verify the AIRGen project structure is sound and Substrate
operational facts are consistent.

1. **Check AIRGen structure:**
   ```bash
   airgen docs list $TENANT $PROJECT
   airgen trace linksets list $TENANT $PROJECT
   ```
   Verify all 5 documents exist and 3 linksets are present.
   If anything is missing, recreate it and note the discrepancy.

   **Known issue:** `airgen bl list` always returns empty due to an API
   bug. Do NOT check baselines via bl list. Baseline refs are stored
   in Substrate (LAST_BASELINE_REF) and should be trusted there.

2. **Check for duplicate requirements:**
   Review `/tmp/all_reqs.json` for requirements with near-identical
   text or duplicate tags. Flag as findings if found.

3. **Check Substrate for stale operational facts:**
   ```bash
   uht-substrate facts query --namespace CLAUDE > /tmp/claude_facts.json
   ```
   Look for facts older than 90 days. Look for (subject, predicate)
   pairs with multiple distinct values (contradictions). Flag any found.

4. **Record result:**
   If clean:
   ```bash
   uht-substrate facts upsert "integrity" LAST_CLEAN_CHECK \
     "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE
   ```

**Flag if:** any contradiction, missing document, or structural issue → urgency `high`

---

### TASK CLASS: TRACE_GAP

Purpose: compare the two most recent baselines of `uht-research` itself
to identify what the loop has added, what gaps remain, and whether
observations from prior sessions have led to hypotheses.

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

3. **Record findings as observations in AIRGen:**
   ```bash
   airgen reqs create $TENANT $PROJECT \
     --text "The research record SHALL address the following gap: \
   <description of gap>. [Identified by baseline diff ${BL_PREV}..${BL_LATEST}, \
   session autonomous-$SESSION_N.]" \
     --document observations \
     --tags trace-gap,session-$SESSION_N
   ```

4. **If an observation suggests a specific hypothesis**, create a trace
   link from the observation to a new or existing hypothesis.

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
   jq '[.[] | select(.document=="hypotheses")]' /tmp/all_reqs.json \
     > /tmp/hyp_reqs.json
   jq '[.[] | select(.document=="results")]' /tmp/all_reqs.json \
     > /tmp/res_reqs.json
   ```
   Look for hypothesis requirements that have no corresponding result
   (by checking trace links or matching tags). Prefer testing an
   existing untested hypothesis over creating a new one.

3. **If no queued or untested hypothesis exists**, generate one from:
   - *Cross-domain clustering*: Do concepts from different domains that
     share a semantic role (e.g. "approved record", "authority decision")
     cluster tighter in UHT space than concepts from the same domain?
   - *EARS pattern clustering*: Do WHEN-condition requirements cluster
     relative to ubiquitous requirements?
   - *Orphan signal*: Do orphaned requirements differ systematically
     from well-traced ones in UHT space?
   - *Layer entropy*: Which UHT layer shows highest variance across
     a sampled corpus?

4. **Create hypothesis in AIRGen:**
   ```bash
   airgen reqs create $TENANT $PROJECT \
     --text "The UHT SHALL <claim being tested> when applied to <context>. \
   [Confirmed by: <criterion>. Refuted by: <criterion>. \
   Rationale: <why worth testing>.]" \
     --document hypotheses \
     --tags hypothesis,session-$SESSION_N
   ```

5. **Execute test** — budget: 20 classify/compare/batch-compare calls.
   Use `uht-substrate classify`, `uht-substrate compare`,
   `uht-substrate batch-compare` as needed.

6. **Create result in AIRGen:**
   ```bash
   airgen reqs create $TENANT $PROJECT \
     --text "Analysis of <hypothesis-ref> SHALL record result: \
   <confirmed|refuted|inconclusive>. <Summary with data.> \
   [Session: autonomous-$SESSION_N. Sample size: <n>.]" \
     --document results \
     --tags result,session-$SESSION_N

   # Get refs for trace link
   HYP_REF=<ref of hypothesis requirement>
   RES_REF=<ref of result requirement>
   airgen trace create $TENANT $PROJECT \
     --source $HYP_REF --target $RES_REF --type derives
   ```

7. **If result motivates a trait proposal:**
   ```bash
   airgen reqs create $TENANT $PROJECT \
     --text "The UHT trait set SHALL be extended with '<trait>': \
   <definition>. [Motivation: <result-ref> shows <finding>. \
   Expected impact: <effect>. Reclassification burden: ~<n> entities.]" \
     --document trait-proposals \
     --tags trait-proposal,session-$SESSION_N

   # Trace from result to proposal
   airgen trace create $TENANT $PROJECT \
     --source $RES_REF --target $TRT_REF --type derives
   ```

8. **Consume queued hypothesis if used:**
   ```bash
   [ -n "$QUEUED_ID" ] && [ "$QUEUED_ID" != "null" ] && \
     uht-substrate facts delete "$QUEUED_ID"
   ```

9. **Baseline** (store ref in Substrate since bl list is broken):
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

2. **If no queued target**, review existing corpus-log entries in
   `/tmp/all_reqs.json` to see which domains have been covered. Select
   an adjacent domain that would create interesting cross-domain
   comparison opportunities with existing entries.

3. **Check existing coverage:**
   ```bash
   uht-substrate search "$TARGET" --limit 20 > /tmp/existing.json
   ```

4. **Identify 5-10 fundamental entities** not yet in the corpus.
   Classify each:
   ```bash
   uht-substrate classify "<entity>" \
     --context "$TARGET domain concept" --json
   ```

5. **Coherence check** — compare each new entity to its nearest
   neighbours:
   ```bash
   uht-substrate batch-compare "<entity>" "<neighbour1>" "<neighbour2>" \
     --json
   ```

6. **Record in AIRGen corpus-log:**
   ```bash
   airgen reqs create $TENANT $PROJECT \
     --text "The UHT corpus SHALL include the following $TARGET entities \
   as of $(date +%Y-%m-%d): <e1> (<hex1>), <e2> (<hex2>), ... \
   [Cross-domain analogies: <observation>. \
   Most surprising classification: <entity> at <hex> because <reason>.]" \
     --document corpus-log \
     --tags corpus-expansion,$TARGET,session-$SESSION_N
   ```

7. **Consume queued target:**
   ```bash
   [ -n "$TARGET_ID" ] && [ "$TARGET_ID" != "null" ] && \
     uht-substrate facts delete "$TARGET_ID"
   ```

8. **Baseline** (store ref in Substrate since bl list is broken):
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

**Flag if:** any entity has Jaccard < 0.30 to nearest neighbour → urgency `low`

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

**Constraints:**
- 300-600 words total across all four sections
- Lead the Observation section in media res — not "In this session, I..."
- The date field in front matter MUST be quoted: date: "YYYY-MM-DD"

**Output the entry as markdown (no code fences around front matter):**

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

Output the journal entry markdown as the **final and only output** to
stdout. Nothing after it.

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
