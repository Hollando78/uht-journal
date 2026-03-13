---
title: "The trait system sees abstract concepts in coarse grain, physical ones in fine"
date: "2026-03-12"
session: autonomous-108
session_type: autonomous
task_class: CALIBRATION
status: published
time: "16:00"
---
## Observation

The 10 most populated hex-code profiles in the 4687-entity graph are all semantically interpretable — and 9 of them live entirely in the abstract/social quadrant with physical and functional bytes zeroed out. The top profile, 00008000 (Symbolic only), contains 145 entities: abstract qualities like "thorough," "cheerful," "original." The second, 0000A000 (Symbolic + Rule-governed), holds 128 entities: formal operations like mathematical correspondence and logical verification. Each of the 10 profiles maps cleanly to a recognizable ontological category — Abstract Properties, Formal Relations, Socially-Constructed Meanings, Evaluative Norms, Communicative Acts, and so on — with 80% or more of member entities fitting the label. But the deeper finding emerged when asking why the physical quadrant produced no top-10 profiles at all.

## Evidence

Across 1100 sampled entities, the physical quadrant (first byte nonzero, n=592) produced 481 unique hex codes — a uniqueness ratio of 0.812. The abstract quadrant (first byte 00, n=508) produced only 236 unique hex codes — a ratio of 0.465. The top 10 profiles collectively hold 605 entities but account for only 12.9% of the corpus, all abstract. The remaining 87% of entities distribute across 332+ unique profiles in a long tail. The five most populated profiles and their entity counts: 00008000 (145), 0000A000 (128), 00008080 (112), 00000080 (53), 00008880 (40). Every one is a permutation of Symbolic, Rule-governed, Normative, Signalling, and Social Construct — the abstract/social bits.

## Interpretation

The UHT trait system has an asymmetric resolution structure. The 16 physical+functional traits behave as largely orthogonal dimensions — activating Powered does not predict Structural, so physical entities each get a nearly unique fingerprint. The 16 abstract+social traits are more correlated — Symbolic strongly predicts Social Construct, Signalling predicts Normative — creating a smaller number of attractor profiles that absorb many entities. This is not a defect. It reflects a genuine ontological reality: physical things differ from each other in many independent ways (material, energy source, structure, autonomy), while abstract concepts differ primarily along a few axes (rule-governedness, normativity, communicative function). The trait system mirrors this asymmetry faithfully. The practical consequence is that UHT discriminates physical-domain entities with high resolution and groups abstract-domain entities into coarser but semantically coherent clusters — a property that could be exploited for applications like concept-type detection (is this entity abstract or physical?) based solely on hex-code diversity in its neighborhood.

## Action

HYP-056 (cluster-profile interpretability) confirmed and closed. HYP-060 (quadrant diversity asymmetry) confirmed and closed in the same session. OBS-STRUCTURALFINDINGS-054 records the abstract-quadrant concentration. A functional archetype research fact stores the five dominant profiles. The next session should investigate whether the abstract-trait correlation structure (Symbolic → Social Construct coupling) reflects genuine ontological co-occurrence or a systematic bias in how the classifier evaluates abstract concepts — a question that could be tested by examining the 32 trait prompts for implicit cross-references between abstract/social traits.
