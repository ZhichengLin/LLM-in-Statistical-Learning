#!/usr/bin/env python3
"""Exercise the actual R entry guard using synthetic QC/binding fixtures; never fit a model.

Records in each isolated case are constructed unit-test state, not production QC evidence.
The public guard_tests.csv contains observed sentinel results only. All identifiers are synthetic.
"""
import argparse, csv, json, shutil, subprocess, sys
from pathlib import Path
import common as C
import bind_ready as B
import qc_checks as Q
import test_qc_fixtures as F

def dump(path,value):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(value,indent=2)+'\n')
def table(path,fields,rows):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)

def baseline(base):
    pkg=base/'package'; code=pkg/'code'; shutil.copytree(C.CODE,code)
    shutil.copy2(C.CONTRACT,pkg/'analysis_contract.yaml')
    shutil.copy2(C.PKG/'renv.lock',pkg/'renv.lock')
    if (C.PKG/'run.R').exists(): shutil.copy2(C.PKG/'run.R',pkg/'run.R')
    data=F.build_valid(); paths=F.write(data,pkg/'data'); out=base/'run'; rec=out/'records'; private=out/'private'
    rec.mkdir(parents=True); private.mkdir()
    req=json.loads((code/'gate_requirements.json').read_text())
    manifest={'schema':'synthetic-public-guard-fixture','files':{str(path.relative_to(pkg)):{'sha256':C.sha256(path)} for path in paths.values()}}
    dump(pkg/'input_manifest.json',manifest)
    key=bytes(range(32)); (private/'fingerprint_key.bin').write_bytes(key)
    cfg={'private_inputs':str(pkg/'data'),'project_root':str(pkg.parent),'fingerprint_key':str(private/'fingerprint_key.bin')}
    dump(rec/'run_config.json',cfg)
    rows,sets=Q.run_checks(paths,F.EXPECTED,{})
    dump(private/'qc_fingerprints.json',{k:{'n':len(v),'fingerprint':C.set_fingerprint(key,v)} for k,v in sets.items()})
    dump(rec/'qc_summary.json',{'verdict':'READY','scope':'CONSTRUCTED SYNTHETIC GUARD UNIT FIXTURE, not study evidence'})
    table(rec/'qc_checks.csv',['rule_id','status','execution'],[{'rule_id':r,'status':'PASS','execution':'completed'} for r in req['required_qc_rules']])
    for file,keyname in [('qc_fixture_results.csv','required_fixture_cases'),('guard_tests.csv','required_guard_cases')]:
        table(rec/file,['case','result'],[{'case':i,'result':'ok'} for i in req[keyname]])
    table(rec/'qc_m1_scoring.csv',['rule_id','status'],[{'rule_id':'Q14b','status':'PASS'}])
    dump(rec/'contract_freeze.json',{'sha256':C.sha256(pkg/'analysis_contract.yaml')})
    dump(rec/'input_verification.json',{'all_required_match':True,'manifest_sha256':C.sha256(pkg/'input_manifest.json'),
         'files':[{'path':r,'role':'required','expected':s['sha256'],'observed':s['sha256'],'match':True} for r,s in manifest['files'].items()]})
    b=B.assess(out,pkg,code); assert b['verdict']=='READY',b['reasons']; dump(rec/'ready_binding.json',b)
    return pkg,out,cfg

