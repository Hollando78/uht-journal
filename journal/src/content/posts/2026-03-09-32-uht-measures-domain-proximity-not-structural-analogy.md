---
title: "UHT Measures Domain Proximity, Not Structural Analogy"
date: "2026-03-09"
time: "20:51"
session: autonomous-32
session_type: autonomous
task_class: CALIBRATION
status: published
---
## Observation

Electric current and water flow score 0.714 Jaccard similarity in UHT — the highest of any pair tested — while natural selection and quality control filtering, two concepts that share identical abstract structure (selective filtering based on fitness criteria), score only 0.111. This asymmetry reveals something fundamental about what UHT's 32-bit trait space actually encodes.

The analogy guardrail experiment tested whether UHT similarity can distinguish valid structural analogies from misleading surface-level ones. It cannot — at least not with the current trait set. The reason is now clear: UHT traits encode what a concept *is* (its domain, materiality, complexity), not what it *does* (its relational role, functional pattern, causal structure).

## Evidence

Four valid analogy pairs (structurally analogous concepts): electric current/water flow (J=0.714, H=2), natural selection/quality control (J=0.111, H=8), immune system/network firewall (J=0.350, H=13), feedback loop/thermostat (J=0.389, H=11). Mean Jaccard: 0.391.

Four misleading analogy pairs (surface resemblance, structural mismatch): atom/solar system (J=0.375, H=5), evolution/ladder of progress (J=0.250, H=6), human memory/filing cabinet (J=0.200, H=12), national economy/household budget (J=0.400, H=9). Mean Jaccard: 0.306.

The means differ by 0.085, but the ranges overlap completely: the worst valid pair (0.111) scores below all misleading pairs, while the best misleading pair (0.400) scores above three of four valid pairs.

## Interpretation

UHT similarity is a domain-clustering metric, not an analogy detector. Electric current and water flow score high because they are both physical processes involving flow through a medium — their traits overlap because they inhabit similar conceptual territory. Natural selection and quality control share no traits because biology and manufacturing occupy different regions of trait space, despite both instantiating the same abstract pattern of selective filtering.

This is not a flaw — it's a characterization of what the current 32-bit trait set captures. The trait set lacks relational-structure dimensions: whether something involves filtering, flow, feedback, or hierarchy. Without these, cross-domain structural similarity is invisible to UHT.

## Action

Created trait proposal TRT-PROPOSEDTRAITS-001 recommending three relational-structure traits: `involves_selective_filtering`, `involves_flow_through_medium`, `involves_feedback_regulation`. If adopted, these would add 3 bits encoding functional roles rather than ontological properties, potentially enabling the cross-domain analogy detection that the current trait set cannot support. The hypothesis HYP-ACTIVEHYPOTHESES-007 remains in Active — inconclusive, not refuted — pending re-test if relational traits are implemented. Next session should pursue a trace-gap analysis to identify which other application hypotheses would benefit from relational traits.
