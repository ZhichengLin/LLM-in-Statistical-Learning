#!/usr/bin/env python3
"""Scoped DataCheck rules for the no-tools long-term reanalysis (Q01-Q27; Q14b is qc_m1_scoring.R).

Evidence written is aggregate only (counts, maxima, flags). No identifiers or participant values are printed or
written outside private/. Keyed set fingerprints go to OUT/private/qc_fingerprints.json (0600).
Usage: qc_checks.py --out DIR
Library use: run_checks(paths, expected, extras) -> (ledger rows, private sets); used by test_qc_fixtures.py.
"""
import argparse
import csv
import datetime
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402

MISSING_TOKENS = {'NA', 'NaN', 'nan', 'None', 'null', 'NULL', 'N/A'}
EARLIER_TOL = 0.0005 + 1e-9   # workbook task means rounded to 3 decimals
EXACT_TOL = 1e-9              # long-term means recomputed exactly from raw items
HOURS = {'0': 'None', '1–5': 'Low', '6–10': 'Low', '11–20': 'High', '>20': 'High'}

REAL_EXPECTED = {
    'cohort_rows': 175, 'items_rows': 2975, 'intervals_rows': 39, 'id_start': 1001,
    'labels': {'AI': 59, 'AI Human': 58, 'Human': 58},
    'm1': {'AI': 29, 'AI Human': 24, 'Human': 31},
    'lt': {'AI': 19, 'AI Human': 12, 'Human': 13},
    'tool_yes': 5, 'tool_unknown': 0, 'exposure': {'yes': 6, 'unsure': 4, 'no': 29},
    'eligible39': {'AI': 19, 'AI Human': 12, 'Human': 8},
    'primary33': {'AI': 16, 'AI Human': 10, 'Human': 7},
    'excluded': {'AI': 0, 'AI Human': 0, 'Human': 5},
    'cohort170': {'AI': 59, 'AI Human': 58, 'Human': 53},
    'one_month_eligible': {'AI': 29, 'AI Human': 24, 'Human': 26},
    'additional6': 6, 'covariate_complete': 168, 'p33_no_expo': 23, 'e39_no_expo': 29,
    'one_month_only': 46, 'neither': 85,
    'excluded_all_human': True, 'excluded_all_m1': True,
    'interval_range': (429.3, 448.2),
    'timing_primary33': {'responses': 204, 'participants': 32, 'early': 105, 'late': 99, 'both_categories': 23},
    'timing_eligible39': {'responses': 241, 'participants': 37},
}


def read_strict(path):
    problems = []
    with open(path, newline='', encoding='utf-8') as f:
        rdr = csv.reader(f, strict=True)
        try:
            header = next(rdr)
        except StopIteration:
            return [], [], ['empty file']
        if any(not h.strip() for h in header):
            problems.append('blank header')
        if len(set(header)) != len(header):
            problems.append('duplicate header')
        rows, bad = [], 0
        for row in rdr:
            if len(row) != len(header):
                bad += 1
                continue
            rows.append(dict(zip(header, row)))
        if bad:
            problems.append(f'{bad} rows with wrong field count')
    return header, rows, problems


def fnum(x):
    """'' -> None; numeric string -> float; anything else raises ValueError."""
    x = (x or '').strip()
    if x == '':
        return None
    v = float(x)
    if math.isnan(v):
        raise ValueError('nan')
    return v


class Ledger:
    def __init__(self):
        self.rows = []

    def add(self, rule, gate, severity, ok, checked, eligible, observed, expected, note='', execution='completed'):
        status = 'UNKNOWN' if ok is None else ('PASS' if ok else 'FAIL')
        if execution != 'completed':
            status = 'UNKNOWN'
        self.rows.append({'rule_id': rule, 'gate': gate, 'severity': severity, 'status': status, 'execution': execution,
                          'checked': checked, 'eligible': eligible, 'observed': observed, 'expected': expected, 'note': note})

    def skip(self, rule, gate, severity, reason):
        self.add(rule, gate, severity, None, 0, 0, '', '', reason, execution='not_run')


def cohort_required_columns():
    cols = ['ID', 'Label', 'completed_1month', 'follow2_tool_use', 'follow2_prior_exposure', 'follow2_attention_passed',
            'follow2_item_order', 'follow2_source_recall', 'follow2_returned', 'Age', 'Gender', 'Field', 'Used_LLM_Hours']
    for _, w in C.WAVES:
        for t in range(0, 4):
            for m in ['accuracy', 'confidence']:
                cols.append(f'{w}_task{t}_{m}')
    return cols


