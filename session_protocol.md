# Autonomous Session Protocol — Systems Engineering decomposition loop
# Executed via: claude --print "$(cat session_protocol.md)"
# CLIs required: airgen-cli, uht-substrate
# SESSION_PROTOCOL_VERSION: 6.1

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
- `SE_PROJECT` — loaded dynamically from Substrate fact `CURRENT_SE_PROJECT`

```bash
SE_PROJECT=$(uht-substrate facts query --predicate CURRENT_SE_PROJECT \
  --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
```

---

## Two Systems, Two Roles

**UHT Substrate** — component classification engine. Every system
component (subsystem, hardware, software, interface) is classified to
get its ontological hex code. The namespace `SE:<system-slug>` isolates
each system's entities. Facts store decomposition relationships:

- `PART_OF` — component belongs to a subsystem or subsystem belongs to system
- `CONTAINS` — system or subsystem contains a component
- `CONNECTS` — interface or data flow between two components
- `PRODUCES` — component generates an output (data, signal, force, etc.)

Operational facts (session counters, project state, directives) live in
the `CLAUDE` namespace. Overwritten freely.

**AIRGen** — requirements management and architecture diagramming tool.
Each system gets its own project (`uht-bot/se-<slug>`) with 6 standard
documents, traced linksets, and block diagrams rendered as Mermaid. This
is the accumulating engineering record. The loop reads AIRGen to
understand decomposition progress and writes AIRGen to record
requirements, architecture decisions, and verification plans.

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

### SE Project Structure

Each system decomposition project uses 6 standard documents:

| Document | Code | Purpose |
|----------|------|---------|
| `stakeholder-requirements` | STK | ConOps-level needs and constraints |
| `system-requirements` | SYS | Top-level system SHALL statements |
| `subsystem-requirements` | SUB | Per-subsystem requirements |
| `interface-requirements` | IFC | Interface definitions between components |
| `architecture-decisions` | ARC | Design rationale and trade-offs |
| `verification-plan` | VER | How each requirement is verified |

### Trace Linksets

- `stakeholder-requirements` → `system-requirements` (derives)
- `system-requirements` → `subsystem-requirements` (derives)
- `system-requirements` → `interface-requirements` (derives)
- `subsystem-requirements` → `verification-plan` (verifies)
- `interface-requirements` → `verification-plan` (verifies)

When creating a trace link, use full IDs (not bare refs):
`airgen trace create $TENANT $SE_PROJECT
--source "uht-bot:$SE_PROJECT:<SOURCE-REF>" --target "uht-bot:$SE_PROJECT:<TARGET-REF>" --type derives`.

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
if [ $? -ne 0 ]; then
  echo "SMOKE FAIL: airgen projects list failed"
  echo "Got: $SMOKE_AG"
  SMOKE_FAIL=1
fi

# 3. Substrate field name is .object (not .object_value)
SMOKE_FIELD=$(echo "$SMOKE_SUB" | jq -r '.facts[0].object // "MISSING"')
if [ "$SMOKE_FIELD" = "MISSING" ] || [ -z "$SMOKE_FIELD" ]; then
  echo "SMOKE FAIL: .facts[0].object field missing — check if field name has changed"
  SMOKE_FAIL=1
fi

# 4. Entity graph is populated and queryable
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

