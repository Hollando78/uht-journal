---
title: "Configuration control — session protocol v5.1"
date: "2026-03-13"
session: operator-131
session_type: human
task_class: INTEGRITY
status: published
time: "17:00"
---
## Summary

Protocol upgrade from v5.0 to v5.1, driven by a research audit identifying topic saturation, methodological weaknesses, and underutilised tools across sessions 117–130.

## Changes

### 1. Research phase: FALSIFICATION → DIRECTED INVESTIGATION

**Problem:** The research phase was labelled "FALSIFICATION" but the bot had settled into a narrow pattern — 53% of journal content touched sparsity-related themes (null-hex, popcount, trait loss). Basic structural properties of the hex space are well-established. Continued falsification of the same properties yields diminishing returns.

**Fix:** Research phase renamed to DIRECTED INVESTIGATION with explicit priorities: (1) scale up from anecdote to statistical analysis, (2) test practical applications, (3) explore neglected dimensions of the taxonomy. Preference shifted toward APPLICATION and CALIBRATION over CORPUS_EXPANSION.

### 2. Saturated topics list

**Problem:** No mechanism existed to prevent the bot from repeatedly studying the same themes. Sessions gravitated toward the most testable properties (sparsity, popcount) because they produce clean confirmable results.

**Fix:** Added a "Saturated topics" section listing 5 topics that MUST NOT be the primary focus of a session:

| Topic | Status |
|---|---|
| Null-hex / sparse trait entities | DONE — three-tier rescuability model established |
| Popcount as complexity metric | DONE — phase boundary and inverted-U confirmed |
| Trait loss / markedness asymmetry | DONE — erasure-not-inversion confirmed across 8+ pairs |
| Antonym / binary opposition structure | DONE — trimodal structure and subsumption found |
| "UHT measures being, not doing" | DONE — confirmed from 6+ independent angles |

Before choosing a research question, sessions must check the last 5 journal entries and avoid these topics.

### 3. Priority-ordered research agenda (16 directives)

**Problem:** Sessions had no structured guidance on what to investigate next. The bot optimised for clean results rather than high-value unknowns. Key tools (`disambiguate`, `semantic-triangle`, `map-properties`, `impact`, `airgen lint`) had never been used. Sample sizes remained at 6–12 hand-picked entities despite 8,300+ entities in the graph.

**Fix:** Added 16 research directives across 5 priority levels:

**P0 — Methodological foundations:**
1. Statistical null model (random baseline for all quantitative claims)
2. Scale up sample sizes to 50–200 entities
3. Use `disambiguate` before classifying ambiguous terms

**P1 — High-value unexplored directions:**
4. Cross-domain analog discovery at scale (UHT's unique value proposition)
5. Trait correlation matrix and effective dimensionality
6. UHT vs embeddings divergence study at scale
7. Context enrichment audit of early classifications

**P2 — Under-explored entity categories:**
8. Temporal / process entities
9. Compositional semantics (compound concept trait inheritance)
10. Trait correlation with external taxonomies (BFO, SUMO, Cyc)

**P3 — Operational application testing:**
11. Run `uht-substrate impact` on a real baseline diff
12. Run `airgen lint` on the research project
13. Requirements deduplication via hex distance (HYP-008/HYP-009)
14. Use `semantic-triangle` and `map-properties` for diagnostic analysis

**P4 — Research infrastructure:**
15. Record research facts aggressively (target: 200+ within 30 sessions)
16. Run corpus-wide aggregate queries

Sessions SHOULD select from this list rather than revisiting saturated topics. Once a directive has 3+ sessions with converging findings, it moves to the saturated list.

### 4. Graph markup convention

**Problem:** The journal enrichment engine relied on heuristic regex detection of entities, traits, and hex codes — prone to false positives on single-word entities and unable to detect AIRGen references without exact pattern matching.

**Fix:** Added a `{{type:ref}}` markup convention to the journal template specification. Sessions now tag references deterministically in the markdown source:

- `{{hex:E6881098}}` — UHT hex codes
- `{{entity:Candle}}` — entity names
- `{{trait:Ritualised}}` — trait names
- `{{hyp:HYP-ACTIVEHYPOTHESES-075}}` — hypothesis refs
- `{{res:RES-CALIBRATIONRESULTS-088}}` — result refs
- `{{obs:OBS-STRUCTURALFINDINGS-060}}` — observation refs
- `{{trt:TRT-TRAITPROPOSALS-009}}` — trait proposal refs

Tags are stripped on page load into `<span>` elements with `data-graph-type` and `data-graph-ref` attributes, enabling the enrichment engine to detect references with 100% precision.

### 5. Open hypotheses list updated

Cleaned up the open hypotheses list. Cross-referenced directives for testable hypotheses (HYP-008 → directive 13, HYP-040/HYP-053 → directive 5). Marked HYP-041 as CLOSED (pre-empted by v4.1 context fix) and HYP-006 as CLOSED (refuted, session 49).

## Implications

1. Sessions from 131 onward should exhibit greater topic diversity and larger sample sizes.
2. The first P0 directive (statistical null model) should be completed within the next 5 sessions — without it, no quantitative claim in the research record is credible.
3. Cross-domain analog discovery (directive 4) represents the single largest missed opportunity with ~20 facts recorded for 8,300+ entities.
4. Graph markup in new journal entries enables deterministic enrichment without false-positive risk.
5. Protocol version is now 5.1. All sessions from 131 onward run under this version.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Session protocol | 5.1 | Up from 5.0 |
| Research phase | DIRECTED INVESTIGATION | Was FALSIFICATION |
| Research directives | 16 (P0–P4) | New |
| Saturated topics | 5 | New |
| Graph markup | {{type:ref}} convention | New |
