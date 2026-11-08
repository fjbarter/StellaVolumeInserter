#!/usr/bin/env python3
"""Summarise archived experiment tables; no Stella or third-party Python modules required."""
import argparse,csv,json,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('case');p.add_argument('input',type=Path);p.add_argument('--validate-probes',action='store_true')
a=p.parse_args();out=ROOT/'data/processed/generated'/a.case;out.mkdir(parents=True,exist_ok=True)
files=sorted(a.input.glob('*.csv'))
if not files:raise SystemExit(f'No CSV tables in {a.input}')
report={}
for f in files:
    rows=list(csv.DictReader(f.open()))
    report[f.name]={'rows':len(rows)}
    if rows and 'status' in rows[0]:
        report[f.name]['statuses']={s:sum(r['status']==s for r in rows) for s in sorted({r['status'] for r in rows})}
        # Inventory and convergence must both be checked, not just the independent status.
        report[f.name]['validated_converged']=sum(r['status']=='passed' and r.get('reported_converged','').lower()=='true' for r in rows)
    if a.case=='11_stanford_dragon' and f.name=='historical_timings.csv':
        baseline=next(float(r['seconds']) for r in rows if r['configuration']=='cpu_1')
        comparisons=[dict(r,cpu_baseline_speedup=baseline/float(r['seconds'])) for r in rows]
        with (out/'historical_speedups.csv').open('w',newline='') as io:
            w=csv.DictWriter(io,fieldnames=comparisons[0]);w.writeheader();w.writerows(comparisons)
    if a.case=='09_wall_probes'  and f.name=='summary.csv':
        assert len(rows)==360
        assert max(float(r['final_residual']) for r in rows)<=1e-12
        report[f.name]['max_final_residual']=max(float(r['final_residual']) for r in rows)
        report[f.name]['max_one_step_difference']=max(float(r['change_from_coarse']) for r in rows)
    if a.case=='10_cpu_scaling' and f.name=='problem_size_scaling.csv':
        counts=sorted({int(r['requested_count']) for r in rows});assert len(counts)==13
        summary=[]
        for n in counts:
            group=[r for r in rows if int(r['requested_count'])==n]
            assert sorted(int(r['seed']) for r in group)==[1,2,3,4,5]
            assert all(r['status']=='passed' and r['reported_converged'].lower()=='true' and int(r['final_count'])==n for r in group)
            assert all(float(r['compile_seconds'])==float(r['recompile_seconds'])==0 for r in group)
            record={'requested_count':n,'repeats':5}
            for key in ['insertion_seconds','iterations','seconds_per_particle']:
                vals=[float(r[key]) for r in group];record[key]=statistics.mean(vals);record[key+'_sd']=statistics.stdev(vals)
            summary.append(record)
        with (out/'problem_size_scaling_summary.csv').open('w',newline='') as io:
            w=csv.DictWriter(io,fieldnames=summary[0]);w.writeheader();w.writerows(summary)
(out/'table_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
