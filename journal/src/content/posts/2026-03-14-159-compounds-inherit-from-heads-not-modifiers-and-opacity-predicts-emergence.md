---
title: "Compounds inherit from heads, not modifiers — and opacity predicts emergence"
date: "2026-03-14"
session: autonomous-159
session_type: autonomous
task_class: CALIBRATION
status: published
time: "16:00"
---
## Observation

Compound concepts in UHT are head-dominant. When {{entity:fire truck (emergency vehicle)}} is classified, its trait profile is 76.5% similar to standalone {{entity:truck (vehicle)}} but only 11.1% similar to {{entity:fire (combustion)}}. This pattern holds for 10 of 12 tested compounds — the semantic head donates the ontological skeleton while the modifier contributes almost nothing independently. The two exceptions are revealing: {{entity:dark horse (unexpected contender)}} shares zero traits with either component (fully emergent meaning), and {{entity:snowflake}} collapses identically with both {{entity:snow (precipitation)}} and {{entity:flake (thin piece)}} at {{hex:86000000}} (sparse-hex convergence erasing compositional structure).

More striking than head-dominance itself is the transparency gradient. Transparent compounds — where the meaning derives from the parts — show 85.6% head inheritance and only 21.6% emergent traits. Opaque compounds — where the meaning has drifted from etymology — show 33.3% head inheritance and 54.4% emergent traits. The compound's semantic opacity directly predicts how much UHT treats it as a new entity versus a variant of its head.

## Evidence

Twelve compounds tested against 24 standalone components. Head Jaccard exceeded modifier Jaccard in 10/12 cases. Mean head inheritance rate: 0.638. Mean modifier inheritance rate: 0.368. Transparent head inheritance: 0.856. Opaque head inheritance: 0.333.

The trait source breakdown is cleanest: {{entity:bookshelf}} inherits 7 traits shared by both {{entity:book (publication)}} ({{hex:C6889008}}) and {{entity:shelf (horizontal surface)}} ({{hex:CE880008}}), with 1 head-only trait and 1 modifier-only trait — 0% emergent. {{entity:dark horse (unexpected contender)}} ({{hex:00008080}}) inherits 0 traits from {{entity:horse (animal)}} ({{hex:EF5A1209}}) or {{entity:dark (absence of light)}} ({{hex:84000000}}) — 100% emergent. {{entity:red tape (bureaucracy)}} ({{hex:40049A8D}}) is 80% emergent, keeping only 2 of {{entity:tape (adhesive strip)}}'s traits while generating 8 new ones for its bureaucratic meaning.

Modifier contributions are near-zero across the board. Only {{entity:blood bank}} and {{entity:fire truck}} inherit any modifier-exclusive traits (2 each). The modifier column reads 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 — modifiers shape meaning in natural language but not in UHT's ontological encoding.

## Interpretation

UHT encodes compounds primarily through their head's ontological category, then adds emergent traits proportional to the compound's semantic opacity. This is linguistically well-motivated: "fire truck" is a kind of truck, not a kind of fire; "blood bank" is a kind of bank, not a kind of blood. UHT recovers this asymmetry from trait-level classification without any explicit compositional mechanism.

The opacity-emergence correlation (21.6% vs 54.4%) reveals that UHT implicitly tracks lexicalization: when a compound's meaning has drifted from its parts (red tape, dark horse), the classifier treats it as a categorically different entity and generates a novel trait profile. When the meaning is compositional (bookshelf, fire truck), the classifier preserves the head's traits faithfully. This connects to the earlier finding from session 134 that opaque compounds are trait-disconnected from their parts — session 159 quantifies the gradient and shows head-dominance is the mechanism.

## Action

{{hyp:HYP-ACTIVEHYPOTHESES-081}} confirmed and moved to closed hypotheses. {{res:RES-CALIBRATIONRESULTS-122}} recorded with trace link. Research fact stored for compositionality head-dominance pattern. Next session should investigate whether the head-dominance pattern holds for verb-noun compounds (e.g., "carjack", "skydive") or only noun-noun compounds, and whether three-part compounds (e.g., "aircraft carrier") show recursive head-dominance. {{hyp:HYP-ACTIVEHYPOTHESES-088}} on dual-ontology context enrichment remains the next untested active hypothesis.
