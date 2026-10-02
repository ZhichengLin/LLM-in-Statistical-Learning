#!/usr/bin/env python3
"""Fault fixtures for qc_checks.run_checks and the eligibility rule, synthetic data only (no study data).

Expected answers come from the fixture construction, not from the checker:
  * V00 valid synthetic cohort (one reported tool user) must PASS every applicable rule;
  * V01 whitespace-padded ' no ' is a legitimate boundary (trimmed 'no') and must PASS;
  * every single injected fault must FAIL its targeted rule(s); eligibility faults must also keep the affected
    participant out of the eligible set (a naive "tool != 'yes'" rule would admit blank/unknown values);
  * the Python and R eligibility implementations must classify a value grid identically to the contract rule and
    produce identical keyed fingerprints for every derived sample of the valid fixture.
Usage: test_qc_fixtures.py --out DIR   (writes DIR/records/qc_fixture_results.csv; fixtures in DIR/qc_fixtures/)
"""
import argparse
import copy
import csv
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import qc_checks as Q  # noqa: E402

LABELS = {1: 'AI', 2: 'AI', 3: 'AI', 4: 'AI', 5: 'AI Human', 6: 'AI Human', 7: 'AI Human', 8: 'AI Human',
          9: 'Human', 10: 'Human', 11: 'Human', 12: 'Human'}
M1 = {1, 2, 3, 5, 6, 9, 10, 11}
LT = {1, 2, 4, 5, 7, 9, 10}
EXPOSURE = {1: 'yes', 4: 'unsure'}
TOOL_YES = {9}
HOURS_MISSING = {12}
# Independent expected answers from the construction above.
EXPECTED = {'id_start':101, 'cohort_rows': 12, 'items_rows': 204, 'intervals_rows': 6,
            'labels': {'AI': 4, 'AI Human': 4, 'Human': 4}, 'm1': {'AI': 3, 'AI Human': 2, 'Human': 3},
            'lt': {'AI': 3, 'AI Human': 2, 'Human': 2}, 'tool_yes': 1, 'tool_unknown': 0,
            'exposure': {'yes': 1, 'unsure': 1, 'no': 4},
            'eligible39': {'AI': 3, 'AI Human': 2, 'Human': 1}, 'primary33': {'AI': 2, 'AI Human': 1, 'Human': 1},
            'excluded': {'AI': 0, 'AI Human': 0, 'Human': 1}, 'cohort170': {'AI': 4, 'AI Human': 4, 'Human': 3},
            'one_month_eligible': {'AI': 3, 'AI Human': 2, 'Human': 2}, 'additional6': 2, 'covariate_complete': 10,
            'p33_no_expo': 3, 'e39_no_expo': 4, 'one_month_only': 3, 'neither': 2,
            'excluded_all_human': True, 'excluded_all_m1': True, 'interval_range': (429.3, 448.2),
            'timing_primary33': {'responses': 8, 'participants': 4, 'early': 4, 'late': 4, 'both_categories': 4},
            'timing_eligible39': {'responses': 12, 'participants': 6}}
EXPECTED_SETS = {'eligible39': {1, 2, 4, 5, 7, 10}, 'primary33': {1, 2, 5, 10}, 'additional6': {4, 7},
                 'excluded_reported_use': {9}, 'excluded_unknown': set(), 'cohort170': set(range(1, 13)) - {9},
                 'one_month_eligible': {1, 2, 3, 5, 6, 10, 11}, 'one_month_only': {3, 6, 11}, 'neither_followup': {8, 12},
                 'primary33_no_prior_exposure': {2, 5, 10}, 'eligible39_no_prior_exposure': {2, 5, 7, 10}}


def pid(i):
    return str(100 + i)


