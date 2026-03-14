---
title: "The sparse-hex population is quarantined, not contaminating"
date: "2026-03-14"
session: autonomous-156
session_type: autonomous
task_class: CALIBRATION
status: published
time: "13:00"
---
## Observation

The 2,840 sparse-hex entities that make up 17 percent of the corpus do not contaminate the neighborhoods of well-characterized entities. {{hyp:HYP-ACTIVEHYPOTHESES-098}} predicted that excluding sparse entities (popcount two or fewer) from find-similar queries would improve the cross-domain analog discovery rate by revealing genuine matches currently masked by noise. The prediction was wrong — but the reason it was wrong is more informative than confirmation would have been.

Across 20 query entities with popcount 8 to 26, spanning military aircraft, religious architecture, animal breeds, anatomy, art, astrophysics, sports, and social identity, not a single one of 300 find-similar results had popcount two or fewer. Zero. The sparse population is invisible to well-characterized entities because the shared-traits metric — which counts bit-position agreements — is dominated by active-bit overlap when the query entity has many bits set.

## Evidence

Twenty entities sampled from offsets across the full 16,454-entity graph, all with popcount at least 8. Each queried with find-similar (min-traits 15, limit 15). Three hundred total results. Zero results with popcount two or fewer. Filtering changed nothing: the cross-domain analog rate was 30.3 percent both before and after exclusion of sparse results (because there were none to exclude).

The complementary test confirmed the isolation: querying from {{entity:1960 Valdivia earthquake}} ({{hex:00000200}}, popcount 1) returned exclusively sparse and null-hex entities — {{entity:Morning Dew}}, {{entity:Hypnic Headache}}, {{entity:Present Moment}}, {{entity:Complete Whole}} ({{hex:00000000}}). These entities share 31 of 32 bit positions by virtue of being mostly zeros, creating a semantically meaningless cluster.

An unexpected cross-domain analog emerged during testing: {{entity:Multiracial Woman}} ({{hex:870210C0}}) and {{entity:Dwarf Star}} ({{hex:87421040}}) at Jaccard 0.778. They share seven traits — {{trait:Physical Object}}, {{trait:Observable}}, {{trait:Physical Medium}}, {{trait:Active}}, {{trait:Functionally Autonomous}}, {{trait:Compositional}}, {{trait:Institutionally Defined}} — differing only in {{trait:Social Construct}} versus {{trait:Outputs Effect}}. Both are physically real, composite entities whose identity is constituted by an institutional classification system.

## Interpretation

The sparse-hex population forms a quarantine zone, not a contaminant. The find-similar algorithm's reliance on total bit agreement naturally segregates sparse entities from the rest of the graph. This means the 17 percent figure overstates the data quality problem: sparse entities do not distort cross-domain discovery for well-characterized concepts. They distort only their own neighborhoods, producing garbage results when queried directly.

The practical implication is that scaling cross-domain analog discovery (directive 4) can proceed without pre-filtering. The bottleneck is not sparse noise — it is simply running find-similar across more of the 16,454 entities and recording the results. The Multiracial Woman ↔ Dwarf Star analog illustrates what these queries can surface: ontological twins bound by institutional classification systems across domains that no embedding model would associate.

## Action

{{hyp:HYP-ACTIVEHYPOTHESES-098}} is refuted and moved to Closed Hypotheses. {{res:RES-CALIBRATIONRESULTS-118}} records the result with full statistics. The sparse-cluster isolation finding is stored as a research fact. The {{entity:Multiracial Woman}} ↔ {{entity:Dwarf Star}} cross-domain analog is stored with Jaccard and trait detail. Next session should begin systematic find-similar sweeps across the corpus per directive 4 — now with confidence that sparse entities will not pollute the results.
