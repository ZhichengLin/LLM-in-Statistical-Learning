# DataCheck report: deposited 14-month extension inputs

**Analysis-readiness verdict: READY for numerical reproduction from the deposited inputs.**

Source correctness: bounded by analysis-ready input identity and downstream internal checks. Historical execution fidelity and private roster linkage: UNKNOWN. Recorded-data validity: PASS within the named gate.

| Rule | Evidence status | Execution | Checked / applicable | Observed |
| --- | --- | --- | --- | --- |
| Q01 | PASS | completed | 8 / 8 | 8 of 8 match |
| Q02 | PASS | completed | 3 / 3 | no problems |
| Q03 | PASS | completed | 65 / 65 | 0 missing |
| Q04 | PASS | completed | 3 / 3 | 175/2975/39 |
| Q05 | PASS | completed | 3189 / 3189 | blank=0; duplicate keys=0; canonical public key set=True |
| Q06 | PASS | completed | 3189 / 3189 | full-row duplicates=0; unrecognized missing tokens=0 |
| Q07 | PASS | completed | 2975 / 2975 | id sets equal=True; ids with wrong item set=0; label/baseline/tool/task conflicts=0/0/0/0 |
| Q08 | PASS | completed | 175 / 175 | {"AI": 59, "AI Human": 58, "Human": 58} |
| Q09 | PASS | completed | 175 / 175 | max S1 17-item accuracy=0.882 |
| Q10 | PASS | completed | 175 / 175 | flag domain violations=0; flag/data inconsistencies=0; M1 by label={"AI": 29, "AI Human": 24, "Human": 31} |
| Q11 | PASS | completed | 175 / 175 | long-term returns=44 {"AI": 19, "AI Human": 12, "Human": 13}; task-level presence inconsistencies=0 |
| Q12 | PASS | completed | 7000 / 7000 | missing required=0; present where not collected=0; primary33 five-wave values=1320 |
| Q13 | PASS | completed | 18900 / 18900 | out of range=0; off score grid=0; non-numeric=0; bad item codes=0 |
| Q14 | PASS | completed | 2256 / 2256 | mismatches=0; max abs deviation=0.000471 |
| Q14b | PASS | completed | 336 / 336 | cohort IDs unmatched in item file=0; duplicate item-file IDs=0; item completeness vs one-month flag conflicts=0; task/17-item mismatches=0; max abs deviation=0.000471; response column classes=logical:17 |
| Q15 | PASS | completed | 44 / 44 | tool-use values {"no": 39, "yes": 5}; exposure {"no": 29, "unsure": 4, "yes": 6}; filled outside long-term returns=0 |
| Q16 | PASS | completed | 39 / 39 | passed=39 |
| Q17 | PASS | completed | 39 / 44 | interval IDs equal long-term returns=True; eligible39 with interval=39; min=429.30; max=448.10 |
| Q18 | PASS | completed | 2975 / 2975 | primary33={"responses": 204, "participants": 32, "early": 105, "late": 99, "both_categories": 23}; eligible39={"responses": 241, "participants": 37, "early": 125, "late": 116, "both_categories": 26}; excluded participants in timing samples=0 |
| Q19 | PASS | completed | 2975 / 2975 | S1 present=2975 |
| Q20 | PASS | completed | 12 / 12 | manifest-bound public historical controls; 12 no-tools paired rows |
| Q21 | PASS | completed | 2 / 2 | manifest-bound public historical controls; expected 32/204 and 37/241 |
| Q23 | PASS | completed | 44 / 44 | eligible=39; excluded reported use=5 {"AI": 0, "AI Human": 0, "Human": 5}; excluded unknown/missing=0; non-returners classified=0; excluded all Human=True; excluded all with one-month data=True |
| Q24 | PASS | completed | 175 / 175 | eligible39=39 {"AI": 19, "AI Human": 12, "Human": 8}; primary33=33 {"AI": 16, "AI Human": 10, "Human": 7}; cohort170=170 {"AI": 59, "AI Human": 58, "Human": 53}; one_month_eligible=79 {"AI": 29, "AI Human": 24, "Human": 26}; additional6=6; covariate_complete=168; p33_no_expo=23; e39_no_expo=29; one_month_only=46; neither=85 |
| Q25 | PASS | completed | 15 / 15 | 15 of 15 relations hold |
| Q26 | PASS | completed | 2975 / 2975 | excluded item rows=85 (tool yes consistent=True); eligible item rows=663 (tool no consistent=True); item-derived eligible set equals cohort-derived=True |
| Q27 | PASS | completed | 170 / 170 | covariate-complete=168; Used_LLM_Hours outside mapped categories=2 |
| Q28 | PASS | completed | 648 / 648 | mismatches=0; max abs deviation=0.000706 |

Numerical-output verification: **PASS**. Overall model verification: **QUALIFIED**.
Strict model-diagnostic failures are retained separately; they never become a numerical PASS.
- full-cohort GLS: requested Satterthwaite-type df obtained (strict; df.error fallback when apVar is not a matrix = FAIL)
- full-cohort lmer: every fit nonsingular (strict; boundary variance components reported)

Evidence: qc_checks.csv, qc_m1_scoring.csv, input_verification.json, qc_fixture_results.csv, guard_tests.csv and ready_binding.json. These are aggregate records. Runtime fitted objects and membership fingerprints are ignored private caches. Any changed bound artifact invalidates readiness.

See QC_PLAN.md and analysis_contract.yaml for interpretation and the retrospective/exploratory decision boundary.
