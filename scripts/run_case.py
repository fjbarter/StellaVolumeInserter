#!/usr/bin/env python3
"""Run one documented case; long benchmarks require an explicit opt-in."""
import argparse,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('case',help='Number 01–11 or full directory name')
p.add_argument('action',choices=['run','validate','analyse'])
p.add_argument('--input',type=Path);p.add_argument('--threads',type=int,default=1)
p.add_argument('--backend',choices=['cpu','metal'],default='cpu');p.add_argument('--allow-expensive',action='store_true')
a=p.parse_args();matches=[c for c in (ROOT/'cases').iterdir() if c.name==a.case or c.name.split('_')[0]==a.case.zfill(2)]
if len(matches)!=1:p.error('Choose a unique case 01–11')
case=matches[0]
if a.action=='run' and case.name[:2] in ('05','10','11') and not a.allow_expensive:p.error('This is a potentially long CPU/GPU experiment; use --allow-expensive')
if a.action=='run':
    if not (ROOT/'Stella/Project.toml').exists():p.error('Clone the authorised Stella repository into Stella/ first; see README.md')
    env=case
else:env=ROOT/'common'/('validation' if a.action=='validate' else 'analysis')
cmd=['julia',f'--project={env}',f'--threads={a.threads}',str(case/(a.action+'.jl'))]
if a.input:cmd.append(str(a.input.resolve()))
if a.action=='run' and case.name.startswith('11'):cmd.append(a.backend)
print(' '.join(cmd),flush=True);subprocess.run(cmd,cwd=ROOT,check=True)
