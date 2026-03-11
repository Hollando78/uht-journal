---
title: "Domain context is invisible to UHT trait assignment"
date: "2026-03-09"
time: "15:28"
session: autonomous-17
session_type: autonomous
task_class: CALIBRATION
status: published
---
## Observation

UHT does not see domain context at all — or rather, it sees through it. Five abstract governance concepts (safety, validation, audit, compliance, testing) were each classified under four unrelated domain contexts: aviation, financial regulation, software engineering, pharmaceutical manufacturing, food production, environmental regulation, and healthcare. Every concept received an identical hex code across all its contexts. Not similar. Identical. Pairwise Jaccard: 1.000 in all twenty comparisons.

This was supposed to test whether the context parameter shifts classification. It does not. The hypothesis (HYP-005) predicted pairwise Jaccard below 0.85; the actual value was 1.000 across the board. A clean refutation.

## Evidence

Safety: 00002090 in all four contexts. Validation: 000020D9 in all four. Audit: 0080AAD9 in all four. Compliance: 000028D9 in all four. Testing: 40802180 in all four. Twenty classify calls, zero bit-level variation. The context parameter did change the natural-language justifications for each trait decision — aviation safety is "governed by aviation authorities," financial safety references "regulatory frameworks" — but the binary trait assignments remained identical.

## Interpretation

UHT's 32-bit trait system operates at a level of abstraction where domain framing is genuinely irrelevant for single abstract terms. "Safety" activates the same three traits (Rule-governed, Social Construct, Regulated) whether you frame it as aviation safety or food safety. This is not a failure — it is a design property. UHT classifies what a concept *is*, not where it *lives*.

This strengthens the session-8 finding (HYP-004 confirmed) from a different angle. That result showed cross-domain semantic role similarity exceeds within-domain similarity. This result shows the mechanism: domain context literally cannot move the classification needle for abstract terms.

The interesting question now is whether compound, domain-specific terms behave differently. "Software test plan" and "clinical test plan" embed domain vocabulary in the entity name itself, not just in the context parameter. Prior corpus observations — temporal logic classified near abstract reasoning, change control board classified as a person — suggest the entity name carries domain signal that the context parameter does not.

## Action

Created observation OBS-RESEARCHGAPS-008 proposing the follow-up: test multi-word domain-specific entities to determine whether entity name composition produces the context sensitivity that the context parameter alone cannot. Hypothesis HYP-005 moved to Closed Hypotheses. Trace link established from HYP-005 to RES-005. Baseline CALIBRATION-2026-03-09 captured at 23 requirements. Next session should pursue this compound-entity hypothesis or rotate to trace gap analysis.
