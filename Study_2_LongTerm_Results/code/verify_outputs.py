#!/usr/bin/env python3
"""Independent Python verification of aggregate outputs (standard library + PyYAML only).

Numerical (blocking) checks: all paired rows recomputed from the frozen cohort file with the Python eligibility rule
and an own Student-t CDF; Holm families; positive controls against the frozen primary-38 package; sample-flow counts vs
contract; correction-timing counts vs the independent QC; R verification; the all-fit membership audit; CI brackets.
Strict model diagnostics (never relaxed; a failure is retained and makes the run QUALIFIED): GLS covariance/df modes,
full-cohort df fallback, lmer singularity, timing-fit warnings. The identifier scan is privacy_scan.py (final step).
Writes OUT/records/verification.json and output_hashes.json. Prints aggregate results only.
"""
import argparse
import csv
import json
import math
import re
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402


def betacf(a, b, x, itmax=300, eps=1e-15):
    qab, qap, qam = a + b, a + 1.0, a - 1.0
    c, d = 1.0, 1.0 - qab * x / qap
    d = 1.0 / (d if abs(d) > 1e-300 else 1e-300)
    h = d
    for m in range(1, itmax + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d; d = 1.0 / (d if abs(d) > 1e-300 else 1e-300)
        c = 1.0 + aa / c if abs(c) > 1e-300 else 1e-300
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d; d = 1.0 / (d if abs(d) > 1e-300 else 1e-300)
        c = 1.0 + aa / c if abs(c) > 1e-300 else 1e-300
        de = d * c
        h *= de
        if abs(de - 1.0) < eps:
            break
    return h


def betai(a, b, x):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    bt = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b) + a * math.log(x) + b * math.log(1 - x))
    if x < (a + 1) / (a + b + 2):
        return bt * betacf(a, b, x) / a
    return 1.0 - bt * betacf(b, a, 1 - x) / b


def t_two_sided_p(t, df):
    return betai(df / 2.0, 0.5, df / (df + t * t))