# Load SE project state
SE_PROJECT=$(uht-substrate facts query --predicate CURRENT_SE_PROJECT \
  --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
SE_SYSTEM=$(uht-substrate facts query --predicate CURRENT_SE_SYSTEM \
  --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')
SE_NAMESPACE=$(uht-substrate facts query --predicate CURRENT_SE_NAMESPACE \
  --namespace CLAUDE 2>/dev/null | jq -r '.facts[0].object // ""')

if [ -n "$SE_PROJECT" ]; then
  # Load existing project state
  airgen docs list $TENANT $SE_PROJECT 2>/dev/null
  airgen reqs list $TENANT $SE_PROJECT --json --limit 200 2>/dev/null | jq '.data // []' > /tmp/se_reqs.json
  SE_REQ_COUNT=$(jq 'length' /tmp/se_reqs.json 2>/dev/null || echo 0)
  echo "SE project: $SE_PROJECT ($SE_REQ_COUNT requirements)"

  # Check decomposition progress
  uht-substrate facts query --namespace "$SE_NAMESPACE" 2>/dev/null | \
    jq '.facts // []' > /tmp/se_facts.json
  SE_FACT_COUNT=$(jq 'length' /tmp/se_facts.json 2>/dev/null || echo 0)
  echo "SE namespace: $SE_NAMESPACE ($SE_FACT_COUNT facts)"
fi

# Load entity graph stats
ENTITY_COUNT=$(uht-substrate entities list --limit 1 2>/dev/null | \
  jq -r '.total // 0')
echo "Entity graph contains $ENTITY_COUNT entities"
```

---

## Phase 2: Select System

```bash
DECOMP_TARGET=$(uht-substrate facts query --predicate DECOMPOSITION_TARGET \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')
DECOMP_TARGET_ID=$(uht-substrate facts query --predicate DECOMPOSITION_TARGET \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].uuid // ""')

DECOMP_STATUS=$(uht-substrate facts query --predicate DECOMPOSITION_STATUS \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '.facts[0].object // ""')
```

If `$DIRECTIVE` contains `PAUSE`, write a minimal journal entry and exit.

**Selection logic (first match wins):**

1. **Operator-queued system** — if `$DECOMP_TARGET` is non-empty, use
   that system. Consume the fact after reading.
2. **QC review due** — if `$DECOMP_STATUS` is `first-pass-complete`,
   run an **SE_QC** session (Flow C below).
3. **Validation due** — if `$DECOMP_STATUS` is `qc-reviewed`,
   run an **SE_VALIDATION** session (Flow D below).
4. **Continue decomposition** — if `$SE_PROJECT` is non-empty and
   `$DECOMP_STATUS` is `scaffolded` or `in-progress`, continue
   decomposing (Flow B).
5. **Pick a new system autonomously** — no active project or current
   system is complete.

### Autonomous system selection

Check `COMPLETED_SYSTEMS` fact for previously completed systems. Pick
from the seed list below, maximising domain diversity. Never repeat a
domain until all domains have been covered.

```bash
COMPLETED=$(uht-substrate facts query --predicate COMPLETED_SYSTEMS \
  --namespace CLAUDE 2>/dev/null | \
  jq -r '[.facts[].object] | join(",")' 2>/dev/null || echo "")
```

**Seed systems (pick one per session, diverse domains):**

| System | Domain | Scale | Notes |
|--------|--------|-------|-------|
| Autonomous vehicle | Transport | Large | Sensors, compute, actuators, safety |
| Hospital patient monitoring | Medical | Medium | Sensors, alerts, records, regulatory |
| Solar farm with battery storage | Energy | Large | Generation, storage, grid interface |
| Naval combat management system | Defence | Large | Sensors, weapons, C2, comms |
| Smart building management | Civil | Medium | HVAC, access, fire, lighting |
| Earth observation satellite | Space | Large | Optics, comms, power, attitude |
| Automated warehouse | Manufacturing | Medium | Robotics, inventory, routing |
| Air traffic control system | Transport | Large | Radar, comms, display, safety |
| Water treatment plant | Civil | Medium | Chemical, filtration, monitoring |
| Surgical robot | Medical | Medium | Haptics, vision, instruments |
| Wind turbine control system | Energy | Small | Pitch, yaw, generator, monitoring |
| Cybersecurity operations centre | IT | Medium | SIEM, threat intel, response |
| Railway signalling system | Transport | Large | Interlocking, detection, comms |
| Offshore oil platform safety system | Energy | Large | Gas detection, shutdown, fire |
| Precision agriculture drone fleet | Agriculture | Medium | Navigation, imaging, spraying |
| Nuclear reactor protection system | Energy | Large | Sensors, trip logic, actuators |
| Container ship cargo management | Maritime | Large | Loading, stability, monitoring |
| Emergency dispatch system | Public safety | Medium | Call handling, dispatch, tracking |
| Autonomous underwater vehicle | Marine | Medium | Navigation, sensors, propulsion |
| Pharmaceutical manufacturing line | Manufacturing | Medium | Dosing, mixing, QC, packaging |

When the seed list is exhausted and the bot proposes its own system, it must be:
- A real, recognisable engineered system (not abstract)
- Different domain from any completed system
- Complex enough for a meaningful decomposition

```bash
uht-substrate facts upsert "autonomous-loop" CURRENT_TASK_CLASS \
  "SE_DECOMPOSITION" --namespace CLAUDE
```

---

## Phase 3: Execute Decomposition

### Engineering principles (apply to ALL steps below)

**Realism over symmetry.** The number of subsystems, components,
requirements, and interfaces must reflect the actual engineered system,
not a template. A wind turbine pitch controller has 3 components; a
naval CMS has 15+ subsystems. If you find yourself producing the same
count for every system, you are templating, not engineering.

**Depth follows complexity.** A safety-critical subsystem may need
sub-components decomposed further; a simple power bus does not.
Decomposition is recursive — if a component is itself a system (has
internal interfaces, multiple functions, independent failure modes),
decompose it. If a component is a single device or algorithm, stop.

**Risk and criticality drive priority.** Decompose the highest-risk,
most architecturally significant subsystem first — not the
alphabetically first or least-touched one. The subsystem with the most
interfaces, the tightest performance constraints, or the highest safety
integrity level should be addressed before simple utility subsystems.

**Context descriptions must be specific.** Do NOT write generic
"1-2 sentence" descriptions. Every `--context` argument must include:
the component's operating environment, its key inputs/outputs,
performance constraints, and what makes it distinct from similar
components. Example: "Multi-constellation GNSS receiver with RTK
corrections, receiving L1/L5 signals from GPS, Galileo, and GLONASS.
Provides <10cm position accuracy at 10Hz for autonomous vehicle
localisation in urban canyons with heavy multipath."

**Budget is flexible within the total.** The 60-operation budget is a
ceiling, not a split. A scaffolding session may use 40 AIRGen ops and
20 Substrate ops. A deep classification session may reverse that ratio.
Spend the budget where the engineering needs it.

---

### Flow A: New System (no existing SE_PROJECT)

Use this flow when starting a fresh system decomposition.

**1. Create AIRGen project:**

```bash
SYSTEM_NAME="<system name>"
SYSTEM_SLUG="<system-slug>"  # lowercase, hyphenated
airgen projects create $TENANT --name "$SYSTEM_NAME" --key "se-$SYSTEM_SLUG" --slug "se-$SYSTEM_SLUG" --description "UHT-backed system decomposition: $SYSTEM_NAME"
```

**2. Create documents:**

Start with the 6 standard documents. If the system warrants additional
documents (e.g., hazard analysis for safety-critical systems, concept
of operations for complex systems), create them.

```bash
P="se-$SYSTEM_SLUG"
airgen docs create $TENANT $P --name "Stakeholder Requirements" --code STK --description "ConOps-level needs and constraints"
airgen docs create $TENANT $P --name "System Requirements" --code SYS --description "Top-level system SHALL statements"
airgen docs create $TENANT $P --name "Subsystem Requirements" --code SUB --description "Per-subsystem decomposed requirements"
airgen docs create $TENANT $P --name "Interface Requirements" --code IFC --description "Interface definitions between components"
airgen docs create $TENANT $P --name "Architecture Decisions" --code ARC --description "Design rationale and trade-offs"
airgen docs create $TENANT $P --name "Verification Plan" --code VER --description "Verification approach for each requirement"
# Add system-specific documents if needed:
# airgen docs create $TENANT $P --name "Hazard Analysis" --code HAZ --description "Safety hazard identification and mitigation"
```

**3. Create sections (one per document):**

```bash
airgen docs sections create $TENANT $P stakeholder-requirements --title "Needs"
airgen docs sections create $TENANT $P system-requirements --title "Reqs"
airgen docs sections create $TENANT $P subsystem-requirements --title "Reqs"
airgen docs sections create $TENANT $P interface-requirements --title "Defs"
airgen docs sections create $TENANT $P architecture-decisions --title "Decisions"
airgen docs sections create $TENANT $P verification-plan --title "Methods"
```

**4. Create trace linksets:**

```bash
airgen trace linksets create $TENANT $P --source stakeholder-requirements --target system-requirements --link-type derives
airgen trace linksets create $TENANT $P --source system-requirements --target subsystem-requirements --link-type derives
airgen trace linksets create $TENANT $P --source system-requirements --target interface-requirements --link-type derives
airgen trace linksets create $TENANT $P --source subsystem-requirements --target verification-plan --link-type verifies
airgen trace linksets create $TENANT $P --source interface-requirements --target verification-plan --link-type verifies
```

**5. Create Substrate namespace:**

```bash
uht-substrate namespaces create "SE:$SYSTEM_SLUG" "$SYSTEM_NAME"
```

**6. Classify the system entity:**

```bash
uht-substrate classify "$SYSTEM_NAME" \
  --context "<detailed description: purpose, operating environment, key constraints, scale, domain>" \
  -n "SE:$SYSTEM_SLUG"
```

**7. Create system context diagram:**

```bash
DIAG_JSON=$(airgen diag create $TENANT $P --name "$SYSTEM_NAME — Context" --view block --description "System context diagram" 2>&1)
DIAG_ID=$(echo "$DIAG_JSON" | jq -r '.diagram.id // empty')

# Create system block
airgen diag blocks create $TENANT $P --diagram $DIAG_ID --name "$SYSTEM_NAME" --kind system

# Create external actor/system blocks — as many as the real system interacts with
airgen diag blocks create $TENANT $P --diagram $DIAG_ID --name "<Actor>" --kind actor
airgen diag connectors create $TENANT $P --diagram $DIAG_ID --source <system-block-id> --target <actor-block-id> --kind flow --label "<data/control flow>"
```

**8. Decompose into subsystems:**

Identify the real subsystems of the real system. The count is driven by
the system's architecture, not a protocol target. Consider:
- What are the major functional groupings?
- What would be separate contracts or separate teams in a real programme?
- What has independent failure modes?
- What has distinct physical or logical boundaries?

For each subsystem:
```bash
uht-substrate classify "<Subsystem>" \
  --context "<specific description: function, key interfaces, performance envelope, technology base>" \
  -n "SE:$SYSTEM_SLUG"

uht-substrate facts store "<Subsystem>" PART_OF "$SYSTEM_NAME" -n "SE:$SYSTEM_SLUG"
```

**9. Create system decomposition diagram:**

```bash
DECOMP_JSON=$(airgen diag create $TENANT $P --name "$SYSTEM_NAME — Decomposition" --view block --description "Subsystem decomposition" 2>&1)
DECOMP_ID=$(echo "$DECOMP_JSON" | jq -r '.diagram.id // empty')
```

**10. Generate stakeholder requirements:**

Derive from the system's real stakeholder needs. Different systems have
different stakeholders — a military system has operators, maintainers,
and a procurement authority; a medical device has clinicians, patients,
and regulators. Write as many requirements as the system demands.

```bash
STK_SECTION=$(airgen docs get $TENANT $P stakeholder-requirements --json 2>/dev/null | jq -r '.document.sections[0].id // empty')

airgen reqs create $TENANT $P \
  --text "The $SYSTEM_NAME SHALL <stakeholder need>." \
  --document stakeholder-requirements \
  --section $STK_SECTION \
  --tags stakeholder,session-$SESSION_N
```

**11. Generate system-level requirements:**

Derive from stakeholder requirements. Each system requirement must
trace to at least one stakeholder requirement. Include performance,
safety, reliability, interface, and environmental requirements as
the system demands — not a fixed set.

```bash
SYS_SECTION=$(airgen docs get $TENANT $P system-requirements --json 2>/dev/null | jq -r '.document.sections[0].id // empty')

SYS_JSON=$(airgen reqs create $TENANT $P \
  --text "The $SYSTEM_NAME SHALL <system requirement>." \
  --document system-requirements \
  --section $SYS_SECTION \
  --tags system,session-$SESSION_N 2>&1)
SYS_REF=$(echo "$SYS_JSON" | jq -r '.requirement.ref // empty')

airgen trace create $TENANT $P \
  --source "uht-bot:$P:$STK_REF" \
  --target "uht-bot:$P:$SYS_REF" --type derives
```

**12. Store SE project state:**

```bash
uht-substrate facts upsert "autonomous-loop" CURRENT_SE_PROJECT "se-$SYSTEM_SLUG" --namespace CLAUDE
uht-substrate facts upsert "autonomous-loop" CURRENT_SE_SYSTEM "$SYSTEM_NAME" --namespace CLAUDE
uht-substrate facts upsert "autonomous-loop" CURRENT_SE_NAMESPACE "SE:$SYSTEM_SLUG" --namespace CLAUDE
uht-substrate facts upsert "se-$SYSTEM_SLUG" DECOMPOSITION_STATUS "scaffolded" --namespace CLAUDE
```

**13. Create baseline:**

```bash
airgen bl create $TENANT $P --label "SCAFFOLD-$(date +%Y-%m-%d)"
```

---

### Flow B: Continuing System (SE_PROJECT exists)

Use this flow when an SE project already exists and decomposition is
in progress. A session may work on one subsystem in depth, multiple
simple subsystems, or revisit a previously decomposed subsystem to
add missing interfaces or deeper component decomposition. Let the
engineering drive the scope, not a one-subsystem-per-session template.

**1. Load project state and assess progress:**

```bash
# Requirements by document
airgen reqs list $TENANT $SE_PROJECT --json --limit 200 2>/dev/null | jq '.data // []' > /tmp/se_reqs.json

# Diagrams
airgen diag list $TENANT $SE_PROJECT 2>/dev/null

# Decomposition structure
uht-substrate facts query -p PART_OF -n "$SE_NAMESPACE" 2>/dev/null | jq '.facts // []'

# Interfaces
uht-substrate facts query -p CONNECTS -n "$SE_NAMESPACE" 2>/dev/null | jq '.facts // []'
```

**2. Choose what to work on based on engineering priority:**

Do NOT simply pick "the least-decomposed subsystem." Instead, consider:
- Which subsystem has the highest risk or safety criticality?
- Which subsystem has the most unresolved interfaces with others?
- Are there components that need further decomposition (sub-components)?
- Are there cross-subsystem interfaces not yet defined?
- Did lint flag issues that need addressing?
- Can two simple subsystems be done in one session?

If a subsystem is complex enough to warrant multiple sessions, that is
correct — do not rush through it to maintain even pacing.

**3. Decompose subsystem into components:**

Identify the real components. Some subsystems have 2 components; others
have 10. If a component is itself complex (has internal interfaces,
multiple functions, independent failure modes), it may need its own
decomposition in a later session — store a fact marking it for deeper
work:

```bash
uht-substrate classify "<Component>" \
  --context "<specific: what it does, key I/O, technology, constraints, performance>" \
  -n "$SE_NAMESPACE"

uht-substrate facts store "<Component>" PART_OF "<Subsystem>" -n "$SE_NAMESPACE"
uht-substrate facts store "<Component>" PRODUCES "<output>" -n "$SE_NAMESPACE"

# If component needs deeper decomposition in a future session:
uht-substrate facts store "<Component>" NEEDS_DECOMPOSITION "true" -n "$SE_NAMESPACE"
```

**4. Create internal block diagram for the subsystem:**

```bash
INT_JSON=$(airgen diag create $TENANT $SE_PROJECT \
  --name "<Subsystem> — Internal" --view internal \
  --description "Internal component diagram for <Subsystem>" 2>&1)
INT_ID=$(echo "$INT_JSON" | jq -r '.diagram.id // empty')
```

**5. Generate subsystem requirements:**

Write requirements driven by the subsystem's engineering needs. Include
performance, interface, safety, and reliability requirements as
appropriate. Do NOT generate a fixed number. A sensor array might need
15 requirements; a simple relay module might need 3.

```bash
SUB_SECTION=$(airgen docs get $TENANT $SE_PROJECT subsystem-requirements --json 2>/dev/null | jq -r '.document.sections[0].id // empty')

SUB_JSON=$(airgen reqs create $TENANT $SE_PROJECT \
  --text "The <Subsystem> SHALL <requirement>." \
  --document subsystem-requirements \
  --section $SUB_SECTION \
  --tags subsystem,<subsystem-tag>,session-$SESSION_N 2>&1)
SUB_REF=$(echo "$SUB_JSON" | jq -r '.requirement.ref // empty')

airgen trace create $TENANT $SE_PROJECT \
  --source "uht-bot:$SE_PROJECT:$PARENT_SYS_REF" \
  --target "uht-bot:$SE_PROJECT:$SUB_REF" --type derives
```

**6. Define interfaces:**

Interfaces exist wherever data, power, control signals, or physical
connections cross a component boundary. Define all real interfaces,
not a fixed quota. Include protocol, data rate, latency, and format
where relevant.

```bash
IFC_SECTION=$(airgen docs get $TENANT $SE_PROJECT interface-requirements --json 2>/dev/null | jq -r '.document.sections[0].id // empty')

airgen reqs create $TENANT $SE_PROJECT \
  --text "The interface between <Component A> and <Component B> SHALL <interface requirement>." \
  --document interface-requirements \
  --section $IFC_SECTION \
  --tags interface,<subsystem-tag>,session-$SESSION_N

uht-substrate facts store "<Component A>" CONNECTS "<Component B>" -n "$SE_NAMESPACE"
```

**7. Quality gate (mandatory before marking complete):**

```bash
airgen lint $TENANT $SE_PROJECT --format text
airgen reports orphans $TENANT $SE_PROJECT
```

Review lint findings. If lint reports medium or high severity issues,
address them before marking the system complete. Orphaned requirements
(no trace links) must be linked or justified.

**8. Cross-domain insight (if budget remains):**

```bash
uht-substrate entities find-similar "<most interesting component>" --min-traits 15 --limit 5
```

If a cross-domain analog suggests missing requirements, interfaces,
or failure modes, add them.

**9. First-pass completion assessment:**

The first pass is complete when ALL subsystems have been decomposed
into components with requirements and interfaces. Do NOT mark
first-pass-complete just because every subsystem has been visited —
check that each has components, requirements, and interfaces defined.

When all subsystems are covered:
```bash
uht-substrate facts upsert "se-$SYSTEM_SLUG" DECOMPOSITION_STATUS "first-pass-complete" --namespace CLAUDE
```

Do NOT mark `complete` — the system must pass QC and validation first.
If decomposition is not yet finished, leave status as-is.

**10. Create baseline:**

```bash
airgen bl create $TENANT $SE_PROJECT --label "DECOMP-$(date +%Y-%m-%d)"
```

---

### Flow C: QC Review (DECOMPOSITION_STATUS = first-pass-complete)

Use this flow when all subsystems have been decomposed and the system
needs quality review. This is an inward-looking review — does the work
meet engineering standards? Task class: `SE_QC`.

**1. Load the full project:**

```bash
airgen reqs list $TENANT $SE_PROJECT --json --limit 500 2>/dev/null | jq '.data // []' > /tmp/se_reqs.json
airgen diag list $TENANT $SE_PROJECT 2>/dev/null
uht-substrate facts query -n "$SE_NAMESPACE" --limit 200 2>/dev/null | jq '.facts // []' > /tmp/se_facts.json
uht-substrate facts namespace-context "$SE_NAMESPACE" 2>/dev/null > /tmp/se_context.json
```

**2. Run quality tools:**

```bash
airgen lint $TENANT $SE_PROJECT --format text
airgen reports orphans $TENANT $SE_PROJECT
airgen reports stats $TENANT $SE_PROJECT
```

**3. Review every requirement for:**
- **Testability** — does it have measurable acceptance criteria?
  Bad: "The system SHALL be reliable." Good: "The system SHALL achieve
  MTBF >= 10,000 hours."
- **Ambiguity** — flag words: appropriate, sufficient, adequate,
  reasonable, normal, timely, user-friendly, robust, flexible
- **Completeness** — missing performance values, missing units,
  missing conditions (EARS "When"/"While" triggers)
- **Duplicates** — requirements that say the same thing in different
  words (check by comparing text similarity across the full set)
- **Traceability** — every SUB/IFC requirement should trace to a SYS
  requirement; every SYS should trace to an STK requirement

**4. Review decomposition for:**
- Missing interfaces (components that interact but have no IFC req)
- Components that should be further decomposed (complex, multi-function)
- Subsystems with suspiciously uniform component counts
- Facts in Substrate with no corresponding AIRGen requirements

**5. Fix issues found:**
- Create new requirements to replace ambiguous ones (tag old as
  `superseded-by-session-$SESSION_N`)
- Add missing interface requirements and trace links
- Add missing verification entries for critical requirements
- Link orphaned requirements
- Mark complex components with NEEDS_DECOMPOSITION if warranted

**6. Update status:**

```bash
uht-substrate facts upsert "se-$SYSTEM_SLUG" DECOMPOSITION_STATUS "qc-reviewed" --namespace CLAUDE
airgen bl create $TENANT $SE_PROJECT --label "QC-$(date +%Y-%m-%d)"
```

---

### Flow D: Validation (DECOMPOSITION_STATUS = qc-reviewed)

Use this flow after QC has been completed. This is an outward-looking
review — does the decomposition accurately represent the real system?
Task class: `SE_VALIDATION`.

**1. Load project and assess overall state:**

```bash
airgen reqs list $TENANT $SE_PROJECT --json --limit 500 2>/dev/null | jq '.data // []' > /tmp/se_reqs.json
airgen reports stats $TENANT $SE_PROJECT
airgen reports orphans $TENANT $SE_PROJECT
uht-substrate facts namespace-context "$SE_NAMESPACE" 2>/dev/null > /tmp/se_context.json
```

**2. Validate each subsystem against real-world engineering:**
- Are these the right components for this subsystem in a real system?
- Are there real-world components that are missing?
- Do the requirements cover the actual operating envelope?
- Are safety-critical requirements identified and appropriately traced?
- Are interface protocols realistic (correct bus types, data rates,
  message formats for this domain)?
- Are performance values in the right ballpark for this class of system?

**3. Validate system-level completeness:**
- Do the stakeholder requirements cover all real stakeholders?
- Are there system-level requirements that no subsystem addresses?
- Are cross-subsystem interfaces complete?
- Is the verification plan adequate for the system's criticality level?

**4. Cross-domain validation:**

```bash
# Check key components for analogs that might reveal missing requirements
uht-substrate entities find-similar "<critical component>" --min-traits 15 --limit 10
```

If a cross-domain analog from a more mature domain (e.g., aerospace,
nuclear) has requirements that this system lacks, add them.

**5. Address gaps:**
- Add missing components and classify them
- Add missing requirements with trace links
- Add missing interfaces
- Fix unrealistic performance values

**6. Verdict:**

If validation passes (no critical gaps remaining):
```bash
uht-substrate facts upsert "se-$SYSTEM_SLUG" DECOMPOSITION_STATUS "complete" --namespace CLAUDE
uht-substrate facts store "autonomous-loop" COMPLETED_SYSTEMS "se-$SYSTEM_SLUG" --namespace CLAUDE
# Clear current project
uht-substrate facts delete <CURRENT_SE_PROJECT fact uuid>
uht-substrate facts delete <CURRENT_SE_SYSTEM fact uuid>
uht-substrate facts delete <CURRENT_SE_NAMESPACE fact uuid>
airgen bl create $TENANT $SE_PROJECT --label "VALIDATED-$(date +%Y-%m-%d)"
```

If validation fails (critical gaps found):
```bash
# Send back for more decomposition work
uht-substrate facts upsert "se-$SYSTEM_SLUG" DECOMPOSITION_STATUS "first-pass-complete" --namespace CLAUDE
uht-substrate facts upsert "se-$SYSTEM_SLUG" VALIDATION_NOTES "<what needs fixing>" --namespace CLAUDE
```

---

## Phase 4: Flag Findings

If significance threshold met, store a notification fact. The dispatcher
reads this after the session, sends the Telegram message, and deletes it.

```bash
uht-substrate facts upsert "telegram-notify" PENDING_NOTIFICATION \
  "$SUMMARY | $URGENCY" --namespace CLAUDE
```

**Flag if:**
- New system scaffolded → urgency `low`
- Cross-domain analog found (Jaccard >= 0.70) → urgency `medium`
- First-pass decomposition complete → urgency `medium`
- QC review complete → urgency `medium`
- System validated and complete → urgency `high`
- Validation failed (sent back for rework) → urgency `high`
- Lint findings reveal requirement quality issues → urgency `medium`

Do not store the fact if no threshold was met.

---

## Phase 5: Write Journal Entry

First-person account of the engineering work performed. Not a log.

**Section structure depends on task class:**

### SE_DECOMPOSITION entries:

## System
What system, which subsystem, progress state.

## Decomposition
What was broken down. Include Mermaid diagram.

## Analysis
UHT classification insights relevant to the engineering. Cross-domain
analogs. Lint findings. Only analysis that serves the engineering.

## Requirements
Key requirements generated. Trace links. Verification approach.

## Next
What remains. What the next session should tackle.

### SE_QC entries:

## System
Which system, QC session scope, overall project statistics.

## Findings
Requirement quality issues, missing interfaces, decomposition gaps,
trace coverage, lint results. Quantify: "12/85 requirements lack
measurable criteria", not "some requirements are vague".

## Corrections
What was fixed — rewritten requirements, added interfaces, new trace
links, verification entries. Reference specific refs.

## Residual
What remains unfixed and why (budget, needs engineering judgement, etc.)

## Next
Ready for validation, or needs another QC pass.

### SE_VALIDATION entries:

## System
Which system, validation scope.

## Assessment
Overall quality. What's strong, what's weak. Compare against real-world
expectations for this class of system.

## Gaps
Missing components, unrealistic requirements, coverage holes.

## Additions
What was added to address gaps.

## Verdict
Pass (→ complete) or fail (→ back to first-pass-complete with notes).

**Graph markup:** When mentioning hex codes, entities, traits, or AIRGen
references in the journal text, wrap them in double-brace tags so the
journal site can link them to the engineering graph automatically:

- `{{hex:E6881098}}` — component hex codes
- `{{entity:GPS receiver}}` — component/subsystem names
- `{{trait:Powered}}` — trait names
- `{{stk:STK-NEEDS-001}}` — stakeholder requirement refs
- `{{sys:SYS-REQS-001}}` — system requirement refs
- `{{sub:SUB-REQS-001}}` — subsystem requirement refs
- `{{ifc:IFC-DEFS-001}}` — interface requirement refs

These render as plain text in the journal but become interactive graph
links when enrichment is toggled on. Use them inline in prose wherever
the reference appears naturally — do not restructure sentences to
accommodate tags. Hex codes and AIRGen refs MUST always be tagged.
Entity and trait names SHOULD be tagged on first mention in each section.

**Exclude:**
- Command names, flag names, JSON keys, tool call mechanics
- Hedging language unless genuine uncertainty exists

**Anti-navel-gazing rule:**
The journal entry MUST describe engineering work — system decomposition,
component analysis, requirements, architecture. If an operational issue
was encountered, note it in Next as one sentence. Do not write about
the loop's infrastructure, protocol, or tooling.

**Constraints:**
- 400-700 words total across all five sections
- Lead the System section with what system and where we are in it
- Include at least one Mermaid diagram per entry (from `airgen diag render`)
- The date field in front matter MUST be quoted: date: "YYYY-MM-DD"

**Output the entry as your final plain-text assistant message (no code
fences, no Bash echo/cat — the dispatcher only captures your text
response, not tool output):**

---
title: "<finding-focused title — not the task class name>"
date: "<YYYY-MM-DD>"
session: autonomous-<SESSION_N>
session_type: autonomous
task_class: <SE_DECOMPOSITION|SE_QC|SE_VALIDATION>
status: published
---

Write the full entry text with ## headings after the front matter.
Use the section structure matching your task class (see above).

---

## Phase 6: Close Session

```bash
uht-substrate facts upsert "autonomous-loop" LAST_SESSION_END \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace CLAUDE

uht-substrate facts upsert "autonomous-loop" LAST_TASK_CLASS \
  "$TASK_CLASS" --namespace CLAUDE
```

## CRITICAL OUTPUT RULES

**Step 1 (mandatory backup):** Before your final message, write the
journal entry to a file using Bash:

```bash
cat > /tmp/uht-journal-entry.md << 'JOURNAL_EOF'
---
title: "<your title>"
date: "<YYYY-MM-DD>"
session: autonomous-<SESSION_N>
session_type: autonomous
task_class: <SE_DECOMPOSITION|SE_QC|SE_VALIDATION>
status: published
---

<your full entry with section headings matching your task class>
JOURNAL_EOF
```

**Step 2:** Your very last message must ALSO be the journal entry as
plain text — NOT inside a tool call. Start with `---` and end with the
last line of the Next section. No commentary before or after.

The dispatcher prefers your final text response but falls back to
`/tmp/uht-journal-entry.md` if the text response has no front matter.

---

## Hard Constraints

**Budget:** 60 bash operations per session. No fixed split between
Substrate and AIRGen — spend the budget where the engineering needs it.
A scaffolding session may be 80% AIRGen; a deep classification session
may be 80% Substrate. The only hard rule: every session MUST produce
at least one diagram or requirement update in AIRGen (do not spend the
entire budget on classification with nothing written to the project).

Execution order: assess state first, then work on the highest-priority
engineering task, then journal entry.

**No silent overwrites:** Do not update or delete requirements created
by prior sessions. If a prior requirement appears wrong, create a new
requirement disputing it, and flag for Telegram.

**Write access:** All writes go to `uht-bot/se-*` projects only.
No writes to any other tenant or project.

**All classify calls must include `--context` and `-n` namespace flag.**
Every component, subsystem, and system entity must be classified with
a rich context description and assigned to its `SE:<slug>` namespace.

**Requirements must follow EARS pattern where possible.** Use
"The <system/subsystem> SHALL ..." for unconditional requirements.
Use "When <trigger>, the <system> SHALL ..." for event-driven
requirements. Use "While <state>, the <system> SHALL ..." for
state-driven requirements.

**Every requirement must be in a section** (for trace linksets to
work). Never create a requirement without `--section <id>`.

**Diagrams must be rendered as Mermaid in the journal entry.** Use
`airgen diag render $TENANT $SE_PROJECT --diagram <id> --format mermaid`
to get the Mermaid source and include it in the Decomposition section.
**Mermaid syntax rules (MANDATORY — violations break rendering):**
- Use `-->` for arrows. Do NOT use `--*`, `--o`, or `==>`.
- Edge labels: `-->|label text| B`. No quotes inside `|...|`.
- Do NOT use `\n` inside label strings — it renders as literal text.
- Do NOT use `>` shape syntax for nodes (e.g., `id>"label"]`).
- Use short IDs (e.g., `RP`, `PM`) not AIRGen block IDs.
- Keep labels short and on one line.
- Use `flowchart TB` or `flowchart LR`.
- The mermaid code fence MUST be closed with ``` on its own line.
  Do NOT put prose inside the mermaid block.
