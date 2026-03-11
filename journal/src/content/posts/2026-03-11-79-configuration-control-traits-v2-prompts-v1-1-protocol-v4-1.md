---
title: "Configuration control — traits v2.0, prompts v1.1, protocol v4.1"
date: "2026-03-11"
session: operator-79
session_type: human
task_class: INTEGRITY
status: published
time: "14:00"
---
## Summary

Coordinated update across the full UHT classification stack: trait definitions, classification prompts, CLI tooling, research protocol, and QC bot protocol. All versions are now tracked and queryable via the CLI.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Trait definitions | 2.0 | Expanded definitions with classification guidance, edge cases |
| Prompt spec | 1.1 | 32 per-trait prompts, gpt-4o-mini, temperature 0.3 |
| uht-substrate CLI | 0.4.5 | New: `--force-refresh`, `--context`, `--format pretty`, `trait-prompts` |
| airgen-cli | 0.4.0 | Server-side filtering, `--document`/`--section` filters |
| Research protocol | 4.1 | Context-enriched classification, force-refresh for drift checks |
| QC protocol | 1.0 | Context-enriched classification, force-refresh for reclassification |

## Changes

### Trait definitions v2.0
Each of the 32 traits now carries an `expanded_definition` and a URL linking to its canonical page on universalhex.org. Viewable via `uht-substrate traits --format pretty`.

### Prompt spec v1.1
Each trait has a dedicated classification prompt with: core definition, APPLICABLE/NOT APPLICABLE examples, and edge cases. The `--context` flag on `classify` injects into the `{{entity_description}}` template variable, meaning every trait evaluator now receives the entity description. Viewable via `uht-substrate trait-prompts --bit N --format pretty`.

### CLI 0.4.5
- `classify --force-refresh` — bypasses entity-name cache, forces fresh 32-trait evaluation. Essential for drift detection.
- `classify --context "<description>"` — now feeds into trait prompts as `{{entity_description}}`, directly influencing classification quality.
- `--format pretty` on `traits`, `trait-prompts`, `entities list` — colour-coded, human-readable output.
- `trait-prompts` command — inspect the exact prompts used for classification.
- `--version` now reports correct version number.

### Research protocol v4.1
- All `classify` calls now require `--context` with a 1-2 sentence description covering domain, key properties, and distinguishing characteristics.
- INTEGRITY drift checks use `--force-refresh` to bypass cache.
- CALIBRATION and APPLICATION test phases include context guidance.
- CORPUS_EXPANSION classify calls include context examples.
- Entity count updated to 2900+.
- CLI reference expanded with `traits`, `trait-prompts`, `--format pretty`.

### QC protocol 1.0
- All `classify` calls use `--context` with rich descriptions.
- DRIFT_CHECK uses `--force-refresh` for meaningful reclassification.
- GRAVITY_WELL_ANALYSIS reclassification uses `--force-refresh` with context.
- Phase 4 (approved action execution) has two RECLASSIFY paths: same-name with `--force-refresh`, or name-change with delete-then-classify.

## Implications

Prior to this update, all classifications were performed with bare entity names and no description. The 2900+ existing entities were classified without the benefit of `{{entity_description}}` in trait prompts. This means:
1. Future `--force-refresh` reclassifications with rich context may produce different hex codes — expected and desirable.
2. The QC bot's DRIFT_CHECK task class can now detect genuine classification improvements, not just cache artifacts.
3. CORPUS_EXPANSION sessions will produce higher-quality initial classifications going forward.

All components are version-tracked and queryable: `uht-substrate --version`, `uht-substrate traits --format pretty` (trait version), `uht-substrate trait-prompts --format pretty` (prompt version).
