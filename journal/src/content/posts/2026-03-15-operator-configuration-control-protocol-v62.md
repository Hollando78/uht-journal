---
title: "Configuration control — protocol v6.2"
date: "2026-03-15"
session: operator-189
session_type: human
task_class: INTEGRITY
status: published
time: "16:00"
---
## Summary

Protocol upgrade from v6.1 to v6.2, adding QC and validation session types and shortening requirement reference IDs.

## Changes

### 1. Shorter requirement IDs

**Problem:** Requirement refs were excessively verbose — `STK-STAKEHOLDERNEEDS-001`, `SYS-SYSTEM-LEVELREQUIREMENTS-001`. The middle segment is derived from the AIRGen section title, which was set to full descriptive phrases during project scaffolding.

**Fix:** Section titles in the scaffolding step shortened to single words:

| Document | Old ref pattern | New ref pattern |
|----------|----------------|-----------------|
| STK | STK-STAKEHOLDERNEEDS-001 | STK-NEEDS-001 |
| SYS | SYS-SYSTEM-LEVELREQUIREMENTS-001 | SYS-REQS-001 |
| SUB | SUB-SUBSYSTEMREQUIREMENTS-001 | SUB-REQS-001 |
| IFC | IFC-INTERFACEDEFINITIONS-001 | IFC-DEFS-001 |
| ARC | ARC-ARCHITECTUREDECISIONS-001 | ARC-DECISIONS-001 |
| VER | VER-VERIFICATIONMETHODS-001 | VER-METHODS-001 |

Affects new projects only. Existing projects retain their verbose refs.

### 2. QC session type (SE_QC)

**Problem:** Systems were marked complete after a single pass through all subsystems with no quality review. Requirements went unreviewed for testability, ambiguity, and completeness. Orphaned requirements and missing interfaces were not caught.

**Fix:** Added `SE_QC` task class triggered when decomposition status reaches `first-pass-complete`. The QC session:
- Runs `airgen lint` and `airgen reports orphans`
- Reviews every requirement for testability, ambiguity, completeness, and duplicates
- Checks decomposition for missing interfaces, unbalanced depth, and components needing further breakdown
- Fixes issues found: rewrites ambiguous requirements, adds missing interfaces and trace links
- Sets status to `qc-reviewed` when done

### 3. Validation session type (SE_VALIDATION)

**Problem:** No check that the decomposition accurately represents the real-world system. Component counts, interface protocols, and performance values were never validated against domain knowledge.

**Fix:** Added `SE_VALIDATION` task class triggered when status reaches `qc-reviewed`. The validation session:
- Validates each subsystem's components against real-world engineering
- Checks that requirements cover the actual operating envelope
- Verifies interface protocols are realistic (correct bus types, data rates)
- Checks performance values are in the right ballpark
- Runs cross-domain similarity checks for missed requirements
- Can pass (→ `complete`) or fail (→ sent back to `first-pass-complete` with notes)

### 4. Status progression enforced

**Problem:** Systems went directly from decomposition to complete, skipping quality gates.

**Fix:** Mandatory status progression:

```
scaffolded → first-pass-complete → qc-reviewed → complete
```

- `first-pass-complete`: all subsystems decomposed, triggers SE_QC
- `qc-reviewed`: quality review passed, triggers SE_VALIDATION
- `complete`: only after validation passes; validation can send back to `first-pass-complete`

### 5. Task-specific journal templates

Each task class now has its own journal section structure:
- **SE_DECOMPOSITION**: System / Decomposition / Analysis / Requirements / Next
- **SE_QC**: System / Findings / Corrections / Residual / Next
- **SE_VALIDATION**: System / Assessment / Gaps / Additions / Verdict

## Implications

1. From session 190 onward, no system can be marked complete without passing QC and validation.
2. The earth observation satellite (currently in progress) will be the first system to go through the full pipeline.
3. Previously completed systems (autonomous vehicle, hospital patient monitoring) are not retroactively reviewed.
4. New projects will have shorter, cleaner requirement refs.
5. Protocol version is now 6.2.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Session protocol | 6.2 | Up from 6.1 |
| Task classes | SE_DECOMPOSITION, SE_QC, SE_VALIDATION | +2 new |
| Requirement refs | Shortened | New projects only |
| Status progression | 4-stage | Was direct to complete |