def build_valid():
    items, cohort = [], []
    for i in range(1, 13):
        corr = {}
        for code in C.ITEM_CODES:
            if code == 't1_q1':
                s = (0, 1, 1)          # early correction
            elif code == 't1_q2':
                s = (0, 0, 1)          # late correction
            else:
                s = (1, 1, 1)
            lt = (1 if (i + int(code[-1])) % 3 else 0) if i in (LT - TOOL_YES) else None
            corr[code] = s + (lt,)
        row = {'ID': pid(i), 'Label': LABELS[i], 'completed_1month': '1' if i in M1 else '0',
               'follow2_tool_use': ('yes' if i in TOOL_YES else 'no') if i in LT else '',
               'follow2_prior_exposure': EXPOSURE.get(i, 'no') if i in (LT - TOOL_YES) else '',
               'follow2_attention_passed': '1' if i in (LT - TOOL_YES) else '', 'follow2_item_order': ('fixed' if i % 2 else 'randomized') if i in (LT - TOOL_YES) else '',
               'follow2_source_recall': 'AI' if i in (LT - TOOL_YES) else '', 'Age': 'band', 'Gender': 'g', 'Field': 'f',
               'Used_LLM_Hours': '' if i in HOURS_MISSING else '1–5'}
        for code, w in C.WAVES:
            collected = code in ('S1', 'S2', 'S3') or (code == 'M1' and i in M1) or (code == 'LT' and i in (LT - TOOL_YES))
            for m in ['accuracy', 'confidence']:
                for t in range(4):
                    row[f'{w}_task{t}_{m}'] = ''
            if not collected:
                continue
            idx = {'S1': 0, 'S2': 1, 'S3': 2, 'LT': 3}.get(code)
            total = 0
            for t, n in C.TASKS:
                k = [4, 3, 5][t - 1] if code == 'M1' else sum(corr[f't{t}_q{j}'][idx] for j in range(1, n + 1))
                total += k
                row[f'{w}_task{t}_accuracy'] = repr(k / n) if code == 'LT' else f'{k / n:.3f}'
                row[f'{w}_task{t}_confidence'] = '3.5'
            row[f'{w}_task0_accuracy'] = repr(total / 17) if code == 'LT' else f'{total / 17:.3f}'
            row[f'{w}_task0_confidence'] = '3.5'
        row['follow2_returned'] = '1' if i in LT else '0'
        cohort.append(row)
        for code in C.ITEM_CODES:
            s1, s2, s3, lt = corr[code]
            items.append({'ID': pid(i), 'Label': LABELS[i], 'Task': code.split('_')[0], 'Item': code, 'S1': str(s1),
                          'S2': str(s2), 'S3': str(s3), 'LT': '' if lt is None else str(lt),
                          'baseline': row['stage1_task0_accuracy'], 'tool_use': row['follow2_tool_use']})
    intervals = [{'ID': pid(i), 'interval_days': str(430.0 + i)} for i in sorted(LT - TOOL_YES)]
    return {'cohort': cohort, 'items': items, 'intervals': intervals}