def run_guard(pkg,out,cfg,model_environment=False):
    # A sentinel would execute only after entry_guard returns successfully. No scientific inference is invoked.
    code=pkg/'code'
    script=';'.join(['suppressPackageStartupMessages({library(jsonlite);library(openssl)})',
                    'source('+json.dumps(str(code/'eligibility.R'))+')', 'source('+json.dumps(str(code/'guard.R'))+')',
                    'cfg <- fromJSON('+json.dumps(str(out/'records'/'run_config.json'))+')',
                    'entry_guard('+json.dumps(str(out))+',cfg,'+json.dumps(str(code))+','+json.dumps(str(pkg/'analysis_contract.yaml'))+',model_environment='+('TRUE' if model_environment else 'FALSE')+')',
                    'cat("SENTINEL_REACHED\\n")'])
    r=subprocess.run(['Rscript','--vanilla','-e',script],capture_output=True,text=True)
    return r.returncode==0 and 'SENTINEL_REACHED' in r.stdout, 'GUARD REJECTED:' in r.stderr

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);a=p.parse_args();out=Path(a.out).resolve()
    base=out/'private'/'guard_fixtures'; base.mkdir(parents=True,exist_ok=True); results=[]
    cases=['G00 valid bound synthetic state','G01 changed consumed data','G02 changed source code','G03 changed contract',
           'G04 missing QC record','G05 empty fixture record','G06 missing guard case','G07 absent readiness',
           'G08 altered sample fingerprint','G09 redirected input path','G10 changed input manifest','G11 missing QC rule',
           'G12 independently wrong sample with updated record hash',
           'G13 incompatible R version despite updated lock hash','G14 stale model lock']
    for case in cases:
        folder=base/case.split()[0]
        if folder.exists(): shutil.rmtree(folder)
        pkg,run,cfg=baseline(folder); rec=run/'records'; ident=case.split()[0]
        if ident=='G01':
            path=pkg/'data'/'cohort.csv';path.write_text(path.read_text()+'\n')
        elif ident=='G02':
            path=pkg/'code'/'eligibility.R';path.write_text(path.read_text()+'\n# changed\n')
        elif ident=='G03':
            path=pkg/'analysis_contract.yaml';path.write_text(path.read_text()+'\n# changed\n')
        elif ident=='G04': (rec/'qc_checks.csv').unlink()
        elif ident=='G05': table(rec/'qc_fixture_results.csv',['case','result'],[])
        elif ident=='G06':
            table(rec/'guard_tests.csv',['case','result'],[{'case':'G00','result':'ok'}])
        elif ident=='G07': (rec/'ready_binding.json').unlink()
        elif ident=='G08':
            path=run/'private'/'qc_fingerprints.json';x=json.loads(path.read_text());x['primary33']['fingerprint']='0'*64;dump(path,x)
        elif ident=='G09':
            shutil.copytree(pkg/'data',pkg/'redirected');cfg['private_inputs']=str(pkg/'redirected');dump(rec/'run_config.json',cfg)
        elif ident=='G10':
            path=pkg/'input_manifest.json';x=json.loads(path.read_text());x['extra']='changed';dump(path,x)
        elif ident=='G11':
            req=json.loads((pkg/'code'/'gate_requirements.json').read_text());table(rec/'qc_checks.csv',['rule_id','status','execution'],
                [{'rule_id':r,'status':'PASS','execution':'completed'} for r in req['required_qc_rules'][:-1]])
        elif ident=='G12':
            path=run/'private'/'qc_fingerprints.json';x=json.loads(path.read_text());x['primary33']['fingerprint']='0'*64;dump(path,x)
            binding=json.loads((rec/'ready_binding.json').read_text());binding['records']['private/qc_fingerprints.json']=C.sha256(path);dump(rec/'ready_binding.json',binding)
        elif ident in {'G13','G14'}:
            path=pkg/'renv.lock';locked=json.loads(path.read_text());locked['R']['Version']='0.0.1';dump(path,locked)
            if ident=='G13':
                binding=json.loads((rec/'ready_binding.json').read_text());binding['model_lock_sha256']=C.sha256(path);dump(rec/'ready_binding.json',binding)
        reached,rejected=run_guard(pkg,run,cfg,model_environment=ident=='G13')
        good=reached if ident=='G00' else (not reached and rejected)
        # Also verify binding refuses stale state where it owns the relevant check.
        binding_reject=None
        if ident in {'G01','G03','G04','G05','G06','G10','G11'}:
            binding_reject=B.assess(run,pkg,pkg/'code')['verdict']=='NOT READY';good &= binding_reject
        results.append({'case':case,'result':'ok' if good else 'UNEXPECTED','sentinel_reached':reached,
                        'guard_rejected':rejected,'binding_rejected':binding_reject if binding_reject is not None else '',
                        'note':'constructed synthetic state; no models'})
    table(out/'records'/'guard_tests.csv',list(results[0]),results)
    for r in results: print(r['case']+': '+r['result'])
    return 0 if all(r['result']=='ok' for r in results) else 1
if __name__=='__main__':sys.exit(main())
