---
title: "Configuration control — session protocol v6.1"
date: "2026-03-15"
session: operator-181
session_type: human
task_class: INTEGRITY
status: published
time: "11:00"
---
## Summary

Protocol upgrade from v6.0 to v6.1, addressing systematic templating behaviour in the SE decomposition loop. Sessions 161–180 produced near-identical 5-component decompositions for every subsystem across three different systems, regardless of real-world complexity.

## Changes

### 1. Remove all fixed component counts

**Problem:** The protocol specified rigid ranges — "4-7 subsystems", "3-6 components", "5-8 stakeholder requirements", "5-10 subsystem requirements", "2-4 interfaces", "3-5 external actors". The bot anchored on the midpoint of every range, producing uniform 5-component decompositions for a vehicle perception subsystem (which should have more) and a communication subsystem (which should have fewer). The symmetry is not real-world.

**Fix:** All numeric ranges removed. Replaced with guidance that the count must reflect the actual system's architecture. A wind turbine pitch controller has 3 components; a naval CMS has 15+ subsystems. Explicit instruction: "If you find yourself producing the same count for every system, you are templating, not engineering."

### 2. Engineering principles section

**Problem:** No overarching guidance on what constitutes good systems engineering in this context. The bot followed the protocol's steps mechanically without engineering judgement.

**Fix:** Added an engineering principles section at the top of Phase 3 with four rules:
- **Realism over symmetry** — counts driven by architecture, not templates
- **Depth follows complexity** — decomposition is recursive; complex components get further breakdown
- **Risk and criticality drive priority** — decompose the highest-risk subsystem first, not the least-touched
- **Context descriptions must be specific** — operating environment, key I/O, constraints, performance; not generic "1-2 sentences"

### 3. Flexible session scope

**Problem:** The protocol forced one subsystem per session ("Focus the session on that subsystem"), making every system take the same number of sessions regardless of complexity. Simple subsystems got a full hour; complex ones were rushed.

**Fix:** Sessions may now work on one subsystem in depth, multiple simple subsystems, or revisit a previously decomposed subsystem. Complex subsystems may span multiple sessions. The engineering drives the scope, not a pacing template.

### 4. Priority-based subsystem selection

**Problem:** "Identify the least-decomposed subsystem" forced sequential, even coverage. In practice, the highest-risk or most architecturally significant subsystem should be addressed first.

**Fix:** Replaced with engineering-priority selection considering: safety criticality, unresolved interfaces, architectural significance, lint findings, and whether simple subsystems can be batched.

### 5. Recursive decomposition

**Problem:** The protocol only supported system → subsystem → component (two levels). Real systems have components that are themselves complex enough to need further decomposition.

**Fix:** Components that have internal interfaces, multiple functions, or independent failure modes can now be marked with a `NEEDS_DECOMPOSITION` fact. These must be decomposed before the system is marked complete.

### 6. Explicit completion criteria

**Problem:** Completion was vague: "check if all subsystems have been decomposed." Systems were being marked complete after a single pass with no quality gate.

**Fix:** Seven mandatory criteria must ALL be true before marking complete:
1. Every subsystem has been decomposed into components
2. Every subsystem has requirements traced to system requirements
3. Cross-subsystem interfaces are defined
4. Every requirement has at least one trace link (no orphans)
5. Lint has no unaddressed high-severity findings
6. Components marked NEEDS_DECOMPOSITION have been decomposed
7. Verification entries exist for critical requirements

### 7. Quality gate on lint

**Problem:** The protocol said to run `airgen lint` but didn't require acting on findings. Lint failures were noted in the journal and ignored.

**Fix:** Medium and high severity lint findings must be addressed before marking a system complete. Orphaned requirements must be linked or justified.

### 8. Flexible budget

**Problem:** The 30/25/5 Substrate/AIRGen/reserve split was hard-coded. A scaffolding session needs mostly AIRGen ops; a deep classification session needs mostly Substrate.

**Fix:** Budget is now 60 total with no fixed split. Only hard rule: every session must produce at least one diagram or requirement update (cannot spend entire budget on classification alone).

### 9. System-specific documents

**Problem:** Every system got exactly the same 6 documents regardless of domain. A safety-critical system may need a hazard analysis document; a simple control system may not need architecture decisions as a separate document.

**Fix:** The 6 standard documents remain the default, but the protocol now permits additional system-specific documents (e.g., hazard analysis) when the system warrants them.

## Implications

1. From session 182 onward, decomposition counts should vary by system and subsystem.
2. The current earth observation satellite decomposition (in progress) should reflect these changes on its next session.
3. Previously completed systems (autonomous vehicle, hospital patient monitoring) retain their uniform decompositions — they are not retroactively reworked.
4. Protocol version is now 6.1.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Session protocol | 6.1 | Up from 6.0 |
| Fixed counts | Removed | Was 4-7, 3-6, 5-8, 5-10, 2-4 |
| Completion criteria | 7-point gate | Was "all subsystems visited" |
| Budget model | Flexible 60 | Was 30/25/5 split |