def write(data, folder, ragged=False):
    folder.mkdir(parents=True, exist_ok=True)
    paths = {}
    for key, rows in data.items():
        p = folder / f'{key}.csv'
        with open(p, 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        if ragged and key == 'cohort':
            text = p.read_text(encoding='utf-8').splitlines()
            text[3] = text[3] + ',extra'
            p.write_text('\n'.join(text) + '\n', encoding='utf-8')
        paths[key] = p
    return paths


def by(d, key, i):
    return next(r for r in d[key] if r['ID'] == pid(i))


def set_tool(d, i, value, items_too=True):
    by(d, 'cohort', i)['follow2_tool_use'] = value
    if items_too:
        for r in d['items']:
            if r['ID'] == pid(i):
                r['tool_use'] = value


def faults():
    def f01(d): by(d, 'cohort', 2)['ID'] = pid(1)
    def f02(d): by(d, 'cohort', 1)['follow_task2_accuracy'] = ''
    def f03(d): by(d, 'cohort', 3)['stage2_task1_accuracy'] = '1.2'
    def f04(d):
        for r in d['items']:
            if r['ID'] == pid(5):
                r['Label'] = 'AI'
    def f05(d): by(d, 'cohort', 2)['follow2_task1_accuracy'] = '0.55'
    def f06(d): next(r for r in d['items'] if r['ID'] == pid(6) and r['Item'] == 't2_q3')['S2'] = '2'
    def f07(d): set_tool(d, 1, 'maybe')
    def f08(d): by(d, 'intervals', 10)['ID'] = pid(12)
    def f09(d): next(r for r in d['items'] if r['ID'] == pid(5) and r['Item'] == 't3_q1')['S1'] = '0'
    def f11(d): by(d, 'cohort', 12)['completed_1month'] = '1'
    def f12(d):  # contamination: the tool user's item rows say 'no'
        for r in d['items']:
            if r['ID'] == pid(9):
                r['tool_use'] = 'no'
    def f13(d): set_tool(d, 2, 'unsure')        # unknown response for a primary participant
    def f14(d): set_tool(d, 5, '')              # missing response for a returner
    def f15(d): set_tool(d, 1, 'yes')           # extra reported user in AI
    def f16(d): set_tool(d, 4, 'yes'); set_tool(d, 9, 'no')   # reported user without one-month data
    def f17(d): set_tool(d, 10, 'No')           # case variant is not an exact 'no'
    def f19(d):  # excluded participant's item rows lose their tool value
        for r in d['items']:
            if r['ID'] == pid(9):
                r['tool_use'] = ''
    def v01(d): by(d, 'cohort', 7)['follow2_tool_use'] = ' no '   # trimmed 'no' is eligible (boundary)
    def f20(d): by(d, 'cohort', 9)['follow2_task0_accuracy'] = '0.5'
    def f21(d): by(d, 'cohort', 1)['follow2_returned'] = '2'
    def f22(d): by(d, 'cohort', 9)['follow2_prior_exposure'] = 'no'
    def f23(d): by(d, 'cohort', 1)['stage1_task0_confidence'] = '3.0'
    def v02(d):
        for rows in d.values(): rows.reverse()
    # name, mutate, target rules that must FAIL, participant that must not be eligible, ragged
    return [('F23 confidence redundancy fault', f23, ['Q28'], None, False),
            ('F20 excluded outcome suppression fault', f20, ['Q11','Q12'], None, False),
            ('F21 invalid return flag', f21, ['Q11'], None, False),
            ('F22 excluded auxiliary suppression fault', f22, ['Q15'], None, False),
            ('V02 row-order invariance', v02, [], None, False),
            ('F01 duplicate cohort ID', f01, ['Q05'], None, False),
            ('F02 missing one-month task in primary', f02, ['Q12'], None, False),
            ('F03 accuracy out of range', f03, ['Q13'], None, False),
            ('F04 item label conflict', f04, ['Q07'], None, False),
            ('F05 long-term mean off score grid', f05, ['Q13'], None, False),
            ('F06 item code 2', f06, ['Q13'], None, False),
            ('F07 invalid tool-use value', f07, ['Q15', 'Q23'], 1, False),
            ('F08 interval ID outside returns', f08, ['Q17'], None, False),
            ('F09 rescoring mismatch', f09, ['Q14'], None, False),
            ('F10 ragged CSV row', None, ['Q02'], None, True),
            ('F11 flag/data inconsistency', f11, ['Q10'], None, False),
            ('F12 tool user relabelled no in items', f12, ['Q07', 'Q26'], None, False),
            ('F13 unknown tool-use response (unsure)', f13, ['Q15', 'Q23', 'Q24'], 2, False),
            ('F14 missing tool-use response (blank)', f14, ['Q15', 'Q23', 'Q24'], 5, False),
            ('F15 extra reported user (non-Human)', f15, ['Q15', 'Q23'], 1, False),
            ('F16 reported user without one-month data', f16, ['Q23'], 4, False),
            ('F17 case variant No is not exact no', f17, ['Q15', 'Q23'], 10, False),
            ('F19 excluded participant item tool blank', f19, ['Q07', 'Q26'], None, False),
            ('V01 whitespace-trimmed no stays eligible', v01, [], None, False)]


RULE_GRID = [('no', True, 'eligible'), (' no ', True, 'eligible'), ('yes', True, 'excluded_reported_use'),
             ('yes ', True, 'excluded_reported_use'), ('', True, 'excluded_unknown'), (None, True, 'excluded_unknown'),
             ('unsure', True, 'excluded_unknown'), ('No', True, 'excluded_unknown'), ('NO', True, 'excluded_unknown'),
             ('n', True, 'excluded_unknown'), ('no', False, 'not_returned'), ('yes', False, 'not_returned')]


def r_cross_check(base, valid_paths):
    """R eligibility rule on the value grid and keyed fingerprints of every derived sample of the valid fixture."""
    key = base / 'fixture_key.bin'
    key.write_bytes(bytes(range(32)))
    grid = base / 'rule_grid.csv'
    with open(grid, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['value', 'is_na', 'returned'])
        for v, ret, _ in RULE_GRID:
            w.writerow(['' if v is None else v, 'TRUE' if v is None else 'FALSE', 'TRUE' if ret else 'FALSE'])
    script = f'''
source({json.dumps(str(C.CODE / 'eligibility.R'))})
g <- read.csv({json.dumps(str(grid))}, colClasses = "character", na.strings = character(0))
v <- ifelse(g$is_na == "TRUE", NA, g$value)
cat("GRID", classify_tool_use(g$returned == "TRUE", v), sep = "\\n")
d <- read.csv({json.dumps(str(valid_paths['cohort']))}, check.names = FALSE, na.strings = c("", "NA"))
idc <- read_ids_chr({json.dumps(str(valid_paths['cohort']))})
s <- derive_samples(d, idc)
key <- readBin({json.dumps(str(key))}, "raw", 32)
for (nm in setdiff(names(s), c("class", "lt_returns"))) cat("FP", nm, set_fingerprint(key, idc[s[[nm]]]), "\\n")
'''
    r = subprocess.run(['Rscript', '--vanilla', '-e', script], capture_output=True, text=True)
    lines = r.stdout.splitlines()
    grid_out = [x for x in lines if x and not x.startswith('FP') and x != 'GRID']
    fps = {x.split()[1]: x.split()[2] for x in lines if x.startswith('FP ')}
    return r.returncode, grid_out, fps, key.read_bytes()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    out = Path(a.out).resolve()
    base = out / 'qc_fixtures'
    base.mkdir(parents=True, exist_ok=True)
    iv = base / 'input_verification_fixture.json'
    iv.write_text(json.dumps({'all_required_match': True,
                              'files': [{'path': f'f{k}', 'role': 'required', 'match': True} for k in range(5)]}))
    extras = {'input_verification': iv}
    results, all_ok = [], True

    valid = build_valid()
    valid_paths = write(valid, base / 'valid')
    rows, sets = Q.run_checks(valid_paths, EXPECTED, extras)
    applicable = [r for r in rows if r['execution'] == 'completed']
    ok = all(r['status'] == 'PASS' for r in applicable)
    sets_ok = all({int(x) - 100 for x in sets[k]} == v for k, v in EXPECTED_SETS.items())
    not_run = sorted(r['rule_id'] for r in rows if r['execution'] != 'completed')
    results.append({'case': 'V00 valid control (one reported user)', 'target_rule': 'all applicable', 'expected': 'PASS',
                    'observed': ('PASS' if ok else ';'.join(f"{r['rule_id']}={r['status']}" for r in applicable if r['status'] != 'PASS'))
                    + f'; derived sets equal construction={sets_ok}',
                    'result': 'ok' if ok and sets_ok else 'UNEXPECTED', 'note': f'not applicable in fixture: {",".join(not_run)}'})
    all_ok &= ok and sets_ok

    for name, fn, targets, must_exclude, ragged in faults():
        d = copy.deepcopy(valid)
        if fn:
            fn(d)
        rws, st = Q.run_checks(write(d, base / name.split()[0], ragged=ragged), EXPECTED, extras)
        status = {r['rule_id']: r['status'] for r in rws}
        if targets:
            hit = all(status.get(t) == 'FAIL' for t in targets)
            expected_txt = 'FAIL ' + '+'.join(targets)
        else:
            hit = all(r['status'] == 'PASS' for r in rws if r['execution'] == 'completed')
            expected_txt = 'PASS all applicable'
        excl_ok = True
        note = ''
        if must_exclude is not None:
            excl_ok = pid(must_exclude) not in st.get('eligible39', set())
            naive = {r['ID'] for r in d['cohort'] if r['follow2_task0_accuracy'].strip() and r['follow2_tool_use'].strip() != 'yes'}
            note = (f'participant kept out of eligible set={excl_ok}; naive "!= yes" rule would admit it='
                    f'{pid(must_exclude) in naive}; ')
        others = sorted(r['rule_id'] for r in rws if r['status'] == 'FAIL' and r['rule_id'] not in targets)
        case_ok = hit and excl_ok
        all_ok &= case_ok
        results.append({'case': name, 'target_rule': '+'.join(targets) or 'all applicable', 'expected': expected_txt,
                        'observed': ';'.join(f'{t}={status.get(t, "MISSING")}' for t in targets) or ('PASS' if hit else 'FAIL'),
                        'result': 'ok' if case_ok else 'UNEXPECTED', 'note': note + f'other FAIL rules: {",".join(others) or "none"}'})

    # Eligibility rule grid (Python and R) and cross-language fingerprints --------------------------------------
    py_grid = [C.classify_tool_use(ret, v) for v, ret, _ in RULE_GRID]
    want = [w for _, _, w in RULE_GRID]
    rc, r_grid, r_fps, key = r_cross_check(base, valid_paths)
    py_fps = {k: C.set_fingerprint(key, v) for k, v in sets.items() if k in r_fps}
    grid_ok = py_grid == want and r_grid == want
    fp_ok = rc == 0 and len(r_fps) == 11 and all(py_fps.get(k) == v for k, v in r_fps.items())
    results.append({'case': 'E01 eligibility rule value grid (Python and R)', 'target_rule': 'eligibility', 'expected': 'contract classes',
                    'observed': f'Python equal={py_grid == want}; R equal={r_grid == want}; values={len(want)}',
                    'result': 'ok' if grid_ok else 'UNEXPECTED', 'note': 'blank, NA, unsure, case variants excluded; trimmed no eligible'})
    results.append({'case': 'E02 Python/R keyed fingerprints of derived samples', 'target_rule': 'eligibility', 'expected': 'identical',
                    'observed': f'R exit={rc}; samples compared={len(r_fps)}; all equal={fp_ok}',
                    'result': 'ok' if fp_ok else 'UNEXPECTED', 'note': 'synthetic key; HMAC-SHA256 over byte-sorted IDs'})
    all_ok &= grid_ok and fp_ok

    required = json.loads((C.CODE / 'gate_requirements.json').read_text())['required_fixture_cases']
    got = {r['case'].split(' ')[0] for r in results}
    coverage_ok = set(required) <= got and len(results) == len(got)
    results.append({'case': 'E03 required fixture coverage (gate_requirements.json)', 'target_rule': 'inventory', 'expected': 'all required IDs once',
                    'observed': f'required={len(required)}; present={len(set(required) & got)}; duplicate IDs={len(results) - len(got)}',
                    'result': 'ok' if coverage_ok else 'UNEXPECTED', 'note': 'missing: ' + (','.join(sorted(set(required) - got)) or 'none')})
    all_ok &= coverage_ok
    (out / 'records').mkdir(parents=True, exist_ok=True)
    with open(out / 'records' / 'qc_fixture_results.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['case', 'target_rule', 'expected', 'observed', 'result', 'note'])
        w.writeheader()
        w.writerows(results)
    for r in results:
        print(f"{r['result']:10} {r['case']:48} {r['target_rule']:14} {r['observed']} | {r['note']}")
    print('FIXTURES:', 'PASS' if all_ok else 'FAIL')
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())
