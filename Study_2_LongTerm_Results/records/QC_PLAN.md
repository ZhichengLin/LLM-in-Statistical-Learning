# DataCheck plan: deposited 14-month extension inputs

Next step: numerical reproduction of the executed exploratory primary33, eligible39 and full-cohort170 analyses. The unit of inference is the participant; timing models retain participant/item dependence. This gate begins with deposited analysis-ready inputs, after the private preparation boundary.

Authority and tolerances: analysis_contract.yaml and gate_requirements.json. Counts and score tolerances retain the executed 2026-09-30 definitions. All substantive rules are evaluated across all applicable records; no statistical effect is used to choose exclusions. An input/code/contract/checker change requires fresh QC before inference.

Privacy: follow2_returned records 44 submissions. The five reporting tools have blank LT outcomes/auxiliaries; only their count and eligibility flag remain. Nonreturn blanks mean not collected. The eligible39 values and historical waves are preserved. Source-key mapping is never emitted.

| Rule | Failure mechanism | Scope / assertion | Severity / missing evidence |
| --- | --- | --- | --- |
| Q01 | Consumed inputs differ from the pinned deposited snapshot | Seven required numerical/historical/QC inputs plus optional all-44 interval metadata | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q02 | Malformed CSV silently shifts or drops fields | All three public CSVs; strict UTF-8 CSV parse | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q03 | Unexpected or absent columns change downstream meaning | Exact declared cohort53/items10/intervals2 schema | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q04 | Rows are missing or duplicated despite plausible data | 175 cohort,2975 items,39 eligible intervals | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q05 | Blank or duplicate keys corrupt joins | Canonical cohort1001..1175; item ID+Item; interval ID | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q06 | Duplicate records or undeclared missing tokens | All rows and cells | Major; missing prerequisite = UNKNOWN, blocks entry |
| Q07 | ID/item/label/task/baseline/tool joins misalign | 175 participants x17 declared items; independent redundant fields | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q08 | Assigned source-label groups change | Original59/58/58 analytic cohort | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q09 | Baseline ceiling exclusions are not preserved | All175 baseline17-item accuracy values <.90 | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q10 | One-month flag differs from recorded outcomes | 84 original completers and matching cohort outcomes | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q11 | Privacy suppression is confused with nonreturn | Explicit44-return flag;39 eligible observed outcomes;0/1 domain | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q12 | Required task outcomes missing or suppressed outcomes present | Historical waves complete; M1 by84 flag;LT eligible39 only | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q13 | Invalid scale or score grid enters a model | Accuracy0..1;confidence1..5;binary item correctness | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q14 | Derived task/overall scores disagree with items | S1-S3 accuracy <=.0005 rounding;eligible LT <=1e-9 | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q14b | One-month outcomes incorrectly joined or scored | All84 completers x4 scores; deposited item workbook/key; <=.0005 | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q15 | Tool/exposure domains or suppression policy change | 44 tool responses;39 eligible exposure responses;excluded auxiliary blanks | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q16 | Recorded attention pass is missing/invalid | 39 eligible long-term attention flags | Major; missing prerequisite = UNKNOWN, blocks entry |
| Q17 | Intervals misjoin or imply another follow-up window | Exactly eligible39 IDs;429.3..448.2 days;0.1-day public precision | Major; missing prerequisite = UNKNOWN, blocks entry |
| Q18 | Correction timing includes excluded/uncorrected rows | Primary204 responses/32people;eligible241/37 | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q19 | Item-difficulty nuisance predictor changes | Original175 x17 S1 items; no LT data | Major; missing prerequisite = UNKNOWN, blocks entry |
| Q20 | Historical paired positive-control targets are wrong | 12 frozen aggregate no-tools rows;manifest-bound | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q21 | Historical timing positive-control targets are wrong | Two frozen aggregate no-tools rows32/204 and37/241 | Major; missing prerequisite = UNKNOWN, blocks entry |
| Q23 | Unknown/missing tool responses wrongly admitted | Exact trimmed no only;yes5 excluded;unknown0;nonreturn precedence | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q24 | Model population differs from retrospective contract | Primary33;eligible39;cohort170;covariate168 andnamed ancillary sets | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q25 | Overlapping/repeated samples treated inconsistently | All15 declared subset/disjoint/partition relations | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q26 | Item-level exclusion disagrees with participant exclusion | All2975 item rows;eligible39 vs excluded5 metadata | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q27 | Covariate collapse changes adjusted-model sample | 168 complete within170; original hours mapping | Critical; missing prerequisite = UNKNOWN, blocks entry |
| Q28 | Confidence overall/task summaries disagree | Earlier weighted17-item summary <=.001 rounding;eligible LT<=1e-9; raw item confidence outside deposited boundary | Critical; missing prerequisite = UNKNOWN, blocks entry |

Earliest checkpoint: input verification before QC, then full deterministic validation before any fitting entry. The READY binding covers manifest inputs, contract, code (including run.R), required QC records, successful actual fixture/guard case inventories and sample fingerprints. Every protected fitting script and the public figure entry recomputes the binding. Synthetic tests exercise valid states and failure precedence without fitting scientific models.

Historical acquisition, independent private roster linkage, administration/consent/ethics and the two unmatched submissions remain UNKNOWN in this deposited-data gate. They are not essential to replaying already deposited scores, but limit source correctness, execution fidelity and broader study claims. This report is not a release authorization, study-wide validation or proof of unaided responding.
