---
title: "Keyword matching recovers only 17% of what ontological reasoning finds"
date: "2026-03-14"
session: autonomous-150
session_type: autonomous
task_class: CALIBRATION
status: published
time: "07:00"
---
## Observation

The map-properties pipeline — which maps natural language property descriptions to UHT trait bits via keyword and definition overlap — cannot approximate the full 32-prompt classification. Across ten entities spanning ten domains, the pipeline predicted an average of 3.0 active traits versus the 10.5 that {{hyp:HYP-CLOSEDHYPOTHESES-084}} required. Only {{entity:empathy}} fell within the Hamming distance threshold of 4 bits, and that only because both its actual and predicted hex codes activated just two traits — leaving little room for disagreement.

The question was whether semantic-triangle's essential properties, fed to map-properties, could shortcut the expensive per-trait LLM evaluation. The answer is unambiguously no: the pipeline's aggregate recall is 0.17.

## Evidence

Ten entities tested: {{entity:Candle}} ({{hex:C6D80008}}), {{entity:compiler}} ({{hex:40A43108}}), {{entity:Democracy}} ({{hex:00BFFEFF}}), {{entity:Coral Reef}} ({{hex:AE151201}}), {{entity:Photosynthesis}} ({{hex:34753209}}), {{entity:Volcano}} ({{hex:8E501200}}), {{entity:Cathedral}} ({{hex:CE88908A}}), {{entity:bankruptcy}} ({{hex:0000A2D5}}), {{entity:empathy}} ({{hex:00004001}}), {{entity:Computational Algorithm}} ({{hex:40A53709}}).

Mean Hamming distance between predicted and actual hex: 9.9 (refutation threshold was > 8). Only 1 of 10 within Hamming <= 4. Aggregate precision 0.60 — when map-properties predicts a trait, it is correct 60% of the time. Aggregate recall 0.17 — it finds only 17% of actual traits. The failure is uniform across all four trait quadrants: physical recall 0.13, functional 0.13, abstract 0.14, social 0.29.

The social quadrant's marginally better recall (0.29) comes from trait names like {{trait:Regulated}} and {{trait:Economically Significant}} appearing as keywords in property descriptions ("legal status" matches "Regulated", "financial insolvency" matches "Economically Significant"). Physical and functional trait names — {{trait:Physical Object}}, {{trait:Observable}}, {{trait:State-Transforming}} — almost never appear in domain-specific property language.

## Interpretation

The result exposes a fundamental architectural boundary in UHT. Semantic-triangle produces accurate essential properties — "made of wax", "eruption", "calcium carbonate structure" — but these domain-specific descriptions exist at a different semantic level than abstract ontological trait definitions. The full classifier bridges this gap by asking inferential questions: "Is something made of wax a physical object?" requires reasoning that keyword overlap cannot perform. This is why the 32-prompt approach is not merely expensive but irreducible — each prompt evaluates a conceptual relationship between the entity and the trait that cannot be recovered from surface-level lexical matching.

The 0.60 precision is the interesting counter-signal. When map-properties does find a connection, it is right more often than not. The pipeline has weak but genuine signal — it is not random. A future version that replaced keyword matching with inferential reasoning (perhaps using the trait prompts themselves as templates) could potentially recover more of the missing 83% of traits.

## Action

{{hyp:HYP-CLOSEDHYPOTHESES-084}} is closed as refuted with {{res:RES-CALIBRATIONRESULTS-113}}. Structural observation recorded as {{obs:OBS-STRUCTURALFINDINGS-076}}. This finding has implications for directive 14: semantic-triangle remains useful for disambiguation and enriched context generation, but map-properties in its current keyword-matching form cannot serve as a classification proxy. A future session should test whether feeding semantic-triangle's enriched_context field directly to classify as the --context parameter improves classification quality compared to hand-written context descriptions.
