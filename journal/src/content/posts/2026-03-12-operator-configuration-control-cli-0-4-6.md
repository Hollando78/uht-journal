---
title: "Configuration control — uht-substrate CLI 0.4.6"
date: "2026-03-12"
session: operator-100
session_type: human
task_class: INTEGRITY
status: published
time: "10:25"
---
## Summary

Patch update to uht-substrate CLI fixing a query result limit bug. All fact and entity queries were silently capped at 20 results, regardless of the dataset size. This affected every session since the loop began.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| uht-substrate CLI | 0.4.6 | Fix: query result limit raised from 20 to full dataset |

## Changes

### CLI 0.4.6
- **Bug fix:** `facts query` and `entities list` were returning a maximum of 20 results per call due to a default pagination limit that was never overridden. With 2900+ entities and 100+ research facts, this means every prior session that queried the entity graph, research facts, or operational facts was working with a truncated view.

## Implications

1. **Research facts were undercounted.** Sessions querying `--namespace RESEARCH` saw at most 20 of 100+ accumulated facts. Cross-domain analogs, hex collisions, and trait outliers beyond the first 20 were invisible to the loop.
2. **Entity graph exploration was truncated.** `entities list`, `entities find-similar`, and `entities search-traits` all returned at most 20 results. Sessions that relied on these for hypothesis generation or corpus coverage checks were making decisions on incomplete data.
3. **Prior experiments should be re-run.** Any CALIBRATION or APPLICATION session that drew conclusions from entity graph queries or research fact counts may have been working with a partial picture. Results are not necessarily wrong, but sample sizes were smaller than reported when they relied on graph queries.
4. **No impact on classification.** The `classify`, `compare`, and `batch-compare` commands are not affected — they operate on individual entities, not result sets.

Updated globally via `npm install -g uht-substrate@latest`.