def holm(ps):
    order = sorted(range(len(ps)), key=lambda i: ps[i])
    k, out, running = len(ps), [0.0] * len(ps), 0.0
    for rank, i in enumerate(order):
        running = max(running, min(1.0, (k - rank) * ps[i]))
        out[i] = running
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    out = Path(a.out).resolve()
    cfg = C.load_config(out)
    checks, ok_all = [], True

    def add(name, ok, detail, category='numerical'):
        nonlocal ok_all
        if category == 'numerical':
            ok_all &= bool(ok)
        checks.append({'check': name, 'category': category, 'pass': bool(ok), 'detail': detail})

    rows = list(csv.DictReader(open(Path(cfg['private_inputs']) / 'cohort.csv', newline='', encoding='utf-8')))
    waves = {'S1': 'stage1', 'S2': 'stage2', 'S3': 'stage3', 'M1': 'follow', 'LT': 'follow2'}

    def score(r, w, m, item=False):
        if item:
            v = r[f'{waves[w]}_task0_{m}']
            return float(v) if v.strip() else None
        vals = [r[f'{waves[w]}_task{t}_{m}'] for t in (1, 2, 3)]
        return sum(float(v) for v in vals) / 3 if all(v.strip() for v in vals) else None

    e39 = [r for r in rows if C.classify_tool_use(r['follow2_returned'] == '1', r['follow2_tool_use']) == C.ELIGIBLE]
    p33 = [r for r in e39 if float(r['completed_1month']) == 1]
    pops = {'primary33': p33, 'eligible39': e39,
            'primary33_no_prior_exposure': [r for r in p33 if r['follow2_prior_exposure'].strip() == 'no'],
            'eligible39_no_prior_exposure': [r for r in e39 if r['follow2_prior_exposure'].strip() == 'no'],
            'primary33_item_weighted': p33, 'eligible39_item_weighted': e39}

    pc = list(csv.DictReader(open(out / 'results' / 'paired_contrasts.csv', newline='')))
    maxd = {'n': 0, 'estimate': 0.0, 'SE': 0.0, 't': 0.0, 'p': 0.0, 'means': 0.0}
    for row in pc:
        item = row['weighting'] == '17-item'
        ref = row['contrast'].split('-')[1]
        diffs, refs, lts = [], [], []
        for r in pops[row['population']]:
            x, y = score(r, 'LT', row['measure'], item), score(r, ref, row['measure'], item)
            if x is not None and y is not None:
                diffs.append(x - y); refs.append(y); lts.append(x)
        n = len(diffs)
        est = statistics.fmean(diffs)
        se = statistics.stdev(diffs) / math.sqrt(n)
        t = est / se
        p = t_two_sided_p(t, n - 1)
        maxd['n'] = max(maxd['n'], abs(n - int(row['n'])))
        maxd['estimate'] = max(maxd['estimate'], abs(est - float(row['estimate'])))
        maxd['SE'] = max(maxd['SE'], abs(se - float(row['SE'])))
        maxd['t'] = max(maxd['t'], abs(t - float(row['t'])))
        maxd['p'] = max(maxd['p'], abs(p - float(row['p'])))
        maxd['means'] = max(maxd['means'], abs(statistics.fmean(refs) - float(row['reference_mean'])),
                            abs(statistics.fmean(lts) - float(row['longterm_mean'])))
    add(f'paired n/means/estimate/SE/t/P recomputed in Python ({len(pc)} rows, Python eligibility rule)',
        len(pc) == 30 and maxd['n'] == 0 and max(maxd['estimate'], maxd['SE'], maxd['means']) < 1e-12 and maxd['t'] < 1e-9 and maxd['p'] < 1e-9,
        maxd)

    fam = {}
    for row in pc:
        fam.setdefault(row['family_id'], []).append(row)
    hd = 0.0
    for rs in fam.values():
        for r, h in zip(rs, holm([float(x['p']) for x in rs])):
            hd = max(hd, abs(h - float(r['p_holm'])))
    add('Holm families recomputed in Python (10 families of 3)', hd < 1e-12 and len(fam) == 10 and all(len(v) == 3 for v in fam.values()),
        {'families': len(fam), 'max_abs_diff': hd})
    boot_ok = all(float(r['boot_lower']) < float(r['estimate']) < float(r['boot_upper']) and r['boot_B'] == '5000' and r['boot_seed'] == '20260930' for r in pc)
    add('bootstrap intervals bracket the estimate; B = 5000; seed 20260930 (all rows)', boot_ok, {'rows': len(pc)})
    m1 = {(r['measure'], r['weighting']): r for r in pc if r['sample'] in ('primary33', 'primary33_item_weighted') and r['contrast'] == 'LT-M1'}
    same = all(abs(float(r[c]) - float(m1[(r['measure'], r['weighting'])][c])) < 1e-15 for r in pc
               if r['sample'] in ('eligible39', 'eligible39_item_weighted') and r['contrast'] == 'LT-M1'
               for c in ['n', 'reference_mean', 'longterm_mean', 'estimate', 'SE', 't', 'p', 'lower', 'upper'])
    add('LT-M1 rows of eligible39 families equal primary33 rows (same 33 pairs)', same, {'compared_families': 3})

    prior = list(csv.DictReader(open(C.PKG / 'historical_controls' / 'p38_paired_contrasts.csv', newline='')))
    pk = {(r['sample'], r['measure'], r['weighting'], r['contrast']): r for r in prior}
    det = ['reference_mean', 'longterm_mean', 'n', 'estimate', 'SE', 'df', 'lower', 'upper', 't', 'p', 'p_holm']
    w33 = max(abs(float(r[c]) - float(pk[('s38_no_tools', r['measure'], 'equal-task', r['contrast'])][c]))
              for r in pc if r['sample'] == 'primary33' for c in det + ['boot_lower', 'boot_upper'])
    w39 = max(abs(float(r[c]) - float(pk[('all44_no_tools', r['measure'], 'equal-task', r['contrast'])][c]))
              for r in pc if r['sample'] == 'eligible39' for c in det)
    add('positive controls: primary33 rows = prior s38_no_tools (all columns); eligible39 = prior all44_no_tools (deterministic)',
        w33 < 1e-12 and w39 < 1e-12, {'primary33_max_abs_diff': w33, 'eligible39_max_abs_diff': w39})

    flow = {r['quantity']: r for r in csv.DictReader(open(out / 'results' / 'sample_flow.csv', newline=''))}
    exp = {'cohort175': 175, 'one_month_completers_original': 84, 'longterm_returns': 44, 'excluded_reported_tool_use': 5,
           'excluded_unknown_tool_use': 0, 'eligible39': 39, 'primary33': 33, 'additional6': 6, 'cohort170': 170,
           'one_month_eligible': 79, 'covariate_complete': 168, 'primary33_no_prior_exposure': 23,
           'eligible39_no_prior_exposure': 29, 'one_month_only': 46, 'neither_followup': 85}
    split = {'eligible39': (19, 12, 8), 'primary33': (16, 10, 7), 'cohort170': (59, 58, 53), 'excluded_reported_tool_use': (0, 0, 5),
             'one_month_eligible': (29, 24, 26)}
    got = {k: int(float(flow[k]['total'])) for k in exp}
    got_split = {k: tuple(int(float(flow[k][c])) for c in ['AI', 'AI_Human', 'Human']) for k in split}
    add('sample-flow counts and label splits equal the contract', got == exp and got_split == split, {'counts': got, 'splits': got_split})

    tm = {r['sample']: r for r in csv.DictReader(open(out / 'results' / 'correction_timing.csv', newline=''))}
    qc = {r['rule_id']: r for r in csv.DictReader(open(out / 'records' / 'qc_checks.csv', newline=''))}
    q18 = qc['Q18']['observed']
    m33 = json.loads(re.search(r'primary33=(\{.*?\})', q18).group(1))
    m39 = json.loads(re.search(r'eligible39=(\{.*?\})', q18).group(1))
    ok = all(int(tm[s]['responses']) == m['responses'] and int(tm[s]['participants']) == m['participants'] and
             int(tm[s]['early_responses']) == m['early'] and int(tm[s]['late_responses']) == m['late'] and
             int(tm[s]['both_category_participants']) == m['both_categories'] for s, m in [('primary33', m33), ('eligible39', m39)])
    add('timing sample counts equal independent QC eligibility counts', ok, {'primary33': m33, 'eligible39': m39})
    flags = all(r['singular'] == 'FALSE' and r['separation_flag'] == 'FALSE' and r['quasi_separation_flag'] == 'FALSE' and not r['warnings']
                and not r['profile_warnings'] and r['item_intercept_dropped'] == 'FALSE' for r in tm.values())
    add('timing fits: no singularity, separation, convergence or profile warnings; item intercept retained', flags, {'samples': len(tm)},
        'model_diagnostic')
    pcc = list(csv.DictReader(open(out / 'results' / 'correction_positive_control.csv', newline='')))
    add('correction-timing positive controls (same-participant prior fits)', all(r['pass'] == 'TRUE' for r in pcc), {'rows': len(pcc)})
    ppc = list(csv.DictReader(open(out / 'results' / 'paired_positive_control.csv', newline='')))
    add('paired positive controls (R)', len(ppc) == 12 and all(r['pass'] == 'TRUE' for r in ppc), {'rows': len(ppc)})

    vm = list(csv.DictReader(open(out / 'records' / 'verify_models.csv', newline='')))
    add('independent R model recomputation (verify_models.csv)', bool(vm) and all(r['pass'] == 'TRUE' for r in vm), {'checks': len(vm)})
    au = list(csv.DictReader(open(out / 'records' / 'fit_membership_audit.csv', newline='')))
    add('all-fit membership audit: every object matches its contracted set; zero excluded participants',
        bool(au) and all(r['pass'] == 'TRUE' for r in au) and sum(int(r['excluded_present']) for r in au) == 0,
        {'objects': len(au), 'fitted_models': sum(r['kind'] not in ('sample', 'paired', 'descriptive', 'fullcohort') for r in au)})
    gd = {r['model']: r for r in csv.DictReader(open(out / 'results' / 'gls_diagnostics.csv', newline=''))}
    add('GLS33/GLS39: unstructured covariance, apVar available, appx-Satterthwaite df, positive-definite covariance',
        all(gd[m]['covariance'] == 'unstructured' and gd[m]['apVar_available'] == 'TRUE' and gd[m]['df_mode'] == 'appx-satterthwaite'
            and float(gd[m]['min_eigen_cov']) > 0 for m in ('gls33', 'gls39')),
        {m: {k: gd[m][k] for k in ('covariance', 'apVar_available', 'df_mode', 'min_eigen_cov')} for m in gd}, 'model_diagnostic')
    fd = list(csv.DictReader(open(out / 'results' / 'fullcohort_diagnostics.csv', newline='')))
    fg = [r for r in fd if r['family'] == 'gls']
    fl = [r for r in fd if r['family'] == 'lmer']
    add('full-cohort GLS: unstructured covariance retained (no fallback)', all(r['covariance'] == 'unstructured' for r in fg),
        {r['model']: r['covariance'] for r in fg}, 'model_diagnostic')
    add('full-cohort GLS: requested Satterthwaite-type df obtained (strict; df.error fallback when apVar is not a matrix = FAIL)',
        all(r['effective_df_mode'] in ('satterthwaite', 'appx-satterthwaite') for r in fg),
        {r['model']: {'requested': r['requested_df_mode'], 'effective': r['effective_df_mode'], 'apVar_available': r['apVar_available'],
                      'apVar_message': r['apVar_message'], 'df_error_used': r['df_error_used']} for r in fg}, 'model_diagnostic')
    add('full-cohort lmer: every fit nonsingular (strict; boundary variance components reported)',
        all(r['singular'] == 'FALSE' for r in fl),
        {f"{r['model']} {r['measure']}": {'singular': r['singular'], 'boundary_components': r['boundary_components'],
                                           'effective_df_mode': r['effective_df_mode']} for r in fl}, 'model_diagnostic')
    ss = list(csv.DictReader(open(out / 'results' / 'df_seed_sensitivity.csv', newline='')))
    spread = {}
    for r in ss:
        k = f"{r['model']} {r['contrast']}"
        spread.setdefault(k, []).append((float(r['df']), float(r['p']), float(r['lower']), float(r['upper'])))
    detail = {k: {'df_range': [round(min(x[0] for x in v), 3), round(max(x[0] for x in v), 3)],
                  'max_abs_d_p': max(x[1] for x in v) - min(x[1] for x in v),
                  'max_abs_d_ci_bound': max(max(x[2] for x in v) - min(x[2] for x in v), max(x[3] for x in v) - min(x[3] for x in v))}
              for k, v in spread.items()}
    add('record: spread of approximate-Satterthwaite df/P/CI across the pipeline RNG state and two fixed seeds (not graded)',
        len(ss) == 27, detail, 'diagnostic_record')
    add('df seed diagnostic: estimates and SEs equal the pipeline values across RNG states (27 rows, 9 contrasts)',
        len(ss) == 27 and all(r['estimate_equals_pipeline'] == 'TRUE' and r['se_equals_pipeline'] == 'TRUE' for r in ss),
        {'rows': len(ss)})
    ci_ok = True
    for f in ['paired_contrasts.csv', 'label_balanced_temporal.csv', 'label_contrasts.csv', 'fullcohort_gls_contrasts.csv', 'fullcohort_lmer_contrasts.csv']:
        for r in csv.DictReader(open(out / 'results' / f, newline='')):
            lo = r.get('lower', r.get('lower.CL')); hi = r.get('upper', r.get('upper.CL'))
            if lo and hi:
                ci_ok &= float(lo) < float(r['estimate']) < float(hi)
    add('every reported CI brackets its estimate', ci_ok, {})

    hashes = {str(p.relative_to(out)): C.sha256(p) for p in sorted((out / 'results').glob('*.csv'))}
    (out / 'records' / 'output_hashes.json').write_text(json.dumps(hashes, indent=1))
    diag_fail = [c['check'] for c in checks if c['category'] == 'model_diagnostic' and not c['pass']]
    status = 'FAIL' if not ok_all else ('QUALIFIED' if diag_fail else 'PASS')
    (out / 'records' / 'verification.json').write_text(json.dumps(
        {'status': status, 'numerical_status': 'PASS' if ok_all else 'FAIL',
         'model_diagnostic_status': 'FAIL' if diag_fail else 'PASS', 'failed_model_diagnostics': diag_fail,
         'status_rule': 'numerical/reproduction checks block; strict model diagnostics are never relaxed: a failed diagnostic is retained '
                        'as FAIL and the run is QUALIFIED (estimates delivered with the explicit limitation)',
         'checks': checks}, indent=2))
    for c in checks:
        tag = 'INFO ' if c['category'] == 'diagnostic_record' else ('PASS ' if c['pass'] else 'FAIL ')
        print(tag + f"[{c['category']}] " + c['check'])
        if not c['pass']:
            print('     ', json.dumps(c['detail'])[:1500])
    print('VERIFICATION:', status, '| numerical:', 'PASS' if ok_all else 'FAIL', '| failed model diagnostics:', diag_fail or 'none')
    return 0 if ok_all else 1


if __name__ == '__main__':
    sys.exit(main())
