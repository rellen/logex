import json, re
P='/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2'
src=open(f'{P}/F-synth-mutation.py').read()
changes={}
for m in re.finditer(r"^m\('(R\d+)'", src, re.M): pass
rs=json.load(open(f'{P}/F-synth-mutation.json'))
rows=['| Revert | Rule reverted | File | Exit | Result | Tests that failed |','|---|---|---|---|---|---|']
for r in rs:
    tests='; '.join(f.split(' :: ')[0].replace('Logex.','')+': '+f.split(' :: ')[1] for f in r['failed'][:3])
    more=len(r['failed'])-3
    if more>0: tests+=f'; and {more} more'
    w=' (w)' if r['compile_warning'] else ''
    rows.append(f"| {r['id']}{w} | {r['rule']} | `{r['file'].replace('lib/','')}` | {r['exit']} | {r['result'].replace('Result: ','')} | {tests} |")
table='\n'.join(rows)
qs=json.load(open(f'{P}/F-synth-questions.json'))
out=[]
for q in qs:
    out.append(f"**{q['id']} · {q['question']}** ({q['item']})\n")
    for o in q['options']:
        out.append(f"- *{o['label']}.* {o['consequence']}")
    out.append(f"\n*Recommend {q['recommendation']}.* {q['why']} *Decide before:* {q['decide_before']}.\n")
d=open(f'{P}/F-synth.md').read()
d=d.replace('MUTATION_TABLE',table).replace('QUESTIONS_SECTION','\n'.join(out))
open(f'{P}/F-synth.md','w').write(d)
print(len(rs),'rows', len(qs),'questions')
