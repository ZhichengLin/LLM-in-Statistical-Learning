#!/usr/bin/env python3
"""Aggregate counts of long-term auxiliary measures for the eligible 39 and the primary 33 (no models).

Source recall (vs original label), reported external-tool use, prior similar-item exposure, recorded item-order
condition and interval days. The five excluded participants appear only as a count. Writes OUT/results/auxiliary_counts.csv.
Usage: auxiliary_counts.py --out DIR
"""
import argparse
import csv
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    out = Path(a.out).resolve()
    cfg = C.load_config(out)
    priv = Path(cfg['private_inputs'])
    rows = list(csv.DictReader(open(priv / 'cohort.csv', newline='', encoding='utf-8')))
    days = {r['ID']: float(r['interval_days']) for r in csv.DictReader(open(priv / 'intervals.csv', newline='', encoding='utf-8'))}
    cls = {r['ID']: C.classify_tool_use(r['follow2_returned'] == '1', r['follow2_tool_use']) for r in rows}
    e39 = [r for r in rows if cls[r['ID']] == C.ELIGIBLE]
    samples = {'eligible39': e39, 'primary33': [r for r in e39 if float(r['completed_1month']) == 1]}
    assert len(samples['eligible39']) == 39 and len(samples['primary33']) == 33
    table = []
    for s, rs in samples.items():
        def add(measure, category, n):
            table.append({'sample': s, 'measure': measure, 'category': category, 'n': n, 'denominator': len(rs)})
        rec = [r['follow2_source_recall'] for r in rs]
        add('source recall', 'correct', sum(x == r['Label'] for x, r in zip(rec, rs)))
        add('source recall', 'incorrect', sum(x not in (r['Label'], 'dont_remember') for x, r in zip(rec, rs)))
        add('source recall', 'do not remember', sum(x == 'dont_remember' for x in rec))
        for v in ['yes', 'no']:
            add('external-tool use (eligibility)', v, sum(r['follow2_tool_use'].strip() == v for r in rs))
        for v in ['yes', 'unsure', 'no']:
            add('prior similar-item exposure', v, sum(r['follow2_prior_exposure'].strip() == v for r in rs))
        for v in ['fixed', 'randomized']:
            add('recorded item-order condition', v, sum(r['follow2_item_order'] == v for r in rs))
        d = [days[r['ID']] for r in rs]
        for stat, val in [('mean', statistics.fmean(d)), ('sd', statistics.stdev(d)), ('min', min(d)), ('max', max(d))]:
            table.append({'sample': s, 'measure': 'interval days', 'category': stat, 'n': round(val, 4), 'denominator': len(rs)})
    n_ex = sum(v in (C.EXCLUDED_YES, C.EXCLUDED_UNKNOWN) for v in cls.values())
    n_ret = sum(v != C.NOT_RETURNED for v in cls.values())
    table.append({'sample': 'excluded (reported tool use)', 'measure': 'count only', 'category': 'excluded', 'n': n_ex, 'denominator': n_ret})
    (out / 'results').mkdir(parents=True, exist_ok=True)
    with open(out / 'results' / 'auxiliary_counts.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['sample', 'measure', 'category', 'n', 'denominator'])
        w.writeheader()
        w.writerows(table)
    print(f'auxiliary_counts.csv: {len(table)} aggregate rows')
    return 0


if __name__ == '__main__':
    sys.exit(main())
