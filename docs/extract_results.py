import json, sys
W='/root/.claude/projects/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/subagents/workflows'
out={}
for lane,r in [('A','wf_eeb83001-205'),('B','wf_cbc0d3c4-7df')]:
    labels={}; res=[]
    for l in open(f'{W}/{r}/journal.jsonl'):
        try: d=json.loads(l)
        except Exception: continue
        if d.get('type')=='started': labels[d['key']]=d.get('label')
        elif d.get('type')=='result': res.append({'label':labels.get(d['key']),'result':d.get('result')})
    open_=[v for k,v in labels.items() if k not in {x for x in []}]
    done={x['label'] for x in res}
    out[lane]={'run':r,'results':res,'in_flight':[v for v in labels.values() if v not in done]}
json.dump(out,open(sys.argv[1],'w'),indent=1)
for lane in out:
    print(lane,len(out[lane]['results']),'results; in flight:',out[lane]['in_flight'])
    print('  fixed:',[x['label'][4:] for x in out[lane]['results'] if x['label'] and x['label'].startswith('fix:')])