DOWNSTREAM = ['Q03', 'Q04', 'Q05', 'Q06', 'Q07', 'Q08', 'Q09', 'Q10', 'Q11', 'Q12', 'Q13', 'Q14', 'Q15', 'Q16', 'Q17',
              'Q18', 'Q19', 'Q23', 'Q24', 'Q25', 'Q26', 'Q27']


def run_checks(paths, expected, extras):
    L = Ledger()
    sets = {}
    # Q01 input hashes ---------------------------------------------------------------------------------
    iv = extras.get('input_verification')
    if iv and Path(iv).exists():
        rec = json.loads(Path(iv).read_text())
        req = [f for f in rec['files'] if f.get('role') == 'required']
        L.add('Q01', 'Source', 'Critical', rec.get('all_required_match') is True and len(req) >= 3, len(req), len(req),
              f"{sum(f['match'] for f in req)} of {len(req)} match", 'all manifest files match')
    else:
        L.skip('Q01', 'Source', 'Critical', 'input_verification.json not supplied')

    # Q02 strict parse ---------------------------------------------------------------------------------
    parsed, parse_problems = {}, {}
    for key in ['cohort', 'items', 'intervals']:
        header, rows, problems = read_strict(paths[key])
        parsed[key] = (header, rows)
        parse_problems[key] = problems
    ok = not any(parse_problems.values())
    L.add('Q02', 'Data contract', 'Critical', ok, 3, 3,
          '; '.join(f'{k}: {", ".join(v)}' for k, v in parse_problems.items() if v) or 'no problems', 'no problems')
    if not ok:
        for r in DOWNSTREAM:
            L.skip(r, 'Data contract', 'Critical', 'prerequisite Q02 failed')
        return L.rows, sets

    ch, cohort = parsed['cohort']
    ih, items = parsed['items']
    vh, intervals = parsed['intervals']

    # Q03 required columns -----------------------------------------------------------------------------
    need = {'cohort': cohort_required_columns(),
            'items': ['ID', 'Label', 'Task', 'Item', 'S1', 'S2', 'S3', 'LT', 'baseline', 'tool_use'],
            'intervals': ['ID', 'interval_days']}
    missing = {k: [c for c in v if c not in parsed[k][0]] for k, v in need.items()}
    ok = not any(missing.values()) and all(set(parsed[k][0]) == set(v) for k, v in need.items())
    n_need = sum(len(v) for v in need.values())
    L.add('Q03', 'Data contract', 'Critical', ok, n_need, n_need, f'{sum(len(v) for v in missing.values())} missing', '0 missing')
    if not ok:
        for r in DOWNSTREAM[1:]:
            L.skip(r, 'Data contract', 'Critical', 'prerequisite Q03 failed')
        return L.rows, sets

    token_hits = sum(1 for rows in (cohort, items, intervals) for r in rows for v in r.values() if v.strip() in MISSING_TOKENS)

    # Q04 rows -----------------------------------------------------------------------------------------
    counts = (len(cohort), len(items), len(intervals))
    exp_counts = (expected['cohort_rows'], expected['items_rows'], expected['intervals_rows'])
    L.add('Q04', 'Data contract', 'Critical', counts == exp_counts, 3, 3, '/'.join(map(str, counts)), '/'.join(map(str, exp_counts)))

    # Q05 keys -----------------------------------------------------------------------------------------
    cid = [r['ID'].strip() for r in cohort]
    ikey = [(r['ID'].strip(), r['Item'].strip()) for r in items]
    vid = [r['ID'].strip() for r in intervals]
    blanks = sum(1 for x in cid if not x) + sum(1 for a, b in ikey if not a or not b) + sum(1 for x in vid if not x)
    dups = (len(cid) - len(set(cid))) + (len(ikey) - len(set(ikey))) + (len(vid) - len(set(vid)))
    key_domain_ok = set(cid) == {str(expected['id_start']+i) for i in range(expected['cohort_rows'])}
    keys_ok = blanks == 0 and dups == 0 and key_domain_ok
    n_keys = len(cid) + len(ikey) + len(vid)
    L.add('Q05', 'Data contract', 'Critical', keys_ok, n_keys, n_keys, f'blank={blanks}; duplicate keys={dups}; canonical public key set={key_domain_ok}', 'blank=0; duplicate keys=0')

    # Q06 full-row duplicates / missing tokens ---------------------------------------------------------
    fdup = sum(len(rows) - len({tuple(r.values()) for r in rows}) for rows in (cohort, items, intervals))
    n_all = len(cohort) + len(items) + len(intervals)
    L.add('Q06', 'Data contract', 'Major', fdup == 0 and token_hits == 0, n_all, n_all,
          f'full-row duplicates={fdup}; unrecognized missing tokens={token_hits}', 'duplicates=0; tokens=0')
    if not keys_ok:
        for r in DOWNSTREAM[4:]:
            L.skip(r, 'Design', 'Critical', 'prerequisite Q05 failed (keys not unique)')
        return L.rows, sets

    Cm = {r['ID'].strip(): r for r in cohort}
    by_id = defaultdict(dict)
    for r in items:
        by_id[r['ID'].strip()][r['Item'].strip()] = r

    # Q07 join integrity -------------------------------------------------------------------------------
    id_set_ok = set(by_id) == set(Cm)
    item_set_bad = sum(1 for pid, d in by_id.items() if sorted(d) != sorted(C.ITEM_CODES))
    label_conf = baseline_conf = tool_conf = task_conf = 0
    for r in items:
        c = Cm.get(r['ID'].strip())
        if c is None:
            continue
        label_conf += r['Label'] != c['Label']
        try:
            b1, b2 = fnum(r['baseline']), fnum(c['stage1_task0_accuracy'])
            baseline_conf += (b1 is None or b2 is None or abs(b1 - b2) > 1e-12)
        except ValueError:
            baseline_conf += 1
        tool_conf += (r['tool_use'] or '').strip() != (c['follow2_tool_use'] or '').strip()
        task_conf += r['Task'] != r['Item'].split('_')[0]
    ok = id_set_ok and item_set_bad == 0 and label_conf == baseline_conf == tool_conf == task_conf == 0
    L.add('Q07', 'Source/design', 'Critical', ok, len(items), len(items),
          f'id sets equal={id_set_ok}; ids with wrong item set={item_set_bad}; label/baseline/tool/task conflicts='
          f'{label_conf}/{baseline_conf}/{tool_conf}/{task_conf}', 'equal; 0; 0/0/0/0')

    # Q08 labels ---------------------------------------------------------------------------------------
    lab = Counter(r['Label'] for r in cohort)
    ok = set(lab) <= set(C.LABELS) and dict(lab) == expected['labels']
    L.add('Q08', 'Design', 'Critical', ok, len(cohort), len(cohort), json.dumps(dict(sorted(lab.items()))), json.dumps(expected['labels']))

    # Q09 ceiling --------------------------------------------------------------------------------------
    try:
        s1 = [fnum(r['stage1_task0_accuracy']) for r in cohort]
        ok = all(v is not None and v < 0.90 for v in s1)
        L.add('Q09', 'Design', 'Critical', ok, len(s1), len(s1), f'max S1 17-item accuracy={max(v for v in s1 if v is not None):.3f}', '< 0.900')
    except ValueError:
        L.add('Q09', 'Design', 'Critical', False, len(cohort), len(cohort), 'non-numeric S1 accuracy', 'numeric')

    def present(r, col):
        try:
            return fnum(r[col]) is not None
        except ValueError:
            return False

    try:
        m1flag = {pid: fnum(r['completed_1month']) for pid, r in Cm.items()}
        flag_domain_bad = sum(1 for v in m1flag.values() if v not in (0.0, 1.0))
    except ValueError:
        m1flag, flag_domain_bad = {}, len(Cm)
    M1 = {pid for pid, v in m1flag.items() if v == 1.0}
    LT = {pid for pid, r in Cm.items() if r['follow2_returned'] == '1'}
    E_PRESENT = {pid for pid in LT if C.classify_tool_use(True, Cm[pid]['follow2_tool_use']) == C.ELIGIBLE}

    def by_label(ids):
        return dict(sorted(Counter(Cm[i]['Label'] for i in ids).items()))

    def by_label3(ids):
        c = Counter(Cm[i]['Label'] for i in ids)
        return {k: c.get(k, 0) for k in C.LABELS}

    # Q10 one-month flag consistency -------------------------------------------------------------------
    incons = sum(1 for pid, r in Cm.items() if present(r, 'follow_task0_accuracy') != (pid in M1))
    ok = flag_domain_bad == 0 and incons == 0 and by_label(M1) == expected['m1']
    L.add('Q10', 'Design', 'Critical', ok, len(Cm), len(Cm),
          f'flag domain violations={flag_domain_bad}; flag/data inconsistencies={incons}; M1 by label={json.dumps(by_label(M1))}',
          f'0; 0; {json.dumps(expected["m1"])}')

    # Q11 long-term returns ----------------------------------------------------------------------------
    lt_incons = sum(1 for pid, r in Cm.items() if any(present(r, f'follow2_task{t}_accuracy') for t in range(4)) != (pid in E_PRESENT))
    flag_bad = sum(r['follow2_returned'] not in ('0', '1') for r in cohort)
    ok = by_label(LT) == expected['lt'] and lt_incons == 0 and flag_bad == 0
    L.add('Q11', 'Design', 'Critical', ok, len(Cm), len(Cm),
          f'long-term returns={len(LT)} {json.dumps(by_label(LT))}; task-level presence inconsistencies={lt_incons}',
          f'{sum(expected["lt"].values())} {json.dumps(expected["lt"])}; 0')

    # Eligibility classification (contract `eligibility`) ---------------------------------------------
    cls = {pid: C.classify_tool_use(pid in LT, r['follow2_tool_use']) for pid, r in Cm.items()}
    E39 = {p for p, v in cls.items() if v == C.ELIGIBLE}
    XY = {p for p, v in cls.items() if v == C.EXCLUDED_YES}
    XU = {p for p, v in cls.items() if v == C.EXCLUDED_UNKNOWN}
    P33 = E39 & M1
    A6 = E39 - M1
    C170 = set(Cm) - XY - XU
    M1E = C170 & M1
    OMO = (C170 & M1) - LT
    NEI = (C170 - M1) - LT
    expo = {p: (Cm[p]['follow2_prior_exposure'] or '').strip() for p in Cm}
    P33NE = {p for p in P33 if expo[p] == 'no'}
    E39NE = {p for p in E39 if expo[p] == 'no'}

    def cov_complete(p):
        r = Cm[p]
        ok_basic = all((r[c] or '').strip() not in ('', 'NA') for c in ['Age', 'Gender', 'Field'])
        return ok_basic and HOURS.get((r['Used_LLM_Hours'] or '').strip()) is not None
    COV = {p for p in C170 if cov_complete(p)}
    sets.update({'lt_returns': LT, 'eligible39': E39, 'primary33': P33, 'additional6': A6, 'excluded_reported_use': XY,
                 'excluded_unknown': XU, 'cohort170': C170, 'one_month_eligible': M1E, 'one_month_only': OMO,
                 'neither_followup': NEI, 'primary33_no_prior_exposure': P33NE, 'eligible39_no_prior_exposure': E39NE,
                 'covariate_complete': COV})

    # Q12 completeness ---------------------------------------------------------------------------------
    miss_req = extra_present = checked = 0
    for pid, r in Cm.items():
        for code, w in C.WAVES:
            should = True if code in ('S1', 'S2', 'S3') else (pid in M1 if code == 'M1' else pid in E39)
            for t in range(0, 4):
                for m in ['accuracy', 'confidence']:
                    checked += 1
                    p = present(r, f'{w}_task{t}_{m}')
                    miss_req += should and not p
                    extra_present += (not should) and p
    p33_values = sum(1 for pid in P33 for _, w in C.WAVES for t in range(4) for m in ['accuracy', 'confidence']
                     if present(Cm[pid], f'{w}_task{t}_{m}'))
    ok = miss_req == 0 and extra_present == 0 and p33_values == len(P33) * 40
    L.add('Q12', 'Data contract', 'Critical', ok, checked, checked,
          f'missing required={miss_req}; present where not collected={extra_present}; primary33 five-wave values={p33_values}',
          f'0; 0; {len(P33) * 40}')

    # Q13 domains --------------------------------------------------------------------------------------
    bad_range = bad_grid = nonnum = 0
    for pid, r in Cm.items():
        for code, w in C.WAVES:
            for t in range(0, 4):
                for m in ['accuracy', 'confidence']:
                    try:
                        v = fnum(r[f'{w}_task{t}_{m}'])
                    except ValueError:
                        nonnum += 1
                        continue
                    if v is None:
                        continue
                    if m == 'accuracy' and not (0 <= v <= 1):
                        bad_range += 1
                    if m == 'confidence' and not (1 <= v <= 5):
                        bad_range += 1
                    if m == 'accuracy' and t > 0:
                        n = dict(C.TASKS)[t]
                        tol = EXACT_TOL if code == 'LT' else EARLIER_TOL
                        if abs(v * n - round(v * n)) > tol * n:
                            bad_grid += 1
    bad_item = 0
    for r in items:
        pid = r['ID'].strip()
        for s in ['S1', 'S2', 'S3']:
            bad_item += r[s].strip() not in ('0', '1')
        lt = r['LT'].strip()
        bad_item += (lt not in ('0', '1')) if pid in E39 else (lt != '')
    ok = bad_range == bad_grid == nonnum == bad_item == 0
    L.add('Q13', 'Data contract', 'Critical', ok, len(Cm) * 40 + len(items) * 4, len(Cm) * 40 + len(items) * 4,
          f'out of range={bad_range}; off score grid={bad_grid}; non-numeric={nonnum}; bad item codes={bad_item}', '0; 0; 0; 0')

    # Q14 independent rescoring from items (S1-S3 and LT) ----------------------------------------------
    mism, maxdev, compared = 0, 0.0, 0
    for pid, r in Cm.items():
        its = by_id.get(pid, {})
        if len(its) != 17:
            mism += 1
            continue
        for code, w in C.WAVES:
            if code == 'M1' or (code == 'LT' and pid not in E39):
                continue
            tol = EXACT_TOL if code == 'LT' else EARLIER_TOL
            try:
                total = 0
                for t, n in C.TASKS:
                    k = sum(int(its[f't{t}_q{i}'][code]) for i in range(1, n + 1))
                    total += k
                    dev = abs(fnum(r[f'{w}_task{t}_accuracy']) - k / n)
                    maxdev = max(maxdev, dev)
                    mism += dev > tol
                    compared += 1
                dev = abs(fnum(r[f'{w}_task0_accuracy']) - total / 17)
                maxdev = max(maxdev, dev)
                mism += dev > tol
                compared += 1
            except (ValueError, TypeError, KeyError):
                mism += 1
    L.add('Q14', 'Data contract', 'Critical', mism == 0, compared, compared,
          f'mismatches={mism}; max abs deviation={maxdev:.6f}', 'mismatches=0 (S1-S3 <= .0005; LT <= 1e-9)')

    # Q15 tool-use / exposure domains ------------------------------------------------------------------
    tool = Counter((Cm[p]['follow2_tool_use'] or '').strip() for p in LT)
    ex = Counter(expo[p] for p in E39)
    suppressed_metadata = ['follow2_prior_exposure', 'follow2_attention_passed', 'follow2_item_order', 'follow2_source_recall']
    mask_bad = sum(bool(Cm[p][c].strip()) for p in (XY | XU) for c in suppressed_metadata)
    non_lt_filled = sum(1 for p in set(Cm) - LT if ((Cm[p]['follow2_tool_use'] or '') + (Cm[p]['follow2_prior_exposure'] or '')).strip())
    ok = (set(tool) <= {'yes', 'no'} and set(ex) <= {'yes', 'no', 'unsure'} and non_lt_filled == 0
          and mask_bad == 0 and tool.get('yes', 0) == expected['tool_yes'] and {k: ex.get(k, 0) for k in ['yes', 'unsure', 'no']} == expected['exposure'])
    L.add('Q15', 'Design', 'Critical', ok, len(LT), len(LT),
          f'tool-use values {json.dumps(dict(sorted(tool.items())))}; exposure {json.dumps(dict(sorted(ex.items())))}; '
          f'filled outside long-term returns={non_lt_filled}',
          f'tool-use values within {{yes, no}} with yes={expected["tool_yes"]}; exposure {json.dumps(expected["exposure"])}; 0')

    # Q16 attention ------------------------------------------------------------------------------------
    try:
        att = [fnum(Cm[p]['follow2_attention_passed']) for p in E39]
        ok = all(a == 1.0 for a in att)
        L.add('Q16', 'Human-participant', 'Major', ok, len(att), len(E39), f'passed={sum(a == 1.0 for a in att)}', f'{len(E39)}')
    except ValueError:
        L.add('Q16', 'Human-participant', 'Major', False, len(LT), len(LT), 'non-numeric attention flag', 'numeric')

    # Q17 intervals ------------------------------------------------------------------------------------
    try:
        days = [fnum(r['interval_days']) for r in intervals]
        lo, hi = expected['interval_range']
        ok = set(vid) == E39 and all(d is not None and lo <= d <= hi for d in days)
        L.add('Q17', 'Design', 'Major', ok, len(days), len(LT),
              f'interval IDs equal long-term returns={set(vid) == E39}; eligible39 with interval={len(E39 & set(vid))}; '
              f'min={min(days):.2f}; max={max(days):.2f}', f'True; {len(E39)}; within [{lo}, {hi}]')
    except (ValueError, TypeError):
        L.add('Q17', 'Design', 'Major', False, len(intervals), len(LT), 'non-numeric interval', 'numeric')

    # Q18 correction-timing eligibility (eligible participants only) -----------------------------------
    def eligible_rows(ids):
        rows = []
        for pid in ids:
            for it in by_id[pid].values():
                if it['S1'] == '0' and (it['S2'] == '1' or it['S3'] == '1') and it['LT'] in ('0', '1'):
                    rows.append((pid, 'Early' if it['S2'] == '1' else 'Late'))
        return rows

    def elig_summary(rows):
        ppl = defaultdict(set)
        for pid, timing in rows:
            ppl[pid].add(timing)
        return {'responses': len(rows), 'participants': len(ppl),
                'early': sum(t == 'Early' for _, t in rows), 'late': sum(t == 'Late' for _, t in rows),
                'both_categories': sum(len(s) == 2 for s in ppl.values())}, set(ppl)

    t33, ppl33 = elig_summary(eligible_rows(P33))
    t39, ppl39 = elig_summary(eligible_rows(E39))
    sets.update({'timing_primary33': ppl33, 'timing_eligible39': ppl39})
    r33, r39 = expected['timing_primary33'], expected['timing_eligible39']
    ok = (all(t33[k] == v for k, v in r33.items()) and all(t39[k] == v for k, v in r39.items())
          and not (ppl39 & (XY | XU)))
    L.add('Q18', 'Design', 'Critical', ok, len(items), len(items),
          f'primary33={json.dumps(t33)}; eligible39={json.dumps(t39)}; excluded participants in timing samples={len(ppl39 & (XY | XU))}',
          f'primary33={json.dumps(r33)}; eligible39={json.dumps(r39)}; 0',
          'references: primary-38 package s38_no_tools timing row; 44-leading package no_tools timing row (same participant sets)')

    # Q19 item-difficulty basis (fixed original-study nuisance predictor) ------------------------------
    s1_ok = sum(1 for r in items if r['S1'] in ('0', '1'))
    L.add('Q19', 'Data contract', 'Major', s1_ok == expected['items_rows'], len(items), expected['items_rows'],
          f'S1 present={s1_ok}', f'{expected["items_rows"]}', 'difficulty = per-item S1 mean over original 175 (historical definition; no long-term response)')

    # Q20/Q21 positive-control targets --------------------------------------------------------------------
    pt = extras.get('prior_targets')
    if pt:
        L.add('Q20', 'Traceability', 'Critical', pt['paired_ok'], pt['paired_checked'], pt['paired_checked'], pt['paired_observed'],
              'manifest match; 6 s38_no_tools rows (n 33) and 6 all44_no_tools rows (n 39/39/33)')
        L.add('Q21', 'Traceability', 'Major', pt['timing_ok'], 2, 2, pt['timing_observed'],
              'manifest match; s38_no_tools 32/204 and no_tools 37/241 rows present')
    else:
        L.skip('Q20', 'Traceability', 'Critical', 'prior target files not supplied')
        L.skip('Q21', 'Traceability', 'Major', 'prior target files not supplied')

    # Q23 eligibility classification --------------------------------------------------------------------
    nonret_classified = sum(1 for p in set(Cm) - LT if cls[p] != C.NOT_RETURNED)
    all_h = all(Cm[p]['Label'] == 'Human' for p in XY)
    all_m1 = XY <= M1
    ok = (len(XY) == expected['tool_yes'] and len(XU) == expected['tool_unknown'] and len(E39) + len(XY) + len(XU) == len(LT)
          and nonret_classified == 0 and all_h == expected['excluded_all_human'] and all_m1 == expected['excluded_all_m1']
          and by_label3(XY) == expected['excluded'])
    L.add('Q23', 'Design', 'Critical', ok, len(LT), len(LT),
          f'eligible={len(E39)}; excluded reported use={len(XY)} {json.dumps(by_label3(XY))}; excluded unknown/missing={len(XU)}; '
          f'non-returners classified={nonret_classified}; excluded all Human={all_h}; excluded all with one-month data={all_m1}',
          f'eligible={sum(expected["eligible39"].values())}; excluded={expected["tool_yes"]} {json.dumps(expected["excluded"])}; '
          f'unknown={expected["tool_unknown"]}; 0; True; True',
          "rule: trimmed tool use == 'no' only; 'yes' and any other value excluded")

    # Q24 derived sample sizes ---------------------------------------------------------------------------
    got = {'eligible39': by_label3(E39), 'primary33': by_label3(P33), 'cohort170': by_label3(C170),
           'one_month_eligible': by_label3(M1E)}
    scal = {'additional6': len(A6), 'covariate_complete': len(COV), 'p33_no_expo': len(P33NE), 'e39_no_expo': len(E39NE),
            'one_month_only': len(OMO), 'neither': len(NEI)}
    ok = all(got[k] == expected[k] for k in got) and all(scal[k] == expected[k] for k in scal)
    L.add('Q24', 'Design', 'Critical', ok, len(Cm), len(Cm),
          '; '.join(f'{k}={sum(v.values())} {json.dumps(v)}' for k, v in got.items()) + '; ' + '; '.join(f'{k}={v}' for k, v in scal.items()),
          '; '.join(f'{k}={sum(expected[k].values())} {json.dumps(expected[k])}' for k in got) + '; ' + '; '.join(f'{k}={expected[k]}' for k in scal))

    # Q25 set relations ------------------------------------------------------------------------------------
    rel = {
        'primary33 subset eligible39': P33 <= E39, 'eligible39 subset LT': E39 <= LT,
        'additional6 = eligible39 - primary33': A6 == E39 - P33, 'primary33 disjoint additional6': not (P33 & A6),
        'excluded disjoint eligible39': not ((XY | XU) & E39), 'excluded union eligible39 = LT': (XY | XU | E39) == LT,
        'reported-use excluded subset one-month completers': XY <= M1, 'cohort170 disjoint excluded': not (C170 & (XY | XU)),
        'cohort170 union excluded = cohort175': (C170 | XY | XU) == set(Cm), 'primary33 = eligible39 & M1': P33 == (E39 & M1),
        'LT-M1 pairs (eligible39 with M1) = primary33': {p for p in E39 if p in M1} == P33,
        'no-prior-exposure subsets within eligible': P33NE <= P33 and E39NE <= E39,
        'covariate-complete subset cohort170': COV <= C170,
        'timing samples within eligible': ppl33 <= P33 and ppl39 <= E39,
        'selection groups partition cohort170': (P33 | A6 | OMO | NEI) == C170 and len(P33) + len(A6) + len(OMO) + len(NEI) == len(C170),
    }
    bad = [k for k, v in rel.items() if not v]
    L.add('Q25', 'Design', 'Critical', not bad, len(rel), len(rel), f'{len(rel) - len(bad)} of {len(rel)} relations hold' + (f'; failing: {bad}' if bad else ''),
          f'{len(rel)} of {len(rel)}')

    # Q26 item-level exclusion consistency ----------------------------------------------------------------
    rows_x = [r for r in items if r['ID'].strip() in (XY | XU)]
    rows_e = [r for r in items if r['ID'].strip() in E39]
    x_tool_ok = all(r['tool_use'].strip() == 'yes' for r in rows_x if r['ID'].strip() in XY)
    e_tool_ok = all(r['tool_use'].strip() == 'no' for r in rows_e)
    items_elig = {r['ID'].strip() for r in items if C.classify_tool_use(r['LT'].strip() in ('0', '1'), r['tool_use']) == C.ELIGIBLE}
    ok = x_tool_ok and e_tool_ok and items_elig == E39 and len(rows_x) == 17 * len(XY | XU) and len(rows_e) == 17 * len(E39)
    L.add('Q26', 'Design', 'Critical', ok, len(items), len(items),
          f'excluded item rows={len(rows_x)} (tool yes consistent={x_tool_ok}); eligible item rows={len(rows_e)} (tool no consistent={e_tool_ok}); '
          f'item-derived eligible set equals cohort-derived={items_elig == E39}',
          f'{17 * expected["tool_yes"]}; {17 * sum(expected["eligible39"].values())}; True')

    # Q27 covariates for adjusted full-cohort models ------------------------------------------------------
    hours_vals = Counter((Cm[p]['Used_LLM_Hours'] or '').strip() for p in C170)
    unknown_hours = sum(v for k, v in hours_vals.items() if k not in HOURS)
    L.add('Q27', 'Data contract', 'Critical', len(COV) == expected['covariate_complete'], len(C170), len(C170),
          f'covariate-complete={len(COV)}; Used_LLM_Hours outside mapped categories={unknown_hours}',
          f'{expected["covariate_complete"]}', 'Used_LLM_Hours collapsed None/Low/High as in the 44-leading analyze.R')
    # Q28 confidence redundancy: task0 is the 17-item weighted mean of task means.
    conf_mism = conf_checked = 0
    conf_max = 0.0
    for row in cohort:
        for code, wave in C.WAVES:
            values = [row[f'{wave}_task{task}_confidence'] for task in range(4)]
            if not all(v.strip() for v in values):
                continue
            try:
                overall = fnum(values[0])
                weighted = sum(n * fnum(values[task]) for task, n in C.TASKS) / 17
                dev = abs(overall - weighted)
                conf_max = max(conf_max, dev)
                conf_checked += 1
                conf_mism += dev > (EXACT_TOL if code == 'LT' else 0.001 + 1e-9)
            except (ValueError, TypeError):
                conf_mism += 1
    conf_expected = (3 * expected['cohort_rows'] + sum(expected['m1'].values())
                     + sum(expected['eligible39'].values()))
    L.add('Q28', 'Data contract', 'Critical', conf_mism == 0 and conf_checked == conf_expected,
          conf_checked, conf_expected,
          f'mismatches={conf_mism}; max abs deviation={conf_max:.6f}',
          '0; earlier <=.001 (two rounded summaries), LT <=1e-9',
          'Redundancy check only: per-item confidence is not deposited; raw-response rescoring is outside scope')
    return L.rows, sets


