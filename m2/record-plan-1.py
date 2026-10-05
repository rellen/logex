p='PLAN.md'
s=open(p).read()
pairs=[
# status
("""§1, §3·M1-1 to M1-6 and §3's OE-1 have been brought current. Milestone 2 and OE-2 are
still forward work.""",
"""§1, §3·M1-1 to M1-6 and §3's OE-1 have been brought current. Milestone 2 and OE-2 are
still forward work; Milestone 2 was designed on 2026-10-02 (§3)."""),
("""instance, have landed since; the next unstarted work is Milestone 2.""",
"""instance, have landed since; the next unstarted work is Milestone 2, designed on
2026-10-02."""),
# M1-5 compiling
("""  the text. A lex or parse error is one diagnostic with its column; every later mistake is
  reported, in line order, with M1-2's and M1-3's messages unchanged.
  `Logex.Compiler.tokenize/1` and `parse/1` keep their own error shapes, for the golden
  record.""",
"""  the text. A lex or parse error is one diagnostic with its column; every later mistake is
  reported, in line order, with M1-2's and M1-3's messages unchanged.
  `Logex.Compiler.tokenize/1` and `parse/1` keep their own error shapes, for the golden
  record. *(Milestone 2's design, 2026-10-02: from M2-5, `compile/2` also takes `types:`,
  a function block's file compiles to `{:ok, %Logex.FbType{}}`, and `compile_file/1`
  loads the blocks a program names from beside its file; `docs/organisation.md` decision
  34.)*"""),
("""  type's name is never spelled in a `.ld` body, so the `.lcf` words wait for M2-2.""",
"""  type's name is never spelled in a `.ld` body, so the `.logex` words wait for M2-2."""),
# §5
("""  Their saved form is `.ld` and `.lcf` text, which printers write, and a data API refuses""",
"""  Their saved form is `.ld` and `.logex` text, which printers write, and a data API refuses"""),
("""  configuration instantiates, wires and schedules; no routines, no controller scope, no
  preemption. **Routines are deferred by decision**""",
"""  configuration instantiates, wires and schedules; no routines, no controller scope, no
  preemption. Milestone 2 was designed on 2026-10-02 (§3), adding the document's
  decisions 30–40, all taken as recommended but the configuration file's extension,
  `.logex`, the maintainer's own choice. **Routines are deferred by decision**"""),
# §8
("""   Decided in §5; Milestone 2 (§3); the model in `docs/organisation.md`.""",
"""   Decided in §5; Milestone 2 (§3), designed 2026-10-02; the model in
   `docs/organisation.md`."""),
# B5
("""  `Logex.Compiler`. M1-6 made them `rung/3`, `series/3`, `element/3` and `evaluate/3`, and
  added `Logex.FbType`, whose surface the same test pins.*""",
"""  `Logex.Compiler`. M1-6 made them `rung/3`, `series/3`, `element/3` and `evaluate/3`, and
  added `Logex.FbType`, whose surface the same test pins.* *(Milestone 2's design,
  2026-10-02: the part Milestone 2 needs, one walk of a program's IR in place of the
  compiler's, `Logex.Warnings`' and `Logex.Edit`'s, answering which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, lands as M2-4's first
  commit. Until then M2-5 adds a `cal` clause to each walk; §3.)*"""),
]
for a,b in pairs:
    assert s.count(a)==1,(a[:70],s.count(a))
    s=s.replace(a,b)
open(p,'w').write(s)
