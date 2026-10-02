#!/usr/bin/env python3
"""Generate the scoped DataCheck plan/report and discrepancy register from one gate inventory."""
import argparse,csv,json,sys
from pathlib import Path
import common as C

RULES={
'Q01':('Consumed inputs differ from the pinned deposited snapshot','Seven required numerical/historical/QC inputs plus optional all-44 interval metadata'),
'Q02':('Malformed CSV silently shifts or drops fields','All three public CSVs; strict UTF-8 CSV parse'),
'Q03':('Unexpected or absent columns change downstream meaning','Exact declared cohort53/items10/intervals2 schema'),
'Q04':('Rows are missing or duplicated despite plausible data','175 cohort,2975 items,39 eligible intervals'),
'Q05':('Blank or duplicate keys corrupt joins','Canonical cohort1001..1175; item ID+Item; interval ID'),
'Q06':('Duplicate records or undeclared missing tokens','All rows and cells'),
'Q07':('ID/item/label/task/baseline/tool joins misalign','175 participants x17 declared items; independent redundant fields'),
'Q08':('Assigned source-label groups change','Original59/58/58 analytic cohort'),
'Q09':('Baseline ceiling exclusions are not preserved','All175 baseline17-item accuracy values <.90'),
'Q10':('One-month flag differs from recorded outcomes','84 original completers and matching cohort outcomes'),
'Q11':('Privacy suppression is confused with nonreturn','Explicit44-return flag;39 eligible observed outcomes;0/1 domain'),
'Q12':('Required task outcomes missing or suppressed outcomes present','Historical waves complete; M1 by84 flag;LT eligible39 only'),
'Q13':('Invalid scale or score grid enters a model','Accuracy0..1;confidence1..5;binary item correctness'),
'Q14':('Derived task/overall scores disagree with items','S1-S3 accuracy <=.0005 rounding;eligible LT <=1e-9'),
'Q14b':('One-month outcomes incorrectly joined or scored','All84 completers x4 scores; deposited item workbook/key; <=.0005'),
'Q15':('Tool/exposure domains or suppression policy change','44 tool responses;39 eligible exposure responses;excluded auxiliary blanks'),
'Q16':('Recorded attention pass is missing/invalid','39 eligible long-term attention flags'),
'Q17':('Intervals misjoin or imply another follow-up window','Exactly eligible39 IDs;429.3..448.2 days;0.1-day public precision'),
'Q18':('Correction timing includes excluded/uncorrected rows','Primary204 responses/32people;eligible241/37'),
'Q19':('Item-difficulty nuisance predictor changes','Original175 x17 S1 items; no LT data'),
'Q20':('Historical paired positive-control targets are wrong','12 frozen aggregate no-tools rows;manifest-bound'),
'Q21':('Historical timing positive-control targets are wrong','Two frozen aggregate no-tools rows32/204 and37/241'),
'Q23':('Unknown/missing tool responses wrongly admitted','Exact trimmed no only;yes5 excluded;unknown0;nonreturn precedence'),
'Q24':('Model population differs from retrospective contract','Primary33;eligible39;cohort170;covariate168 andnamed ancillary sets'),
'Q25':('Overlapping/repeated samples treated inconsistently','All15 declared subset/disjoint/partition relations'),
'Q26':('Item-level exclusion disagrees with participant exclusion','All2975 item rows;eligible39 vs excluded5 metadata'),
'Q28':('Confidence overall/task summaries disagree','Earlier weighted17-item summary <=.001 rounding;eligible LT<=1e-9; raw item confidence outside deposited boundary'),
'Q27':('Covariate collapse changes adjusted-model sample','168 complete within170; original hours mapping')}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);a=ap.parse_args();out=Path(a.out).resolve();rec=out/'records'
    req=json.loads((C.CODE/'gate_requirements.json').read_text())
    q=list(csv.DictReader(open(rec/'qc_checks.csv',newline=''))) if(rec/'qc_checks.csv').exists() else []
    by={r['rule_id']:r for r in q}
    plan=['# DataCheck plan: deposited 14-month extension inputs','',
          'Next step: numerical reproduction of the executed exploratory primary33, eligible39 and full-cohort170 analyses. '
          'The unit of inference is the participant; timing models retain participant/item dependence. '
          'This gate begins with deposited analysis-ready inputs, after the private preparation boundary.', '',
          'Authority and tolerances: analysis_contract.yaml and gate_requirements.json. Counts and score tolerances '
          'retain the executed 2026-09-30 definitions. All substantive rules are evaluated across all applicable records; '
          'no statistical effect is used to choose exclusions. An input/code/contract/checker change requires fresh QC before inference.', '',
          'Privacy: follow2_returned records 44 submissions. The five reporting tools have blank LT outcomes/auxiliaries; '
          'only their count and eligibility flag remain. Nonreturn blanks mean not collected. The eligible39 values and '
          'historical waves are preserved. Source-key mapping is never emitted.', '',
          '| Rule | Failure mechanism | Scope / assertion | Severity / missing evidence |',
          '| --- | --- | --- | --- |']
    for i in req['required_qc_rules']:
        mechanism,scope=RULES[i]; severity=by.get(i,{}).get('severity','Critical')
        plan.append(f'| {i} | {mechanism} | {scope} | {severity}; missing prerequisite = UNKNOWN, blocks entry |')
    plan += ['', 'Earliest checkpoint: input verification before QC, then full deterministic validation before any fitting entry. '
             'The READY binding covers manifest inputs, contract, code (including run.R), required QC records, '
             'successful actual fixture/guard case inventories and sample fingerprints. Every protected fitting script and '
             'the public figure entry recomputes the binding. Synthetic tests exercise valid states and failure precedence '
             'without fitting scientific models.', '',
             'Historical acquisition, independent private roster linkage, administration/consent/ethics and the two unmatched '
             'submissions remain UNKNOWN in this deposited-data gate. They are not essential to replaying already deposited '
             'scores, but limit source correctness, execution fidelity and broader study claims. This report is not a release '
             'authorization, study-wide validation or proof of unaided responding.']
    (rec/'QC_PLAN.md').write_text('\n'.join(plan)+'\n')
    summary=json.loads((rec/'qc_summary.json').read_text()) if(rec/'qc_summary.json').exists() else {'verdict':'NOT READY'}
    verification=json.loads((rec/'verification.json').read_text()) if(rec/'verification.json').exists() else None
    lines=['# DataCheck report: deposited 14-month extension inputs','',
           '**Analysis-readiness verdict: '+summary['verdict']+' for numerical reproduction from the deposited inputs.**','',
           'Source correctness: bounded by analysis-ready input identity and downstream internal checks. '
           'Historical execution fidelity and private roster linkage: UNKNOWN. Recorded-data validity: '
           +('PASS within the named gate' if summary['verdict']=='READY' else 'not yet established / see blocking rules')+'.', '',
           '| Rule | Evidence status | Execution | Checked / applicable | Observed |','| --- | --- | --- | --- | --- |']
    discrepancies=[]
    for i in req['required_qc_rules']:
        r=by.get(i,{'status':'UNKNOWN','execution':'not_run','checked':0,'eligible':0,'observed':'not evaluated'})
        lines.append(f"| {i} | {r['status']} | {r['execution']} | {r['checked']} / {r['eligible']} | {r['observed'].replace('|','/')} |")
        if r['status']!='PASS': discrepancies.append({'issue_id':i,'gate':'recorded-data validity','severity':r.get('severity','Critical'),'status':r['status'],'scope':RULES[i][1],'consequence':'Dependent numerical reproduction blocked','resolution':'Inspect and resolve; do not repair source values silently'})
    for i,label in [('S01','Independent private roster linkage'),('S02','Historical delivery and complete acquisition evidence'),('S03','Administration/consent/ethics records'),('S04','Two unmatched submissions outside the frozen snapshot')]:
        discrepancies.append({'issue_id':i,'gate':'source/execution boundary','severity':'Boundary','status':'UNKNOWN','scope':label,'consequence':'No source-wide or recruitment-wide clearance; deposited-data replay remains separately scoped','resolution':'Retain source qualification; not reconstructed by this public package'})
    if verification:
        lines += ['', 'Numerical-output verification: **'+verification['numerical_status']+'**. Overall model verification: **'+verification['status']+'**.',
                  'Strict model-diagnostic failures are retained separately; they never become a numerical PASS.']
        for detail in verification['failed_model_diagnostics']:lines.append('- '+detail)
    lines += ['', 'Evidence: qc_checks.csv, qc_m1_scoring.csv, input_verification.json, qc_fixture_results.csv, '
              'guard_tests.csv and ready_binding.json. These are aggregate records. Runtime fitted objects and '
              'membership fingerprints are ignored private caches. Any changed bound artifact invalidates readiness.', '',
              'See QC_PLAN.md and analysis_contract.yaml for interpretation and the retrospective/exploratory decision boundary.']
    (rec/'QC_REPORT.md').write_text('\n'.join(lines)+'\n')
    with (rec/'discrepancy_log.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['issue_id','gate','severity','status','scope','consequence','resolution']);w.writeheader();w.writerows(discrepancies)
    print('Scoped QC plan/report/discrepancy register generated from the gate inventory.')
    return 0
if __name__=='__main__':sys.exit(main())
