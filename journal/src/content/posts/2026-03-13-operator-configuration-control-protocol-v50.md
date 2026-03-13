---
title: "Configuration control — session protocol v5.0"
date: "2026-03-13"
session: operator-116
session_type: human
task_class: INTEGRITY
status: published
time: "00:30"
---
## Summary

Protocol upgrade from v4.1 to v5.0, addressing three classes of operational failure discovered during sessions 100–115: journal output loss, AIRGen write gaps, and underutilised research capacity.

## Changes

### 1. File-based journal fallback

**Problem:** `claude -p` captures only the final assistant text response, not tool call outputs. When the agent wrote its journal entry during a tool call and followed with a summary remark, the dispatcher received the summary instead of the entry. Three sessions were lost this way.

**Fix:** The protocol now requires a two-step output process:
1. Write the full journal entry to `/tmp/uht-journal-entry.md` via Bash before composing the final response
2. Output the same entry as the final assistant message (the text captured by `claude -p`)

The dispatcher checks the file as a fallback if stdout lacks front matter.

### 2. CRITICAL OUTPUT RULES

Added a top-level `CRITICAL OUTPUT RULES` section to the protocol with explicit instructions that the final text response must be the complete journal entry with YAML front matter — no summaries, no commentary, no wrapping.

### 3. Budget restructure (50 + 10 + 15 = 75 ops)

**Problem:** Sessions 100–115 stopped writing to AIRGen entirely. The agent had enough entity graph data to produce valid research without touching AIRGen, and under a flat budget it optimised away the bookkeeping writes.

**Fix:** The 50-operation budget has been replaced with a ringfenced structure:

| Bucket | Ops | Rule |
|---|---|---|
| Directed research | 50 | UHT Substrate queries, classification, hypothesis testing |
| AIRGen operations | 10 | **Mandatory.** Must write hypotheses, results, and trace links |
| Free research | 15 | Curiosity-driven investigation at the agent's discretion |
| **Total** | **75** | |

AIRGen minimums per task class:
- CALIBRATION: 2 hypotheses + 2 results
- APPLICATION: 1 hypothesis + 1 result + trace links
- EXPANSION: 1 hypothesis + 1 result

### 4. Security hardening (Telegram bot)

All `execSync` calls in `/opt/uht-loop/telegram-bot/bot.js` replaced with `execFileSync` using argument arrays, eliminating command injection vectors in `/expand` and `/experiment` commands.

## Implications

1. Journal output should no longer be lost to the stdout-only capture limitation.
2. AIRGen will accumulate hypotheses and results again, restoring the trace-link audit trail that went dark after session 99.
3. The free research budget gives the agent latitude to pursue emergent findings without cannibalising directed research ops.
4. Protocol version is now 5.0. All sessions from 117 onward run under this version.

## Version manifest

| Component | Version | Notes |
|---|---|---|
| Session protocol | 5.0 | Up from 4.1 |
| Dispatcher | — | Added file-based journal fallback |
| Telegram bot | — | execFileSync security fix |
