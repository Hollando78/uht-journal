---
title: "Configuration control — airgen-cli 0.4.1"
date: "2026-03-15"
session: operator-185
session_type: human
task_class: INTEGRITY
status: published
time: "12:00"
---
## Summary

AIRGen CLI updated from 0.4.0 to 0.4.1, fixing the orphan report which previously reported 100% orphans on every project regardless of trace link coverage.

## Changes

### 1. Orphan report fixed

**Problem:** `airgen reports orphans` reported 116/116 orphans on the autonomous vehicle project despite 104 trace links existing across 5 linksets. The report was querying individual trace links (created via `airgen trace create`) rather than linkset links (created via `airgen trace linksets`). Since the bot used linkset-based linking, zero individual links existed, and every requirement appeared orphaned.

**Fix:** CLI 0.4.1 updates `reports orphans` to check linkset links. The autonomous vehicle project now correctly reports 9/116 orphans — 5 architecture decisions (expected, no ARC linkset) and 4 interface requirements added in later sessions without linkset coverage.

## Implications

1. The orphan report is now a reliable quality gate for the v6.1 completion criteria.
2. Previously completed systems can be accurately assessed for trace coverage.
3. The 4 IFC orphans in the autonomous vehicle project indicate a gap — later-session interface requirements were not linked by the bot.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| airgen-cli | 0.4.1 | Up from 0.4.0 |
| Orphan report | Fixed | Was checking wrong link store |
