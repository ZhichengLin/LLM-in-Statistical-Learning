# Study 2 — Long-Term (Follow-Up) Analyses

One-month retention of learning and durability of attitude change, analysed with
two parallel samples kept in self-contained subfolders:

| Subfolder | Sample | Role |
|-----------|--------|------|
| `MAR/` | Deposited initial-session cohort *N* = 178; analytic *N* = 175 after the ceiling screen; missing follow-up data handled under a missing-at-random assumption | **Main** long-term analysis (paper body) |
| `Follow-Up Completers Only/` | Deposited follow-up responders *N* = 87; analytic completers *N* = 84 after the same ceiling screen | **Robustness** check |

Both run the same H1 (accuracy), H2 (confidence and attitude change), and H3
(moderation) models, so the two are directly comparable; agreement indicates the
conclusions are not driven by differential attrition. `MAR/` additionally holds
the attrition diagnostics (drop comparison and demographics) supporting the MAR
approach.

See each subfolder's `readme.md` for its data, notebooks, and outputs; shared
variable definitions follow `../Study_2_Main_Results/readme.md`.

> **Exclusion** (both samples): three participants with
> `stage1_task0_accuracy >= 0.9` are removed by the ceiling filter. The file
> sizes (178 and 87) therefore differ from the analytic sample sizes (175 and
> 84).