def prior_targets(cfg):
    root = C.PKG / 'historical_controls'
    paired = list(csv.DictReader(open(root / 'p38_paired_contrasts.csv', newline='')))
    s38 = [r for r in paired if r['sample'] == 's38_no_tools' and r['weighting'] == 'equal-task']
    a44 = [r for r in paired if r['sample'] == 'all44_no_tools' and r['weighting'] == 'equal-task']
    t38 = [r for r in csv.DictReader(open(root / 'p38_correction_timing.csv', newline='')) if r['sample'] == 's38_no_tools']
    t44 = [r for r in csv.DictReader(open(root / 'p44_correction_timing.csv', newline='')) if r['population'] == 'no_tools']
    return {'paired_ok': len(s38)==6 and len(a44)==6 and sorted(int(r['n']) for r in s38)==[33]*6
            and sorted(int(r['n']) for r in a44)==[33,33,39,39,39,39], 'paired_checked':12,
            'paired_observed':'manifest-bound public historical controls; 12 no-tools paired rows',
            'timing_ok':len(t38)==1 and len(t44)==1 and int(t38[0]['participants'])==32 and int(t38[0]['responses'])==204
            and int(t44[0]['participants'])==37 and int(t44[0]['items'])==241,
            'timing_observed':'manifest-bound public historical controls; expected 32/204 and 37/241'}


