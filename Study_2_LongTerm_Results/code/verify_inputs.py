#!/usr/bin/env python3
"""Verify every deposited numerical/QC input before downstream work; no participant output."""
import argparse, csv, json, sys
from pathlib import Path
import common as C

REQUIRED = {'data/cohort.csv', 'data/items.csv', 'data/intervals.csv',
            'historical_controls/p38_paired_contrasts.csv', 'historical_controls/p38_correction_timing.csv',
            'historical_controls/p44_correction_timing.csv',
            '../Study_2_Early_Late_Correction/data/correction_raw_data.xlsx'}

def verify(package):
    manifest = json.loads((package / 'input_manifest.json').read_text())
    files, ok = [], REQUIRED <= set(manifest.get('files', {})) <= REQUIRED | {'historical_controls/all44_interval_summary.csv'}
    for rel, spec in sorted(manifest.get('files', {}).items()):
        path = package / rel
        observed = C.sha256(path) if path.is_file() else None
        match = observed == spec.get('sha256')
        if path.suffix == '.csv' and path.is_file():
            with path.open(newline='', encoding='utf-8') as f:
                r = csv.reader(f, strict=True); header = next(r); rows = list(r)
            match &= header == spec.get('columns') and len(rows) == spec.get('rows')
            match &= len(header)==len(set(header)) and all(len(x)==len(header) for x in rows)
        files.append({'path':rel, 'role':'required', 'expected':spec.get('sha256'), 'observed':observed, 'match':bool(match)})
        ok &= bool(match)
    return {'all_required_match':bool(ok),'manifest_sha256':C.sha256(package/'input_manifest.json'),'files':files}

def main():
    p=argparse.ArgumentParser(); p.add_argument('--out', required=True); a=p.parse_args(); out=Path(a.out).resolve()
    record=verify(C.PKG); (out/'records'/'input_verification.json').write_text(json.dumps(record,indent=2)+'\n')
    contract=C.CONTRACT
    (out/'records'/'contract_freeze.json').write_text(json.dumps({'sha256':C.sha256(contract),'role':'current public portability contract snapshot'},indent=2)+'\n')
    print('Input verification:', 'PASS' if record['all_required_match'] else 'FAIL', '| manifest files:',len(record['files']))
    return 0 if record['all_required_match'] else 1
if __name__=='__main__': sys.exit(main())
