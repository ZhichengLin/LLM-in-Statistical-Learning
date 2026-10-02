#!/usr/bin/env python3
"""Fail-closed binding of the public-data QC verdict to its consumed snapshot (stdlib)."""
import argparse, csv, json, sys
from pathlib import Path
import common as C

def assess(out, package, code):
    rec=out/'records'; req=json.loads((code/'gate_requirements.json').read_text()); reasons=[]
    def load(p):
        return json.loads(p.read_text()) if p.exists() else {}
    manifest=load(package/'input_manifest.json'); current={}
    lock=package/'renv.lock'
    if not lock.is_file(): reasons.append('model environment lock missing')
    ver=load(rec/'input_verification.json'); frozen=load(rec/'contract_freeze.json')
    if not ver.get('all_required_match'): reasons.append('input verification failed or missing')
    if ver.get('manifest_sha256') != C.sha256(package/'input_manifest.json'): reasons.append('manifest changed since input verification')
    saved={x['path']:x for x in ver.get('files',[]) if x.get('role')=='required'}
    if not manifest.get('files') or set(saved)!=set(manifest['files']): reasons.append('manifest inventory differs from verification')
    for rel,spec in manifest.get('files',{}).items():
        p=package/rel; h=C.sha256(p) if p.is_file() else None; current[rel]=h
        x=saved.get(rel,{})
        if h is None or h!=spec.get('sha256') or h!=x.get('observed') or h!=x.get('expected') or not x.get('match'):
            reasons.append('input differs from pinned verified snapshot: '+rel)
    contract=package/'analysis_contract.yaml'; ch=C.sha256(contract)
    if frozen.get('sha256')!=ch: reasons.append('contract changed since freeze')
    if load(rec/'qc_summary.json').get('verdict')!='READY': reasons.append('QC summary is not READY')
    qc=list(csv.DictReader(open(rec/'qc_checks.csv',newline=''))) if (rec/'qc_checks.csv').exists() else []
    qids=[r.get('rule_id') for r in qc]
    if len(qids)!=len(set(qids)) or not set(req['required_qc_rules'])<=set(qids): reasons.append('QC rule inventory missing/duplicated')
    if any(r.get('status')!='PASS' or r.get('execution')!='completed' for r in qc if r.get('rule_id') in req['required_qc_rules']): reasons.append('required QC evidence is not completed PASS')
    for filename,key in [('qc_fixture_results.csv','required_fixture_cases'),('guard_tests.csv','required_guard_cases')]:
        path=rec/filename; rows=list(csv.DictReader(open(path,newline=''))) if path.exists() else []
        ids=[(r.get('case') or '').split(' ')[0] for r in rows]
        if not rows or len(ids)!=len(set(ids)) or not set(req[key])<=set(ids) or any(r.get('result')!='ok' for r in rows): reasons.append(filename+' missing, incomplete or non-ok')
    missing=[rel for rel in req['required_records'] if not (out/rel).is_file()]
    if missing: reasons.append('required record missing')
    return {'verdict':'NOT READY' if reasons else 'READY','reasons':reasons,
            'scope':'deposited-data reproduction; historical acquisition and private linkage are outside this gate',
            'inputs':current,'model_lock_sha256':C.sha256(lock) if lock.is_file() else None,'manifest_sha256':C.sha256(package/'input_manifest.json'),'contract_sha256':ch,
            'code':{rel:C.sha256(code/rel) for rel in C.code_files(code,req['bound_code_extensions'])},
            'records':{rel:C.sha256(out/rel) for rel in req['required_records'] if rel not in missing}}

def main():
    p=argparse.ArgumentParser(); p.add_argument('--out',required=True); a=p.parse_args(); out=Path(a.out).resolve()
    b=assess(out,C.PKG,C.CODE); (out/'records'/'ready_binding.json').write_text(json.dumps(b,indent=2)+'\n')
    print('Readiness binding:',b['verdict'],'|', '; '.join(b['reasons']) or 'exact snapshot verified')
    return 0 if b['verdict']=='READY' else 1
if __name__=='__main__': sys.exit(main())