def verdict(rows, dispositions):
    blocking, needs = [], []
    for r in rows:
        if r['severity'] == 'Critical' and r['status'] != 'PASS':
            blocking.append(r['rule_id'])
        if r['severity'] == 'Major' and r['status'] == 'FAIL' and r['rule_id'] not in dispositions:
            needs.append(r['rule_id'])
    return ('READY' if not blocking and not needs else 'NOT READY'), blocking, needs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    out = Path(a.out).resolve()
    cfg = C.load_config(out)
    rec_dir = out / 'records'
    rec_dir.mkdir(parents=True, exist_ok=True)
    priv = Path(cfg['private_inputs'])
    paths = {k: priv / f'{k}.csv' for k in ['cohort', 'items', 'intervals']}
    extras = {'input_verification': rec_dir / 'input_verification.json', 'prior_targets': prior_targets(cfg)}
    rows, sets = run_checks(paths, REAL_EXPECTED, extras)
    m1 = rec_dir / 'qc_m1_scoring.csv'
    if m1.exists():
        rows.extend(csv.DictReader(open(m1, newline='')))
    else:
        rows.append({'rule_id': 'Q14b', 'gate': 'Data contract', 'severity': 'Critical', 'status': 'UNKNOWN', 'execution': 'not_run',
                     'checked': 0, 'eligible': 84, 'observed': '', 'expected': '', 'note': 'qc_m1_scoring.R output missing'})
    dispositions = {}
    fields = ['rule_id', 'gate', 'severity', 'status', 'execution', 'checked', 'eligible', 'observed', 'expected', 'note']
    with open(rec_dir / 'qc_checks.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in sorted(rows, key=lambda x: x['rule_id']):
            w.writerow({k: r.get(k, '') for k in fields})
    v, blocking, needs = verdict(rows, dispositions)
    key = C.ensure_key(cfg['fingerprint_key'])
    fps = {k: {'n': len(s), 'fingerprint': C.set_fingerprint(key, s)} for k, s in sorted(sets.items())}
    C.write_private(out / 'private' / 'qc_fingerprints.json', json.dumps(fps, indent=1))
    summary = {'checked_at': datetime.datetime.now().astimezone().isoformat(timespec='seconds'), 'verdict': v,
               'scope': 'deposited-data reproduction of exploratory primary33/eligible39/cohort170 analyses; source execution and private linkage not certified',
               'blocking_rules': blocking, 'major_without_disposition': needs, 'n_rules': len(rows),
               'status_counts': dict(Counter(r['status'] for r in rows)),
               'sample_sizes': {k: v2['n'] for k, v2 in fps.items()}}
    (rec_dir / 'qc_summary.json').write_text(json.dumps(summary, indent=2))
    for r in sorted(rows, key=lambda x: x['rule_id']):
        print(f"{r['rule_id']:5} {r['severity']:8} {r['status']:8} {r['observed']}")
    print('VERDICT:', v, '| blocking:', blocking, '| majors needing disposition:', needs)
    return 0 if v == 'READY' else 1


if __name__ == '__main__':
    sys.exit(main())
