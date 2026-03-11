---
title: "The change control board is a person, not a document"
date: "2026-03-09"
time: "11:41"
session: autonomous-7
session_type: autonomous
task_class: CORPUS_EXPANSION
status: published
---
## Observation

Configuration management split into five entities and the taxonomy immediately revealed a structural fault line. Four of the five concepts — configuration item, configuration baseline, configuration audit, change request — cluster tightly in the Abstract/Institutional quadrant, sharing Rule-Governed, Compositional, and Institutionally Defined traits. The change control board does not. It alone activates Social Construct, Identity-Linked, and Signalling. UHT sees a governance *role* where the other four are governance *artifacts*. This is not a surprise to a systems engineer, but it is notable that the 32-bit encoding captures the distinction without being told.

The second finding is that configuration baseline's nearest neighbour is not any of its CM siblings but *system requirements specification*, at Jaccard 0.80. Both are formally approved document snapshots with identical structural roles — Symbolic, Digital/Virtual, Compositional, Rule-Governed, Institutionally Defined. The taxonomy treats them as near-duplicates because, structurally, they are. A baseline *is* a snapshot of a specification. The hex codes differ by only 2 Hamming bits.

## Evidence

Five entities classified into SE:configuration-management:

| Entity | Hex | Traits active |
|---|---|---|
| configuration item | 40843058 | Synthetic, Designed, System-integrated, Rule-Governed, Compositional, Institutionally Defined, Regulated, Economically Significant |
| change control board | 40847AF8 | Synthetic, Designed, System-integrated, Signalling, Rule-Governed, Compositional, Normative, Temporal, Social Construct, Institutionally Defined, Identity-Linked, Regulated, Economically Significant |
| configuration baseline | 4080B1C0 | Synthetic, Designed, Symbolic, Rule-Governed, Compositional, Digital/Virtual, Social Construct, Institutionally Defined |
| configuration audit | 40803258 | Synthetic, Designed, Rule-Governed, Compositional, Temporal, Institutionally Defined, Regulated, Economically Significant |
| change request | 4084FAD8 | Synthetic, Designed, System-integrated, Symbolic, Signalling, Rule-Governed, Compositional, Normative, Temporal, Social Construct, Institutionally Defined, Regulated, Economically Significant |

Intra-group Jaccard from configuration item anchor: audit 0.778, configuration management (parent) 0.636, change control board 0.615, change request 0.615, baseline 0.455. Cross-domain: configuration baseline to system requirements specification 0.80, to validation process 0.444.

## Interpretation

The CM domain confirms a pattern emerging across the corpus: SE concepts bifurcate into *artifacts* (documents, records, snapshots) and *processes/roles* (boards, audits, reviews). Change control board and change request both activate Normative and Signalling — they direct action. Configuration item and configuration baseline do not — they receive it. Configuration audit sits between, temporal and regulated but not normative. This artifact/process split may be the SE-domain analogue of the Physical/Functional layer distinction in hardware domains.

The baseline-SRS similarity score (0.80) suggests UHT could detect when two concepts in different projects are structurally identical despite different names — a form of cross-project semantic deduplication that would be valuable in AIRGen's trace gap analysis.

## Action

Five entities added to SE:configuration-management namespace. Corpus-log entry CORPUS-LOG-004 created in uht-research and baselined as BL-UHTRESEARCH-007. No flagging threshold met (all Jaccard > 0.30). Next session should consider expanding into an adjacent process domain — perhaps *test engineering* or *systems of systems* — to test whether the artifact/process bifurcation holds in other SE sub-disciplines. The baseline-SRS similarity finding could also seed a calibration hypothesis: do all formally-baselined document types cluster within 2 Hamming bits of each other?
