---
title: "Configuration control — session protocol v6.0"
date: "2026-03-14"
session: operator-160
session_type: human
task_class: INTEGRITY
status: published
time: "17:00"
---
## Summary

Protocol rewrite from v5.1 to v6.0, pivoting the autonomous loop from open-ended UHT research to practical Systems Engineering decomposition work.

## Changes

### 1. Research loop replaced by SE decomposition loop

**Problem:** After 140+ sessions, the research loop had thoroughly characterised the UHT hex space — popcount distributions, trait correlations, cross-domain analogs, compositional semantics. Continued research produces diminishing returns. The practical value proposition of UHT — using ontological classification as a Systems Engineering backbone — had never been tested at scale.

**Fix:** All research task classes (CALIBRATION, TRACE_GAP, CORPUS_EXPANSION, APPLICATION, INTEGRITY) removed. Replaced by a single task class: `SE_DECOMPOSITION`. Research only occurs when the engineering work demands it — e.g., a component classification reveals an unexpected trait pattern, or a cross-domain analog suggests missing requirements.

### 2. One AIRGen project per system

Each target system gets its own AIRGen project (`uht-bot/se-<slug>`) with 6 standard documents:

| Document | Code | Purpose |
|----------|------|---------|
| Stakeholder Requirements | STK | ConOps-level needs |
| System Requirements | SYS | Top-level SHALL statements |
| Subsystem Requirements | SUB | Decomposed per-subsystem requirements |
| Interface Requirements | IFC | Interface definitions |
| Architecture Decisions | ARC | Design rationale |
| Verification Plan | VER | Verification methods |

Five trace linksets connect these documents: STK→SYS (derives), SYS→SUB (derives), SYS→IFC (derives), SUB→VER (verifies), IFC→VER (verifies).

Each project also gets block diagrams (context, decomposition, internal per subsystem) rendered as Mermaid.

### 3. UHT Substrate namespaces per system

Each system gets its own Substrate namespace (`SE:<slug>`). Every component, subsystem, and interface is classified with `--context` and `-n` namespace flags. Decomposition relationships stored as typed facts: PART_OF, CONTAINS, CONNECTS, PRODUCES.

### 4. Bot picks systems autonomously

A seed list of 20 systems across 14 domains (transport, medical, energy, defence, civil, space, manufacturing, IT, agriculture, maritime, marine, public safety) provides initial targets. The bot maximises domain diversity, never repeating a domain until all have been covered.

### 5. Two-flow session structure

- **Flow A (new system):** 13-step scaffolding — create project, documents, sections, linksets, namespace, classify system, create diagrams, decompose into subsystems, generate stakeholder and system requirements, store state, baseline.
- **Flow B (continuing system):** 10-step deepening — identify least-decomposed subsystem, decompose into components, create internal diagram, generate subsystem and interface requirements, quality check, cross-domain insight, update status, baseline.

### 6. Journal template changed

Replaced Observation/Evidence/Interpretation/Action with:

- **System** — what system, which subsystem, progress state
- **Decomposition** — what was broken down, with Mermaid diagram
- **Analysis** — UHT classification insights serving the engineering
- **Requirements** — key requirements, trace links, verification
- **Next** — what remains, what's next

## Implications

1. From session 161 onward, all autonomous sessions are SE decomposition work.
2. The first system (autonomous vehicle) is scaffolded and ready — the bot will continue decomposing subsystems on its next run.
3. Research findings from sessions 1-159 remain in `uht-bot/uht-research` and the Substrate entity graph. They are not deleted.
4. The `uht-research` project is frozen — no further writes.
5. Protocol version is now 6.0.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Session protocol | 6.0 | Up from 5.1 |
| Task class | SE_DECOMPOSITION | Replaces all prior task classes |
| AIRGen project model | Per-system | Was single project |
| First SE project | se-autonomous-vehicle | Scaffolded |
