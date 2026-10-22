# Logex — development plan

Status of this document: written 2026-08-30 against commit `c9c7f51`, revised after an
adversarial review of the plan itself, and brought current after Milestone 0 was
implemented and merged (PRs #3 and #4). §3 onward, and every reference to
`CLAUDE.md`, anchors on function, clause and bullet names rather than line numbers —
deliberately: line numbers in this file have gone stale three times, most recently because
the commit that fixed the `compiler.ex` ones then edited `CLAUDE.md` and shifted those.
§1 and §2 keep their numbers; §2 is explicitly historical. It records the findings of a full
review of the codebase and turns them into an ordered plan.

**Keeping this document true.** Landing work stales it: §1's counts, §7's Status column and
any "Settled, not yet landed" bullet in the README all go out of date. The repo's practice
is a separate audit pass rather than editing this file in the same commit — but the pass
has to happen, or the next reader inherits a plan that disagrees with the code.

**§2 (Milestone 0) is complete.** It is kept as the record of what was wrong and why each
fix took the shape it did, so its present tense describes the code *before* those commits.
§1, §3·M1-1 to M1-6, §3's OE-1, §3's M2-1, §3's M2-5, §3's M2-2 and M2-3, §3's M2-4,
§3's M2-6, §3's OE-2, §3's M3-1, M3-2, M3-3, M3-4 and M3-5, and §3's Milestone 4 have been brought current. Milestone 2 was designed on 2026-10-02 (§3), its
first item, M2-1, landed the same day, M2-5 on 2026-10-04, M2-2 and M2-3 on 2026-10-11,
and M2-4 and M2-6 on 2026-10-12, so Milestone 2 is done; OE-2 was designed and landed on
2026-10-13 (§3), and Milestone 3 was designed and decided on 2026-10-14, its first four
items, M3-1, M3-2, M3-3 and M3-4, landing the same day and its last, M3-5, on 2026-10-15,
so Milestone 3 is done (§3, "Milestone 3"). Milestone 4, the wall-clock runner, was
designed and decided on 2026-10-17 (§3, "Milestone 4"), its first item, M4-1, landing the
same day, its second, M4-2, on 2026-10-18, and its third, M4-3, the same day, with the
answers to its review and the maintainer's two answers, decisions 130 and 131, the
answers to the verification of those, decision 132, and the maintainer's answer to that,
a fixed timer, which amends decision 130 and supersedes decision 132; and its fourth,
M4-4, the watchdogs and the fault path, the same day, its review's findings fixed on
2026-10-19, with five questions put to the maintainer, who answered them the same day,
each with the option recommended and built, decisions 133 to 137 (§3, M4-4); and its
fifth, M4-5, edits and forcing through the runner, on 2026-10-19, its review's
findings fixed the same day, four of its choices put to the maintainer, who answered them
the same day, decisions 138 to 141, the second with the option recommended, then built
(§3, M4-5); and its sixth, M4-6, the contract walk over the runner, the same day, with a
fix to the devices it found and one question put to the maintainer, its review's
findings fixed on 2026-10-20, and the maintainer's answer the same day, a restart that
reads every device first, decision 142, then built (§3, M4-6), and the maintainer's
confirmation the same day of two calls the lead made in its verifications, a report-only
reading kept across a restart, a fix within decision 142, and a refused change's good
points kept, decision 143; and its seventh and last, M4-7, the documents, the same day,
so every item of Milestone 4 has landed, its done sentence checked clause by clause
against the tests (§3, after M4-7): every clause is pinned by a test on the manual
clock, but the three of timing on the real clock, rounds back to back one a millisecond
at most, the share and the grid with its missed periods, are met there only under the
milestone's own rule, timing tested on the manual clock and a test on the real clock
asserting liveness, the plant's 2 s run asserting no more rounds than milliseconds and
nothing finer, a reading the maintainer accepted on 2026-10-20, so Milestone 4 is done.
Milestone 5, data types, was designed and decided on 2026-10-21 (§3, "Milestone 5";
`docs/organisation.md` §4.12 and decisions 144–160), the maintainer answering its sixteen
questions and a follow-up the same day, six of them otherwise than recommended, among
them integer overflow wrapping in every width, which supersedes decision 77; the
record's ten questions put back to the maintainer and its three open rules were answered
the same day (decisions 161–167, and notes on the decisions the rest settle), three of
the ten otherwise than the record read them: a real too large for its integer target
rounded and then wrapped (161), the truncations named `real_trunc_int` (162), and
`ctu_dint`, `ctd_dint` and `ctud_dint` aliases of `ctu`, `ctd` and `ctud` (163); its
sixteen items, M5-1 to M5-16, are planned, and the first, M5-1, one table of types, landed
the same day with no behaviour changed (§3, M5-1), and the second, M5-2, on 2026-10-22:
the dint wraps, decision 77's saturation superseded on purpose (§3, M5-2); the
maintainer's four answers to their reviews' questions landed the same day (decisions
168–171, §3 after M5-2): a program type named with no article, a hand-edited program's
port holding an instance the host's mistake, the type table's width in bits, and a value
a state holds outside its tag's type refused where the state is handed in; and the third,
M5-3, the same day: IEC's eight integer widths declared everywhere a dint is, `move` and
literals by Figure 11, and the 56 integer conversions (§3, M5-3); and the maintainer's
eight answers to M5-3's and decision 171's questions the same day (decisions 172–179, §3
after M5-3): a value a state holds that is no integer refused as one outside its type is,
a conversion's source widening into its `from` type, every width's misfit told its range,
and a conversion of a literal warned, the other four confirmed as built; and the fourth,
M5-4, the same day: arithmetic and comparison over every integer width, computed in the
destination's type, each source widening into it by Figure 11 (§3, M5-4).

Every claim below was reproduced by executing code against a scratch copy of the
repository (Erlang/OTP 25, Elixir 1.14). Where a fix is proposed it was applied to that
copy and the result checked, including `mix test` and, for grammar changes, a yecc
conflict check. Where a proposed fix turned out not to work as first written, the
corrected version is what appears here. Claims that ran on the pinned Elixir 1.20.4 /
OTP 28 instead say so; the yecc conflict check went with yecc (§6).

---

## 1. Where we stand

Logex is a Ladder Logic compiler and interpreter using a conventional ladder instruction
vocabulary. Its code is all hand-written — `lib/`, `test/` and `mix.exs`; the one
generated file is the golden record, `test/fixtures/frontend_golden.txt` — and it has no
dependencies. The front end is `Logex.Lexer` and `Logex.Parser` (§6
says why they are hand-written); `Logex.Compiler` delegates `tokenize/1` and `parse/1` to
them and holds the validating lowering; `Logex.Printer` turns a parse AST back into source.
Since M1-5 a host calls none of those stages: `Logex.compile/2` and `Logex.compile_file/1`
run the first three and return one error type, and `Logex.Runtime` runs the scans, through
an evaluator that is private to it (B5). The stage functions stay public for the tests.

```
 source string
   │  Logex.Compiler.tokenize/1        Logex.Lexer              binary pattern matching
   ▼  {:ok, tokens, endline}
 [{:name,{1,1},"xic"}, {:name,{1,5},"aa"}, {:bst,{1,8}}, {:name,{1,10},"mov"}, {:int_lit,{1,14},123}, …]
   │  Logex.Compiler.parse/1           Logex.Parser             recursive descent
   ▼  {:ok, ast}
 {:routine, {:rungs, [{:rung, [{:name, 1, "xic"}, {:name, 1, "aa"}, {:branches, [[…]]}]}]}}
   │  Logex.Compiler.instructionize/2  declarations to a tag table (Logex.Declarations);
   │                                   lowering, checked against each operand signature
   │                                   and each tag's declaration
   ▼  {:ok, program} | {:error, [%Logex.Diagnostic{line:, message:}]}
 %Logex.Program{rungs: [{:rung, [{:xic, 3, [{:name, 3, "aa"}]}, {:ote, 3, [{:name, 3, "bb"}]}]}],
                tags: %{"aa" => %Logex.Tag{type: :bool, section: :var_input, …}, …}}
   │  Logex.Runtime.call/4             the evaluate/3 clauses, private: a {power_flow, env} fold
   │                                   with the scan's read-only %Logex.Scan{now:, first:}
   ▼  {outputs, %Logex.Instance{env: %{"aa" => 1, "bb" => 1}, …}}
```

### What works

- Series contacts, parallel branches to arbitrary nesting depth.
- `xic`, `xio`, `ote`, `otl`, `otu`, `move` with **correct** latch/unlatch retention semantics.
- Multi-rung routines, with power flow correctly reset per rung.
- Driven one scan at a time through `Logex.Runtime` (M1-5), a correct seal-in motor circuit.
- `ton` on the injected clock, `ons`, and `eq ne lt gt le ge` (M1-6); a timer is a declared
  instance, `var t1 ton`, whose members `t1.dn` and `t1.acc` are read anywhere.
- A staged online edit of one running instance (OE-1): `Logex.Edit` accepts a candidate
  beside the running program, then tests, untests, assembles or cancels it between two
  scans, moving the state by name and reporting every step.
- A configuration built from Elixir data (M2-1): `Logex.Configuration` holds program
  types, periodic tasks, globals located at input and output points or not, program
  instances and their connections, checked by one validator, and `Logex.Runtime` runs it
  as one resource, a cycle at a time on the injected clock, by priority, with missed
  periods counted and reported.
- User function blocks (M2-5): a file headed `function_block seal` compiles to a
  `%Logex.FbType{}`, which `Logex.compile/2` takes in `types:` and `Logex.compile_file/1`
  loads from beside the file that names it; a program declares instances, `var s1 seal`,
  runs each with `cal`, rung power its EN, and reads its outputs, `s1.run`, anywhere.
  Blocks nest, a block never holds itself, and an online edit moves a block's members by
  path.
- A configuration file (M2-2, M2-3): `plant.logex` declares periodic tasks, globals at
  input and output points or not, program instances and arrow-free connections, and
  `Logex.Configuration.compile_file/1` reads it, loads each program type from its `.ld`
  file beside it, and checks it with M2-1's one validator, every mistake a diagnostic at
  its file and line in the configuration file's words; `Logex.Configuration.Text` prints
  a configuration back to its text, exactly. `Logex.compile_file/1` takes a `.ld` file
  only.
- Globals shared by name (M2-4): `var_external estop bool` in a program's `.ld` file
  names the configuration's `var_global estop bool`, bound by name and type and checked
  once a program type; a scan reads and writes the global itself, one copy in the
  resource, and two writers of one global are warnings. `Logex.Walk` is the one walk of a
  program's IR that the checks read.
- IEC's counters (M3-1): `var boxes ctu`, `var hopper ctd` and `var stock ctud`, run by
  `ctu boxes 12` and `ctd hopper 40`, a `ctud` by one of each on two rungs; a rising edge
  counts, never on a first scan; the reset `r` and load `ld` are inputs a rung writes; the
  count stops at the dint's limits with `ov` or `un` latched; and an online edit moves a
  counter's `pv`, forecasts its `q` and blocks an edge it would otherwise make.
- The other timers (M3-2): IEC's off-delay `tof`, `.dn` on through its delay, and pulse
  `tp`, its pulse `.tt` from a rising edge, never on a first scan, and the conventional
  retentive `rto`, keeping its time across a false rung and cleared by its `r` input; each
  a timer by every rule a `ton` keeps, its forecast and resume by its own type across an
  online edit, a `tp`'s edge blocked as a counter's is, and each warned of under an event
  task in its own words.
- Integer arithmetic (M3-3): `add sub mul div mod neg abs` on dints, the result brought to
  the nearer limit with no power on that scan, IEC's ENO, and since M5-2 wrapped instead,
  its low 32 bits kept, with no power and no fault (decision 146); a zero divisor 0 and no power,
  reported to the host as a minor fault, a `%Logex.Fault{}` in a lone instance's state and
  a `{:fault, ...}` event of a cycle; and negative literals, `-5`, a sign glued to its
  digits.
- The pulse coils (M3-4): IEC's transition-sensing coils in the conventional set's form,
  `osr s1 pulse` and `osf s1 pulse`, a pulse for one scan on the rise or the fall of the
  power the coil receives, never on a first scan, that power passed on, the storage bit
  under every rule an `ons` bit keeps.
- A forward jump (M3-5): `jmp auto`, once its rung is done, skips the rungs after it up to
  the one `lbl auto` heads, which runs; a skipped rung runs nothing, frozen as a block
  whose `cal` is false is, a timer in it catching up when next run; a jump back, to its
  own rung or to a label its routine lacks, and a label not first on its rung, are each a
  located diagnostic; and a label is a name of its routine's own, never a tag.
- A staged online edit of a running configuration (OE-2): `Logex.Configuration.Edit`
  accepts a candidate configuration against the resource that runs the original, refusing
  what changes only with a restart at its line, then tests, untests, assembles or cancels
  it between two cycles: each kept instance moved by its program type's one plan,
  instances started, set aside and brought back, globals started and held, every step
  reported, and a stale edit refused by the resource's generation.
- Watchdogs and the continuous task (M4-2): a task line takes `watchdog <ms>` after its
  priority, 500 ms unless set, and one line may declare the continuous task, `task main
  continuous watchdog 200`, which runs every instance with no timed task, `with main` or
  none, after the due tasks, each run reported under its name; a watchdog changes while
  the plant runs, and the runner reads it, below.
- The wall-clock runner (M4-1, M4-3 to M4-6): `Logex.Runner` runs a configuration's
  resource on a clock, `Logex.Runner.Clock`'s monotonic one or a manual one a test moves,
  through devices bound to adapters (`Logex.IO`, with `Logex.IO.Sim` the one shipped),
  its untimed programs back to back, one round a clock millisecond at most, a share kept
  for its own work, and each timed task on its grid; a watchdog on every task, a device's
  deadline and an idle watchdog trip it, every output 0 once, until a cold or warm
  restart, which reads every device first; a stop and its death zero every output too;
  inputs are forced, kept in a file across a crash; and an online edit is stepped
  through it between rounds. README's "Running a plant on the clock" runs it, and "What
  logex is not" says what it is not, a safety controller first.

These were each verified directly:

```
OTE de-energises on a false rung      xic gg ote xx  gg=0,xx=1  ->  %{"xx" => 0}
OTL is retentive on a false rung      xic gg otl xx  gg=0,xx=1  ->  %{"xx" => 1}
branches OR, env threads in order     ( xic gg ote mm | xic mm ote zz )
                                                     gg=0,mm=1  ->  mm=0, zz=0
no short-circuit — every branch runs  ( xic aa ote p1 | xic bb ote p2 ) ote res
                                       aa=1,bb=0,p2=1 -> p1=1, p2=0, res=1
nested branch = a AND (b OR c)        xic aa ( xic bb | xic cc ) ote res
                                       aa=1,bb=0,cc=1 -> res=1
rung independence (flow resets)       xic gg ote r1\note r2   gg=0  ->  r1=0, r2=1
```

The grammar, left-factored as `Logex.Parser` implements it, is LL(1) — every decision is
made on the next token — for a language with arbitrary branch nesting. Nothing checks that
mechanically since yecc went (§6); the golden record and the printer's round-trip
generator stand in. On 1.20.4, `mix format --check-formatted` and
`mix compile --force --warnings-as-errors` both exit 0.

### What does not work

The three things this section listed before Milestone 0 — `mov` with an integer literal,
any source read from a file, and single-character tag names — all work now; M0-1, M0-5 and
M0-4 closed them. Of the three listed below, two gave *wrong answers* silently and one an
unusable error; all three are closed now.

- **`xic` and `xio` were not complementary.** ***Closed — M1-3 and M1-4.*** Two
  independent *positive* tests, so a tag holding anything outside `{0,1}` — or no value at
  all — read false for both. M1-3 made it unreachable from source: `move 250 sp xic sp ote
  hi`, which gave `hi=0`, is a compile error however `sp` is declared. M1-4 closed it for an
  env the host builds by hand: `xio` is now the negation of `xic`, whatever the value.
- **A missing space before `nxb` silently turned OR into AND.** ***Closed — §4·B1.***
  `bst xic aa nxb xic bb bnd ote dd` with `aa=0,bb=1` gave `dd=1`; deleting the one space
  before `nxb` gave `dd=0`, with no error anywhere. The delimiters are `(` `|` `)` now,
  which are outside `NAME` and cannot fuse.
- **There was no validation of any kind.** ***Closed — M1-2.*** An unknown mnemonic, a
  wrong-case mnemonic or a wrong operand count survived to `instructionize/1` or
  `evaluate/2` and raised a bare `MatchError` or `FunctionClauseError` naming neither the
  mnemonic nor the line, and `mov src ote` wrote a tag called `ote` with no error at all.
  Each is now a located diagnostic, `XIC aa` is simply `xic aa`, and every mistake in a
  routine is reported, not just the first.

### The gap that let this happen — now closed

There was no test anywhere that ran a source string through to an environment. Each
stage's test hand-typed its own input, so a mismatch at a stage boundary was invisible: the
two downstream fixtures **disagreed with each other** — `instructionize_test.exs:38` said
`int_lit:`, `evaluation_test.exs:13` said `lit_int:` — and both were green.

M0-2 closed this with `test/logex/end_to_end_test.exs` (`03c10e0`), which drives source to
an environment and names no IR tag in any assertion — its one AST match is the
`{:routine, {:rungs, _}}` wrapper used to count rungs — so no fixture in it can encode a
stage-boundary mismatch. M0-1 (`690fc2d`) reconciled the fixtures on `:int_lit` —
`evaluation_test.exs:19` and `:69` now read `{:move, 2, [{:int_lit, 2, 123}, …]}`, the 3-tuple since M1-1
(`a22bf39`) — and the `:lit_int` atom appears nowhere in the tree.

---

## 2. Milestone 0 — make a green test run mean something — DONE

**All five items are landed and merged; nothing in this section is waiting to be done.**
M0-1 `690fc2d`, M0-2 `03c10e0`, M0-3 `dde8c1d`, M0-4 `3f3b104` (PR #3, merge `22bc81a`);
M0-5 `b65e756` (PR #4, merge `863af6f`). Re-verified on `main` after M1-1: `mix test` →
`27 tests, 0 failures`. M1-1 to M1-6 and §3's OE-1, a staged edit of one program
instance, have landed since; the next unstarted work is Milestone 2, designed on
2026-10-02.

The items are kept in full because their diagnoses are the record of *why* the code looks
the way it does — why the parser drops empty rungs, why `CLAUDE.md` once documented an
`rm -f src/*.erl && rm -rf _build` loop, why `end_to_end_test.exs` names no IR tag.
**Apart from each item's Status line, everything from here to the end of §2 describes the
tree as it stood *before* these commits: read the present tense as historical, and the
`.xrl` / `.yrl` / `CLAUDE.md` line numbers as pre-M0 ones.** The Status lines were current
when written, but the front end has since been rewritten by hand (§6): their `.xrl` and
`.yrl` references name files that no longer exist, and each rule or production they cite
is now code in `Logex.Lexer` or `Logex.Parser`.

### M0-1 · Fix the transposed literal atom `:lit_int` → `:int_lit`

**Status: DONE — `690fc2d` (PR #3).** `get_arg/2`'s literal clause now reads
`defp get_arg(_env, {:int_lit, _, val}), do: val` (the `_` line slot since M1-1), and both
`evaluation_test.exs` fixtures (`:14` and `:59`) say `{:int_lit, 2, 123}`. The scratch `e2e.exs` below was never committed; the
permanent check is `test/logex/end_to_end_test.exs`. Two refs in the diagnosis moved when
M0-5 landed: the `{INT}` rule is now `ladder_lexer.xrl:20` and `elem -> int_lit` is now
`ladder_parser.yrl:32`. The `1 doctest, 5 tests` in the acceptance block is this item's own
contemporaneous run; the suite was 27 tests when M1-1 landed.

**Severity: high.** `lib/logex/compiler.ex:119` matches `{:lit_int, val}`. The lexer
emits `int_lit` (`src/ladder_lexer.xrl:18`), the parser preserves it
(`src/ladder_parser.yrl:19`), and `instructionize/1` passes operands through untouched
(`compiler.ex:35`). Since `mov` is the only instruction taking a literal, the entire
integer-literal feature is dead end to end.

Reproduce with a scratch `e2e.exs` in the project root — the initial env is load-bearing,
since with an empty env the movs write `nil` and the failure looks different:

```elixir
run = fn src, env ->
  try do
    {:ok, toks, _} = Logex.Compiler.tokenize(src)
    {:ok, ast} = Logex.Compiler.parse(toks)
    ast |> Logex.Compiler.instructionize() |> Logex.Compiler.evaluate({true, env})
  rescue
    e -> {:RAISED, Exception.message(e) |> String.split("\n") |> hd()}
  end
end

show = "( mov aa bb | mov cc dd | mov ee ff ( mov 123 hh ) ) ( ote xx | ote yy )"
IO.inspect(run.(show, %{"aa" => 1, "cc" => 2, "ee" => 3}), label: "showcase")
IO.inspect(run.("mov 123 dd", %{"dd" => 0}), label: "mov literal")
IO.inspect(run.("mov aa dd", %{"aa" => 7}), label: "mov tag->tag")
```

```
$ mix run e2e.exs
showcase:     {:RAISED, "no function clause matching in Logex.Compiler.get_arg/2"}
mov literal:  {:RAISED, "no function clause matching in Logex.Compiler.get_arg/2"}
mov tag->tag: {true, %{"aa" => 7, "dd" => 7}}
```

The suite is green because `evaluation_test.exs:13` and `:56` hand-write the same
misspelling into their input, so the typo appears on both sides and cancels.
`git log -S` shows the clause, the wrong fixture, and a *correct* `int_lit` fixture in
the sibling file were all introduced in `ec0534a` — whose suite was already red from an
unrelated lexer bug, so the fixture cannot have been transcribed from real output.

**Fix as three coordinated sites in one commit.** Changing only `compiler.ex` turns a
green suite red (2 failures), which invites a revert.

```diff
--- a/lib/logex/compiler.ex
+++ b/lib/logex/compiler.ex
@@ -119 +119 @@
-  defp get_arg(_env, {:lit_int, val}), do: val
+  defp get_arg(_env, {:int_lit, val}), do: val

--- a/test/logex/evaluation_test.exs
+++ b/test/logex/evaluation_test.exs
@@ -13 +13 @@   (and identically at :56)
-             [{:xic, [name: "bit0"]}, {:mov, [lit_int: 123, name: "dd"]}]
+             [{:xic, [name: "bit0"]}, {:mov, [int_lit: 123, name: "dd"]}]
```

**Acceptance** — verified on a scratch copy, same `e2e.exs`:

```
$ mix run e2e.exs        # after the fix
showcase:     {true, %{"aa" => 1, "bb" => 1, "cc" => 2, "dd" => 2, "ee" => 3,
                       "ff" => 3, "hh" => 123, "xx" => 1, "yy" => 1}}
mov literal:  {true, %{"dd" => 123}}
mov tag->tag: {true, %{"aa" => 7, "dd" => 7}}
$ mix test
1 doctest, 5 tests, 0 failures
```

The showcase case becomes the first seed of `test/logex/end_to_end_test.exs` in M0-2,
after which the permanent check is just `mix test` and `e2e.exs` can be deleted.

### M0-2 · Add an end-to-end test that never names an IR tag

**Status: DONE — `03c10e0` (PR #3).** `test/logex/end_to_end_test.exs` exists: 14 tests,
none of whose *assertions* names an IR tag (one helper matches the
`{:routine, {:rungs, _}}` wrapper to count rungs). It carries all four seeds described
below plus rung counts, an empty program, jumper legs and unbalanced-branch rejection —
14 of the suite's 24 tests as it landed; it was 18 of 27 when M1-1 landed.

**Severity: medium.** Without this, M0-1 recurs. The test must drive source → env so
that no fixture can encode a stage-boundary mismatch.

```elixir
defp run(src, env) do
  {:ok, t, _} = Logex.Compiler.tokenize(src)
  {:ok, ast}  = Logex.Compiler.parse(t)
  ast |> Logex.Compiler.instructionize() |> Logex.Compiler.evaluate({true, env})
end

test "mov of a literal, source to env" do
  assert {_, %{"dd" => 123}} = run("mov 123 dd", %{"dd" => 0})
end
```

Seed `test/logex/end_to_end_test.exs` with two reproductions and two regression guards —
**not four failures.** Only two of the four fail today.

Broken today: the `lex_and_parse_test.exs:6` showcase string (green once M0-1 lands), and
a source with a trailing newline. Already correct, and seeded so they stay that way: the
multi-rung routine from §1, `"xic gg ote r1\note r2"` with `gg=0` → `%{"gg" => 0,
"r1" => 0, "r2" => 1}`; and a seal-in circuit, which needs three `run/2` calls because one
call is one scan and retention is only visible across scans:

```
seal = "( xic start | xic motor ) xio stop ote motor"
scan 1  start=1                  -> %{"motor" => 1, "start" => 1, "stop" => 0}
scan 2  start=0 (seal holds)     -> %{"motor" => 1, "start" => 0, "stop" => 0}
scan 3  stop=1  (drops out)      -> %{"motor" => 0, "start" => 0, "stop" => 1}
```

**The trailing-newline case could not pass until M0-5, three items later.** It was tagged
`@tag :skip` so M0-3 and M0-4 landed against a green suite — CLAUDE.md's `mix test` bullet says tests must
pass before committing, and M0-3's whole subject is a build trap that a trustworthy
`mix test` is what catches. That happened as planned: `b65e756` dropped the tag, no
`@tag :skip` remains anywhere in `test/`, and the case is green and unskipped.

### M0-3 · Untrack the generated scanners, and correct `CLAUDE.md`

**Status: DONE — `dde8c1d` (PR #3), and since moot: the front end is hand-written (§6), so
there are no generated scanners to track or untrack.** At the time, `git ls-files src/`
listed only the `.xrl` and the `.yrl`, `.gitignore` carried `/src/*.erl`, and a fresh clone
ran leex and yecc. (`.gitignore` carries it again, for a checkout built before §6: see
CONTRIBUTING's "The test output will lie to you".)
`CLAUDE.md` was rewritten in the same commit (31 lines before it), so every `CLAUDE.md:`
number below — and in §7's row — is a pre-M0 one. What shipped is slightly *stronger* than
the wording proposed here: it bolds the `rm -f` step, says the edit **is** silently ignored
rather than "may be", and names the tell ("`mix compile` prints nothing and `mix test`
stays green"). The Key Files bullet was rewritten too, and gained rows for
`end_to_end_test.exs` and `PLAN.md`.

**Severity: medium.** CLAUDE.md's `mix compile` bullet said it "regenerates `.erl` from
`.xrl`/`.yrl`". It does not. Mix's leex/yecc compilers are mtime-gated at whole-second
granularity, and `git clone` writes the `.xrl` and the tracked `.erl` inside the same
second. On a fresh clone `mix compile` prints `Compiling 2 files (.erl)` — leex never
runs, `git status` stays clean, and the **committed** scanners are the build input.

Combined with the then-current Key Files bullet ("edit these, not the generated `.erl`
files"), the doc instructed a workflow that produced silently-dead commits. That bullet is
now reads "The generated `src/*.erl` are build artifacts, not
tracked; never edit them." The full loop, as reproduced before the fix:

```
$ sed -i 's/^NAME = .*/NAME = [a-zA-Z_][a-zA-Z0-9_]*/' src/ladder_lexer.xrl
$ git commit -am "fix NAME regex (edited .xrl only, per CLAUDE.md:14)"
$ git clone . ../clone2 && cd ../clone2
$ sed -n '5p' src/ladder_lexer.xrl
NAME = [a-zA-Z_][a-zA-Z0-9_]*            # the fix IS in the clone
$ mix compile
Compiling 2 files (.erl)                 # leex never runs
$ mix run -e 'IO.inspect Logex.Compiler.tokenize("ote a")'
{:error, {1, :ladder_lexer, {:illegal, 'a'}}, 1}   # …and has no effect
$ touch src/ladder_lexer.xrl && mix compile
Compiling 1 file (.xrl)
$ mix run -e 'IO.inspect Logex.Compiler.tokenize("ote a")'
{:ok, [{:name, 1, "ote"}, {:name, 1, "a"}], 1}
```

**Fix.** `git rm -f src/ladder_lexer.erl src/ladder_parser.erl` — note `-f`, **not**
`--cached`. `git rm --cached` leaves the files in the working tree, and mix then still
compiles them as `.erl` inputs; verified:

```
$ git rm --cached src/ladder_lexer.erl src/ladder_parser.erl
$ ls -1 src/*.erl
src/ladder_lexer.erl
src/ladder_parser.erl
$ mix compile
Compiling 2 files (.erl)     # leex still never runs
```

Then add `/src/*.erl` to `.gitignore`. An absent target regenerates, so this removes the
*fresh-clone* case — **but not the class.** leex and yecc write `src/*.erl` back into the
working tree, so from the first `mix compile` onward the whole-second gate is live again:
an `.xrl`/`.yrl` edit whose mtime lands in the same wall-clock second as the previously
generated `.erl` is silently skipped — `mix compile` prints nothing, `mix test` stays
green, and `git status` offers the dead edit for commit. Copying a built tree (`cp -r`)
reintroduces the same collision. The reliable edit loop for `src/*.xrl` / `src/*.yrl` is
therefore permanently:

```
rm -f src/*.erl && rm -rf _build && mix compile
```

Untracking also removes ~700 lines of cross-OTP churn: the
generated files embed absolute `/nix/store/…erlang-26.2.1/…` paths
(`src/ladder_lexer.erl:1`, `src/ladder_parser.erl:7`), so regenerating under a different
OTP produces a 699-line diff of pure prelude boilerplate.

**Tradeoff worth accepting.** Untracking makes the build depend on leex and yecc being
present, which they are not always: on Debian/Ubuntu they ship in `erlang-parsetools`,
a package separate from `erlang-base`.

```
$ dpkg -S $(erl -noshell -eval 'io:format("~s",[code:which(leex)]),halt().')
erlang-parsetools: /usr/lib/erlang/lib/parsetools-2.4.1/ebin/leex.beam
```

Today the tracked `.erl` masks that — a slim image with only `erlang-base` still builds.
Nix's `pkgs.erlang` bundles parsetools, so the dev shell is unaffected; the constraint
lands on whatever CI image M0/§4 introduces, which must install `erlang-parsetools` or
use a full Erlang image.

CLAUDE.md's `mix compile` bullet was then corrected to read (the landed wording is slightly stronger than
this draft):

> - `mix compile` — compile. leex/yecc regenerate `src/*.erl` from `.xrl`/`.yrl` only
>   when the `.erl` is absent or at least one whole second older. After editing a
>   `.xrl`/`.yrl`, run `rm -f src/*.erl && rm -rf _build` first, or your edit may be
>   silently ignored.

Done. The new-instruction recipe — CLAUDE.md's "New instructions, step 2" bullet — omitted that the de-energised `{false, env}` clause is **mandatory**;
following it literally yielded code that worked on an energised rung and raised
`FunctionClauseError` the moment a contact opened. It now states the mandate and names that
consequence. (§4's guard-clause collapse does not retire the underlying *code* trap: see
the Style bullet.)

### M0-4 · Fix the `NAME` regex — one line, two bugs

**Status: DONE — `3f3b104` (PR #3).** `src/ladder_lexer.xrl:5` now reads
`NAME = [a-zA-Z_][a-zA-Z0-9_]*`. The line number did *not* move, so the broken regex quoted
below is what line 5 used to say, not what it says now. Verified at the time:
`tokenize("ote a")` → `{:ok, [{:name, 1, "ote"}, {:name, 1, "a"}], 1}`. Since §6 the rule
is `Logex.Lexer`'s `is_name_start`/`is_name_char` guards and tokens carry a column; on
1.20.4, `{:ok, [{:name, {1, 1}, "ote"}, {:name, {1, 5}, "a"}], 1}`.

`3f3b104` shipped with no regression coverage — it touched `src/ladder_lexer.xrl` and
nothing else, and no test used a single-character tag or a bracketed name, so reverting the
regex in full left `mix test` green. Closed by `b8fc743`, which adds one test per bug in
`end_to_end_test.exs`, each failing only for its own half of the regex:

```
NAME = [a-zA-Z_][a-zA-Z0-9_]*   (as shipped)   0 failures
NAME = [a-zA-Z_][a-zA-Z0-9_]+   quantifier     1) single-character tag
NAME = [a-zA-Z_][a-zA-z0-9_]*   char class     1) brackets
NAME = [a-zA-Z_][a-zA-z0-9_]+   both           1) and 2)
```

**Severity: low** — the failure is loud and total, never a wrong answer; it is in M0
only because it is one character. `src/ladder_lexer.xrl:5` reads
`NAME = [a-zA-Z_][a-zA-z0-9_]+`.

- The `+` requires two characters, so single-letter tags — ordinary in ladder — are a
  hard lex error: `tokenize("ote a")` → `{:error, {1, :ladder_lexer, {:illegal, 'a'}}, 1}`.
- `a-zA-z` is a lowercase-`z` typo spanning ASCII 91–96, so ``[ \ ] ^ ` `` are legal
  inside identifiers. `ote a[3]` lexes as one name `"a[3]"` — it looks like array
  indexing works, but it is a weirdly-spelled scalar.

**Fix:** `NAME = [a-zA-Z_][a-zA-Z0-9_]*`. Keyword precedence was preserved — verified at
the time that `bst` still lexed as `{:bst,1}` while `bstx` lexed as a name. §4·B1 has since
made the delimiters punctuation, so there is no word keyword left to lose to `NAME`:
`tokenize("bst")` is now `{:ok, [{:name, {1, 1}, "bst"}], 1}` and the precedence question
is moot.

### M0-5 · Grammar: make newlines and empty branches derivable

**Status: DONE — `b65e756` (PR #4).** `src/ladder_parser.yrl:8` carries the empty-rung
filter and `:21` the `branch -> '$empty'` production; `ladder_lexer.xrl:10` and `:19` carry
`RND = (\r?\n)` and `({WHITESPACE}*{RND})+`. Two refs in the diagnosis are pre-M0 —
`rungs -> rung rnd rungs` is now `yrl:12` and `branch -> elems` is now `yrl:16`; both old
numbers are blank lines today. Since §6 the filter is `keep/2` in `Logex.Parser`, the empty
leg is `branch/2`'s last clause, and a newline run is `Logex.Lexer`'s two `?\n` clauses:
the second emits the `rnd`, the first swallows each newline after it.

This item originally opened by ordering M0-3 first and requiring
`rm -f src/*.erl && rm -rf _build` before every compile in M0-4 and M0-5. The sequencing is
spent, and so is the `rm -f` half. It outlived M0-3, which removed the fresh-clone case but
not the mtime gate, and lived in CLAUDE.md's `mix compile` bullet until the generated front
end went (§6). CONTRIBUTING's "The test output will lie to you" records what is left for
`.ex` files.

**Severity: medium.** `rungs -> rung rnd rungs` (`src/ladder_parser.yrl:9`) makes the
newline a mandatory *infix* separator, and `branch -> elems` (`:13`) via `elems -> elem`
requires every branch leg to be non-empty. Both are the same root cause: nothing can
derive empty.

```
"ote xx"            -> {:ok, …}
"ote xx\n"          -> {:error, {1, :ladder_parser, ['syntax error before: ', []]}}
"\note xx"          -> {:error, {1, …, ['syntax error before: ', 'rnd']}}
"ote xx\n\note yy"  -> {:error, {2, …, ['syntax error before: ', 'rnd']}}
""                  -> {:error, {999999, …}}
"bst xic aa nxb bnd ote xx"  -> {:error, {1, …, 'bnd'}}   # a plain jumper leg
```

One production plus one lexer rule fixes all six, with zero conflicts and no evaluator
change:

```diff
--- a/src/ladder_parser.yrl
+++ b/src/ladder_parser.yrl
@@ -5 +5 @@
-routine -> rungs : {routine, {rungs, '$1'}}.
+routine -> rungs : {routine, {rungs, [R || R = {rung, E} <- '$1', E =/= []]}}.
@@ -13 +13,2 @@
 branch -> elems : '$1'.
+branch -> '$empty' : [].

--- a/src/ladder_lexer.xrl
+++ b/src/ladder_lexer.xrl
@@ -10 +10 @@
-RND = (\n)
+RND = (\r?\n)
@@ -17 +17 @@
-{RND} : {token, {rnd, TokenLine}}.
+({WHITESPACE}*{RND})+ : {token, {rnd, TokenLine}}.
```

**Why the first hunk is not optional.** `rung -> branch` sits directly above
`branch -> '$empty'`, so allowing an empty branch leg also makes an empty *rung*
derivable. Without the filter, a leading or trailing newline materialises a phantom
`{rung, []}` — and a trailing newline is the most common shape a file on disk has:

```
"ote xx\n"             -> 2 rungs: [rung: [name: "ote", name: "xx"], rung: []]
"\note xx"             -> 2 rungs: [rung: [], rung: [name: "ote", name: "xx"]]
"ote xx\n\n\note yy\n" -> 3 rungs, the last empty
""                     -> 1 rung, empty
```

It is inert in today's `evaluate/2` (`{:rung, []}` folds to `{true, env}` unchanged),
which is exactly why it would go unnoticed — until M1-2's rung-scoped diagnostics and
M1-5's `%Logex.Program{rungs:}` start numbering rungs and every count is off by one. The
comprehension drops only top-level empty rungs; empty *branch legs* — the
`( xic aa | )` jumper — are untouched and still pass power. Equivalently the filter
can live in `instructionize/1`, which is more in keeping with §6's preference for a
newline-naive grammar; pick one. **Settled: the grammar.** The filter's boundary is
`E =/= []` on the *element* list, so `"( )"` survives as `{rung, [branches: [[]]]}` —
after this filter "empty rung" means *no tokens*, not *no effect*. Such a rung still
occupies a rung number, which is what M1-2's rung-scoped diagnostics and M1-5's
`%Logex.Program{rungs:}` will see.

The `RND = (\r?\n)` hunk is belt-and-braces: `\r` is already in `WHITESPACE`, so CRLF
lexed correctly before this change too. Keep it for explicitness, but the CRLF line in the
acceptance block below is earned by `branch -> '$empty'`, not by this hunk.

**Acceptance** — verified on a scratch copy. These transcripts predate §4·B1 and are left
verbatim, so their branches read `bst … nxb … bnd` where the language now writes
`( … | … )`; the same applies to the error block above.

```
$ erl -noshell -eval 'io:format("~p~n",[yecc:file("src/ladder_parser.yrl",[{report,true},{return,true}])]),halt().'
{ok,"…",[]}                    # empty warning list = zero conflicts
$ mix test
0 failures. The total is higher than M0-1's 5 — M0-2 added end_to_end_test.exs —
so read the failure count, not the total.

"ote xx\n"                 -> {:ok, %{"xx" => 1}}
"\note xx"                 -> {:ok, %{"xx" => 1}}
"ote xx\n\n\note yy\n"     -> {:ok, %{"xx" => 1, "yy" => 1}}
"ote xx\r\note yy\r\n"     -> {:ok, %{"xx" => 1, "yy" => 1}}
"bst xic aa nxb bnd ote xx" aa=0 -> %{"xx" => 1}    # jumper passes power
"xic aa bnd"               -> still correctly rejected

# rung counts — the env projection above cannot see these, so assert them too
"ote xx\n"  parses to {:routine, {:rungs, [rung: [name: "ote", name: "xx"]]}}   # 1, not 2
""          parses to {:routine, {:rungs, []}}
```

> **Trap.** The obvious alternative newline fix — adding `rungs -> rung rnd : ['$1'].`
> — is *individually* conflict-free but **conflicts with `branch -> '$empty'`**: yecc
> reports `0 shift/reduce, 1 reduce/reduce` and returns `{error, …}`, emitting **no
> parser at all**, so that variant does not build. After `rung rnd` at `$end` it cannot
> decide between a trailing separator and an empty final rung. Use the version above,
> which needs no trailing-separator production because the empty branch already covers it.

**With M0-1 … M0-5 landed, a green `mix test` means something:** every stage boundary is
exercised from source, and the three things §1 listed as broken — integer literals, sources
read from a file, single-character tags — all work, and all three are *guarded*: reverting
M0-1, M0-4's `NAME` regex, or M0-5's empty-rung filter each turns the suite red. That was
the *testability* gate, not the correctness gate. Three med-severity defects that produce
silently wrong answers survived all of M0 (§7): `xic`/`xio` non-complementarity (M1-4),
`nxb` fusion turning OR into AND on a missing space (§4·B1, **closed**), and the absence of
any validation (M1-2). M1-2 and M1-4 are the correctness gate.

---

## 3. Milestone 1 — a routine you can run

The ordering here matters: each item is cheaper now than after the one below it lands.

### M1-1 · Keep the token line in the AST

**Status: DONE — `a22bf39`, coverage completed in `1b1b1df`.** An elem is
`{kind, line, value}`. At `a22bf39` it was the token itself — the yecc `elem -> name` and
`elem -> int_lit` productions passed `'$1'` through and the `Erlang code.` block went.
Since §6 tokens carry `{line, column}`, and `Logex.Parser`'s `branch/2` builds the elem
with the line alone. The operand sites named below destructure the 3-tuple as
`{kind, _, value}`; since M1-2 they are the `evaluate/2` and `get_arg/2` heads, and the
lowering binds the line to cite it. The `{branches, legs}` node carries
no line of its own — the opening `(` token's line is dropped in the parser. Instruction
tuples were `{symbol, args}` until M1-2 widened them to `{symbol, line, operands}`.

Two sides to guard. The *producer* side — the parser keeping the right line — is held by
two tests in `lex_and_parse_test.exs` that assert lines other than 1: "lexes and parses
two rungs" (line 2, names and a literal) and "every elem carries the line it was read
from" (lines 1, 3, 6 across blank lines, indentation and a CRLF, with a branch group and a
bare elem sharing line 6). The *consumer* side — the ten `_` slots really being wildcards —
is held by "no stage depends on an instruction sitting on line 1" in `end_to_end_test.exs`
(every instruction, both power states, literal and tag operands, from line 3 down,
asserting values), with the per-stage fixtures on lines 4/9 and 2 so no constant satisfies
them. `a22bf39` landed with only the producer side; an adversarial review found eight of the
ten slots could be a literal `1` with the suite green, and `1b1b1df` closed that. Checked by
mutating, not by reasoning — fresh copy per row:

```
as shipped                                                    27 tests, 0 failures
elem -> name : setelement(2, '$1', 1).     shape kept, line 1  27 tests, 2 failures   the two producer tests
elem -> int_lit : setelement(2, '$1', 1).  shape kept, line 1  27 tests, 2 failures   the same two
elem -> name : {name, element(3, '$1')}.   line dropped        27 tests, 17 failures
branches legs rebuilt with every line 1    group only          27 tests, 1 failure    "every elem …" alone
instructionize/1 rewriting operand lines   lowering            27 tests, 1 failure    "instructionizes an AST" alone
instructionize/1 head: `_` -> 1            one slot            27 tests, 4 failures
evaluate/2 ote-false head: `_` -> 1        one slot            27 tests, 2 failures   "no stage depends …" + fixture
evaluate/2 otl-true head: `_` -> 1         one slot            27 tests, 2 failures
get_arg/2 int_lit clause: `_` -> 1         one slot            27 tests, 3 failures
get_arg/2 name clause: `_` -> 1            one slot            27 tests, 1 failure    "no stage depends …" alone
```

The "shape kept, line 1" rows are the ones that matter: with the shape right and every
line wrong, only the line-asserting tests fail. Without those tests every row but "line
dropped" would be green.

The diagnosis, as written before it landed:

`extract_token/1` (the `Erlang code.` block of `src/ladder_parser.yrl`) discarded the line. The lexer produces
correct `TokenLine` on every token; the parser throws it away, so the AST is
position-free and **no stage after parsing can cite a location**. Every error the
compiler will want to report — unknown mnemonic, bad arity, undefined tag, duplicate
coil — originates downstream of here.

Today this is four lines of Erlang in the parser, plus an AST elem shape change that
reaches ten pattern sites in `lib/logex/compiler.ex` — the `[{:name, name} | tail]` clause
of `instructionize/1`, the six `[name: arg]` `evaluate/2` clause heads, the
`{:mov, [arg1, {:name, arg2}]}` clause, and both `get_arg/2` clauses — plus the elem fixtures in the three per-stage
test files. `end_to_end_test.exs` asserts only on source, rung counts and env maps; its one
AST match is the `{:routine, {:rungs, _}}` wrapper, which the elem change does not touch. The
`compiler.ex` edits are mechanical one-liners but unavoidable: a 3-tuple elem stops being
a keyword pair. Do not reach for the pair-preserving alternative (`{name, {Line, Value}}`)
to dodge them — it compiles clean under `--warnings-as-errors` and then feeds a tuple to
`Map.get(@instructions, name)`.

After a validator, a formatter and a language server exist this touches all of them.
**Do this before M1-2, not after.**

### M1-2 · A validation pass

**Status: DONE — `e569113` (the validation pass) and the `mov` → `move` rename after it.**
`instructionize/1` returned `{:ok, ir}` or `{:error, diagnostics}`: every
`%Logex.Diagnostic{line:, message:}` in the routine, in source order. `@instructions` maps
each mnemonic to an operand signature (`"move" => {:move, [:value, :tag]}` then; M1-3 made
each operand `{access, type}`), and every case
in the table below is a located diagnostic, each pinned in `validation_test.exs`. The open
call at the end of this item was decided for the instruction tuple: it is
`{symbol, line, operands}` now, so a later pass can cite a line too. One decision was
added: **mnemonics are reserved words**, in any case (§5), which is what closes
`mov src ote`. Mnemonics are matched case-insensitively (§5). `%Program{}` stayed with
M1-5: `ir` is the same routine tuple as before. *(M1-3 brought `%Logex.Program{rungs:,
tags:}` forward: `instructionize/2` returns `{:ok, %Logex.Program{}}`, and since M1-5 its
`warnings:` too.)* What follows is the item as written.

`instructionize/1` validates nothing. `{symbol, args} = Map.get(@instructions, name)`
in the `[{:name, _, name} | tail]` clause of `instructionize/1` destructures `nil` for any
unrecognised name, and the `Enum.take(tail, args)` beside it truncates silently when operands run out:

```
"zzz aa"          -> MatchError: no match of right hand side value: nil  (no name, no line)
"XIC aa"          -> MatchError: …                       (case, same path)
"xic aa bb"       -> MatchError: …                       (extra *name* operand read as opcode)
"xic aa 7 ote bb" -> FunctionClauseError in instructionize/1   (extra *literal* operand)
"123 aa"          -> FunctionClauseError in instructionize/1   (literal in opcode position)
"ote"             -> {:ote, []} accepted, then FunctionClauseError in evaluate/2
"mov src ote"     -> no error at all: %{"ote" => 9}       (mnemonic eaten as an operand)
```

Every case but the last one raises. **The last is the worst, and it is not the
truncation case:** nothing was truncated — `Enum.take(tail, 2)` found exactly two tokens,
the second being the *next instruction's mnemonic*, so `mov` completed with `ote` as its
destination tag. A coil became a tag name, on an energised rung, with no exception and no
diagnostic. It needs neither a short operand list nor a de-energised rung, so it bites
where the reader is least likely to look.

The truncation case is the next worst: because several `evaluate/2` clauses use a
wildcard for `{false, env}`, a truncated instruction is *silently accepted* when power
flow is already false, and crashes only when a tag flips.

Both are the same root cause and the same fix — arity is a number in a map, consulted
after parsing, so the grammar cannot tell an operand from a mnemonic. Note that §4·B1
does **not** help here: it made the *delimiters* unfusable, and this is the same failure
shape one level down, on the operand list. The operand-signature table below is what
closes it.

Widen `@instructions` from an arity to an operand signature — `"mov" => {:mov, [:value, :tag]}`,
`"ote" => {:ote, [:tag]}` — and drive validation from the table rather than from
`evaluate/2`'s clause heads. Produce `{:ok, %Program{}} | {:error, [%Diagnostic{}]}`
rather than raising. Duplicate-coil and undefined-tag warnings belong here later.

**Two §5 decisions are scheduled into this item**, and they are cheaper together than
separately: the `mov` → `move` rename (so the unknown-mnemonic diagnostic can carry *"did
you mean `move`?"* rather than needing an alias) and the `String.downcase/1` that makes
mnemonics case-insensitive. See §5. The third, the `bst` → `( … | … )` migration hint,
shipped with B1 rather than waiting for this item: it is a guard clause on
`instructionize/1`'s name head that raises before `Map.get/2` can return `nil`, so it
names the word and its line. It should become a `%Diagnostic{}` like the rest when this
item lands.

The last two cases above never reach `@instructions` at all, so **a table-driven
validator alone does not cover them**. `instructionize/1` has list clauses for a
`{:branches, _}` head, a `{:name, _, _}` head and `[]`, and nothing
else — while the `elem -> int_lit` production makes a literal in opcode position
perfectly legal AST, so it falls off the end of the function before the table is
consulted. The pass also needs a catch-all clause over the element list reporting
`expected an instruction mnemonic, found <token>` for any head that is neither a name nor
a branch group.

**Open — decide it here, when a diagnostic first needs it.** Only operands carry a line.
The `{branches, legs}` node drops the opening `(` token's line in the parser, and
`instructionize/1` drops the mnemonic's own line when it builds `{symbol, args}`. So an
"unknown mnemonic" or "bad arity" diagnostic must take its line from the mnemonic's
`{:name, line, _}` *before* lowering, or the instruction tuple must grow a line. Widening
the branches node touches its two `{:branches, _}` clauses and the three per-stage
fixtures; widening the instruction tuple touches all ten operand sites. M1-1 left both as
they were on purpose rather than guess which M1-2 wants.

### M1-3 · A tag table with types

**Status: DONE — landed 2026-09-28**, in the six commits listed at the end of this item;
124 tests pass on Elixir 1.20.4, and the messages of steps (3) to (5) record their
mutation tables; (2) is a refactor with none. An adversarial review then added tests for
the mutants those tables missed, and fixed what it found; its commit follows (6). Where
the landing departs from the text below: the note for a program with no declaration line
reads "each is now declared before the first rung", naming no plan item; it is given only
when there is no declaration line at all, not when every declaration was wrong, and it
offers `bool` or `dint` rather than guessing; an undeclared tag cites its operand's own
line; and `%Logex.Tag{}` keeps `initial: nil` when none was declared, which
`Logex.Program.initial_env/1` reads as 0. Every recommendation of the design panel was
adopted, together with `docs/organisation.md` §6.1's four additions. A spike of this
design on a copy of `37b7932`, on Elixir 1.20.4 / OTP 28, passed 90 tests (76 migrated, 14
new) with the README output byte-identical; it is a receipt, not code in the repository.

The problem: no declarations, no BOOL/DINT distinction, no scope. That is what makes M1-4
possible and what makes a typo'd tag name a silent dead rung rather than a compile error.

**Where and how.** Declarations live in the `.ld` file, before the first rung, one per
line: `<section> <name> <type> [<initial>]`, with section `var`, `var_input` or
`var_output` and type `bool` or `dint`. They take IEC's words lowercased (naming rule 1;
each word gets its `docs/naming.md` stanza before its code). IEC's `VAR_INPUT start :
BOOL; END_VAR` loses its punctuation, as logex drops it elsewhere, and a keyword on every
line replaces the block, so there is no `end_var`. Blocks were rejected: they need
unclosed, nested and stray-block diagnostics and a recovery heuristic, and adding them
later would reserve `end_var`. The README program becomes:

```
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var fault bool

( xic start | xic motor ) xio stop ote motor
…
```

- **No grammar edit.** A declaration line parses as an ordinary rung: names, with an
  `int_lit` last when it has an initial value. A `Logex.Declarations` pass at the top of
  `instructionize/2` takes the leading lines whose first word is a section keyword; the
  lexer, parser, printer and golden record do not change. A declaration after the first
  rung is a diagnostic, but still declares its tag.
- **Section and type words are data tables,** so M2-4's `var_external` is one more row,
  and M1-6's `var t1 ton` and M2-5's `var s1 seal` resolve through the same type lookup:
  no second declaration parser. (A user function block's name is built per compile, not a
  row, so it is not reserved.)
- **Reserved in any case, in `.ld` files:** `var var_input var_output bool dint`. The commit
  that reserves them says so.
- **Strict.** Every tag a rung uses must be declared. An undeclared tag is a located
  diagnostic at its first use, with a did-you-mean; a program that declares nothing says
  once how to declare. Strict-only-when-declared was rejected: deleting the last
  declaration would silently bring the dead-rung defect back.
- **Types.** `bool` holds 0 or 1; `dint` is 32-bit (Ed 2 Table 10). The default initial
  value is 0 (Ed 2 Table 13). Other types, arrays and STRUCT wait, each an `unknown type`
  diagnostic. `var retain r bool` is a diagnostic until M1-5's `restart` gives a tag
  something to survive; `retain` itself stays unreserved. *(M1-5 landed `restart/3` and
  left `retain` out, for scope; the diagnostic now says a warm restart, like a cold one,
  starts every tag but the `var_input`s at its initial value.)*
- **Roles.** `var_input` is supplied from outside: logic may read it but not write it —
  IEC's own rule, *"Externally supplied, not modifiable within organization unit"* (Ed 2
  Table 16a) — and it takes no initial value. `var_output` is produced for the caller.
  `var` is internal. Binding any of them to physical I/O is the configuration's job, never
  the program's (`docs/organisation.md` §4.5).
- **Scope.** The file is the program's scope. There is no controller scope; sharing comes
  later through `var_global`/`var_external` (M2-4).
- **Typed operand signatures.** Each operand is `{access, type}`: `xic`/`xio`
  `{:read, :bool}`; `ote`/`otl`/`otu` `{:write, :bool}`; `move`
  `[{:value, :any}, {:write, :any}]`, whose two `:any` operands must agree, as IEC's MOVE is
  `IN : ANY` → `OUT : ANY` (`docs/naming.md`, Scalar move). M1-2's messages stay
  byte-identical.
- **Data.** `%Logex.Tag{name:, type:, section:, initial:, line:}`;
  `%Logex.Program{rungs:, tags:}` (M1-5 adds `name:`, `source:`, `warnings:`);
  `Logex.Program.initial_env/1` builds the first env from the declared initial values. The
  env stays `%{name => integer}` — a Milestone-1 fact, not an invariant: M1-6 nests timer
  instances in it, and no M1-3 check may depend on it being flat.
- **The Elixir-side declarer.** `instructionize(ast, declared)` takes `%Logex.Tag{}` values
  built with `Logex.Tag.new!/4`, validated by the same checks as a declaration line. It is
  the seam `docs/defladder.md` §11's M1-3 row asks for, and M1-5's `compile/2` does not
  expose it. defladder.md §15's decisions stay open; its decision 3 (head declarations in
  the DSL's output) stays B9's.
- **Deferred:** warnings (declared but unused, a `var_output` never written, duplicate
  coil) go to M1-5's `warnings:`; a declaration-inferring migration aid is not built.
  *(All three landed with M1-5, `a34fa87`.)*

**Diagnostics** (the spike's wording): `` `strat` is not declared — did you mean
`start`? `` · `` `xic` reads a bool, but `speed_sp` is a dint (declared on line 7) `` ·
`` `ote` writes `start`, a var_input (declared on line 1): logic must not write an
input `` · `` `move` takes operands of one type: … `` · a literal that does not fit its
destination · a keyword or type where a tag must go · on declaration lines: declared twice,
two names differing only in case (§5), a missing or unknown type, an initial value that
does not fit, an initial value on a `var_input`, a reserved word as a name, a declaration
after the first rung.

**Landed in commits, each green; (3) to (5) each with a test that fails when its change is
reverted:** (1) the `docs/naming.md` stanzas for the five words, `d818cd8`; (2) typed
operand signatures, no behaviour change — a refactor: the M1-2 messages stay
byte-identical and reverting it leaves the suite green, which its commit says rather than
inventing a failing test — `2a65aef`; (3) declaration lines and `%Logex.Program{}`, not
yet enforced, `5b63a9f`; (4) strictness — undeclared tags are errors — with the suite and
README migrated (35 of the 76 earlier tests went red without it), `efa1d13`; (5) type and
role checks on operands, `2b093de`; (6) documents, the commit after.

### M1-4 · Make `xic` and `xio` complementary by construction

**Status: DONE — landed 2026-09-28.** The strict half came with M1-3 (`2b093de`). The
`bit/2` half is the sketch below with one correction: `xic` reads `bit/2`, `xio` its
negation, and `get_arg/2` defaults a missing tag to 0, but `bit/2` reads a number by value
(`!= 0`) and a boolean as itself, with `nil` and a missing tag open. The sketch's
`not in [0, nil]` matched strictly, so `0.0` and `false` read *closed* — a regression for
`0.0`, which the old `== 0` read correctly, and a `false` from a host would have closed an
`xic`. `end_to_end_test.exs` pins complementarity for 0, 1, 5, -3, 0.0, -0.0, 2.5, `false`,
`true`, `nil` and a missing tag, and `move` from a missing tag (and, since M1-5's second
review, an atom and a string, which read closed). Reverting either contact, the
`get_arg/2` default, or `bit/2`'s treatment of floats, `false`, `nil` or a missing tag, or
`bit/2` becoming `== 1`, each turns it red. What follows is the item as written.

the `{:xic, _, [{:name, _, arg}]}` clause tests `== 1` and `{:xio, …}` tests `== 0` — two independent *positive*
tests, so any value outside `{0,1}` reads false for both:

```
tag=0     -> hi=0 lo=1     ok
tag=1     -> hi=1 lo=0     ok
tag=5     -> hi=0 lo=0     wrong: neither closed nor open
undefined -> hi=0 lo=0     wrong: (Map.get default nil)
```

A bit that answers false to both "is it set?" and "is it clear?" is unrepresentable on
real hardware — an interlock guarded by `xio` simply never fires, silently. This is
reachable from source **today** via an undefined tag, and becomes reachable via
`move 250 setpoint` (then `mov`) since M0-1 landed in `690fc2d`: it stores `250`, and then both
`xic setpoint` and `xio setpoint` read false.

```elixir
# Replaces the two {true, env} clauses of {:xic, …} and {:xio, …} ONLY. Keep their
# {false, env} clauses; deleting them makes any de-energised xic/xio raise
# FunctionClauseError while `mix test` stays green.
def evaluate({:xic, _, [{:name, _, a}]}, {true, env}), do: {bit(env, a), env}
def evaluate({:xio, _, [{:name, _, a}]}, {true, env}), do: {not bit(env, a), env}

# ...and these at the BOTTOM of the module, beside get_arg/2. A defp placed between the
# evaluate/2 clauses splits the clause group: Elixir warns "clauses with the same name
# and arity should be grouped together" and `mix compile --warnings-as-errors` exits 1.
defp bit(env, name), do: Map.get(env, name, 0) not in [0, nil]

# REPLACES the existing `defp get_arg(env, {:name, _, name})` clause — not an addition.
# Pasted as a second clause it compiles with warnings, leaves the old clause first,
# and `mix test` stays green because nothing covers `move` from an undefined tag.
defp get_arg(env, {:name, _, name}), do: Map.get(env, name, 0)
```

Verified with the above applied (after M1-1, against the 3-tuple elem):

```
t=0       xic=0  xio=1   ok        t=absent  xic=0  xio=1   ok
t=1       xic=1  xio=0   ok        t=nil     xic=0  xio=1   ok
t=5       xic=1  xio=0   ok        mov nosuch dst -> %{"dst" => 0}
```

Two things this block decides, neither obvious. **(a)** `Map.get/3`'s default only covers
an *absent* key, and absent is not the only way a non-bit reaches `env`: `get_arg/2`
(its `{:name, _, name}` clause) is a bare `Map.get/2`, so `move undefined_tag dst` stores `nil` today.
With a plain `!= 0` the sketch reads such a tag as a **closed** `xic` contact — trading a
contact that never closes for one that closes on a typo — so harden both sites together,
as above. **(b)** `not in [0, nil]` is nonzero-is-true, which is a *dialect choice*, not a
bug fix: every dialect surveyed takes a BOOL operand and rejects a numeric one at
verification. **§5 settles this:** keep the coercion as a totality guarantee so `xic`/`xio`
cannot disagree, and reject it as a *language* rule — once M1-3's tag table exists, a
non-BOOL operand becomes a located diagnostic rather than a silent coercion. The escape
hatch is bit addressing, `xic setpoint.3`.

**Landing order — §5 settles this, and it is narrower than it first reads.** Land the
`bit/2` half **now**: it makes `xic`/`xio` complementary by construction, which is a pure
improvement and needs nothing from M1-3. What waits for M1-3 is the *second* half — turning
a non-BOOL operand into a located diagnostic instead of a coercion — because the `0`
default is only safe once an undeclared tag is a compile error rather than a silent zero.
So: `bit/2` now, strictness after M1-3. (§5's M1-4 bullet says the same thing; if the two
ever disagree, §5 is the decision of record.)

**The strict half landed with M1-3** (`2b093de`): a `dint` on `xic`, `xio` or a coil is a
located diagnostic, and an undeclared tag, `move undefined_tag dst` included, can no longer
reach `env`. What was left of M1-4 was `bit/2`, for values the host supplies — an env built
by hand rather than by `Logex.Program.initial_env/1` can still hold a 5 or leave a tag out
— and that has landed too (status above).

### M1-5 · A real public API

**Status: DONE — landed 2026-09-29**, in the nine commits listed at the end of this item;
184 tests pass on Elixir 1.20.4 (6 of them doctests), and each commit's message records
its mutation table. Where the landing departs from the text below: B5 landed before the
documents, not after, so the documents could describe the finished surface once; a second
`ote` on the same rung is reported as "already has an `ote` in this rung" rather than
citing its own line; and the seeded property also requires every refusal's message to
begin with one of the pinned prefixes, so a crash with the wrong message cannot pass as a
refusal. A `scan/3` that accepted a negative `elapsed_ms` would be caught by
`runtime_test.exs` and not by the property alone: the property does pass one, but the
scan's own time check then refuses it with a documented message. A clock that goes
backwards in `call/4` is caught by both. The Milestone-1 done sentence is met, and
`test/logex_test.exs` runs it as written.

An adversarial review of the ten commits (six lenses, and a skeptic reproducing each
finding) confirmed 26 findings, 21 once the ones found twice are merged, and refuted 3.
Its fixes are the commit after the documents, and the suite is at 194 tests (6
doctests). One was a defect: the warnings walked every use for every tag, so compiling
was quadratic (16,000 tags took 7.5 s); a test now bounds the growth in reductions. One
was a false message: step 5 reworded M1-3's `retain` diagnostic to say a warm restart
starts *every* tag at its initial value, which `restart/3` contradicts for the
`var_input`s. Four were stale passages in these documents. The other fifteen were rules
no test failed without, each now pinned and checked by reverting it: among them series
AND after an open contact, the power each coil passes on (step 7 had dropped the one
assertion that guarded a de-energised `ote`'s), the state and program checks at every
entry point, and the edges of the name rule.

A second round (five lenses over the fixed code, a skeptic per finding) confirmed 27 findings,
23 once merged, and refuted 6; its fixes are the commit after `b8a9bd8`, and the suite is at
196 tests (6 doctests). One was a defect: `Logex.Declarations.validate!/1` let a tag
declared from Elixir carry a `line`, and the warnings then took it for one declared in
source; it now raises. Seven were rules no test failed without (among them a use in a
group nested in another group, "anything else is closed", the did-you-mean's 0.8 cut-off,
and how a file's name becomes the program's). Two were the property's own claims: it
checked that a refusal was documented but never that a mistake was refused or a good call
accepted, and it never reached a dint `var_input`, a bad state outside `call/4`, or two of
its nine refusal kinds. It now has that oracle and asserts its reach, and by itself catches
twelve rule-breaks the old one missed. Six were stale passages. Seven were practices, now
in `CONTRIBUTING.md`: among them the commit gate's `mix test --warnings-as-errors`, since
`mix compile` never sees a warning in a test file.

**Decided 2026-09-28, from `docs/organisation.md` §6.1** (its rationale is there):
1. `%Logex.Program{name:, tags:, rungs:, source:, warnings:}`, named and stateless. The name
   is the file's basename (`Logex.compile_file("motor.ld")`) or `compile(source, name:)`;
   a configuration refers to program types by it. `%Logex.Program{rungs:, tags:}` came
   forward with M1-3; M1-5 adds `name:`, `source:` and `warnings:`.
2. The core is the instance call, `Logex.Runtime.call(program, state, inputs, scan)`;
   `scan/2` and `scan/3` are sugar for one task-less instance. `scan/3` takes elapsed
   milliseconds, **not** "n scans" as written below. Unknown or non-input keys in
   `inputs` are errors.
3. `%Logex.Diagnostic{}` is widened once, with `file:`, `stage:` and `column:` together.
4. `Logex.Runtime.restart(program, state, :cold | :warm)` is the RETAIN hook.
5. The Milestone-1 done sentence below is amended accordingly.
6. B5 lands straight after: every recursive `evaluate` clause becomes a `defp`.

**Designed and decided 2026-09-29.** A design panel built three designs (the smallest
surface, one shaped for M1-6 and M2-1, one built around the error model and the host
contract), each spiked on a copy of `36fa3b5`; two judges scored them, a synthesis was
spiked as nine commits (188 tests on Elixir 1.20.4, every rule reverted and caught), and
two refuters checked it. The maintainer took every recommendation, including two where the
refuters overturned the synthesis (program names, and restart keeping the inputs). The
design:

- **Compiling.** `Logex.compile(source, name: name)` and `Logex.compile_file(path)` return
  `{:ok, %Logex.Program{}}` or `{:error, [%Logex.Diagnostic{}]}`. The name is required, so
  there is no `compile/1`, and there is no raising `compile!/1`. `compile_file/1` names the
  program after the file's basename and stamps `file:` on every diagnostic. `source:` holds
  the text. A lex or parse error is one diagnostic with its column; every later mistake is
  reported, in line order, with M1-2's and M1-3's messages unchanged.
  `Logex.Compiler.tokenize/1` and `parse/1` keep their own error shapes, for the golden
  record. *(Milestone 2's design, 2026-10-02: from M2-5, `compile/2` also takes `types:`,
  a function block's file compiles to `{:ok, %Logex.FbType{}}`, and `compile_file/1`
  loads the blocks a program names from beside its file; `docs/organisation.md`
  decision 34. Landed with M2-5, which also gave `%Logex.Program{}` a `file`, fix F15.)*
- **One diagnostic.** `%Logex.Diagnostic{stage:, line:, message:, file:, column:,
  severity:}`: `stage` is `:file | :lex | :parse | :validate`, and `severity` is `:error`
  or `:warning`. `severity` goes beyond the decided three fields on purpose, in the same one
  widening. `format/1` gives `motor.ld: line 3, column 5: message`, dropping what is nil,
  and puts `warning: ` before a warning's message.
- **File problems.** An unreadable file is a `:file` diagnostic, not a `File.Error`. A
  basename that is not shaped like a name (a letter or `_`, then letters, digits or `_`) is
  a `:file` diagnostic, and the source is still compiled. Names are checked for shape only:
  reserved words are scoped by file kind (`docs/organisation.md` decision 10), and a program
  type's name is never spelled in a `.ld` body, so the `.logex` words wait for M2-2.
  *(Landed with M2-2 and M2-3: they are reserved in a configuration file only, and
  `compile_file/1` now takes a `.ld` file only.)*
- **Warnings**, only when the program compiles, never for a tag declared from Elixir: a tag
  declared but used by no rung; a `var_output` no rung writes ("it stays at" its initial
  value); a second `ote` on one tag.
- **Running.** `Logex.Runtime.instance(program) :: %Logex.Instance{type:, env:, now:,
  first:}`, which holds no program; `call(program, state, inputs, %Logex.Scan{now:,
  first:}) :: {outputs, state}`; `put_inputs(program, state, inputs) :: state`, the checked
  way into the task-less sugar's input image; `scan(program, state, elapsed_ms \\ 0) ::
  {outputs, state}`; `restart(program, state, :cold | :warm) :: state`. `%Logex.Scan{}`
  lands now and is checked, and nothing reads it until M1-6.
- **The host contract.** A mistake in the source is a returned diagnostic; a mistake by
  the host raises `ArgumentError` (§4.6: "it is a host bug"), with every input problem in
  one raise and a did-you-mean. Only a declared `var_input` may be set, by its string name,
  with a value that fits its type exactly (a bool is 0 or 1, a dint 32 bits), and inputs
  merge into a persistent image. Outputs are every `var_output`. Time never goes backwards
  for an instance; `first` is per instance, and a `%Scan{}` that disagrees with it raises.
  A state is matched to its program by name, and its values are not checked each scan, so
  M1-4's totality stays reachable. A `%Program{}` or `%Instance{}` built by hand is outside
  the contract.
- **Restart** puts every tag but the `var_input`s back to its initial value, marks the next
  scan first, and keeps the clock. The `var_input`s are the host's input image: IEC leaves
  inputs *"initialized in an implementation-dependent manner"* (Ed 2 §2.4.2 rule 4, p.38),
  and keeping them is what makes `scan/2` agree with a one-instance configuration, whose
  copy-in refreshes them every scan (§4.6). `:warm` equals `:cold` until `retain` exists;
  `retain` does not land in M1-5, for scope — nothing needs it yet, and it owes a naming
  stanza (Ed 2 Table 33 f3a) first.
- **B5.** The evaluator moves into `Logex.Runtime`, private; `Logex.Compiler.evaluate/2`
  goes. The stage functions stay public. A test pins the exact public surface of `Logex`,
  `Logex.Runtime` and `Logex.Compiler`.

**Landing, in commits, each green and each with a test that fails when its change is
reverted:** (1) the diagnostic widening; (2) `Logex.compile*`, the named program and
`doctest Logex`; (3) the warnings; (4) `Logex.Runtime` with `Instance` and `Scan`; (5)
`restart/3`; (6) a seeded property over the host contract; (7) the suite run through the
public API rather than `evaluate/2` (test-only); (8) documents; (9) B5.

**Landed as:** (1) `6d57d19`; (2) `cb5049e`; (3) `a34fa87`; (4) `ee91fe5`; (5) `88ba3ab`;
(6) `02d555e`; (7) `72bee33`; (9) B5, `d0870b3`; (8) the documents, the commit after.

The item as written follows.

There is no `Logex` module at all: the `mix new` stub and its doctest were deleted
rather than left standing in for an API. So every consumer must know the stage order and
unwrap two different `:ok` tuple shapes. There is no `compile/1`, no scan loop, and nothing
representing "a compiled routine".

Two related shape problems:

- **`{power_flow, env}` leaked into the public signature.** It is exactly right as a
  *rung-internal* accumulator and exactly wrong as the shape a caller sees — the
  routine clause ignores the incoming boolean and hard-codes `{true, new_env}`
  (the `{:routine, {:rungs, rungs}}` clause of `evaluate/2`), so callers pass a meaningless
  `true` and discard a constant.
- **There is no compiled-program value.** The closest thing is a raw
  `{:routine, {:rungs, …}}` tuple with no identity, no tag table, no source reference,
  and no way to distinguish it from an un-instructionized AST. `%Logex.Program{rungs:,
  tags:, source:, warnings:}` is ~20 lines now; later it is a change to every
  consumer's pattern match.

Target surface: `Logex.compile/1`, `Logex.Runtime.scan(program, env) :: env`,
`Logex.Runtime.scan/3` for n scans. Keep `evaluate/2` internal at
`{power_flow, env} -> {power_flow, env}`, and make the seal-in circuit the README
example.

*Since the hand-written front end (§6): `Logex.Lexer` and `Logex.Parser` return the same
two shapes, now with `{line, column}` locations and Elixir binaries rather than charlists,
and each has a tested `format_error/1` — an unclosed group is reported at the innermost
`(` still open, and an unexpected token names what was expected. Nothing outside the tests
calls them yet; the single `%Logex.Error{}` below is still this item's to design, and can
now carry a column. M1-2 added `%Logex.Diagnostic{line:, message:}` for lowering: make that
the one error type, widened with a stage and a column, rather than add a second. The
`%Logex.Program{rungs:, tags:}` below came forward with M1-3, and `instructionize/2`
returns it; naming it, and `source:` and `warnings:`, are still this item's.* As first written: normalise errors while here: `tokenize/1` returns
leex's 3-tuple, `parse/1` yecc's 2-tuple, `instructionize/1` a bare value that raises. Raw Erlang charlists leak, and
`format_error/1` is exported by both generated modules and called by neither — the
lexer's is genuinely useful (`{:illegal, ~c"@"}` → `illegal characters "@"`). Empty input
reported yecc's internal sentinel as a line number (`{:error, {999999, …}}`) *until M0-5*:
that sentinel is emitted from exactly one site in the generated parser, reachable only
from an empty token list, and M0-5 — landed in `b65e756` — made the empty program a legal
parse: `parse([])` now returns `{:ok, {:routine, {:rungs, []}}}`. So by the time
M1-5 lands there is no empty-token special case to write. One
`%Logex.Error{stage:, line:, message:}`, and nothing more.

The repository has no doctest since the stub was deleted, and no `test/logex_test.exs`.
Put the seal-in example in an `@doc` on `Logex.compile/1` and restore that file as
`doctest Logex` — the example is then executable documentation rather than prose the README
can silently outlive.

### M1-6 · TON and ONS

**Status: DONE — landed 2026-09-30**, as the eight commits of the landing order below: (1)
the naming stanzas, `a64e42f`; (2) `evaluate/3`, `cd83e71`; (3) `ons`, `6775890`; (4) the
comparisons, `d73886d`; (5) `var t1 ton` and members, `260a02d`; (6) `ton`, `8d6ea80`; (7)
the host-contract property, `615d5ea`; (8) the documents, the commit after it. 307 tests
pass on Elixir 1.20.4 (6 of them doctests), up from 214. The messages of (3) to (6) record
their mutation tables, every rule reverted alone and the full suite judged by exit code,
each red; (7) records its `lib/` mutants against the property alone; (1), (2) and (8) are
documents and a refactor. The maintainer's five changes to the synthesis landed in the
commits the design below names, each with a test that fails when it is reverted: a second
`ons` in (3); `last`, a negative `.acc` and nothing after a `ton` in (6); decision 6 per
rising edge in (6), with a test of a timer that re-triggers itself. So did the second
refuter's fixes: every malformed schema or initial value raises `ArgumentError` from
`Logex.Tag.new!/4` and `split/2` ((5) and (6)); a `ton` or two compared literals in a group
nested in another is found ((4), (6)); a `ton` with a wrong preset, or none, still counts,
so a second `ton` is reported too, and one on a declared tag that is not a timer runs
nothing; `var_input ton` is told a ton is declared with `var`; a dotted input key is called
a member only when it is one; and a timer declared from Elixir starts at a `.pre` of 0 to
2147483647 ms, what the preset slot takes. *(Withdrawn by OE-1 on 2026-10-01:
`Logex.Tag.new!/4` no longer takes a timer's `%{"pre" => ms}`, nor any initial value on an
instance, which gets the message a declaration line does. A `ton` silently replaced the
map, and with none no text could give that `.pre`; `docs/organisation.md` §7, decision 24.)*
No departure from the design. Beyond its text: an
element after a `ton` is reported once, at its own line, citing the first `ton` on its path,
and a group after one as "a branch group"; an `ons` on anything but a declared bool, like a
`ton` on anything but a declared timer, is left to the diagnostic it already has. Measured
at the landing: compiling 4x the tags takes 4.2x the reductions, and a scan of the README
motor 280.9 reductions against 265.7 at `19868d4`, the 5.7% the design records.

An adversarial review of the eight commits (five lenses, and a skeptic reproducing each
finding) confirmed 22 findings, 19 once the ones found twice are merged, and refuted 5.
Its fixes are the commit after the documents, and the suite is at 317 tests (6
doctests). Two were defects. The path pass copied what it had found in a group at every
level of nesting, so a rung 8,000 groups deep with a `ton` innermost took 205 million
reductions and 2.9 s; it, and the instruction and warning walks, which copied in the same
way, now gather newest first and reverse once, and a second growth test bounds compiling
in depth as the first does in size. And a timer line broken after its type word, `var
t1 ton 5 6`, declared nothing, against the design's "a misdeclared timer is still
declared"; it is now declared, and its uses are not reported as undeclared. Five were
misleading messages: the `move` a tag preset is told to write and the `xic t1.dn` a path
error names are given only where they would compile; a timer first met in a program that
declares nothing is shown `var t1 ton`, not `bool` or `dint`; `ton.dn` is a member of an
instruction, not an undeclared name; `t1.acc.3` is bit access, not a path too deep; and a
starting `pre` out of range from Elixir is told the range, which -5, a dint, is not (a
message withdrawn with the map, above). Five
were rules no test failed without: which `ton` a group with two cites, a bool member's
too-deep message, the preset range's upper end, the section check on a timer from
Elixir, and that a `last` which is not an integer adds nothing. One was the property's
claim: operation 6's `scan/2` skipped the oracle, which now checks all 245 accepted scans
of a timed program at the seed, not 233 (490 oracle runs, not 466, since each accepted
call is made twice). Six were stale passages: `Logex.Tag.new!/4`'s
doc, CLAUDE.md's rule for a type word, instruction-sets.md's "flat env", defladder.md's
`bit/2`, and two things the contract did not say about a state kept across a recompile
of the same name, now in `Logex.Runtime`'s moduledoc and organisation.md's online-edit
row, with a test of the second: a tag whose type the recompile changes keeps its old
value, a timer's map reaching the outputs; and a tag it adds reads 0 until a restart, so
an added timer starts at a `.pre` of 0 and is done at its first true scan.

A second round (four lenses over those fixes, among them a comparison of both compilers'
output on generated programs, and a skeptic per finding) confirmed 18 findings, 14 once
merged, and refuted 2. Its fixes are the commit after `77d1b01`, and the suite is at 320
tests (6 doctests). Six were messages: the hints still named a `move` or an `xic t1.dn`
that never compiles where the timer and the preset are one name (`ton b b`) or where a
name differs from a declared tag only in case; a timer first used as a member or as a
bool, and run by a `ton`, was not shown `var t1 ton`; `bool.3` was called a member, and
is now, like `ton.dn`, a name that "begins with `bool`, a type, which cannot name a tag";
`t1.acc.3.x` had become bit access, and goes too deep again; and a bool's bit, `a.0` or
`t1.dn.0`, was told bit access is "not supported yet", where a bool has no bits. One was
the contract: `restart/3` kept a var_input whose type a recompile had changed, against
the new sentence that a restart puts a kept state right; it keeps only the var_inputs
whose values fit their types now. Four were rules no test failed without: the salvaged
timer's line and its name check, the order of path errors across legs and nested groups,
and the walk that finds the first rung's line for a declaration after it, which the depth
test's programs never reached. Finding that line once, not once per late declaration,
also removes an older quadratic cost, from M1-3. Three were documents: the growth
figures, the 490 above, which counted each accepted call twice, and instruction-sets.md's
"flat-env" heading. The depth test now takes the least of three counts and a bound of
18.5, where the fixed compile measures about 16x and the copying walks 20x or more
(`2c8cfea`'s message says 15.7x and 21x to 29x, which the third round below corrects):
one refuted finding reported a single run of the earlier test at 18.0x, which 582 runs
could not reproduce.

A third round (three lenses over `2c8cfea`, a skeptic per finding) confirmed 9 findings,
6 once merged, and refuted 3. Its fixes are the commit after `2c8cfea`; the suite stays
at 320 tests. One was a regression: the twin check walked the whole tag table on each
lookup miss, so many hints after one undeclared timer compiled quadratically (8,000 of
them beside 8,000 tags took 24 s). The declared names are indexed by their lowercase form once per
compile now, and the size test's program runs a timer no line declares, so it reaches
that lookup. Two were messages: `ton b B` still hinted `move B b.pre`, where two names
that differ only in case cannot both be declared; and `d.3.x` on a plain tag was still
bit access, and goes too deep now, as `t1.acc.3.x` does. One was a message the restart
change made stale, the `retain` diagnostic's "starts every tag but the var_inputs". One
was a rule no test failed without: a twin declared in capitals and used in lowercase.
And the growth figures, which the test itself does not give as quoted: reductions count
garbage collection, so a mutant's ratio moves from run to run, and CONTRIBUTING now says
to quote the fixed compile's figure and the lowest mutant's.

A fourth round (two lenses over `2afed5a`, a skeptic per finding) confirmed 3 findings and
refuted none, all about that commit's own figures and claims; the code was left as it was.
Its message gives the fixed compile 15.5x and D2b, the compiler's two copying walks as at
`b30ab18`, 29x "as the test itself runs them": the committed test gives 16.1x, and D2b 50x
to 61x. Both wrong figures came from a copy of the test that also
timed 2,000 levels after 8,000, which moved the garbage collection the counts include;
CONTRIBUTING now records that. And its row Q1 says both growth tests catch the walk on
each miss, but the Q1 mutant walked the table on every lookup, hits included: reverted
faithfully, as a walk on a miss only, the walk is caught by the size test alone, since the
depth test's timer is declared and its hints never miss.

**Decided 2026-09-28, from `docs/organisation.md` §6.1 and §4.6:**
1. `evaluate/3` threads a read-only `%Logex.Scan{now:, first:}`; the accumulator stays
   `{power_flow, env}`. CLAUDE.md's `evaluate/2` convention changes with it. *(Since M1-5
   the `%Scan{}` exists and `Logex.Runtime.call/4` checks and receives it; the evaluator
   is `Logex.Runtime`'s, private, so `evaluate/3` is a change inside that module.)*
2. Timers are declared instances, `var t1 ton`; an undeclared one gets M1-3's diagnostic.
3. Instance state nests: a per-instance record with a schema per FB type
   (`%Logex.FbType{}`), which M2-5's user function blocks reuse. `ons` reads
   `scan.first`.
4. Members are readable anywhere; logic may write only `.pre` and `.acc`. A dotted name
   that is not a declared member is a diagnostic.
5. A timer adds `now − last_scanned` to `.acc`, keeping its last-scanned time as an
   internal member (the delta formula `docs/naming.md` Timers settles), not a per-instance
   `dt`, so a timer in a frozen function block catches up.
6. Before calling the model settled, spike a real `ton`: one program type, two instances
   on 10 ms and 50 ms tasks, and an assertion that `.acc` reaches the preset at the same
   logical time in both.
7. The settled `.` and `//` lexer rules land exactly as written: `a.1b` is a lex error,
   `ote a // note⏎ote b` is two rungs, and the golden record changes in exactly two
   entries. B8 is fixed before any configuration file exists. *(All three landed
   2026-09-30. The golden record changed in exactly those two entries for the two rules,
   and in the 165 entries B8 predicted.)*

**Designed and decided 2026-09-30.** A design panel built three designs (the conventional
reading, one shaped for Milestone 2, one built around the error model and the host
contract), each spiked on a copy of `da2159b`; two judges scored them, and a synthesis
took the contract design's semantics and error model, the Milestone-2 design's data model,
and the conventional design's decision-6 test, and was spiked as eight commits (290 tests
on Elixir 1.20.4, 128 rules each reverted and caught). Two refuters checked it. The
maintainer took every recommendation, including five where the refuters changed the
synthesis (a second `ons`, `last`, what follows a `ton`, decision 6's wording, and a
negative `.acc`). The design:

- **Surface.** Eight mnemonics, reserved in any case: `ons`, `eq ne lt gt le ge`, `ton`
  (a program with a tag of any of those names stops compiling). `ton` is a type word too.
  No syntax change: `t1.dn` has lexed as one name since `46f17f0`.
- **`evaluate/3`** threads the checked `%Scan{}`, read-only, to every instruction; only
  `ons` reads `first` and only `ton` reads `now`.
- **`ons s1`**, `[{:write, :bool}]`: power on the one scan in which the power reaching it
  rises, never on an instance's first scan (it reads `scan.first`, which stands for the
  conventional prescan). `s1` is an ordinary `var` or `var_output` bool. A second `ons` on
  one storage bit is an error at its line, citing the first: the false one clears the bit
  every scan, so the true one fires every scan, and no arrangement of two works. Another
  writer (`ote`, `otl`, `otu`, `move`) is a warning citing the `ons`, since a deliberate
  re-arm cannot be told from a mistake; the second-`ote` warning skips a storage bit.
- **Comparisons**, `[{:value, :dint}, {:value, :dint}]`: dint tags, members or literals
  that fit 32 bits, `lt a b` meaning a < b. They are input instructions and pass no power
  de-energised; `ne ge le` are the negations of `eq lt gt`, so each pair is complementary.
  Two literals compile, with a warning that the result never changes.
- **Timers.** `var t1 ton`, in `var` only, with no initial value; a misdeclared timer is
  still declared, so its uses do not cascade. `%Logex.FbType{}` is the schema, carried
  inline as the tag's type, with members that have a role and a write flag; M2-5 reuses
  it. State nests: `env["t1"]` is `%{"pre", "acc", "dn", "tt", "en", "last"}`, every key a
  string. `last` is internal: no name reaches it, and it is the time of the timer's last
  run, as decision 5 has it.
- **Members** are typed by the schema (`.pre .acc` dint, `.dn .tt .en` bool, all
  case-sensitive), read anywhere, written only to `.pre` and `.acc`, and lowered to
  `{:member, line, path}` in the IR, so the runtime never splits a name. Every other
  dotted name is a located diagnostic of its own: an unknown member (a did-you-mean on the
  member's name, else the member list), a member of a non-instance, bit access (`word.3`,
  not supported yet), a path too deep, an undeclared instance (named once), and an
  instance named whole where a value belongs.
- **`ton t1 5000`**, `[{:instance, "ton"}, {:preset, :dint}]`. The preset is a literal of 0
  to 2147483647 ms and the timer's starting `.pre`: the compiled tag carries it, and
  `instance/1` and `restart/3` restore it. The instruction never writes `.pre`, so a
  `move` into it holds. One `ton` runs a timer; a second is an error. Energised, `.en` is 1
  and `.acc` gains `now − last` if `.en` was already 1, nothing on the first true scan;
  `.acc` is floored at 0 before the time is added and capped at `max(.pre, 0)`; `.dn` is
  `.acc` at the cap, recomputed each true scan, so a raised `.pre` resumes timing; `.tt`
  is `1 − .dn`. De-energised, `.acc .dn .tt .en` are 0. `last` is set to `now` on every
  run. **Nothing may follow a `ton` on its path** (in its leg, or after a group one of whose
  legs ends in it): whether the power after a `ton` is the rung's, as after `ote`, or the
  timer's `.dn`, IEC's Q, is left open, and refusing is the reversible way to leave it.
  A timer no `ton` runs is a warning.
- **The host contract** is M1-5's, unchanged: a member as an input key is refused with its
  own `input …` message, values are not checked each scan, and the evaluator is total on a
  hand-built env, a timer entry of any shape included.
- **Decision 6, measured.** One program type, two instances stepped through `call/4` every
  10 ms and every 50 ms, `go` rising at 1000 ms with a 5000 ms preset: both are done at
  6000 ms and agree at every time both scan. The equality holds per rising edge, when both
  instances see that edge at one time and the preset is a multiple of both periods (a
  1030 ms preset is done at 1030 ms and 1050 ms). A timer that re-triggers itself repeats
  every preset plus two task periods, as MatIEC's TON does, so its period differs at 10 and
  50 ms.
- **Known costs, recorded.** After `move 3000 t1.pre` the rung still reads 5000 until a
  restart. An instance kept running under a recompiled program of the same name keeps its
  old `.pre` until a restart, which organisation.md's online-edit row must answer when that
  lands. A scan costs about 5.7% more reductions, nearly all of it `evaluate/3`'s threading.
  *(The review above found two more for that row: a tag the recompile adds, or whose type
  it changes. OE-1 answers all three, 2026-10-01: `Logex.Edit` moves `.pre` where it still
  holds the old preset, starts what is added, and refuses a type change, and a plain swap
  still does what is recorded here.)*

**Landing, in commits, each green and each with a test that fails when its change is
reverted:** (1) the eight naming stanzas; (2) `evaluate/3`, a refactor; (3) `ons`; (4) the
comparisons; (5) `var t1 ton` and members; (6) `ton`; (7) the host-contract property over
all of it; (8) the documents. A new backlog item, B10, records that
`Logex.Warnings.second_otes/2` orders warnings that share a line by a map, never by rung.

The item as written follows.

Both need per-instance cross-scan state, so they are the proof that M1-5's architecture
is right. TON is what turns this from an expression evaluator into something
recognisable as a PLC: it needs a per-instance struct (`.PRE/.ACC/.DN/.TT/.EN`)
persisting across scans plus an elapsed-time source. Comparisons (`eq ne lt gt le ge`,
per `docs/naming.md`) ride along in the same pass for nearly free — they are pure input instructions
with exactly the existing rung-condition contract.

**§5 has settled the addressing question:** member access is `.`, added as one lexer rule
producing a single `name` token, with no grammar edit — so `t1.dn` and `t1.acc` lex, and
`env` holds a per-instance record rather than flat `"t1.dn"` keys, because `.acc`
and `.dn` must update together in one scan. That work is a prerequisite for this item, not
a follow-up. Take the elapsed time as an *injected scan input* rather than an internal
clock read, or the runtime stops being deterministic and testable. **ONS** is the smaller
half and worth doing first: it needs one bit of cross-scan state and no time source at
all, which makes it the cheapest possible proof of the per-instance state design.

Note there is currently no scan loop at all: `evaluate/2` runs exactly one pass, with no
repeat, no scan counter, no first-scan bit, and no separation of input image from output
image — so nothing marks which tags are physical inputs that logic must not write. The
semantics are correct; only the driver is missing, and it is roughly an `Enum.reduce`.
*(Since M1-3 a `var_input` is declared and logic may not write it; since M1-5 an instance
carries its clock and first-scan bit, and `put_inputs/3` keeps the input image apart from
the `var_output`s a scan returns. There is still no loop: the host calls each scan, and
scheduling is Milestone 2's.)*

**Milestone 1 is done when a seal-in circuit written in a `.ld` file on disk can be
compiled once into a named, stateless value you can hold, run for N scans as an instance
against a typed tag table, and report a located diagnostic — ``seal.ld: line 3: unknown
instruction `xyz` `` — instead of raising.** (Amended 2026-09-28 per M1-5, and its example
2026-09-29 to the message `Logex.compile_file/1` really gives.) **Met with M1-5:**
`test/logex_test.exs` compiles `seal.ld` from disk, runs it for four scans as an
instance, and asserts that message for a broken file, which `format/1` prefixes with the
path as it was given. That single sentence
exercises M1-1 through M1-5; M1-6 is what proves the design was right rather than merely
plausible. *(M1-6 landed 2026-09-30: decision 6's two-rate test is its proof.)*

### Milestone 2 — program organisation

**Decided 2026-09-28** (§5; design and rationale in `docs/organisation.md`, whose §7
decisions were all taken as recommended). *(Its §7 has since gained decisions 15–29, on
online edit, taken on 2026-10-01: 18, 28 and 29 depart from their recommendations and 19
had none; see "Online edit — decided 2026-10-01".)* Each item surveys its new words in
`docs/naming.md` first, lands green, and pins every rule with a test that fails when the
rule is reverted. M2-5 needs only M1-6 and B5, so it may move ahead of M2-1. *(Ordered
2026-10-02 by decision 30, below: M2-5 lands after M2-1.)*

**Designed 2026-10-02** (`docs/organisation.md` §4.10, "Milestone 2's design", and its §7
decisions 30–40; "decision N" in this section is that §7's). A design pass spiked
Milestone 2 in three tracks on copies of `47319f7`: the scheduler (M2-1); user function
blocks (M2-5); and the configuration file, shared globals and event tasks (M2-2, M2-3,
M2-4, M2-6). Each track was reviewed for correctness and for fit, then revised, and each
reverted every rule it adds alone under its full suite: 113 rules in the scheduler's
spike, 88 in the function blocks' and 127 in the configuration file's, every one red but
one (owed below). The scheduler's and the function blocks' spikes, merged, pass together:
582 tests on Elixir 1.20.4. The maintainer took decisions 30–40 as recommended but 35,
the configuration file's extension, choosing `.logex`, outside the options offered; the
pass's routine choices, the rules of §4.10, were all taken as recommended. M2-1 landed
on 2026-10-02, M2-5 on 2026-10-04, M2-2 and M2-3 on 2026-10-11, and M2-4 and M2-6 on
2026-10-12 (below), which completes Milestone 2.

**The order (decision 30):** the design record, then M2-1, M2-5, M2-2, M2-3, M2-4 and
M2-6.
- **M2-1 first**, decision 1's default. M2-5's Done-when then stands as written: its
  `m1.s2.run` is read through M2-1's `get/2`.
- **M2-5 before M2-2,** so the configuration file's reader, its loader and the IR walk
  are written against `cal` from their first commit. In the other order a hand merge of
  the spikes failed at four seams: a walk of a program's writes that raised on `cal`, a
  loader that put a function block type among the programs, a block's `var_external` that
  raised `FunctionClauseError`, and two loaders.
- **Then the text items in turn:** M2-3's task lines build on M2-2's reader, M2-4's checks
  on the IR walk that is its first commit, and M2-6's event tasks on M2-3's task lines.
  The walk lands before the first check that reads a program's writes or timers.

Each commit lands green under the full gate, with its mutation rows in its message, every
rule it adds reverted alone. M2-1's and M2-5's commits were built as gated series; the
configuration file's must be built that way before they land.

- **M2-1 · The scheduler, from Elixir data, no syntax.** `%Logex.Configuration{}`,
  `Logex.Runtime.start/cycle/next_due_in/get`, periodic and task-less instances,
  copy-in/copy-out, overlap events. *Done when* a configuration built in Elixir with a 10
  ms task, a 30 ms task and a task-less instance, cycled every 10 ms from 0 to 990 ms by an
  injected clock, runs each instance exactly as often as its task dictates, in priority
  order; a late cycle yields one `{:overlap, …}` and no lost phase; the README program
  gives identical outputs through `scan/2` and through a one-instance configuration.
  *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "cycled for one
  simulated second", which did not say how the clock is stepped. The counts are 100, 34
  and 100 runs.)*
  *(Online edit, 2026-10-01: M2-1 also keeps `docs/organisation.md` §4.9's constraints,
  so OE-2 needs no rework: the runtime value holds plain data only; state is keyed by name,
  program instances are held flat and never nested under a task, and execution order is a
  list; each item's rule for a new piece
  of state serves both `start/1` and an edit that adds one, with the edit's exceptions
  listed; one checked constructor, which M2-2's parser feeds; an opaque
  `%Logex.Runtime{}`; one copy of each global; and an open set of events. OE-1's design
  adds one: `start/1` builds each instance through the same constructor as
  `Runtime.instance/1`, so an instance's `first`, its one-shot block list and any field it
  gains later cannot drift between the two.)*

  *Designed 2026-10-02* (`docs/organisation.md` §4.10, M2-1). The scope widens twice,
  each annotated where it was decided: every `docs/organisation.md` §4.4 check that M2-1's
  data can express, over tasks, globals, located points, instances and connections, lands
  here in `Logex.Configuration.check/1`, pinned from data, where M2-2 had them; and
  `restart/2` and `overlaps/1` join §4.6's API (decision 38). A host mistake no text can
  say raises `ArgumentError` (decision 36), and a priority is 0 to 65535 (decision 37).
  `CLAUDE.md`'s rule for new state extends to `%Logex.Runtime{}`. A configured plant is
  not edited until OE-2: `Logex.Edit` edits a lone instance, and `%Logex.Runtime{}`
  changes only through the API. It lands as:
  1. `Logex.Configuration` and the `:configure` stage: the element structs, `check/1`,
     `new!/1`, `location/1` and `initial/1`;
  2. the resource with periodic tasks: `%Logex.Runtime{}`, `start/1`, `cycle/3`,
     `next_due_in/1`, `overlaps/1` and `get/2`;
  3. `restart/2`;
  4. the contract walk over a configuration, in `api_contract_test.exs`;
  5. the Done-when end to end, with the walks of the README's examples;
  6. the documents, among them the README's "Changing a running program", which says that
     a configured plant is not edited until OE-2.

  The first five are built as a gated series on copies of `47319f7`: 466, 504, 509, 510
  and 514 tests, from 430, each commit's rules red in its own tree. The second's prose
  names `restart/2` early and is trimmed when it lands.

  **Status: DONE — landed 2026-10-02**, as the six commits of its landing order: (1)
  `Logex.Configuration` and the `:configure` stage, `44bb4dd`; (2) the resource with
  periodic tasks, `5a7db68`; (3) `restart/2`, `0216b96`; (4) the contract walk over a
  configuration, `31bbf6a`; (5) the Done-when end to end, `cedfdb3`; (6) the documents,
  the commit after it, among them the README's "A configuration", whose output is a real
  run, and its "Changing a running program", which says that a configured plant is not
  edited until OE-2: `Logex.Edit` edits a lone instance, and `%Logex.Runtime{}` changes
  only through its API. 522 tests pass on Elixir 1.20.4 (8 of them doctests), up from
  430. The messages of (1) to (3) record their mutation tables, every rule each adds
  reverted alone in its own tree and the full suite judged by exit code: 148 rules (89,
  52 and 7), every one red. (4) and (5) add no rule; each reverted the 65 rules of (1) to
  (3) a configuration runs on in its own tree, every one red, the walk failing 50 of them
  and the Done-when 19. The walk passed with its full reach under seeds 1 to 30 besides
  its own. (1) applies what the spike did not follow: decision 36, `check/1` raising one
  `ArgumentError` with every host mistake, a line each, the line between a host's mistake
  and a diagnostic drawn by what a configuration's text can hold, its message deciding
  each of the spike's messages by it; decision 37's bound; and the record's rule on
  lines. Two words differ from the spike besides: an instance named whole is "a program
  instance of `motor`", and a negative initial value is refused for a bool as for a dint.
  Every growth bound was read over 32 runs; the cycle at 16x the instances now has 20.5,
  where the spike's 19.5 sat less than a fifth above the measured top.

  A review of the six commits (three lenses, correctness, fit and tests, and a skeptic
  reproducing each finding) confirmed 22 findings, 20 once the two found twice are
  merged. Their fixes are the commit after (6), and the suite is at 527 tests (8
  doctests). Three were in `lib/`'s behaviour. `check/1` checked no other field of an
  element whose name it refused, a duplicate, a case twin or a name with `.` parts, where
  a `.ld` declaration line checks them; it now checks every field of such an element and
  refuses only its name. A configuration or an element that lacked one of its struct's
  keys escaped `check/1`, `new!/1` and `start/1` as a `KeyError` or a
  `FunctionClauseError`; it is now the host's mistake, as any value that is not the
  struct is (decision 36). And `get/2` told a path to an internal member, `m1.t1.last`,
  that it was no member, where §4.10 says such a path is told what it names; it is now
  told the member is internal. One was words: three new messages put "a" before a
  program's name, "`m1` is a `outer`", the form the Owed list below calls a defect; they
  say "a program instance of `outer`". Ten were rules no test failed without, each now
  with one: `cycle/3` refusing a struct as its inputs, and its key order past 32 keys;
  `get/2`'s did-you-mean offering an instance; `check/1` refusing a program whose tags or
  rungs are junk, a dint var_input's constant past 32 bits, a second connection of a
  var_input first tied to a constant, a connection to a name with `.` parts as a
  diagnostic, a mistyped var_output driving nothing, the declaration order of unconnected
  var_inputs, and the configuration's name before its programs among the host's
  mistakes. The rest were documents: the runtime's one-rule section said a task an edit
  keeps keeps its due time, against decision 40; decision 30's `{:ok, 1}`, the probe's
  own wrapper; §6.2's "Adds `configuration_test.exs`"; `Logex.Diagnostic`'s moduledoc on
  who returns diagnostics and sets `file`; a test comment citing fix F8 for decision 36's
  rule; and two comments in `Logex.Configuration` claiming one message per host mistake,
  which `new!/1` does not keep where a bad name leaves a var_input unconnected, now
  stating the rule the code keeps: a bad name is not recovered, as on a `.ld` line.

  A check of those fixes confirmed four findings, three once the two found twice are
  merged, all in what the tests saw and none in `lib/`'s behaviour; the commit after the
  fixes pins each. No test held a use of a duplicate global's name to the global that
  kept the name. The filter that keeps an element named by the host's mistake out of
  every diagnostic was pinned as a whole, not for a task's interval and priority, a
  global's location and address, or an instance's task alone. And no test gave `check/1`
  a plain map or another struct, or gave it or `new!/1` an element that lacks a key and
  has another in its place. The suite is at 528 tests (8 doctests).
- **M2-2 · The configuration file, task-less.** A separate `.logex` file (the extension
  was a placeholder until decision 35 chose it on 2026-10-02): `var_global`, plain and
  located (`at panel.q.0`), `program <inst> <type>`, arrow-free connections (`m1.start
  pb_start_1`), every `var_input` connected, one driver per sink. *Done when* two instances
  of one `.ld` program type, wired in a configuration file to different input and output
  points, run for N cycles from one input image and keep independent state; a mis-wired,
  unknown, undriven-input or mistyped connection is a located diagnostic naming its file
  and line. *Also decided 2026-09-30:* the extension says what kind of file it is, so
  `Logex.compile_file/1` refuses anything but `.ld` with a `:file` diagnostic. Until
  then it names a program after its basename less the last extension, whatever that is,
  and `test/logex_test.exs` pins that; its `seal.txt` assertion flips with this item.
  *(Flipped with it, 2026-10-11: `seal.txt` is a `:file` diagnostic.)*

  *Designed 2026-10-02* (§4.10, M2-2). Two departures from the scope above, each annotated
  where it was decided: the §4.4 checks M2-1's data can express land with M2-1, and M2-2
  asserts each again as a whole diagnostic list from source; and the loader is M2-5's, one
  memo per configuration. The file is read by a recursive descent over `Logex.Lexer`'s
  tokens and printed back with an exact round trip. It reserves `program var_global at`
  in the configuration file. It lands as:
  1. the `program`, `var_global` and `at` stanzas;
  2. `compile_file/1` takes only `.ld`, as a gate in front of M2-5's loader;
  3. `Logex.Configuration.Text`: the reader, the text's own definition of what a line can
     say, and the printer; it reserves the words, and each message that names a word
     lands with it;
  4. the configuration file's checks as rows of M2-1's `check/1`, in the file's words,
     with one diagnostic per instance for its unconnected var_inputs;
     `Configuration.compile/3`; every M2-1 check asserted again from source; the
     public-surface pin of `Logex.Configuration` rewritten once;
  5. the configuration's loader, through M2-5's with one memo per configuration, refusing
     a block's file on a `program` line;
  6. the round trip, totality and growth;
  7. a location in a `.ld` rung named as one;
  8. the Done-when on M2-1's `cycle/3`, and the documents.

  The fourth is the largest piece no spike built (owed, below).

  **Status: DONE — landed 2026-10-11**, as nine commits, gated alone, each with its
  mutation table in its message, every rule it adds reverted alone and the full suite
  judged by exit code. The first five were built on `025199a`, before M2-5, and rebased
  onto `732c0b6`, the last three after M2-3's commits, a departure from the record's order
  made because they need M2-5's loader: (1) the survey, `f2929d4` (the record's 1); (2) the
  reader and printer, `Logex.Configuration.Text`, `be90e26` (3); (3) the checks as rows of
  `check/1`, with `Configuration.compile/3`, `3a17ecd` (4); (4) the round trip, totality
  and growth, `2e015cb` (6); (5) a location in a rung, `82bb5af` (7); then, after M2-3's,
  (6) `compile_file/1` takes only `.ld`, `20ff260` (2); (7) the configuration's loader,
  `4d2aac1` (5); (8) the Done-when from files on disk, `229a45a` (8); (9) the documents,
  the commit after it (8). 770 tests pass on Elixir 1.20.4 (8 of them doctests), up from
  675 on `732c0b6`. The mutation tables of (1) to (5) were run before the rebase, on
  `025199a`, 154 rules (9, 55, 59, 20 and 11), every one red; (5)'s eleven were run again
  on the rebased tree, since M2-5 changed the compiler's lookup most, and all are red.
  (6) and (7) add 29 rules (6 and 23), every one red on their own trees; (8) adds none
  and reverted twelve the Done-when relies on, every one red. The rebase kept both sides
  of every conflict: M2-5's `function_block` words beside the configuration file's in
  `docs/naming.md`, `naming_test.exs` and `CLAUDE.md`, M2-5's describes in
  `end_to_end_test.exs`, and M2-5's one block-type message, which `compile/3` raises and
  whose words the totality property now pins, a user block's among them.

  Readings the landing made, each stated in its commit and pinned:
  - the loader is `Logex.Configuration.compile_file/1`, beside `compile/3` as
    `Logex.compile_file/1` is beside `compile/2`, and M2-5's private loader is opened as
    `Logex.compile_files/1`, several `.ld` files through one memo; so the public-surface
    pins of `Logex` and of `Logex.Configuration` are each rewritten again, where the
    record's fourth item rewrote Configuration's once;
  - the configuration is named after its file, `plant.logex` being `plant`; a bare
    `.logex` "names no configuration" (decision 35), and any other extension, a file
    that cannot be read and a name that is none are `:file` diagnostics, the text still
    compiled after a refused name; `compile_file/1` tells a `.logex` file whose it is;
  - a `program` line's type that gives no program type is cited once, at its first
    instance's line, its other instances silent: a missing `<type>.ld` as an unknown
    program type, with a did-you-mean among the `.ld` files beside the configuration; a
    block's file with the one block-type message; a file that does not compile by name,
    with the files its mistakes are cited in, and those diagnostics after the
    configuration's, each with its own file and line, each once, in the order the types
    are named (so worded after the review below);
  - a program type's warnings stay in its program, a block's handed back once a
    configuration, by the first program type that holds it and compiles (so worded
    after the review below); the configuration's own stay
    in its `warnings`;
  - a type that is no name, or a keyword, is not looked for.
  Growth: the reader, the printer and `compile/3`, read over 44 runs, 4.20x to 4.59x,
  4.01x to 4.06x and 4.25x to 4.95x for 4x the input, bounds 5.6, 5.0 and 6.0; the
  loader, over 36, 4.007x to 4.025x for 4x the program types, bound 4.9.

  A review of M2-2's and M2-3's commits confirmed findings fixed in the commits after
  `a5b4e62`, each with a test that fails when its fix alone is reverted:
  - `Logex.compile_files/1` keeps which blocks a program has handed back apart from its
    memo, so a block's own file before a program that holds it no longer takes the
    warnings of the blocks below it from that program; and a result a cycle gave is not
    kept past its path, so each path's result is its own `compile_file/1`'s.
  - `Logex.Configuration.compile_file/1` lists a block's mistakes once, though several
    program types hold it, and a program type that does not compile names the files its
    mistakes are cited in, a block's among them, where it named the type's own; and a
    test pins that the types' diagnostics come in the order the types are named.
  - a `program` line broken before its instance's name, `program 5 motor`, `program`
    alone or `( program m1 motor`, declares a program it cannot name, a placeholder
    `Logex.Configuration.Text.read/1` gives with no name, so the configuration is given
    the line's diagnostic only, not "declares no `program`" after it.
  - README's list of the public API, and its syntax list and "A configuration file",
    name `Logex.compile_files/1`, the loader a configuration's program types go through.

  775 tests pass on Elixir 1.20.4 (8 of them doctests), up from 770 on `a5b4e62`.
- **M2-3 · Periodic tasks in text.** `task <n> interval <ms> priority <p>` and `with`.
  *Done when* the plant of `docs/organisation.md` §4.4 without its event task, its `motor`
  the §4.2 one plus `var t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`,
  `var_external` or `cal`, which arrive with M2-4 and M2-5), cycled every 10 ms from 0 to
  990 ms, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  the one clock. *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "driven
  for one simulated second".)*
  *(M1-6: that motor compiles without a warning and times. Say how the
  inputs are timed: an instance sees an edge when a scan copies it in, so the equality
  holds per rising edge, when two instances see that edge at one time and the preset is a
  multiple of both periods. A timer that re-triggers itself repeats every preset plus two
  task periods, so its rate differs between tasks, as MatIEC's TON does.)*

  *Designed 2026-10-02* (§4.10, M2-3). A priority is 0 to 65535 (decision 37), and the
  item's documents state decision 40's rule for an interval OE-2 changes. It reserves
  `task interval priority with`, and lands as: (1) the `task`, `interval`, `priority` and
  `with` stanzas; (2) task lines and `with` turned on, with the warning for a task that
  runs no instance; (3) the Done-when, on M2-1's scheduler, and the documents. The reader
  is spiked.

  **Status: DONE — landed 2026-10-11**, as three commits between M2-2's fifth and sixth,
  built on `025199a` and rebased onto `732c0b6` without a conflict but in the Done-when's
  test file, with the documents in M2-2's last commit: (1) the survey, `0668643`; (2)
  task lines and `with`, the warning for a task that runs no instance, and the §4.4
  receipt's seven diagnostics word for word, `bd6980f`; (3) the Done-when, `4fa6cbc`:
  §4.4's plant without its event task, read by `Configuration.compile/3`, cycled every 10
  ms from 0 to 990 ms, runs `m1` 100 times and `m2` 20 times, and each `t1` times against
  the one clock, the inputs timed as the record asks. (2)'s 51 rules and the 21 the
  Done-when relies on, reverted on `025199a` before the rebase, are every one red.
  Decision 40's rule for an interval OE-2 changes, `min(next_due, now + new interval)`,
  is stated in the `interval` stanza of `docs/naming.md` and in `Logex.Runtime`'s
  one-rule section; nothing builds it before OE-2.
- **M2-4 · Shared globals.** `var_external` in `.ld`; type agreement (Ed 2 §2.4.3); no
  writes to an input point; a two-writer warning. *Done when* an e-stop declared once as
  a `var_global` and read by two instances through `var_external` stops both in the same
  cycle; a `var_external` with no matching global, or of another type, is a located
  diagnostic.

  *Designed 2026-10-02* (§4.10, M2-4). One copy of each global: the scheduler merges each
  `var_external`'s global into its instance's state before `call/4` and splits it off
  after. A function block's file refuses `var_external`, a deliberate, reversible
  departure from IEC. The two-writer warnings ride on the configuration's `warnings`. It
  lands as: (1) B5's one IR walk, with public functions for which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, and no change in
  behaviour; (2) `var_external`: its stanza, the section and its `.ld` rules, and its
  refusal in a block's file with a located diagnostic; (3) the binding checks and the two
  writer warnings, from the walk, into M2-1's `check/1`; (4) one copy of a global at run
  time, the Done-when and the documents. The walk, the block-file refusal and the
  run-time copy are not spiked. *(A throwaway spike of the run-time copy, 2026-10-04,
  built it on `025199a` against a model with no merge or split, every rule red when
  reverted; decisions 46–49 and §4.10's rules settled what it found. The Done-when is
  tested on §4.4's plant at a cycle both tasks are due, 50 ms, with a second test that a
  pulse shorter than `m2`'s interval never reaches it (decision 46). The survey is
  committed first, on its branch, since CLAUDE.md asks for the survey before the code.)*

  **Status: DONE — landed 2026-10-12**, as six commits on `fd8fda8`, the record's four
  with the survey first and the documents last, each green under the full gate on Elixir
  1.20.4 / OTP 28: (1) the `var_external` stanza, ported from the backup of 2026-10-04 and
  its quotations checked again, `c057553`; (2) B5's one walk, `Logex.Walk`, whose
  `instructions/1`, `uses/2`, `writes/1` and `timers/1` the compiler, `Logex.Warnings` and
  `Logex.Edit` read in place of their own walks, `writes/1` and `timers/1` reaching into
  each block a `cal` runs by path, with no change in behaviour, the suite of `c057553`
  passing whole against its `lib/` and every traced call of that suite agreeing,
  `2a03b52`; (3) the section, its `.ld` rules, a configuration file's keywords refused as
  a var_external's name, and its refusal in a block's file, `c9087ca`; (4) the binding,
  the input-point write check, a var_external in a connection, M2-2's two warnings brought
  to it and decision 48's two writer warnings, in `check/1`, `b71b780`; (5) one copy of
  each global at run time, decisions 46, 47 and 49, the Done-when from text and from files
  on disk, the sampling test, the rule tests and the contract walk against a model of one
  map of globals, `6f91512`; (6) the documents, the commit after it. The messages of (2) to
  (5) record their mutation tables, every rule each adds reverted alone in its own
  worktree and the full suite judged by its exit code: 61 rules (22, 9, 22 and 8), every
  one red. 821 tests pass on Elixir 1.20.4 (8 of them doctests), up from 775.

  Readings the landing made, each pinned by a test, and in §4.10's M2-4 note: the walk
  gives a path inside a block the lines of the block's own text, each block type read
  once a call, its paths put from the top down, since putting them level by level was
  cubic in a chain's depth; the storage-bit words of the writer warnings are given
  wherever any writer's `ons` keeps its bit in the global, whoever the other writer is;
  a var_external line refused for its initial value declares nothing, as a var_input's
  does; and the binding needs neither a sort of the instances nor decision 42's silence,
  since `check/1` holds lines rising and no var_external can be named as a refused global
  is. The tie-break test §4.10 owes M2-6 now has the form M2-4 gives it, two writers of one
  global through `var_external` in `end_to_end_test.exs`; the event task's half waits for
  M2-6. Growth bounds are a fifth above the highest of 32 or more runs, half of them
  beside three full suites; the walk's depth test and M2-2's loader test each failed once
  in the 39 full suites the mutation rows ran four at once on four cores, the load "Costs
  to keep in view" records.
- **M2-5 · User function blocks.** `function_block <name>` as a file's first line,
  matching the file name; *(its first rung since 2026-10-02: comments and blank lines may
  come before it, §4.10)*
  instances (`var s1 seal`); `cal` with positional operands, rung power as EN, and nothing
  copied on a false EN; nesting; recursion is a diagnostic. *Done when* a seal-in written
  once as a function block and instantiated three times in one program behaves as three
  independent seal-ins, `m1.s2.run` reads one of them, a false EN freezes only its own
  instance, and a recursive type, an unknown FB type or a `cal` of a non-instance is a
  located diagnostic. *(From M1-6, for this item: `Logex.FbType` already recurses into a
  member whose type is a type, and `public/1` leaves a `:local` role out by default; a
  frozen instance must leave a timer's `.en` and `last` alone, so a timer that was timing
  catches up; the "no `ton` runs it" warning must say `cal` for a user type; `first` is
  the program instance's, so an `ons` inside a block frozen on the first scan is not held
  back when it first runs; which of a user block's members logic may write is open; and
  `cal` on a built-in type should be refused.)* *(Answered 2026-10-02: no member of a user
  block is written from outside it, by decision 33, and `cal` of a `ton` is refused,
  naming the `ton` that runs it; the other notes stand as written.)*

  *Designed 2026-10-02* (§4.10, M2-5). It lands after M2-1 (decision 30), so its
  Done-when stands as written and its own test reads `get(rt, "m1.s2.run")`. The scope
  above leaves out three things the design gives it, each annotated where it was decided:
  the nested migration that `docs/organisation.md` §4.9 and OE-2 below assign to it, so a
  program that holds blocks may change while it runs, by path (decision 31), a one-shot
  inside a block blocked until a scan runs it (decision 32); the loader, ahead of M2-2,
  `compile_file/1` finding `<word>.ld` beside the file and handing back the loaded blocks'
  warnings (decision 34); and `types:` on `Logex.compile/2`, a block's file compiling to
  `{:ok, %Logex.FbType{}}`. Fix F15 lands here: `%Logex.Program{}` gains a `file`. It
  lands as:
  1. the survey: the `function_block` and `cal` stanzas, and
     `Logex.Declarations.kinds/0` with its naming test;
  2. the IR walks learn a signature per instruction, with no change in behaviour;
  3. blocks and `cal`, reserving `cal` in every `.ld`, in any case, and `function_block`
     in a block's file; fix F15; the Done-when, through `get/2`; one message for a block
     type given where a program goes, at every entry point, M2-1's `check/1` included;
  4. the edit by path (decisions 31 and 32), in one push with the third, whose edit refuses
     every change to a block;
  5. the loader (decision 34);
  6. the documents.

  The spike holds the first five, not cut into commits. Fix F15, the `get/2` assertion,
  the one message in `check/1` and the warnings of decision 34 are not built. A separate
  commit after M2-5 excuses the uses of a declaration whose type is unknown.

  **Status: DONE — landed 2026-10-04**, as seven commits: the first five of its landing
  order, then the excusal the record put after M2-5, then the documents, a departure from
  the record's order made so that the documents describe the excusal with the rest; an
  eighth that fixes what a review of the seven confirmed, `4fc8587`; a ninth that holds
  each block type once per body, `9ff76f6`; a tenth that fixes what a check of the
  eighth, the ninth and `4230f65` confirmed, `4d006d6` (below); an eleventh that holds
  each block type once per outermost type, decision 53, `1a16b1d` (below); a twelfth that
  compiles each type given again from its source text, decision 54, `dafb5a0` (below);
  and a thirteenth, the commit after `0183bf2`, that fixes what a check of the eleventh
  and the twelfth confirmed (below). `4230f65`, which gives three older walks more draws,
  and `0183bf2`, which corrects this plan's note on M2-4's and M2-6's run time, are not
  part of M2-5. (1) The survey,
  `4db37b1`; (2) one lookup of an instruction's slots for the walks,
  `Logex.Compiler.signature/2`, with no change in behaviour, `e8a55b6`; (3) blocks and
  `cal`, `969a5a4`; (4) the edit by path, `a87edcc`; (5) the loader, `2c3c609`; (6) the
  uses of a declaration whose type is unknown excused, so a misspelled block name is one
  message, `776a810`; (7) the documents, the commit after it, among them the README's "A
  function block", whose output is a real run. 643 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 529. The messages of (1) to (6) record their mutation tables, every
  rule each adds reverted alone in its own tree and the full suite judged by exit code:
  214 rules (2, 3, 125, 46, 30 and 8), every one red. (2) also traced every call the suite
  makes to `Logex`, `Logex.Runtime`, `Logex.Edit`, `instructionize` and
  `Logex.Warnings.of/2`, under the old code and the new, and the two digests are one. (3)
  and (4) are to land in one push: (3)'s edit refuses any change to a block.

  The landing built what the spike did not: fix F15, a `file` on `%Logex.Program{}` that
  `compile_file/1` sets, on a block's body too, and that every `:edit` diagnostic carries;
  one message for a block type given where a program goes,
  `Logex.Declarations.not_a_program/1`'s, from the runtime, `Logex.Edit.accept/3` and
  `Logex.Configuration`'s `check/1` and `new!/1`, in place of M2-1's interim words
  (`Configuration.compile/3` and the configuration's loader, which M2-2 lands, are the
  entry points left; *landed with M2-2, which gives it at both*); the Done-when reading
  `Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 1}` through a configuration, from text and
  from files on disk; decision 34's warnings handed back by `compile_file/1`; a test for
  every check inside `Logex.Compiler.lowered?/1`, so the owed rising-lines check below is
  closed; and "an instance of `outer`" for a user block's instance, so the owed "a outer"
  below is too. (6) is new besides: the spike kept M1-3's report of each use of a
  misspelled type's tag.

  Readings the landing made, each stated in its commit and pinned: a user block's name
  takes no article, "an instance of `seal`", since one chosen by its first letter gets
  "user" and "hour" wrong, while the built-in timer stays "a ton", and the block-type
  message says "through `ton`" for it; `get/2` calls a block's own `var` "a `var` of
  `seal`, hidden outside it"; a switch never reports a block's var_inputs as `:input` or
  `:unread`, since `cal` copies them in, and reports a block's var_output whose initial
  value changed as `:initial_changed` by its path; `compile_file/1` hands back the
  program's own warnings first, then each block's in the order compiled, and a block's
  own file only its own; a broken block's file stops the file that names it, but every
  block that file names is still loaded, so each broken one is reported; and a directory
  with a block's name "cannot be read". It reserves `cal` in every `.ld`, in any case,
  and `function_block` in a block's file; no test, `lib/` file or fixture names a tag
  either. Growth is pinned in reductions: a type given is checked once a compile, not once
  an instance (16 instances cost 1.05x one; declared from Elixir, 1.04x, since the
  review's fix); a switch and the scan after it grow with the block list's bytes, bound
  1.3x their growth; the scan right after a switch at 16x the instances took 16.2x to
  16.4x, and a second edit's steps at 16x the pending nested bits 16.4x to 16.8x, each
  bound 24. The edit walk over blocks in
  `api_contract_test.exs` passed with its full reach under seeds 1 to 30 besides its own,
  the rarest of what it asserts it reaches at least 6 times a run.

  A review of the seven commits confirmed 23 findings, and the eighth commit fixes 21,
  each fix a test can see with a test that fails when that fix alone is reverted.
  `Logex.FbType.same?/2` is now the one definition of a version of a block, which a
  compile and `user?/1` share, so a block given two versions of a block it holds that the
  compile took as one is a type the next compile takes; it compares the source text, as
  §4.10 says. `user?/1` and `lowered?/1` are total over warnings that are not a proper
  list and a struct for tags, `lowered?/1` checks each operand's line, `types:` must be a
  proper list, and a tag declared from Elixir is one version with every block the types
  given hold. Accept, a compile's lookup of a member, and the check of a type that
  instances declared from Elixir hold are linear, as growth tests in a block's members and
  in such instances pin. Tests now pin what had none: nothing copied out on a false EN, a
  body's tag table, recursion through a tag two levels down, a block's name matched
  exactly, the loader's case and its section lines, a nested `:preset_kept` (in the walk
  too), the order of the bits a scan keeps blocked and of several kind changes on one
  line, and a `cal` with one operand too many. It left two questions, which the maintainer
  decided on 2026-10-04. A body holding two instances of one block held its type twice,
  once per tag, so a copy that keeps no sharing grew as the width to the power of the
  depth: each block type is to be held once per body, its instances' tags naming it, as
  §4.10's "Held types" records, which `9ff76f6` builds, the type held in the body's
  `blocks` and read back by `Logex.Program.typed_tags/1`. And three walks that predate
  M2-5 each missed one atom of their reach under one seed of a family they were not
  measured under: they get more draws until their reach holds under 60 seeds of more than
  one family, measured on seeds they were not tuned on, which `4230f65` builds, 2,000
  sources, 150 programs and 400 configurations a run, up from 600, 40 and 150.

  A check of `4fc8587`, `9ff76f6` and `4230f65` confirmed 15 findings, 11 once the four
  found twice are merged, and `4d006d6` fixes them, but for the two
  questions below. A block's compiled body run as a program started each instance it holds
  at 0 and ran it wrong, and `get/2` and `Logex.Edit.accept/3` raised errors that are no
  `ArgumentError` on it: the runtime, `get/2` and the edit now read a program's tags
  through `typed_tags/1`, as a compile does. Tests now pin what had none: a timer's tag in
  a section no line gives it, each rung on one line inside a group, a nested group and
  past an instruction's first operand, `same?/2`'s rungs and every held type it compares,
  `user?/1` checking each type once however many paths reach it (a diamond of types), and
  accept reading a block's body once however many instances run it: 661 tests pass on
  Elixir 1.20.4 (8 of them doctests), up from 654. Documents that claimed more than the
  code does are narrowed: a type copied flat is linear in its depth where each type is
  reached through one holder; §4.9's cost for a program that holds blocks is linear in its
  instances too; `user?/1` checks a type's shape, not that its body is the one its source
  text gives; and `lowered?/1` is total over the tag tables it expects. Two are left for
  the maintainer. Where each level has two types and each holds both of the level below, a
  type copied flat is written out once per path and grows as 2 to the power of the depth,
  as an instance's state does: is each user type to be held once per outermost type,
  beyond §4.10's once per body, so that it stays linear there too? And `user?/1` takes a
  type whose rung was edited into another that text could say, its source text left as it
  was, as a version of its own, which only a compile that holds the genuine one too
  refuses: is `user?/1` to compile a body's source text again and ask that it give that
  body, so that §4.10's "a hand-edited type is an `ArgumentError` where it is given" holds
  for it?

  The maintainer answered the first on 2026-10-05: each block type is held once per
  outermost type, decision 53, which `1a16b1d` builds. The type a compile
  gives, and a program, hold every user block type their instances reach, at any depth,
  once, in one table, `blocks`, each held with no table of its own
  (`Logex.FbType.held/1`), and every instance's tag at any depth, a program's own among
  them, names its type, which `Logex.FbType.type_of/2` and `Logex.Program.typed_tags/1`
  give read inside the table (`Logex.FbType.within/2`); a `cal` hands its body the
  program's table, and the edit reads each type's body once from it. In the diamond of
  two types a level, each holding both of the level below, a type copied flat took 4,645
  and 9,313 words at 6 and 12 levels, where it took 36,405 and 2,354,805, and 18,678 and
  37,411 bytes as `term_to_binary/1`, where it took 147,620 and 9,546,257. With w types at
  a level sharing a chain of 16 below them, a program given the w types took 5,216 and
  8,984 words at w of 4 and 16, where it took 16,854 and 67,158, and a compile given them
  46,607 and 112,240 reductions, where it took 115,510 and 458,709: a compile now checks a
  type the tables of the types given share once, over the same types it names
  (`Logex.FbType.check/2`). Growth tests pin the diamond and the width, in words, bytes
  and reductions, and a compile's one-version check walking a type's table once however
  many instances hold it. A program's own tags no longer hold each type itself, so the
  tests that read a program's types read its `blocks`. 665 tests pass on Elixir 1.20.4
  (8 of them doctests), up from 661.

  The maintainer answered the second the same day: a type given is to be the one its
  source text compiles to, decision 54, which `dafb5a0` builds.
  `Logex.FbType.user?/1` compiles again each type a value holds, the outermost and every
  type in its one table, once a call, each before any type that names it, as a block of
  its name over the types it names as the table holds them, trusted and not checked again
  (`Logex.Compiler.recompiled/4`), and asks that the result be the type given, its members
  and its body's name, rungs, tag table and warnings, with the file the body was read
  from, none or a path to a file named after the block, which stamps each warning;
  `Logex.FbType.check/2` compiles a type that the tables of several types given share
  once. So a rung edited into another that text could say, a tag table edited into one
  declaration lines could give, a source text edited with its body left as it was, and a
  file that is no such path are each an `ArgumentError` where the type is given, §4.10's
  "a hand-edited type is an `ArgumentError` where it is given" holding exactly; a source
  text that gives the same body, a comment more, is the type a compile gives for it. A
  compile given one block of 50 and 200 rungs took 70,113 and 275,398 reductions, where
  it took 58,806 and 231,598, and given a chain of 50 and 200 types 113,959 and 446,194,
  where it took 87,334 and 340,188: a growth test pins both linear. It left a block that
  `Logex.Compiler.instructionize/3` builds with no source text to compile again, so a
  block whose members are declared from Elixir was refused; on 2026-10-11 the maintainer
  chose to keep such a block a type a compile takes, and the commit after the check's fix
  gives it a source text, each rung printed on its line, and hands its members from
  Elixir to the recompile. `user?/1` no longer calls `Logex.Compiler.lowered?/1`, which a
  body equal to its text's compile satisfies, so nothing in `lib/` calls it; it is kept,
  public and tested, as the definition of a compiled body the record names. 670 tests pass on
  Elixir 1.20.4 (8 of them doctests), up from 665.

  A check of `1a16b1d`, `dafb5a0` and `0183bf2` confirmed 21 findings, 17 once the four
  found twice are merged, and the commit after `0183bf2` fixes them all. Two were in the
  code. Each tag declared from Elixir checked its type with a memo of its own, so a type
  the tables of several tags' types shared was compiled again for each, against decision
  54's "once a compile": the tags now share the compile's memo, after the types given
  (`Logex.Declarations.split/4`), and tags of 4 types sharing a chain of 16 compile 20
  types again, not 68. And an edit's plans kept each block type read inside the program's
  table, so an edit copied flat wrote the table out once per instance and member planned,
  4,443,950 words with 16 types at a level sharing a chain of 16: the plans keep each type
  as the table holds it, and an edit copied flat grows with the instances its programs
  nest, 202,544 words there (§4.9, "Cost"). Tests now pin what had none: a tag built by
  hand of a type edited in its warnings or its file, given beside the genuine type; a
  held instance's initial value in `Logex.Compiler.lowered?/1`; a block's file of any
  extension, or none; two tags of two versions of one block; two types given whose tables
  disagree, whichever the source declares; a tag of an older version of the block itself;
  a table holding an older version of its outermost type; the version a program's table
  holds where one is given; and the check's memo keeping every version of what a type
  names. The M2-5 compile walk takes 7,500 sources, up from 3,000, sized from its rarest
  atom, and its reach held under 300 seeds of three families it was not sized on. Every
  growth figure was read again over 96 runs of the suite, 32 alone, 32 two at once and 32
  four at once, and each bound less than a fifth above the highest raised to a fifth
  above it, the size tests of `logex_test.exs` and `edit_test.exs` among them. Documents
  that claimed more than the code does are narrowed: a program holding a hand-edited block
  body may raise in the runtime. 675 tests pass on Elixir 1.20.4 (8 of them doctests), up
  from 670.
- **M2-6 · Event tasks.** `task <n> single <g> [interval <ms>] priority <p>`, fired by a
  rising edge, and in the first cycle if the trigger is already true; with `interval` too,
  it runs periodically only while the trigger is 0, plus a run on each edge (IEC rule 2). *Done when* an event task triggered
  from an input point runs once per rising edge, before lower-priority tasks due in the
  same cycle, and runs in cycle 1 if its trigger is already true.

  *Designed 2026-10-02* (§4.10, M2-6). `single` with `interval` is decision 39; an event
  task's due time, for the tie-break, is the cycle's `now`; a restart sets a trigger's
  last sample to 0, and an edit keeps it. The warning for a `ton` in a program an event
  task runs, on the configuration's `warnings`, covers a task with `interval` too and a
  `ton` inside a block. It reserves `single`, and lands as: (1) `single`: its stanza, its
  task lines, the warning from the walk, and `single` on `Logex.Configuration.Task`; (2)
  edges at run time, the Done-when and the documents. The reader and the checks are
  spiked; the edges at run time are not. *(Reordered 2026-10-04: a throwaway spike of the
  edges at run time, on `025199a`, found that after (1) `cycle/3` raises
  `ArithmeticError` on an event task, against the host contract. So the stanza comes
  first, then the data and the run time (the field, `check/1`'s rows, the edges, the
  Done-when from data, the contract walk), then the text (the task lines, `single`
  reserved, the warning from the walk, the Done-when from source) and the documents.
  Decisions 50–52 and §4.10's rules settled what the spike found.)*

  **Status: DONE — landed 2026-10-12**, as eight commits on `f75f1f1`, the reordered
  record's with the survey first, Milestone 2's done sentence walked before the documents
  and the documents last, each green under the full gate on Elixir 1.20.4 / OTP 28: (1)
  the `single` stanza, ported from the backup of 2026-10-04, its quotations
  checked again against the saved sources and the stanza brought to M2-2's to M2-4's
  keywords and to decisions 50 to 52, `0e86384`; (2) `single` on
  `Logex.Configuration.Task`, `check/1`'s rows, the edges at run time, decision 39 and
  decisions 50 to 52, the trigger's last sample in `Logex.Runtime`'s one-rule section, the
  rule tests and a growth test, `48eb735`; (3) PLAN M2-6's Done-when from data, the owed
  tie-break with two writers of one global, and M2-1's contract walk drawing event tasks
  against a model of decision 39 in phase points, `8ee4a33`; (4) the task line, `single`
  reserved, every check asserted again from source, `81cde64`; (5) the warning for a
  `ton` in a program an event task runs, from `Logex.Walk.timers/1`, `b967e77`; (6) the
  Done-when from source, §4.4's plant whole from text and from files on disk, `bbe68f5`;
  (7) Milestone 2's done sentence walked in `logex_test.exs`, `40ab59c`; (8) the
  documents, the commit after it. The messages of (2), (4) and (5) record their mutation
  tables, every rule each adds reverted alone in a worktree of its commit and the full
  suite judged by its exit code: 49 rules (27, 13 and 9), every one red; (3), (6) and (7)
  add tests only, and record which earlier rows they turn red. 860 tests pass on Elixir
  1.20.4 (8 of them doctests), up from 821.

  Readings the landing made, each pinned by a test, and in §4.10's M2-6 note: until the
  reader read `single`, a task with neither input kept M2-3's message, and since then it
  is offered both, its example naming the task only where its name is one, as a task with
  no priority, shown one of its own kind since the review, is named; an event
  task's interval of 0 is told to leave it out; a single counts as a use of its global; a
  single's value on a task line is any name token but an input's word; the ton warning is
  one a timer, at its instance's line, citing the `ton`'s own file and line, each program
  type's timers read once; and a decision-52 cycle counts the periods it missed as any
  late periodic task does. The contract walk took 500 configurations, up from 400, its
  reach held at 300 seeds of three families, and since the review takes 1000. Growth bounds are a fifth above the highest
  of 32 runs, half of them beside three full suites or in a full suite.

  Its review's fixes, each a commit after the documents', each green under the full gate
  and with its mutation table in its message: the ton warning cites each timer once a
  program type, each routine's typed tags read once, where a timer inside a block read
  the program's tags once a timer, quadratic in the timers, now pinned by a growth test in
  reductions with its timers inside blocks; and a block's timer from types read from no
  file is cited by the block's name, "on line 5 of block `inner`", where "on its line 5"
  read as the program's line; and a task with no priority is shown a task line of its own
  kind, `task e single trig priority 1` for an event task, where every task was shown a
  periodic one, named by the rule the interval's examples use, so a refused `u.v` is
  shown `task t …`; and a dint single, a diagnostic, counts no use of its global, a
  branch no warning could show, since a configuration with a diagnostic gives none; and
  the contract walk takes 1000 configurations, the maintainer's choice, up from 500, its
  reach measured again at the same 300 seeds, every atom reached by 11 configurations a
  run or more (`:due_time_order`), where 500 gave 2. 864 tests pass on Elixir 1.20.4 (8
  of them doctests), up from 860.

The scheduling rules are decided too: PRIORITY on every task, 0 the highest; ties go to
the earlier due time, then declaration order; no preemption; missed periods coalesced,
counted and reported; time injected in milliseconds, never read from a clock; reserved
words scoped by file kind. Once a wall-clock runner exists, a watchdog fault is to stop
scheduling, zero the output image once, report, and require an explicit restart: the
recommended choice, confirmed when the runner is designed (`docs/organisation.md` §7,
decision 14). *(Confirmed 2026-10-17 by decision 113, Milestone 4's design.)* *(Since 2026-10-02 a priority is 0 to 65535, decision 37, and an event
task's due time, for the tie-break, is the cycle's `now`.)*

**Milestone 2 is done when** a configuration file on disk instantiates one `.ld` program
type twice, with a function block inside it; wires the instances to declared I/O points
and to a shared global; schedules them under a periodic task, an event task and no task;
runs deterministically for N cycles from an injected clock and input image, with the same
outputs on every run; and reports every wiring, typing or scheduling mistake as a located
diagnostic naming its file and line. *(Done 2026-10-12, with M2-6: `test/logex_test.exs`,
"Milestone 2's done sentence, as written in PLAN.md", walks it clause by clause from files
on disk through `Logex.Configuration.compile_file/1`. "Schedules them" is read as the
configuration's instances: the one type's two run under the periodic task and no task,
and the event task runs a snapshot, as §4.4's plant has it, since two instances cannot run
under three schedules.)*

**Owed, from the design (2026-10-02).**
- **The port of the configuration checks into one validator.** The configuration
  spike's checks stand in a validator of their own, which cannot be merged with M2-1's:
  both add `lib/logex/configuration.ex`. M2-2's fourth commit ports them into M2-1's
  `check/1` as rows, rewrites the public-surface pin once, and asserts every M2-1 check
  again from source. Two device names that differ only in case are refused there, the one
  check M2-1's data can express that M2-1 does not land; no spike built it. *(Closed by
  M2-2's third commit, `3a17ecd`, the device names' case among its rows.)*
- **The seams between M2-5 and the configuration file** are planned, not built: the
  configuration spike has no `cal`. Each commit at a seam checks it on the composed tree:
  a `cal`'s outputs among a program's writes, a block's `ton` among its timers, a block's
  file on a `program` line, a block's `var_external`, and one loader. *(M2-5 has landed,
  so each is now checked against its code: the walks read a `cal`'s slots through
  `Logex.Compiler.signature/2`, the loader is `Logex.compile_file/1`'s private `load/3`,
  which M2-2 is to open for one memo per configuration, and the one block-type message is
  `Logex.Declarations.not_a_program/1`.)* *(Two of the five are closed by M2-2: one
  loader, `Logex.compile_files/1`, which the configuration's loader goes through, and a
  block's file on a `program` line, given the one block-type message. The other three,
  a `cal`'s outputs among a program's writes, a block's `ton` among its timers and a
  block's `var_external`, are M2-4's.)* *(Closed by M2-4: `Logex.Walk.writes/1` counts a
  `cal`'s outputs as writes and `timers/1` names a block's `ton` by its path, its second
  commit, and a block's file refuses `var_external` at its line, its third.)*
- **Two run-time pieces were not spiked by the design:** M2-4's one copy of a global, and
  M2-6's edges with `single` and `interval`. Their rules were the design's text alone. A
  test of the event task's tie-break is owed: an event task and a late periodic task of
  one priority, both writing one global, asserting which write lands. *(Both were spiked
  on 2026-10-04, as M2-4 and M2-6 above record: throwaway spikes on `025199a` built the
  run-time copy and the edges at run time, each against an independent model, every rule
  red when reverted, and decisions 46–52 and `docs/organisation.md` §4.10's rules under
  M2-4 and M2-6 settled what they found. The tie-break test is still owed, and §4.10 now
  says how it is written: in both forms, two writers of one global through
  `var_external` in `end_to_end_test.exs`, once M2-4 has landed, and, beside the rule
  tests, one instance writing a global that another copies to an output point.)* *(Closed
  by M2-6, in both forms: `end_to_end_test.exs` and `scheduler_test.exs`, `48eb735` and
  `8ee4a33`.)*
- **The untested rising-lines check.** M2-5 checks that a block's body given in `types:`
  is one a compile gives, its rungs among them on rising lines, each on one line, after
  its declarations. Reverted alone, that line check left the function blocks' spike green,
  and three more calls in the same check (to the compiler's `shared_bits/2`, `calls/1` and
  `path/2`) have no revert at all. Each gets a test that fails when it is reverted, or the
  check goes. *(Closed by M2-5's third commit, `969a5a4`: each check inside
  `Logex.Compiler.lowered?/1`, those four among them, has a test that fails when it alone
  is reverted. All but one: the review of M2-5 found that two declarations on one line
  were refused twice, by a check of their own and by the rising lines, so the first could
  not fail alone; the fix after the documents drops it, and a test pins the second for
  them. It also checks each operand's line, which the rising-lines check missed.)*
- **Messages.** M1-6's member messages put "a" before a type's name, which reads "a outer"
  for a block so named. M2-1's `get/2` follows them for a function block instance
  ("`m1.t1` is a ton", "is not a member of `m1.t1`, a ton") and owes the same. Its
  messages that named an instance's program that way now say "a program instance of
  `motor`". *(Closed by M2-5's third commit, `969a5a4`: every message that names a user
  block's instance, the compiler's, the runtime's, `get/2`'s and the edit's, says "an
  instance of `outer`", through `Logex.Declarations.instance_of/1`; the built-in timer is
  still "a ton".)*
- **Costs to keep in view.** Every compile checks each block type it is given at full
  depth: 2,486 reductions for a small block against 244 before, and 138,358,875 for a
  chain of 400 files built one at a time. A refusal of many bad keys is quadratic in its
  keys and the names, and so is the configuration file's check of a source with many
  mistaken names, from the same did-you-mean pass as the `.ld` compiler's; only a mistake
  pays it. Three of the suite's existing growth tests in reductions, `logex_test.exs`'s
  "compiling stays linear in the program's size" and two of `edit_test.exs`'s F16 tests,
  failed now and then under a load average near 40 while the spikes ran, and pass run
  alone; a CI runner that shares cores could see that. *(As M2-5 landed, the full-depth
  check of each type given stands, as §4.10 decided, and runs once a compile, however many
  instances declare the type, which a growth test pins: for instances declared from Elixir
  only since the review's fix, before which each checked it again. The three growth tests
  failed now and then again while M2-5's mutation rows ran three copies at a time, and
  passed in every gate. After the check of decisions 53 and 54 every growth bound was read
  over 96 runs, 32 alone, 32 two at once and 32 four at once, and set a fifth or more
  above the highest, so that each of the 96 passes, four suites at once among them,
  where the edit's size test reached 6.06x against its old bound of 6; a load like the
  spikes' may still raise one past its bound.)*

### Online edit — decided 2026-10-01

**Decided 2026-10-01** (§5; design, measurements and sources in `docs/organisation.md`
§4.9, decisions 15–20 in its §7, and OE-1's design decisions 21–29). A running controller
is changed the way the conventional family's is: a candidate is accepted beside the
running program, tested, untested, and assembled or cancelled, with state moved by name,
and never through the Elixir compiler. Each item surveys any new word in `docs/naming.md`
first, lands green, and pins every rule with a test that fails when the rule is reverted.

- **OE-1 · A staged edit of one program instance, before M2-1.** Accept, test, untest,
  assemble and cancel over one `%Logex.Instance{}` and two programs of one name, with
  §4.9's migration defaults and a report from every step. Its design pass first settles
  the four questions §4.9 leaves open: which `ons` bits are armed, a timer whose `ton` an
  edit restores, the report for a done timer whose preset rises, and which steps read the
  live state. It also gives the rules for a new piece of state that M2-1's `start/1` will
  share. *Done when* an instance of the README motor plus `var t1 ton` and a rung `xic motor ton
  t1 5000` (M2-3's motor), running with `t1` done, takes a candidate that raises `t1`'s
  preset, adds a second timer, adds an `ons` and removes the rung that drives a var_output
  (keeping the motor's own rung, so `t1`'s rung stays true): test runs the candidate with
  the decided `.pre`, initial values and no one-shot pulse, and its report names the held
  output and the dropped `.dn`; untest runs the original over the same state, and its
  report lists no undriven output; assemble prunes, and its report names the held output;
  a type change is refused at accept; and a program built from data that the text cannot
  say is refused. *(Designed 2026-10-01, the four questions answered:
  `docs/organisation.md` §4.9, "OE-1's design", and its §7 decisions 21–29 and fixes
  F1–F16.)*

  **Status: DONE — landed 2026-10-01**, as the eight commits of its landing order: (1) the
  design record in `docs/organisation.md` §4.9 and §7, `1e3efc1`; (2) the data path
  refuses what the text cannot say, decisions 24 and 28, `a619e90`; (3) the instance's
  one-shot block list, `48e1299`; (4) `Logex.Edit`, with its stages, refusals, start
  rules, inputs, held outputs, initial values, forecast and prune, and the contract walk,
  `3e45ea8`; (5) timers across a switch, `c1e5d54`; (6) one-shots across a switch,
  `1a39feb`; (7) the Done-when end to end, `a4a35b3`; (8) the documents, the commit after
  it, among them the README's "Changing a running program", whose output is a real run.
  420 tests pass on Elixir 1.20.4 (6 of them doctests), up from 320. The messages of (2)
  to (6) record their mutation tables, every rule each adds reverted alone and the full
  suite judged by exit code: 187 rules, every one red. By the messages' own totals the
  tables hold 188 (35, 17, 78, 40 and 18), because (4)'s mutant E46, red only from (5),
  which added the test that fails without it, is in both; as rows they hold 186 (35, 18,
  75, 40 and 18), because (3)'s row X1 is a behaviour its total leaves out and (4)'s row
  E10–E13 is four rules. A table's labels are its own, and (4)'s mutants E1–E71 are not
  decisions E1–E9. (7) adds no rule; it
  reverted 20 that the Done-when relies on, each red, and `end_to_end_test.exs` alone
  fails 19 of them. (1) and (8) are documents. Each of decisions 21–29 and fixes F1–F16 is
  cited by name in the commit that landed it. Where the design left a gap, a commit
  records its reading and §4.9 states it: a var_input a start rule writes is reported as
  `:input`, not `:added`; fix F7's program is fix F3's, the one that last scanned, and a
  switch blocks none of the started program's own one-shots when that program scanned
  last; an output the next program still shows is held at the state's value, and one it
  does not show at a value the edit learnt only while `switched` and `first` were both
  false; `:preset_kept` is reported wherever a timer the started program runs keeps a
  `.pre` that is not its preset; and fix F1's record covers every timer either program
  declares. Departures, each recorded in its commit: `%Logex.Instance{}` gains `switched`
  in (4), not (6), because fix F4 needs it too; decision 24's refusals sit inside
  `Logex.Declarations.check/1`, so it stays the one validator and now refuses a compiled
  timer's tag; a rung of nothing but empty groups takes a line in the rung order, as it
  does in the text; an edit accepted before a plain swap's scan is outside the contract;
  the switch and prune are built per instance for OE-2 but stay private until it calls
  them; and the Done-when's assemble follows a second test at the same boundary, since
  assemble is taken under test. Measured at the landing: accept and its steps take 4.4x
  the reductions for 4x the tags and 14.4x to 14.6x for 16x the depth; compiling costs
  about 17% more reductions, since the entry check lexes every name again, and stays
  linear; and at 2,000 rungs and 4,000 tags a test takes 0.68–1.19 ms against 1.31–1.36 ms
  for one scan (`docs/organisation.md` §4.9, "Cost").

  An adversarial review of the eight commits (three lenses, correctness, contract and
  mutation, and a skeptic reproducing each finding) confirmed 15 findings, 14 once the one
  found twice is merged. Its fixes are the commit after (8), and the suite is at 430 tests
  (6 doctests). Two were defects. The scan right after a switch looked each `ons` up in
  the block list by walking it, so 16x the blocked one-shots cost 65x the reductions of
  that scan, which comes when a controller most needs to stay on time; the scan now makes
  the list a map once, and a growth test counts that scan. And a test then an untest with
  no scan between left a timer the test resumed with its `last` moved, unreported, so a
  later plain swap caught it up from the test's switch; the untest now gives the `last`
  back, as fix F1 gives back `.pre`, and reports it as `:resume_undone`, a new report
  kind. One was a report's meaning: `:initial_changed`, "the running value is kept", was
  also given for a tag a start rule had just started, and for a var_input of the program
  started, whose new initial value a restart never applies; neither is reported now.
  Four were rules no test failed without: a restart after a switch, with no scan since,
  leaves the record of held outputs standing; the pending-block filter of fix F2, now
  bounded by a growth test of a second edit taken before any scan; `:unread`'s value, read
  after the start rules; and accept's check that a program's tags are a map and its rungs
  a list. One was the walk: its round trip took its exemptions from the reports under
  test, so an edit that reset an input whose section changed passed it; it now finds what
  a switch starts from the programs' text and the state, and checks decision 25. The rest
  were documents: fix F4's wording against an output the next program still shows (§7
  gains an as-built note, and the walk now checks such an output against its next scan);
  "the program the state is running", now defined once, which had shut fix F2's case out
  of the contract and let in an accept against the original after an assemble; labels
  (lettered hazards, numbered refuter findings) that only the design notes defined, now
  replaced by decision and fix names, with a test that refuses them; a stale test comment;
  and the rule count above. Step (7)'s message ends with a paragraph after its mutation
  table, against the house shape; history is not rewritten, and the fix commit says so.

  A review of that fix commit, `d05d4a2`, confirmed 14 findings, fixed in the commit
  after it; the suite stays at 430 tests. None was in `lib/`'s behaviour. The walk's
  generator never reached decision 29's two exceptions, nor a restart between a switch
  that resumed a timer and the switch back, so the walk's restatements of them decided
  nothing; it now reaches both and asserts it. The two new growth tests had bounds set
  from a few runs, and over 48 the one-shot test came within 3% of its bound; both bounds
  are now 24. The labels test missed a hazard in the plural or in brackets, and now also
  checks each fix and decision number cited against §7. The rest were documents: decision
  29's exceptions in `Program.initial_env/1`'s doc, §4.9 and §7; `:held` for an output the
  next program shows, the state's value, which can differ from the point's; the undo of a
  `.pre` or a resume, which holds only within one edit; the map a scan is given; and the
  row count above. History is not rewritten, so three earlier messages stay wrong:
  `3e45ea8`'s "Contract:" paragraph, which `d05d4a2`'s item 5 supersedes (after a test
  and an assemble at one boundary an edit is accepted against the candidate, not the
  original); `1e3efc1`'s "29 (E9) {:initial_changed, ...} at every switch"; and
  `d05d4a2`'s ranges for those growth tests, 16.4x to 16.5x and 16.3x to 16.8x, which 48
  runs put at 16.4x to 17.9x and 16.2x to 17.5x, and the check of those fixes, 63 more
  runs of the second, at up to 17.8x.
- **OE-2 · A staged edit of a configuration, after Milestone 2.** The same cycle over the
  whole `%Logex.Configuration{}` and `%Logex.Runtime{}`, switched between two cycles, with
  each M2 item's rule for new state; a task's interval and priority changed while running;
  moving an instance to another task, adding or removing a task, located I/O, devices and
  a function block's members refused (adding or removing a task until its rule is
  verified, a function block's members until M2-5); output points
  left undriven held and reported. *Done when* §4.4's plant, from text and from files on
  disk, running with both motors sealed in and `t1` timing, takes a candidate that raises
  `t1`'s preset and adds an `ons` in `motor.ld`, adds a member to `seal.ld`, shortens
  `slow`'s interval from 50 to 20 ms, removes `snap`, and adds an unlocated global `alarm`
  with an initial value, which the motor reads through `var_external`: test switches the
  resource between two cycles with no instance restarted, no one-shot pulsed and no event
  fired, `m1` and `m2` keeping their state by path with the decided `.pre`, `slow` next due
  within 20 ms, and its report names each instance's preset move and added member, the
  added global, `alarm` joined in each instance, the interval, `snap` stopped and
  `k1_at_trip` held; untest runs the original over the same resource, `snap` back from
  the state it was set aside with, its timers carrying on from where they stopped; assemble
  prunes `snap` and its report names it; a changed `single`, an added task, an instance
  moved to another task, a moved output point and a changed tag type are each refused at
  accept, at their line in `plant.logex` or `motor.ld`; and a step on an edit that has
  ended is refused by the generation counter. (`trip` then runs no instance, a warning,
  which stops nothing. The candidate's `ons` moves no output, so it drives no new point, as
  OE-1's Done-when keeps its own.)

  *Designed 2026-10-13* against `92431a9` (`docs/organisation.md` §4.9, "OE-2's design"),
  from a throwaway spike of the switch on §4.4's plant, and decided the same day, every
  question as recommended (decisions 55–65): the shared global wins when a `var` becomes a
  `var_external`, the instance's own value dropped and reported (55); a timer resumes from
  the resource's clock, an instance's `now` set to it at a switch (56); an instance back
  from aside carries on from where it stopped, its timers not caught up (57); a held output
  is named both as its point and as the instance's var_output (58); a second module,
  `Logex.Configuration.Edit`, beside `Logex.Edit` (59); the generation counter on the
  resource only, a stale edit of a lone instance the host's duty, documented (60); a
  retyped instance may run on another task (61); a reorder of tasks or instances allowed
  and reported as `:order` (62); a candidate `check/1` refuses is the host's mistake, raised
  as `start/1` raises it (63); cancel from accept moves the generation (64); and
  `restart/2` during an edit drops what is set aside and what only the other configuration
  declares, the next switch starting it again (65). It reserves no word, so it owes no
  survey and no `docs/naming.md` stanza. Its landing order, each commit gated alone by
  `mix format --check-formatted`, `mix compile --force --warnings-as-errors` in both
  environments and `mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4,
  and each rule it adds reverted alone and red:
  1. the design record: `docs/organisation.md` §4.9's "OE-2's design" and §7's decisions
     55–65, each "until OE-2" annotated where it stands, and this Done-when;
  2. before the code that depends on it, a spike in the contract walk of OE-1's record of
     each instance across instances on slow tasks, which skip cycles, and what it finds:
     *(done 2026-10-13: fix F11's undo must read the instance's own clock, before decision
     56 moves it to the resource's; and a timer frozen by a switch loses the time since its
     instance's last scan when a later switch resumes it, which decision 56 accepted, a
     known limit; `docs/organisation.md` §4.9, "OE-2's design")*
  3. the per-instance half of `Logex.Edit` moved to an internal `Logex.Edit.Plan`, with no
     change in behaviour, shown as M2-4 showed it for `Logex.Walk`;
  4. the resource's new state, `generation` and `aside`, with their rules in
     `Logex.Runtime`'s one-rule section;
  5. `Logex.Configuration.Edit`'s accept and its refusals;
  6. test, untest, assemble and cancel;
  7. held outputs;
  8. shared globals across a switch;
  9. the report kinds;
  10. the contract walk in `api_contract_test.exs`, with an oracle that knows nothing of
      the implementation;
  11. the Done-when in `end_to_end_test.exs`, from text and from files on disk;
  12. the documents: README's "Changing a running program" with a real run, CLAUDE.md's
      Key Files, `Logex.Runtime`'s one-rule section, `docs/organisation.md` and this
      status.

  **Status: DONE — landed 2026-10-13**, as the twelve commits of its landing order: (1)
  the design record, `626bbae`; (2) the spike's record, `2ec04d9`; (3)
  `Logex.Edit.Plan`, `d237f15`; (4) the resource's `generation` and `aside`, `7812d4e`; (5)
  accept and its refusals, `abd2f39`; (6) the steps, `c00f3f2`; (7) held outputs,
  `08a339c`; (8) a shared global's section change, `ac95a73`; (9) the report kinds,
  `2a15d9b`; (10) the contract walk and the growth tests, `e739834`; (11) the Done-when,
  `9c2e732`; (12) the documents, the commit after it, among them README's "A running
  plant", whose output is a real run. 931 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 864: 923 at the landing, and eight more with the review's fixes below. The messages of (3) to (9) record their mutation tables, every
  rule each adds reverted alone and the full suite judged by its exit code: 107 rules, 8,
  6, 43, 28, 8, 7 and 7, every one red, (6)'s row 6.11 once a test was added for it, the
  one survivor; and two rules found dead, an element with no line sorted last in (5) and
  a connection's member checked to be a var_output in (7), were removed and say why. (10)
  and (11) add no rule: rows of the earlier commits applied alone turn the walk red on 25
  of 25, and the Done-when on 12 of 13, the thirteenth decision 56's clock, which its plant
  does not reach. (1), (2) and (12) are documents.

  The spike of (2) found one defect in the design as written, decided by the record: fix
  F11's undo must read the instance's own `now`, before decision 56 moves it to the
  resource's; and one cost decision 56 accepted, a timer frozen by a switch not counting
  the time since its instance's last scan, a known limit. The walk of (10) found no
  defect in `lib/`; it found that a test then an untest with no cycle between changes
  three things decided rules change (decisions 55, 57 and 56's limit), which it allows by
  name, in every instance's env (the review below found the rest of the resource
  unchecked). Readings and departures, each in its commit: the split drops a var_external
  the started program does not declare at all, rather than keep a copy of a global unused,
  against decision 45's words, which decision 49 forbids (6); `:joined` and `:left` are
  writes, not the facts the design's table called them (8); a held global is one the
  configuration started declares (7); a reorder of the tasks is reported under `:tasks`
  (9); a step checks the generation before the configuration the resource runs (5); an
  instance back from aside keeps its `first`, `switched` and block list (6); the design's
  steps 5 to 7, kept and added instances and the globals, were split by what each commit's
  tests could see, the forecast needing the switch at (5) and the resource after a step at
  (6), with merge and split in (5) and (6) and their reports in (8); and the growth tests
  landed with the walk. Measured at the landing: accept and its steps take 3.90x to 3.95x
  the reductions for 4x the instances of one type, 4.00x to 4.03x for 4x the types and
  4.01x to 4.05x for 4x a program's size, over 32 runs; the walk takes about 9 s alone,
  and the full suite 23.4 s, up from 18.0 s.

  *The review of the landing* (2026-10-14, against `eff585d`) found one defect, fixed in
  the commits after the landing, each with a test that fails when the fix alone is
  reverted: an edit accepted while another was open, superseding it, brought back an
  instance the old edit had set aside, unmigrated under a newer version of its program,
  and kept a global the old edit had kept unused at its value, under another type. At an
  edit's first test both are now dropped before the switch and reported, `:instance_pruned`
  and `:pruned`, so the candidate starts what it names again afresh (decision 66, taken
  with the fix); the contract walk now accepts while an edit is open, superseding it,
  against a fresh start of the candidate. It also found rules no test pinned, each now
  pinned: a timer inside a block an instance holds, resumed by its path when the
  instance comes back from aside; no resume of an instance back at the time it was set
  aside; accept's refusals in line order from a text that puts globals before tasks; and
  the order of the elements only the running configuration has, its tasks and then its
  located globals, which a comment had given as their order there.
  And it found the round trip's claim, here and in §4.9, wider than the walk's check,
  which compared each instance's env, the names set aside and the original's globals
  alone: the walk now compares every state, each set aside, the globals and the tasks,
  allowing by name what a switch's own rules set, an instance's `now` (decision 56), a
  kept one's `switched`, one brought back from aside (decision 57) and a changed
  interval's next due time (decision 40), and both claims say so.

  *From Milestone 2's design (2026-10-02; `docs/organisation.md` §4.9, "One rule for new
  state", and §4.10).* M2-5 brings the edit of a function block's members, by path
  (decision 31), so OE-2 refuses them no longer *(landed with M2-5, 2026-10-04, for the
  edit of one program instance)*; a block type changed for the whole
  configuration changes each program type that holds it, by that type's own plan. A
  changed interval makes the task next due at `min(next_due, now + new interval)`
  (decision 40). An event task's trigger keeps its last sample across a switch, and a
  changed `single`, or an event task's `interval` added or removed, is refused. OE-2 adds
  the generation counter that detects an edit outside the contract; Milestone 2 does not
  reserve it. Until OE-2 lands, a configured plant is not edited. **OE-2 decides** three
  questions Milestone 2 leaves it, none of which an M2 commit depends on. *(All three
  were decided on 2026-10-04 as recommended, `docs/organisation.md` decisions 43, 44 and
  45; how OE-2 reports the write into a shared global when a `var` becomes a
  `var_external` stays OE-2's.)* *(That one was decided on 2026-10-13 by decision 55, with
  OE-2's design: no switch writes the global.)*
  - an instance whose type an edit changes: recommended as a remove plus an add, the old
    instance pruned and the new one started by `Runtime.instance/1`, over a refusal,
    since instances may be added and removed while running and state is keyed by name;
  - a kept global whose initial value changed: recommended reported, as decision 29
    reports a tag's, one rule for two kinds of state; since that extends decision 29, it
    is the maintainer's call;
  - how a switch sees an instance's `var_external`s: recommended, the configuration's
    switch merges each global into the instance's state by the running program's
    externals before `Logex.Edit`'s per-instance switch, and splits it off by the
    candidate's after, so the value kept is the one decision 25 keeps. How OE-2 reports
    the write into a shared global when a `var` becomes a `var_external` is OE-2's to
    design.

### Milestone 3 — the missing instruction set

**Designed and decided 2026-10-14** (`docs/organisation.md` §7, decisions 67–92;
"decision N" in this section is that §7's). §8's domain gaps, in its order: counters, the
other three timers, integer arithmetic, the coil one-shots `osr` and `osf`, and control
flow. A design pass on `970dede` surveyed each item and built a throwaway spike of an up
counter through `Logex.FbType`, the walks and the edit (never landed). The spike counted
with no new mechanism and found six places that assume every built-in is a `ton`:
`Logex.Edit.Plan` raised `FunctionClauseError` on a counter's preset change, reading a
timer's `.en`; the path rule's message in `Logex.Compiler` names `ton`; the unrun warning
says "is a ton"; `Logex.Walk.timers/1` feeds both the edit's preset rule and M2-6's
event-task warning, so widened alone it would warn about counters; a counter an edit adds
while its rung is true counted at once; and a counter in a frozen block misses an edge
that comes and goes while it is frozen. The maintainer took the questions as recommended
but three: IEC's three counter kinds (decision 67), IEC's member names (68), and a zero
divisor reported to the host as a minor fault (78). 67 and 68 sent M3-1 back to IEC's
counter model, whose routine choices are decisions 84–89. After M3-1's review the
maintainer answered three more questions the same day: an `rto` is cleared by an `r`
input member, with no `res` (decision 90); a counter's reset or load acts when its own
rung runs, as IEC's rule has it (91, confirmed as built); and `cv` stays read-only to
logic (92, confirmed).

Each item surveys its words in `docs/naming.md` first, before any code, and lands as a
gated series, each commit gated alone by `mix format --check-formatted`, `mix compile
--force --warnings-as-errors` in both environments and `mix test --warnings-as-errors`,
judged by exit code on Elixir 1.20.4, with its mutation table in its message, every rule
it adds reverted alone and the suite judged by exit code, every survivor given a test.
Each new mnemonic is reserved in any case, and each commit that adds one says which tag
names it breaks. Growth tests are in reductions.

**The order:** this design record, then M3-1 to M3-5.
- **M3-1 first**, decisive by §8, and the item that makes every built-in stop being a
  `ton`, with a type that keeps no time, so "has a preset" and "times" part from the
  start.
- **M3-2 next**, reusing that refactor.
- **M3-3 third.** It is independent, but brings negative literals, which change the
  golden record.
- **M3-4 fourth**, reusing the edge rules M3-1 generalises.
- **M3-5 last**, where dropping it would cost nothing else.

- **M3-1 · Counters: `ctu`, `ctd`, and the type words `ctu`, `ctd` and `ctud`.** IEC's
  three counters (decision 67), with IEC's members lowercased (decision 68): `var boxes
  ctu`, `var hopper ctd`, `var stock ctud`, each a `var` with no initial value. Rung power
  into `ctu boxes 12` is its count input `cu`, into `ctd hopper 40` its `cd`; the number is
  the preset, the `pv` an instance starts with. The reset `r`, the load `ld` and `pv` are
  input members, written by any instruction (`xic reset_pb ote boxes.r`) and read when
  the counter's instruction next runs (decision 84); a `ctud` is run by one `ctu` and one
  `ctd`, from two rungs, their presets agreeing (decision 85). Logic writes only `r`, `ld`
  and `pv` (decision 86). A count needs a rising edge, never on the first scan (decision
  69); a reset or load keeps the edge memory (70); the count stops at the dint's limits,
  setting `ov` or `un` until a reset or load (71); nothing may follow a counter on its path
  (73); a counter under an event task is a configuration warning (72); across an online
  edit each counter's edge memory joins decision 21's block list by path, a rung compared
  without its presets (87), and a moved `pv` forecasts `q` as `:dn_drops` and `:dn_rises`
  (88); and a frozen block holds its counters (89). *Done when* a box counter in a `.ld`
  file, a `ctu` on a photo-eye whose `q` lights a "case full" lamp at its preset and whose
  `r` a button drives, counts every rising edge exactly once over seeded scans, none on the
  first scan and none for a box on the eye at a reset; a `ctud` buffer count, `ctu` on the
  infeed eye and `ctd` on the outfeed, and a `ctd` hopper loaded through `ld`, agree with
  an oracle that knows nothing of logex; a count driven to the dint's top stops there with
  `ov` on until a reset; and an online edit that raises the preset while boxes are
  counted keeps the count, moves `pv`, forecasts `q`, and counts no box at the switch that
  was not a real edge. Its landing order:
  1. the survey: the stanzas `ctu`, `ctd` and `ctud`, and the Counters table's logex
     column, IEC's model and names;
  2. the refactor that stops treating every built-in as a `ton`, with no change in
     behaviour, shown as M2-4 showed it for `Logex.Walk`: each built-in type described as
     data, its instructions, preset member, done member and edge memories; the compiler's
     preset, run and path rules over those instructions, each message in its instruction's
     words; `Logex.Walk.presets/1` beside `Logex.Walk.timers/1`, the edit reading the
     first, M2-6's warning the second; the unrun warning in its type's words; and the
     edit's plan reading each type's preset member and forecast;
  3. the counter types, their instructions and rules, the compiler's refusals and
     warnings, the event-task warning, and the edit's rules for a counter;
  4. the contract walk's generators gaining counters, with an oracle that knows nothing
     of the implementation;
  5. the Done-when in `end_to_end_test.exs`, from text and from files on disk;
  6. the documents: README's instruction table and an example with a real run, CLAUDE.md's
     Key Files, `docs/organisation.md` §4.9's rules for the new state, and this status.

  **Status: DONE — landed 2026-10-14**, as the six commits of its landing order, after the
  design record: (0) the design record, `89dba29`; (1) the survey, `4571826`;
  (2) the refactor that stops treating every built-in as a `ton`, `2edd634`; (3) the
  counters, `eb7ba9c`; (4) the contract walk, `e1fb841`; (5) the Done-when, `84be063`; (6)
  the documents, the commit after it, among them README's "A counter" and the counter in
  "Changing a running program", whose output is a real run. 974 tests pass on Elixir
  1.20.4 (8 of them doctests), up from 932. (2) changes no behaviour: the suite is
  unchanged, and a differential probe of 3,000 seeded programs and 600 seeded edits gives
  identical hashes in its tree and its parent's. (3)'s message records its mutation
  table, every rule it adds reverted alone and the full suite judged by its exit code: 54
  rules, 52 red at once and two survivors, each given a test and red with it. (4) and (5)
  add no rule: (3)'s rows that touch a scan or the edit turn the walk alone red on 28 of
  34, and the Done-when alone on 26, each of the rest red in the full suite and named in
  its commit.

  Readings and departures, each in its commit and its decision: IEC's model sent the
  design back (decisions 67 and 68), so there is no `res`, a counter's reset and load being
  its `r` and `ld` inputs, written by any rung and read at its next run (decision 84); a
  `ctud` is run by a `ctu` and a `ctd` (85); `cv` is read-only, where decision 9 lets logic
  write a timer's `.acc` (86); the conventional RES clears `.CU`, and logex keeps the edge
  memory (70); the conventional CTUD rolls over, and logex stops (71). Two rules the design
  did not name came with the counters: an `ons` on a counter's `r` or `ld`, the first bool
  members logic may write, is refused, since the edit's block list names a storage bit as
  a tag; and a second `ote` is told by its target's path, a ctud's `r` and `ld` being two
  bits. The unknown-type message for a type given from Elixir now names
  `Logex.FbType.builtins/0`, not `Logex.FbType.ton()`. The walk found no defect in `lib/`.

  M3-1's review found no defect in the counters, against IEC and the decisions, and its
  fixes are the commits after (6). Step 3 had changed one rule of OE-1's without saying
  so: a rung is compared without the preset of any `ton` on it too, so an edit that moves
  only a `ton`'s preset no longer blocks an `ons` on its rung. The change loses fewer real
  edges and makes none up, so it was kept, owned by decision 87 and pinned in
  `edit_test.exs`. No test pinned a `ctud`'s forecast, on its `qu`, and one does now. A
  counter's forecast was said to be certain, and holds only unless the run it forecasts
  counts, resets or loads, as decision 88 now says, pinned both ways. Decision 67's words
  had a new `ctd` start from its preset, loaded, where IEC's CTD and M3-1 start it empty,
  `cv` 0 and `q` on until `ld` loads it; the maintainer confirmed IEC's on 2026-10-14, and
  decision 67 and README now say so, as `docs/naming.md` did. The one-rule lists now name
  a counter's blocked edge memory, and README's `ctu` row no `ld`. The maintainer's
  answers to three questions asked after the review are decisions 90–92: an `rto`'s clear
  for M3-2, and two confirmations of what M3-1 built, a reset or load acting at the
  counter's own run and `cv` read-only. The suite is at 977 tests (8 doctests).
- **M3-2 · The other timers: `tof`, `tp`, `rto`.** Each an instruction and a type word, as
  `ton` is, with the `ton`'s members `.pre .acc .dn .tt .en` (decision 68 keeps them for
  timers), in milliseconds. `tp`'s pulse is `.tt`, `.dn` coming on as it ends (decision
  74), and it fires on a rising edge, never on the first scan (75), its edge memory on the
  block list as a counter's is (87); an `rto` keeps `.acc` across a false rung and starts
  again at every restart until `retain` lands (76); nothing may follow any of them (73);
  M2-6's event-task warning is widened to every timer, in its own words; and across an
  edit each has its `.dn` forecast and resume trigger by type. An `rto` is cleared by its
  reset input member, `xic greased ote lube.r`, written like a counter's reset, and there
  is no `res` instruction (decision 90, decided 2026-10-14 after M3-1's review, where this
  was open); what else `.r` clears, and its rule across an edit, are M3-2's design. *Done
  when* a fan's `tof` runs it on for its preset after the motor stops, two instances on 10
  ms and 50 ms tasks stopping the fan at the same logical time, as decision 6 measured
  `ton`; a `tp` sounds a horn for exactly its preset from a fault's rising edge, whatever
  the fault does meanwhile, and not for a fault present at start; an `rto` lubrication
  timer keeps its time across the motor stopping and loses it only to its clear and a
  restart; and the event-task warning names each.

  **Status: DONE — landed 2026-10-14**, as eight commits, M3-1's landing order with step 3
  one commit per timer: (1) the survey, the stanzas `tof`, `tp` and `rto`, `e34712f`; (2)
  the refactor that stops reading every timer as a `ton`, `64fe3d4`; (3) `tof`, `39e0261`,
  `tp`, `795150e`, and `rto`, `6740d16`; (4) the contract walk, `a3e0c33`; (5) the
  Done-when, `035ddae`; (6) the documents, the commit after it, among them README's "Three
  more timers", whose output is a real run. 1032 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 977. (2) changes no behaviour: the suite is unchanged, and a
  differential probe of 4,000 seeded programs and 600 seeded edits gives identical hashes in
  its tree and its parent's. Each of (3)'s messages records its mutation table, every rule
  it adds reverted alone and the full suite judged by its exit code: 89 rules, 82 red at
  once and seven survivors, each given a test and red with it. (4) and (5) add no rule:
  (3)'s 82 rows that touch a scan or the edit turn the walk alone red on 66, and the
  Done-when alone on 31, each of the rest red in the full suite and named in its commit.

  Readings and choices, each in its commit and its decision: a `tof`'s `.dn` is IEC's Q
  and the conventional TOF's `.DN`, on through its delay (decision 93), where decision 74's
  words, "done never means still running on any timer", would read otherwise for a `tof`,
  as the maintainer confirmed after the review, knowing "done" is then on while the run-on
  still counts;
  a `tp` is IEC's TP, its edge memory `.en` on decision 21's block list by path (decision
  94); an `rto`'s `r` clears `.acc`, `.dn` and `.tt`, keeping `.pre`, and `.en` stays
  the rung's, where the conventional RES clears `.EN` too, and is a member kept across an
  edit (decision 95), so a reset held at a switch under a candidate that writes `r` no
  more stays held until a restart, which since decision 96 the switch reports
  `:unwritten`. A `tof` blocks nothing: an edit that turns its rung false starts its delay. A
  new `tof` starts at rest with `.acc` 0, where the conventional prescan sets `.acc` to
  `.pre`. The forecasts reuse `:dn_drops` and `:dn_rises`, a `tp`'s `:dn_rises` its pulse
  ending, as decision 88 reused them for a counter. The walk found no defect in `lib/`.

  M3-2's review found one defect in `lib/`, and its fixes are the commits after (6). A
  `tof`'s `.pre` moved to 0 while its rung is true changed `.dn` with no forecast: its
  delay then ends on the falling edge's own scan, where the original's runs on. The edit
  now forecasts `:dn_drops`, `{0, 0}`, at its next run with its rung false, as decision 93
  now says, pinned in `edit_test.exs` and the contract walk. No test brought a `tof` or a
  `tp` back from aside, where each resumes by `.tt`, not `.en`, and the reviewer's mutant
  reading `.en` for every timer survived: `config_edit_test.exs` now sets aside a `tof` in
  its delay and a `tp` in its pulse, their rungs false, and the configuration-edit walk
  draws `t1` as any of the four timers. An unknown type's two messages named only `ton`
  among the built-in types, from a declaration line and from Elixir: each now lists every
  type word, `Logex.FbType.builtins/0`'s among them, and suggests the nearest, `tpp` told
  of `tp` and `:tof` of `Logex.FbType.tof()`. The messages called an `rto` "a rto": a
  type word's article is now by how it is said, from a table of logex's own type words, so
  "an rto", and a user block's name still takes none of its own. The rest were the
  record's words. §4.9's M3-2 table read a `tp` back from aside as blocked, which it is not,
  as a counter is not: an input that rose while it was aside is a real edge. The one-rule
  lists now name a `tp`'s blocked `.en`. Decisions 93 and 94 claimed MatIEC's bodies step
  for step, and at a preset of 0 MatIEC holds Q one call longer than logex, as each now
  notes. Decision 95 and `docs/naming.md`'s `rto` said `r` clears what the conventional
  RES clears, which clears `.EN` too: logex keeps `.en`, a departure each now owns. §8 maps
  `.dn` to Q but for a `tp`. Asked after the review, the maintainer confirmed decision 93,
  a `tof`'s `.dn` IEC's Q through the run-on, the one exception to decision 74's words.
  Asked too what an edit does to a block's input it leaves no rung writing while it is on, a
  reset held when its rung goes, the maintainer chose decision 96: it keeps its value, as an
  output an edit stops driving does, and each switch reports it by its path, `{:unwritten,
  "lube.r", 1}`, a new kind in `Logex.Edit`'s table and §4.9's, read from the new
  `Logex.Walk.member_writes/1`, for a counter's `r`, `ld` and `pv`, an `rto`'s `r` and a
  timer's `.pre`, in a configuration by each kept instance's path. The suite is at 1044
  tests (8 doctests).
- **M3-3 · Integer arithmetic: `add sub mul div mod neg abs`.** IEC's names, and `neg`
  the vendors' (decision 79); `sqrt` waits for a real type. A result outside a dint is
  brought to the nearer limit and the instruction passes no power on that scan (decision
  77); a zero divisor gives 0 and no power, and the cycle reports it to the host as an
  event, a minor fault naming the instance, the file and the line, the plant running on
  (78), the event's shape M3-3's to design; a literal zero divisor is refused. Negative
  literals land first, a lexer rule with `Logex.Parser.well_formed!/1` and
  `Logex.Declarations.check/1` widened and the golden record regenerated where `-`
  appears, its diff read. *Done when* a fill valve's total, `add total flow total` on
  every scan of a 100 ms task, agrees with an Elixir oracle over seeded flows and closes
  the valve at a setpoint read with `ge`; a total driven past 2147483647, a `div` by a tag
  that is 0, which the cycle reports as its event, and a `mod` of a negative operand each
  give what their stanzas say; and no value outside a dint ever reaches a state.

  **Status: DONE — landed 2026-10-14**, as nine commits, M3-1's landing order with the
  negative literals first, as this item says, and step 3 one commit per family: (1) the
  survey, the stanzas `add`, `sub`, `mul`, `div`, `mod`, `neg` and `abs`, `68e638b`; (2)
  negative literals, with the front end, the printer's generator and the golden record,
  `7445d57`; (3) `add sub mul`, `c9d383e`, `div mod`, `941861a`, and `neg abs`,
  `9220d63`; (4) the divide-by-zero report, `747b27b`; (5) the contract walk, `7837ea0`;
  (6) the Done-when, `1858bc3`; (7) the documents, the commit after it, among them README's
  "Arithmetic", whose output is a real run. 1115 tests pass on Elixir 1.20.4 (8 of them
  doctests), up from 1044. Each of (2), (3) and (4)'s messages records its mutation
  table, every rule it adds reverted alone and the full suite judged by its exit code:
  97 rules, 93 red at once and four survivors, each given a test and red with it (a
  divisor a hand-built env holds as no integer, a bool divisor and `mod`'s destination
  refused, and a block's record of its faults left in its instance's map). A row whose
  first failure was a load-sensitive growth bound or a timeout was run again and judged
  by what failed then. (5) and (6) add no rule: (3) and (4)'s 58 rows that touch a scan
  turn the walk alone red on 48 and the Done-when alone on 22, each of the rest red in the
  full suite and named in its commit. The golden record gained 24 entries, each a new
  source with a `-`, and changed none.

  Readings and choices, each in its commit and its decision: a negative literal is its
  sign glued to its digits, one token, and a sign begins a lexeme, so `a-5` and `5-3` are
  each one mistyped lexeme, named whole, as B2's `1bst` is, never a silent split; it goes
  wherever a literal goes, a preset staying 0 or more, and a configuration file's numbers
  with it, where a negative interval or priority is now a diagnostic in the file's words,
  no longer the host's mistake (decision 97). The power out is IEC's ENO, settled, so
  anything may follow an arithmetic instruction on its path, where decision 73 refuses
  what follows a counter or a timer (decision 98). A result is computed exactly and then
  brought to the nearer limit, so a product far past it stops at the limit of its sign;
  `div` truncates toward zero and `mod` takes the dividend's sign, Elixir's `div/2` and
  `rem/2`, where CODESYS documents a non-negative remainder. A zero divisor gives 0 and no
  power for `mod` as for `div`, where MatIEC's MOD keeps ENO TRUE, as the maintainer
  confirmed after the review, and only a zero
  divisor is reported, an overflow not (decisions 77 and 78). The report is plain data,
  `%Logex.Fault{}`, in a new instance field, `faults`, its last scan's, which a scan
  replaces and `put_inputs/3`, `restart/3` and a switch keep, and a cycle's new event,
  `{:fault, task, instance, fault}`, after its scan's `{:ran, ...}`, a resource keeping no
  fault in its states (decision 99). Every source a literal draws a warning, as two
  compared literals do; a destination that is a source, and a divide by 1, draw none.
  Arithmetic keeps no state of its own: what it writes is a tag's, under every rule an
  edit keeps. The walk found no defect in `lib/`. A commit before the nine, `0a3832a`,
  sets `function_block_test.exs`'s bound on accept reading a block's body once a fifth
  above its figure again, 1.64: the figure had grown from 1.12x, which set the bound of
  1.35, to about 1.35x by decision 96, on the bound, and CI failed it from (4) on, where
  M3-3 moved it about 0.005x higher. M3-3 reads no body more than once: each rung costs
  accept about the same at 100 and 400 instances, and a body read again for each instance
  gives 3.20x.

  M3-3's review found no defect in `lib/`, and its fixes are the commits after (7). Eight
  of the arithmetic's operand slots were pinned by no test, each widened from a dint to
  any type with the suite green: `add`'s second source and destination, the first source
  of `sub`, `mul` and `div`, `mod`'s second source and destination, and `neg`'s
  destination, where `neg d b` wrote -5 to a bool. `validation_test.exs` puts a bool in
  every slot of every arithmetic instruction, each refused at its line. Two of decision
  98's warning rules were pinned by no test: a warning added for a divide by a literal 1,
  and none given for a `mul` of two literals, each left the suite green; the warnings
  test now holds `div d 1 d` and `mod d 1 d`, which draw none, and `mul 2 3 d`, which
  draws its warning. `state.faults`'s message was missing from `runtime_test.exs`'s table
  of every message the runtime raises, and its check could move after the owner's with
  the suite green: the table now holds it, and a state of another program whose faults
  are no list raises the faults' message, as the block list's does. CLAUDE.md still said
  four things M3-3 made untrue: that `Logex.Configuration.check/1` raises a negative
  number as the host's mistake, that `Logex.Declarations.check/1` and `Logex.Tag.new!/4`
  refuse a negative initial value, and that `well_formed!/1` takes a literal of 0 or more;
  each now says what is, and its Key Files give a fault's fields, the `faults` field's
  rule at every step and its check before the owner's, and a `-` that still does not lex.
  `docs/organisation.md` §4.9's "The data path" still read as before negative literals, a
  literal of 0 or more, a negative initial value refused from Elixir and an `ArgumentError`
  test of a negative preset that M3-3 removed; each is annotated as landed with M3-3, as
  are M2-1's landing note and decision 28. The golden record's header named the commit
  under (2) before the series was rebased, `c48bba5`, which is not in its history; it now
  names `68e638b`, and the record regenerated on top of `68e638b` with (2) is byte for
  byte the one committed. Asked after the review, the maintainer confirmed that a `mod` by
  zero behaves as a `div` by zero, 0, no power and a reported fault, noted on decision 98.

  `0a3832a`'s bound held the right figure the wrong way: comparing accept at 50 and 200
  rungs of a body at 100 instances weighs what accept does once a type against what it
  does for each instance, so the type's walks, 67 reductions a rung at `d5df77e` and 436
  after decision 96, moved it with no instance costing more, and another 2x of them would
  have failed 1.64 with no regression. The test now compares accept's cost per rung of the
  body at 100 and at 400 instances, (200 rungs less 50) over 150, which an instance's cost
  drops out of and a type's is the same in: 0.99x to 1.31x over 48 runs, 16 alone and 32
  four at once, bound 1.57; a body read again for each instance gives 3.87x, its
  instructions alone walked again 3.5x, and the type's body read eight times, which
  failed the old ratio at 1.77x, 1.02x to 1.13x. `logex_test.exs`'s "compiling stays
  linear in the program's size" reached 6.88x at main and 7.29x at the tip with four
  suites at once, over its bound of 6.8, and 6.84x in the 48 runs taken to re-measure it.
  What drives it is garbage collection, not the compile: with a heap so large that none
  runs, compiling 4x the tags takes 4.04x to 4.09x the reductions, at `d5df77e`, at main
  and at the tip alike; collection, 65 major ones at 2,000 tags to 13 at 500, each copying
  a heap that holds the program built so far, takes it to about 4.5x in a VM of its own;
  and a busy VM charges the same collections more, 5% more beside eight busy processes, so
  in the suite the count at 2,000 tags rises with the compile's time, 28.4M reductions at
  2.0 s to 44.3M at 10.8 s, while 500's stays at 6.2M to 6.7M. With nothing in logex to
  fix, the bound is now a fifth above the highest figure seen, the review's 7.29x: 8.75,
  which the warnings' old quadratic pass, 13.5x to 13.7x, still fails. The suite is at
  1115 tests (8 doctests).
- **M3-4 · The coil one-shots: `osr`, `osf`.** IEC's transition-sensing coils in the
  conventional form, a storage bit and a pulse bit (decision 80), which pass on the power
  they receive; each storage bit under every rule an `ons` bit has, on decision 21's block
  list, never firing on the first scan (69). *Done when* `osr` and `osf` give, on seeded
  inputs, the pulses `ons` and `xio … ons` give on their own rungs, pass on the power they
  receive, never fire on a first scan, and an edit that adds or changes one blocks it until
  a scan runs it, as decision 21 blocks an `ons`.

  **Status: DONE — landed 2026-10-14**, as M3-1's landing order with no refactor, a tidy
  of two load-sensitive tests from M3-3's review before it: (0) the tidy, `b4be654`; (1)
  the survey, the stanzas `osr` and `osf`, `2460ea0`; (2) the coils, `28470f9`; (3) the
  contract walk, `082632a`; (4) the Done-when, `138f51d`; (5) the documents, the commit
  after it, among them README's "Two pulse coils", whose output is a real run. 1159 tests
  pass on Elixir 1.20.4 (8 of them doctests), up from 1115. (2)'s message records its
  mutation table, every rule it adds reverted alone and the full suite judged by its exit
  code: 41 rules, 41 red at once, no survivor. (3) and (4) add no rule: (2)'s 22 rows that
  touch a scan or the edit turn the walk alone red on 20 and the Done-when alone on 20, the
  other two, a storage bit a hand-built env holds as anything but 0 or 1, red in the full
  suite. (0) measures "compiling stays linear in the program's size" in a process whose
  heap starts at 4M words, where 2,000 tags take one major collection and not 61: 4.07x
  to 4.36x over 32 runs, 16 alone and 16 four at once, so its bound is 5.24, down from
  8.75, which the quadratic mutant, 13.46x, still fails, and the large heap reverted alone
  fails it four at once; and gives the configuration-edit walk a timeout of 300 s, its
  draws kept, after it passed 60 s twice in M3-3's mutation runs.

  Readings and choices, each in its commit and in decisions 100–103: the coils are IEC's
  transition-sensing coils in the conventional set's form, `osr s1 pulse`, the storage bit
  first, each run writing the pulse bit and then the storage bit with the power it
  receives; the power out is that power, settled by IEC and the conventional set alike,
  so anything may follow a coil (decision 100), where nothing follows a counter or a timer;
  the pulse bit may be a member logic may write, never the storage bit, and a second coil
  on it is the second-`ote` warning (decision 101); `osf` sees its fall on its false rung's
  run, and a frozen block holds both bits, so a pulse given at its body's last run stays on
  until it next runs (decision 102); and a coil under an event task is not warned about, as
  an `ons` is not, the record's reading of decisions 72 and 80, left to the maintainer
  (decision 103), who chose a warning after the review (below). Every rule of an `ons`
  storage bit is a coil's: one one-shot of the three to a bit, never a member, any other
  write a warning, the configuration's writer warning naming its one-shot, and decision
  21's block list by name, the whole rung compared without presets, so a coil whose pulse
  bit alone changes is blocked too. The walk's first draft found a gap in its own oracle,
  a restart's fresh bits, and none in `lib/`.

  M3-4's review found no defect in `lib/`, and its fixes are the commits after (5). One
  rule of the block list was pinned for an `ons` and by no test for a coil: a storage bit
  the program that last scanned also writes another way is blocked, and a coil's taken for
  a counter's edge memory, which no logic writes, left the suite green, so that an untest
  gave a pulse no edge made. `edit_test.exs` now holds an `osr` and an `osf` whose storage
  bit the candidate also writes, each blocked at the untest. A coil in a block whose `cal`
  is first true after the instance's first scan reads its storage bit as declared at the
  block's first run, so an `osf` declared 1 pulses there on a false rung, a fall that never
  happened, and an `osr` held true since start pulses, where README and `docs/naming.md`
  said a button held at start steps nothing and called the declared value the one visible
  difference from the conventional prescan. The behaviour is kept, one rule with `ons` and
  the counters (decision 89): decision 102 now records it, README, the two stanzas and the
  runtime's comment on `cal` say so, and `pulse_coil_test.exs` pins the `osf`'s pulse and
  the `osr`'s. `logex_test.exs`'s "compiling stays linear in the program's size" has
  measured since (0) in a heap so large that its collections barely run, where a copy
  costs few reductions: a `Logex.Walk.instructions/1` that appends each rung with `++`,
  12x to 15x the time at 4x the tags, grew 5.27x to 6.42x there and passed its bound of
  5.24 in three of five runs of the suite. The test is now two, the large heap's at 5.24
  and the VM's own heap's, which grew 4.40x to 4.67x alone and 4.87x to 6.19x four at once
  over 32 runs, bound 7.43: the `++` walk grows 12.4x to 12.9x there, the warnings'
  quadratic pass 13.4x in either heap, a linear search for a one-shot's storage bit 7.2x
  in the large heap and 7.6x in the VM's, and a count of the rungs at every rung 6.4x in
  the large heap, each failing at least one. A `++` in `Logex.Warnings.of/2` alone, 4.3x
  and 5.8x to 6.0x, still passes both. Over the same 32 runs the large heap's figure
  reached 4.50x four at once, 16% under its bound of 5.24, so on landing the bound was
  set a fifth above it, 5.40, as CONTRIBUTING's growth practice asks. The readings
  above credited decisions 100–103 with a coil's rung compared whole, so that one whose
  pulse bit alone changes is blocked, which none of them recorded: decision 101 now does,
  with its cost, one real press, where the press rises on the first scan after the switch,
  and why it is kept though decision 87's reason for leaving presets out would leave the
  pulse bit out too: one rule with `ons`, whose rung is compared whole, what its pulse
  drives among it. README's coil under an edit says so. Asked after the review, the
  maintainer confirmed decision 102's frozen pulse: a pulse inside a block whose `cal` is
  false stays on until the block runs again, as everything in a frozen block holds, which
  M3-4 built; decision 102 and §7's opening record it, and `pulse_coil_test.exs`'s frozen
  block now reads the block's own pulse bits beside the program's tags, which the
  decision's alternative, a false `cal` clearing them, had changed with only the contract
  walk red. Asked too whether a one-shot under an event task should be warned of, as a
  counter is, the maintainer chose a warning for all three, `ons` with the coils,
  superseding decision 103's "no warning" and what decision 72 said of an `ons`: each
  one-shot a program instance runs under a task with a `single`, at any depth, is a
  warning on the configuration's `warnings` in its own words, after the instance's timers
  and counters, a block's by its storage bit's path, citing its instruction's own file and
  line, from a new fact, `Logex.Walk.one_shots/1`, read once a program type as the timers
  are, so that the e-stop's own coil, `xic estop osr s1 pressed`, is told it never pulses.
  `configuration_test.exs` pins it from text, from Elixir and from files on disk, and
  `walk_test.exs` the fact, whose two growth tests walk it too, their bounds again a fifth
  above the highest of 48 runs, 1.82 and 19.0. Two of the record's words were stale:
  `docs/instruction-sets.md` §2.2 still had Ed 3's numbering from a secondary source
  alone, where M3-4's survey read Table 76's features 8 and 9 in the standard, and it now
  says so, in §10 too; and CLAUDE.md said the compiler and `Logex.Edit` read
  `Logex.Walk.storage_bits/1`, where they read `one_shots/0` and only `Logex.Warnings` and
  the configuration's writer warnings read the bits. CLAUDE.md's Key Files now say which
  reads which, and bring the review's rules in: a block's later first run, the frozen
  pulse confirmed, a pulse bit edited alone, `one_shots/1` and the one-shot event-task
  warning. The suite is at 1167 tests (8 doctests).
- **M3-5 · Control flow: forward `jmp` and `lbl`, and no MCR.** A forward jump only, a
  label first on its rung, labels a routine's own namespace (decision 81); skipped rungs
  freeze as a false `cal` freezes a block, a timer in them catching up when next run (82);
  and no master control zone, ever (83). *Done when* a forward `jmp` over a manual-mode
  section freezes that section's outputs, counters and timers exactly as a false `cal`
  freezes a block; a backward jump, a missing label and a label not first on its rung are
  each a located diagnostic; and a program with no `jmp` scans within a measured bound of
  its cost before.

  **Status: DONE — landed 2026-10-15**, as M3-1's landing order with a refactor before
  the jump, as M3-1 and M3-2 had, and Milestone 3's done sentence walked before the
  documents: (1) the survey, the stanzas `jmp` and `lbl` and the master control zone's
  row, "not added, for good", `47b5d46`; (2) one rung loop for a program's rungs and a
  block's body, with no change in behaviour, `8dda93b`; (3) the jump, `dcadb6d`; (4) the
  contract walk, `5035307`; (5) the Done-when, `7a514e7`; (6) Milestone 3's done sentence
  in `logex_test.exs`, `825bb81`; (7) the documents, the commit after it, among them
  README's "A forward jump", whose output is a real run. 1223 tests pass on Elixir 1.20.4
  (8 of them doctests), up from 1167. (3)'s message records its mutation table, every
  rule it adds reverted alone and the full suite judged by its exit code: 59 rules, 58 red
  at once and one survivor, a `tp`'s mark on a skipped rung, whose rule was deleted, since
  one `tp` runs its instance and a skipped one leaves the instance out of the scan's
  record, which keeps all the instance holds. (2) adds no rule: a differential probe of
  3,000 seeded programs, 852 of them compiling, and 800 seeded edits gave identical hashes
  in its tree and its parent's. (4), (5) and (6) add no rule either: (3)'s 21 rows that
  touch a scan turn the walk alone red on 15, the Done-when alone on 8 and the done
  sentence alone on 6, the rest red in the full suite, by `jump_test.exs`'s programs built
  by hand and its growth tests. A scan of a program with no jump costs fewer reductions
  than before M3-5, the least of 50 scans: 308 against 319 for the README motor and 39,126
  against 41,126 for 1,000 rungs. The Done-when bounds the rung loop's cost per rung
  beside its instructions' at 1.207, the ratio a loop a fifth dearer than before would
  give: 1.179 at `16d47ed` and 1.141 at (5), over 32 runs each.

  Readings and choices, each in its commit and in decisions 104–107: the jump is taken
  once its rung is done, IEC's rule 3, and `jmp` passes on the power it receives, so
  anything may follow it, anywhere on its rung, one a rung (decision 104); a label is a
  name, never a tag nor an integer, of its routine's own namespace, a twin in another case
  refused and one no `jmp` names a warning (105); a memory an edit's switch blocks on a
  rung a jump skips stays listed until a scan runs its instruction, as decision 32 keeps
  one in a frozen block, and a rung is compared whole, its `lbl` and `jmp` among it (106);
  and the walks and the warnings read a rung a jump may skip as any rung, so two `ote`s on
  one tag in sections a jump makes exclusive are still the second-`ote` warning (107). The
  contract walk's first draft found a gap in its own oracle, a restart between a test and
  an untest leaving every memory fresh, and none in `lib/`. `jmp` and `lbl` are reserved
  in any case, so a program with a tag of either name no longer compiles.

  M3-5's review, on 2026-10-15, found a rule no test pinned, a host mistake the runtime
  ran on, a word a block's body took as a label, a suggestion of a jump back, and words
  gone stale, its own and older, and its fixes and the maintainer's two answers after it
  are the commits after (7). A skipped rung marks each listed memory wherever on it its
  instruction stands, a group's legs among the places, and a mark of its top-level series
  alone left the suite green. `jump_test.exs` now holds a one-shot on a group's second
  leg, one two groups deep, and a ctud's side on a leg while its other side runs, each
  kept listed through the skip and blocked at its first run; and the contract walk puts
  the one-shot, each side and the `cal` on a leg of a group now and then, first or second,
  whose other leg passes no power, its edits moving a memory into a group or out. The
  walk's draw of a program with no jump, `1..0`, which Elixir reads as two steps down,
  gave two jumps, so that no program was drawn without one, and gives none now. A host's
  env holding a key the runtime keeps a scan's records under changed the run: `%{jump:
  "nowhere"}` skipped every rung after the first, and `%{faults: [div: 3]}` gave a fault
  no divisor met, a tolerance `fault_test.exs` and `function_block_test.exs` had pinned
  for `:faults` and `:ran`. Every entry point that takes a state, `Logex.Edit`'s steps
  among them, now refuses one whose env holds `:faults`, `:jump` or `:ran`, all it holds
  named in one message `runtime_test.exs`'s table pins, checked with the env's shape,
  before the clock and the owner: no state that `instance/1`, a scan, `restart/3`, an
  edit's switch or a resource gives holds one, nor any key but a tag's name. A `cal` drops
  them from its instance's map before its body runs, since the values in a state are not
  checked each scan and an instance is one, read whatever it holds. The check is three
  lookups in a guard, so the README motor's scan still costs 308 reductions; a key no tag
  is but none of those is never read, and stays unchecked, since a check of every key
  would cost each scan a step a tag. A block's body took `lbl function_block` and `jmp
  function_block`, where the word that heads a block's file is reserved in one, in any
  case (`docs/organisation.md` §4.8), as README and decision 105 say: each is now an error
  at its line, `Function_Block` among the spellings, as the word is for a tag there, a
  program's file still taking it, and `Logex.Compiler.lowered?/1` holds a body to it. A
  `jmp` that names no label was told the nearest label of its routine, one on an earlier
  rung or its own among them, which followed gives "jumps back"; the nearest on a later
  rung alone is suggested now. Five passages still said every rung runs at the top level:
  `call/4`'s doc, two comments in `Logex.Edit.Plan`, on the bits a scan leaves pending and
  on a timer's `last`, and in `docs/organisation.md` §4.9's block-list paragraph and
  decision 21's note, each now saying what a skipped rung leaves, the two notes with a
  dated one of decision 106. Older words were stale too: `docs/organisation.md`'s Status
  said the configuration file, shared globals and event tasks were not yet implemented,
  and now says Milestones 1 to 3, OE-1 and OE-2 have landed; `docs/instruction-sets.md` §7
  had `cal` deferred, a `res` that decision 84 dropped, `ret`, `shl` and `shr` with no
  marking though none exists, the up/down counter as none and a counter's bounds unknown,
  and §8 called `res` planned; and `docs/naming.md`'s Program control table had `cal`
  deferred and `ret` unmarked, which are corrected in place, as each survey since M3-1 has
  corrected that table's logex cells, the stanzas being what the file keeps append-only,
  and its `shl` and `shr` are marked deferred with them, so that §7's column stays
  naming.md's. Asked after the review, the maintainer confirmed two of M3-5's choices,
  which decisions 106 and 107 and §7's opening record, dated: two coils on one tag in
  sections that jump over each other keep the second-`ote` warning, since the checks read
  the program's text, not which rungs run (decision 107); and an edit that only adds a
  `lbl` or a `jmp` to a one-shot's or a pulse coil's rung blocks it once, the rung
  compared whole, one rule with decision 101, at the cost of one possible press (decision
  106), which `edit_test.exs` now pins for an `osr` beside the `ons` it pinned, a press
  that rises on the first scan after the switch pulsing nothing and the next one pulsing.
  The suite is at 1231 tests (8 doctests).

**Milestone 3 is done when** a small bottling line written in `.ld` files runs under a
`.logex` configuration through `Logex.Runtime.cycle/3`, against an oracle that knows
nothing of logex: a conveyor whose `ctu` counts bottles into cases, reset through its `r`
when a case leaves; a buffer whose `ctud` counts bottles in and out; a fan run on by a
`tof` after the motor stops; a horn pulsed by a `tp` on a jam; a fill valve whose `add`ed
total closes it at a setpoint, a zero divisor in its rate reported as a minor fault while
the line runs on; an `osr` that steps a case counter; and a manual-mode section skipped by
`jmp`. While it runs it is edited through `Logex.Configuration.Edit` to change the case
size and the run-on time, with no count lost, no phantom count and no timer reset, and the
Done-when tests check each piece against its rule. *(Done 2026-10-15, with M3-5:
`test/logex_test.exs`, "Milestone 3's done sentence, as written in PLAN.md", walks it
clause by clause from files on disk through `Logex.Configuration.compile_file/1`: a
conveyor and a filler on a 10 ms and a 100 ms task, 1,200 seeded cycles against a model
of the line in plain Elixir, every cycle's outputs, events and bottle count exact, edited
after cycle 600 to a case of 24 and a run-on of 500 ms, the count kept, a bottle on the
eye across the switch counted once, and the run-on in progress at the switch ending 500
ms after the motor stopped. "The Done-when tests" are read as M3-1's to M3-5's in
`end_to_end_test.exs`, beside each item's own test file.)*

### Milestone 4 — the wall-clock runner

**Designed and decided 2026-10-17** (`docs/organisation.md` §4.11 and §7, decisions
108–121, and 122–128 after M4-1's review; "decision N" in this section is that §7's). §8's
second domain gap: a runner that runs a configuration's resource on the real clock,
through device adapters, with a watchdog, the one piece of logex that reads a clock. A
design pass on `d3931bd` designed it and built a throwaway spike of every piece, on the
branch `backup/runner-design` (`spike-runner/`), never landed. The maintainer changed
three of its answers: rounds run back to back while untimed programs exist, a share of the
time, 20% unless set, kept for the runner's own work, as IEC's rule 4 and the conventional
continuous task with its system overhead time slice (decision 108), not on a steady beat;
a watchdog is 500 ms unless set (109), not required; and each task has its own, on its
line (110), not one for the controller. Two the maintainer added, outside the questions
put: a configuration may declare its one continuous task, `task main continuous watchdog
200` (111); and a device may report its inputs' changes, an event task whose trigger
changed running at once between rounds, a device that cannot report read every poll
period, 10 ms unless set (112). The rest the maintainer took as recommended: a watchdog
trip zeroes every output once, stops, reports and waits for a restart, the last state
readable, confirming decision 14 (113); a failing device trips (114); a crashed runner
stays down (115); a normal stop zeroes every output first (116); and input forcing comes
now, kept across a restart and listed in the status (117). Decisions 118–121 are the
record's routine choices where the answers left one open: the cycle in steps, so that the
runner times each task's run (118); each device's heartbeat at the longest watchdog plus a
poll period, the runner refreshing every device at least once a poll period (119); every
device read every poll period, a reporting one passing its changes on between reads, and
each change of a trigger its own round (120); and the share and the poll period options of
the runner, not words of the configuration file (121). After M4-1's review, on 2026-10-18,
the record took three more where it had been silent: rounds back to back one a clock
millisecond at most, so that they are defined on a clock that does not move, and the share
served in the conventional table's slots, a share of the continuous task's time and the
runner's own, from 10% to 90% (122); a trigger logic writes rounding at the next
millisecond, which closes decision 50's livelock (123); and a device passing its changes
on by a call the runner answers once the round they cause has run, so that a test's
`Logex.IO.Sim.set/3` returns after that round by construction (124). Two more replace
looser rules: every device refreshed before every step, each refresh carrying that step's
own deadline, its watchdog plus a poll period, which supersedes decision 119's rule and
its cost (125); and a round's watchdog trip naming each of its steps with its time, so
that a slow timed task in the round is seen (126). And the maintainer answered once more
the same day, outside any question put: forces survive a crash, kept in a file, as the
conventional family does, so that a runner started after a crash comes back with every
input that was forced still forced and listed (127), with the record's choices on how.

Each item lands as a gated series, each commit gated alone by `mix format
--check-formatted`, `mix compile --force --warnings-as-errors` in both environments and
`mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4, with its mutation
table in its message, every rule it adds reverted alone in a copy of its commit and the
suite judged by its exit code, every survivor given a test. Throughout:
- **`Logex.Runtime` stays pure** and never reads a clock; nothing compiles to BEAM; a host
  mistake raises an `ArgumentError` whose message a test pins; and each new public module
  joins `runtime_test.exs`'s exact-surface pin.
- **Every rule is tested on the manual clock.** A test on the real clock asserts liveness
  only, short, with bounds far from what load can reach, since CI shares its cores and
  CONTRIBUTING.md forbids skipping or quarantining a test.
- **Growth is tested in reductions**: a round's work linear in the points and the tasks,
  `start_link/1`'s checks linear in the devices and points, but for a sort of the names,
  n log n, and a refusal's did-you-mean, quadratic in the names it is told against and the
  devices, which only a host's mistake pays, as §4.10 accepts for a configuration's.
- **A configuration file's new words** (M4-2) are surveyed first, and carried through the
  reader, the printer, the round trip, its totality and growth tests,
  `configuration_text_test.exs` and `naming_test.exs`.

**The order:** this design record, then M4-1 to M4-7. M4-1 first, since it needs nothing;
M4-2 next, the configuration's words the runner reads; M4-3 the runner on them; M4-4 its
watchdogs and faults; M4-5 its edits and forcing; M4-6 the contract walk over all of it;
and M4-7 the documents.

- **M4-1 · The clock, the I/O contract and the simulated device.**
  `Logex.Runner.Clock`, the behaviour a clock implements, `now_ms/1`, `wake_at/4` and
  `cancel/2`, with two clocks: `Logex.Runner.Clock.Monotonic`, `System.monotonic_time/1`
  in milliseconds and `Process.send_after/4` to an absolute time; and
  `Logex.Runner.Clock.Manual`, a process a test moves, its `advance/2` delivering each
  timer due on the way in time order, ties in the order they were set, and returning once
  each receiver has handled its message, by a call to the receiver from the process that
  sent it, and its `pass/2` moving time inside a step and delivering nothing.
  `Logex.IO`, the adapter behaviour, `init/3`, `read/1`, `write/2`, and the optional
  `report/2` and `close/1`, each failing by returning `{:error, reason, state}` rather than
  raising, with `%Logex.IO.Point{}`, a point's name, direction, address and type.
  `Logex.IO.Sim`, an in-memory device in a process of its own: its inputs set, its outputs
  and every write recorded, its reads counted, its changes reported to the device that
  opened it where it was started to, and one failure acted out on the call it names: an
  error, a raise, a throw, an exit, a hang, a delay on the manual clock, or a value of the
  test's choosing. And the grouping of a configuration's located points by device,
  `Logex.IO.points/1`, with `Logex.IO.bind!/2`, a host's bindings checked against it,
  every mistake at once, as `start_link/1` will check them. *Done when* the manual clock
  delivers timers in time order, ties in the order they were set, a timer set while one is
  handled within the same advance, and returns from `advance/2` only once each receiver
  has handled its message, by construction; the monotonic clock wakes a process no sooner
  than its time, live; `Logex.IO.Sim` reads, writes, records every write, reports each
  change to the device that opened it and acts out each failure; and §4.4's plant's
  points, from files on disk, group as `panel` with eight inputs and four outputs and
  `drive` with two outputs, each binding mistake raised with its pinned message. Its
  landing order:
  1. the clock;
  2. the behaviour and the simulated device;
  3. the grouping, with its host mistakes pinned;
  4. the documents: CLAUDE.md's Key Files and this status.

  **Status: DONE — landed 2026-10-17**, as the four commits of its landing order, after
  the design record: (1) the clock, `587ac41`; (2) the behaviour and the simulated device,
  `29c23c5`; (3) the grouping, `5d09f89`; (4) the documents, the commit after it. 1284 tests
  pass on Elixir 1.20.4 (8 of them doctests), up from 1231. Each of (1) to (3) records its
  mutation table, every rule it adds reverted alone in a worktree of its commit and the
  full suite judged by its exit code: (1) 31 rules, 30 red and one survivor, a timer set
  relative to now rather than absolute, kept on an argument M4-1's review found half
  right, corrected below; (2) 55, all red; (3) 28, all red. `Logex.Runtime` is
  unchanged.

  Found while landing, each in its commit: the VM refuses an absolute timer from before it
  started, so the monotonic clock brings a time already past to now, as the behaviour says
  a past time is sent at once; `{:ok, %{}, ^state} =` in an assertion matches any map,
  which let a mutant through, and the tests compare values whole; and a wait shorter than
  its default is caught by slow receivers only while the machine keeps up, so each default
  wait is pinned by a test that waits it out. Chosen while landing, beyond the design: the
  simulated device's `set/3` reports from the caller, not from the sim's own process, so
  that the sim never waits on a device that may be calling it, by construction rather
  than for a deadlock seen; the reporting callback is `report/2`, not `handle_info/2`, so
  that an adapter that is also a GenServer meets no clash; the manual clock's `wait:` and
  `pending/1`, the simulated device's `wait:` and `reads/1`; and `bind!/2`'s order of
  mistakes, a key that is no device's name first.

  M4-1's review, on 2026-10-17, found host mistakes taken or misread, rules no test
  pinned and words gone loose in its design record, and its fixes are the commits after
  (4). A `wait:` longer than the VM waits for an answer, 2^32 − 1 ms, was taken by the
  manual clock and the simulated device, and then escaped `advance/2` and `set/3` as an
  `ErlangError`; each refuses it at start now, in its words, and takes 4294967295. A
  receiver of the manual clock, or a device a sim reports to, that went down with the
  reason `:timeout` while it handled its message was told it had not answered, since its
  exit has a wait's shape, and the advance stopped there, its later timers undelivered;
  each is passed over now, as one down for any other reason is, and only one still alive
  that has not answered is the mistake. Eight of the review's mutants left the suite
  green, each a rule no test reached: an input never set taken as changed when set to 0,
  a delay acted out after its call rather than before, an adapter's module not loaded
  before its callbacks were looked for, `pending/1` in the reverse of delivery order, the
  clock's `wait:` and the sim's ignored for 5000 ms, and the clock and the sim started
  unlinked; a test now kills each, the waits by a receiver that answers after a second,
  well within 5000 ms, and the delay by a write found asleep with nothing written. (1)'s
  survivor was kept as firing when the absolute timer does, but for the microseconds
  between the read of now and the call. That holds for a relative timer that reads now
  once, `max(at - now, 0)`, which shows only drift, never more than the time from the
  read to the call: it survives still, since only a trace of the call, which sees
  `[abs: true]` given to `:erlang.send_after/4`, can tell it, and such a test would pin the
  implementation rather than a behaviour. The mutant (1) tabled read now twice, `max(at,
  now) - now`, which comes out a millisecond below 0 wherever the tick falls between the
  two reads, and the VM refuses it, so a wake raised: 9 of 200,000 at a past time in the
  review's probe. `clock_test.exs` now wakes a process at a past time for 200 ms of the
  clock and finds no raise, which that mutant fails in every run. (1)'s commit message
  stands as landed, and this is its correction. An adapter's own options could not be
  checked when the bindings were: `{Logex.IO.Sim, []}` and `{Logex.IO.Sim, sim: :x}` each
  bound, and were refused only inside `init/3`, in the device's process, where §4.11 makes
  a raise `{:io_init, ...}` or an I/O fault, a host's typo reported as the plant's state.
  `Logex.IO` has a sixth callback, `check/3`, optional, given what `init/3` will be, which
  `bind!/2` calls in the host's process for an adapter that implements the behaviour and
  has keyword options, each line it gives one of the one `ArgumentError`, and a check that
  gives no list of messages told so; `Logex.IO.Sim`'s holds its options to `sim:` alone, a
  sim that runs, and `init/3` raises the first of the same. One sim bound to two devices
  passed `bind!/2`, its reports reaching only the device that opened it last and both
  devices' outputs written over each other, a takeover `io_test.exs` had pinned; a sim
  is one device's now: another device's process may open it only once the first has
  closed it or gone down, the process that opened it may open it again, `check/3` refuses
  a sim another device holds open, and the sim refuses an open that came second, in one
  message naming the device that holds it. One `bind!/2` that binds one sim to two
  devices still passes, since neither has opened it, and the second device's `init/3`
  raises. `Logex.IO.points/1`'s doc said a configuration `Logex.Runtime.start/1` refuses
  raises in its words, but a value that is no configuration was refused in
  `Logex.Configuration.check/1`'s; `start/1` itself refuses it now, so `points/1` and
  `bind!/2` give its words, which `io_test.exs` pins for a value that is no struct, a map
  and a struct that lacks its keys. `bind!/2`'s refusal of many devices bound that no
  point is at took time quadratic in them and the devices, its did-you-mean's and a sort
  of the devices' names for each, 1,000 of each in 1.28 s and 2,000 in 5.6 s, though PLAN
  said linear and the doc said nothing; it sorts the names once a call now, its doc says
  what the did-you-mean costs, as `Logex.Configuration`'s does, and the plan's growth rule
  above is qualified. A growth test with names no did-you-mean is looked for pins the rest
  at n log n: 16x the devices and bindings take 16.8x the reductions, bound at 24, where
  the sort for each took 38.4x. The suite is at 1303 tests (8 doctests).

  The review also found the design record silent on four things the runner must do the
  same way on either clock, and its answers are decisions 122–124, taken on 2026-10-18
  with M4-3's Done-when and landing order above changed to match. Rounds back to back had
  no defined behaviour on the manual clock, where a round takes no time: a receiver that
  set its next wake for the time it was at took 49,989 deliveries in a second with the
  clock at 0, and rounds after one `advance/2` came out 19,772, 2,658 and 2,658 in three
  fresh runs. A back-to-back round is now a wake at the millisecond after the one the
  round before began in, or at once where it took a millisecond or more, so at most one
  round runs a clock millisecond, on either clock, and `advance(clock, n)` runs n; the
  share is served in slots by the conventional formula, from 10% to 90%, a share of the
  continuous task's time and the runner's own with the timed tasks' runs left out, as the
  conventional rule quoted leaves out periodic and event tasks; and "between rounds" reads
  "at the start of the next round, never preempting one", where the record had also said
  a round runs its due timed tasks first (122). Two event tasks that write each other's
  trigger rounded at once for ever in zero time under decision 120, the livelock decision
  50 left to the runner; a change logic writes now makes its round at the next
  millisecond (123). And a round a report causes gave a test nothing to wait on: in a
  model, 200 sets each followed by a read of the outputs found 33 rounds run; a device now
  passes each change on by a call the runner answers once the change is merged or the
  round it makes has run and been written, so `Logex.IO.Sim.set/3` returns after that
  round by construction, and a real run takes each device's changes one at a time, in
  order (124). Decision 119's heartbeat refreshed a device only when a refresh was due and
  only between steps, so in a model a step that took exactly its watchdog, 9 ms after the
  last refresh, left 1 ms before the device latched, and a runner stuck in the conveyor's
  task held its contactor for the fan's 2 s; every device is now refreshed before every
  step, each refresh carrying that step's own deadline, so a stuck conveyor's step zeroes
  every device at its 50 ms and a poll period, the poll period the margin, and the record
  says why a heartbeat for each device fails with no preemption (125, superseding 119's
  rule and cost, with M4-4's Done-when). Decision 118 passed over timing the whole cycle
  because it would trip naming a task that was not slow, which decision 111's watchdog
  for each round does when a timed task in it is slow; a round's trip now names each of
  its steps with its time (126). M4-6's Done-when asked for every trip reason, among them
  `{:internal, message}`, which the host contract makes unreachable; it is left out of the
  walk, and M4-4 reaches it through one hidden option, a seam named there. The
  milestone's done sentence had a stopped or killed runner restarted, though such a
  runner is gone, and asked for each timed task "on its grid as closely as the machine
  allows", which no test can check; it says the host starts a new runner, and that no
  run comes before its grid time and that runs and periods reported missed together make
  one for each grid time. And §4.11 said the simulated device reports each input it is
  set to, where it reports changes, and gives a value of the test's choosing for a read
  alone, where a report takes one too, and decision 120 paraphrased p.46 as a warning of
  a pulse unseen, where it warns of an overlap; each is corrected. Asked nothing, the
  maintainer answered once more on 2026-10-18: forces survive a crash, kept in a file, as
  the conventional family does (127). It is recorded, with M4-5's Done-when and the done
  sentence to match, and built with M4-5: the host names the file, `forces:`, and a runner
  without one takes no force; each force and unforce writes it whole and atomically;
  every start reads it, a force the configuration cannot take refused there as the host's
  mistake; `unforce_all/1` clears it; and the status always lists every force. IEC 61131-3
  says nothing of forcing, and the conventional family's keeping of forces through a
  power cycle, with a "forces on" indicator, is unverified in the manuals saved *(checked
  2026-10-20, decision 127: the FORCE status indicator and forces held by the controller
  are verified, 1756-PM004L pp.52–53; a power cycle is not found)*.
- **M4-2 · Watchdogs and the continuous task in a configuration.** The survey first: the
  stanzas `watchdog` and `continuous` in `docs/naming.md`, then the words in
  `Logex.Configuration.Text.keywords/0` and `naming_test.exs`'s pinned list. A task line
  takes `watchdog <ms>` after its priority, 1 to 2147483647 ms, 500 unless set (decisions
  109 and 110); one line may declare the continuous task, `task main continuous`, with a
  watchdog or none and no interval, single or priority, a second refused (decision 111).
  `Logex.Configuration.Task` gains `watchdog` and `continuous`, `name` alone enforced,
  since a continuous task has no priority, and `check/1` says what a line can say, from
  Elixir data as from text, a task with no priority still shown one of its own kind. A
  program with no `with` runs in the continuous task, and `with main` means the same
  (decision 111). In the core, a continuous task's instances run with the task-less ones,
  last, once a cycle, reported under its name; `next_due_in/1` counts it not; and
  `overlaps/1` lists it at 0, as an event-only task. `Logex.Configuration.Edit` refuses the
  line added or removed while running, as any task, moves nothing for `with main` added or
  taken away, and settles a watchdog's rule across an edit, with its report if one may
  change. *Done when* §4.4's plant, every task line with a watchdog and a box counter in
  its continuous task, `task main continuous watchdog 200` and `program boxes counter`,
  reads, prints back exactly, compiles with no warning and cycles as before, the box
  counter's runs reported under `main`; each refusal is pinned as a whole list from source
  and from data; the round trip, its totality and its growth hold with the new words; and
  an online edit that adds `with main` moves nothing.

  **Status: DONE — landed 2026-10-18**, as seven commits, M2-6's pattern: (1) the two
  stanzas and decision 129, the rule across an edit that decision 110 left to M4-2,
  `8fefe54`; (2) the fields, `check/1`'s rows and the core from Elixir data, `06a81d2`;
  (3) the reader, `entries!/1`, the printer and the reserved words, every check again
  from source, `f68cc25`; (4) the round trip, totality and growth with the new words,
  `847a091`; (5) the edit rules, with the contract walk, `6499982`; (6) the Done-when from
  text and from files on disk, `1e8047d`; (7) the documents, the commit after it. 1331
  tests pass on Elixir 1.20.4 (9 of them doctests), up from 1303. Each of (2), (3) and (5)
  records its mutation table, every rule it adds reverted alone in a worktree of its
  commit and the full suite judged by its exit code: (2) 26 rules, 25 red and one
  equivalent survivor, the continuous task among a cycle's timed tasks, which its own
  rule of no due time never lets run; (3) 24, all red; (5) 12, all red, each failing the
  contract walk too. `Logex.Runtime` changed as this item says, and no more: a
  continuous task's instances run with the task-less ones under its name, it is never
  due, and it is listed at 0; it reads no watchdog.

  Chosen while landing, each in its commit: `Logex.Configuration.watchdog/1`, the one rule
  for a task's watchdog, as `initial/1` is a global's, joining the public surface;
  `continuous` straight after the name, a word with no value, and `watchdog` after the
  priority, each once, out of order shown a line with it in place; a continuous task
  given inputs told them all in one diagnostic; a task whose `continuous` is the host's
  mistake read as neither kind; a task with no interval, single or priority offered the
  continuous task where none is declared; a task that needs a priority shown its own
  watchdog; and, decision 129, a watchdog changed while running, reported in ms, 500 for
  none, the continuous line's change a task's, a task's kind change its one refusal, and
  the untimed instances one place and one order under the continuous task's name. Found
  while landing: the contract walk's new draws moved its seeded stream, and its old seed
  no longer reached a `tp`'s resume in 500 configurations, so it takes another that
  reaches every kind; and a test helper named as one of `end_to_end_test.exs`'s own made
  the suite abort on its warnings with every test green, which the gate's exit code
  caught.

  M4-2's review, on 2026-10-18, found an edit's cost grown with the continuous task, and
  its fixes are the commits after (7). Decision 62's orders looked for the continuous
  task, in the original and in the candidate, once an instance, so accept, test and
  untest took time in the tasks times the instances: 4x of both took 10.09x the
  reductions in the review's probe, 3.98x before M4-2. Each is looked for once an edit
  now, and `config_edit_test.exs`'s growth tests gain the tasks and instances grown
  together, bound at 4.83. A mutant of `check/1` that skipped the watchdog of a task
  whose `continuous` is the host's mistake left the suite green, since the one task
  pinned had a watchdog that is a host's mistake too; a task with `continuous: "yes"` and
  a watchdog of 0 is now told both. The continuous line moved among the task lines
  was reported as a reorder of every task, `{:order, :tasks, names}`, though it is never
  due and takes part in no tie, decision 62's reason for reporting the tasks' order; the
  tasks' order is the timed tasks' now, a note on decision 129, and such a move reports
  nothing. `Logex.Configuration.watchdog/1` gave back a watchdog of 0 or -5, which no
  check had passed, as a task's; it raises for one outside 1 to 2147483647 ms now, as for
  one that is no integer, since every caller reads a checked task. The suite is at 1333
  tests (9 doctests).
- **M4-3 · The runner: start, rounds, devices, stop, read, subscribe.** *Done when* §4.4's
  plant with M4-2's box counter, loaded from files on disk through
  `Logex.Configuration.compile_file/1`, runs through `Logex.Runner` on the manual clock and
  two simulated devices, the panel reporting its changes and the drive only read, over a
  seeded sequence of presses and waits, and every round's outputs, events and `get/2`
  values equal those of `Logex.Runtime.cycle/3` called directly with the same
  `elapsed_ms` and inputs, an oracle that knows nothing of the runner. The run must also:
  - repeat exactly from fresh processes;
  - run its first round at once after start;
  - run one round each clock millisecond while the box counter exists, `advance(clock,
    n)` running exactly n (decision 122), the runner's own work served within its share,
    its slots, C ms of rounds and then up to S ms of its own work, pinned at 10%, 20%, 50%
    and 90% where rounds fill their milliseconds, a slow drive's write passing time inside
    them; and with the box counter taken out, round only at due times and at each change
    of `estop`, a press and release between two due times running `trip` once, at once,
    each `Logex.IO.Sim.set/3` returning once its round has run and its outputs are
    written (decision 124);
  - make the round of a trigger logic writes at the next clock millisecond, two event
    tasks that write each other's trigger rounding once a millisecond and a host's call
    served between (decision 123);
  - keep 100,000 periodic rounds on their grid with no drift;
  - leave every output at 0, written once, when stopped (decision 116);
  - raise every host mistake of §4.11, with its pinned message, in the caller, with the
    runner still alive.

  A real-clock test runs the plant for 2 s and asserts liveness and an orderly stop. Its
  landing order:
  1. the cycle in steps (decision 118), internal to `Logex.Runtime`, its composition
     pinned against `cycle/3` over seeded configurations;
  2. `start_link/1` and its host mistakes, relayed calls among them;
  3. the device processes: reading every poll period, reports passed on by a call the
     runner answers once the round they cause has run (decision 124), writes and
     refreshes, each refresh carrying its deadline (decisions 120 and 125);
  4. the rounds (decisions 108 and 122), one a clock millisecond with the share's slots,
     between due times otherwise, each change of a trigger its own round, at once from a
     device and at the next millisecond from logic (decision 123);
  5. stop, status, `get/2` and subscriptions;
  6. the oracle test from files on disk.

  **Status: DONE — landed 2026-10-18**, as seven commits, the six of its landing order
  and the documents: (1) the cycle in steps, `7d0da34`; (2) `start_link/1` and its host
  mistakes, `da746ee`; (3) the devices, `f7fd5de`; (4) the rounds, `7d37c85`; (5) stop,
  status and subscriptions, `56bf766`; (6) the oracle test from files on disk, with the
  real-clock test and the growth test, `a8819a8`; (7) the documents, the commit after it.
  1382 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1333. Each of (1) to (5)
  records its mutation table, every rule it adds reverted alone in a worktree of its
  commit and the full suite judged by its exit code: (1) 12 rules, all red; (2) 24, all
  red; (3) 30, 29 red and one equivalent, a round's inputs kept for the next, which the
  image holds already; (4) 27, 25 red and two equivalent, C without its floor of 1,
  which the count of at least 1 at every wake makes no slot of, and a count kept with
  no untimed program, which no slot reads; (5) 25, all red. Eight survivors of the first
  runs were each given a test in its commit and are red: a value read again passed on as
  a change, a device with no output zeroed by an empty write, one round for two triggers
  in one report, C truncated rather than rounded, an earlier wake not cancelled, a stale
  wake taken, the status's overlaps and its longest refresh gap. The growth test bounds
  the runner's reductions over 20 rounds at 4.33 for 4x the instances and the devices,
  4.24 for the instances and 1.28 for the devices, a fifth above the highest of 32 runs,
  half beside three suites, 3.605, 3.533 and 1.066. `Logex.Runtime` changed as (1) says
  and no more: `cycle/3` is the composition of three hidden steps.

  Chosen while landing, each in its commit: the devices opened by a call once the runner
  is running, since a refusal from `init/1` kills the linked caller, so a device that
  cannot be opened stops the runner normally; `get/2` and `get!/2` in (2), the relayed
  calls it pins, ahead of (5); a refresh is a message to the device's process carrying its
  deadline and calls no adapter, which is written where its outputs changed and read
  every poll period, put to the maintainer; a device with no output point is never
  written nor zeroed; a slot serves its first request whatever the time, since one that
  looked first served nothing on a clock whose reading takes time; a host's request is
  served at once where no round is owed and always with no untimed program, so on the
  manual clock one made while a round is owed waits for the advance that runs it;
  `stop/2` is served at once; subscribing to a kind that is none of the seven is the
  host's mistake; anything else sent to the runner changes nothing; and the status's
  keys, `status`, `now`, `rounds`, `trip`, `overlaps`, `forces`, `edit`, `runs`,
  `latest_wake` and `refresh_gap`. Left as PLAN gives them: the trips, every I/O fault and
  the runner's death, a deadline acted on, `restart/2` and the hidden seam are M4-4's;
  `forces:`, forcing and the edit's steps through the runner M4-5's, `forces:` until then
  an unknown option. A device's callback that fails, a value that does not fit and an
  unknown address crash the runner until M4-4 trips on them.

  **Its review, and the maintainer's two answers, 2026-10-18.** A review of `a2ad82c`
  matched the rounds, events and writes against an independent scheduler over 1,600
  random plants, the 8 that differed all one tie, and found five defects and eleven
  surviving mutants;
  the maintainer answered M4-3's two questions the same day. Six commits on it, each
  gated and each with its mutation table:
  (1) `46714c3`, the devices opened inside `init/1` rather than by a call after start, so
  a host's call by the runner's name that came first no longer crashed the runner and
  its starter (F1, 33 of 300 starts in the review's probe), and a stop that came first
  gives `{:ok, pid}` and then stops; each request still queued at a stop, or left
  unanswered as the runner goes down, raises that the runner is not running (F2); a cast
  or a message is passed over and a call none of its functions makes is the caller's
  mistake (F5); 6 rules, all red;
  (2) `935193c`, an improper list of kinds and a repeated option each told in their own
  words (F4); 3 rules, all red;
  (3) `67be539`, decisions 130 and 131 recorded, and a slot served at the end of the
  round that completes its C ms, so that on the manual clock a call whose slot a round
  completes is answered in the advance that runs that round, `advance(clock, 0)` among
  them (F3, kept apart from the rule decision 131 keeps), with a refresh before the rest
  of a millisecond is served where a request waits; 6 rules, 5 red and 1 equivalent;
  (4) `9fd1270`, decision 130 built: each device writes its last outputs again at its
  poll, at most once a poll period, where nothing was written within one and its last
  deadline has not passed; 6 rules, 5 red and 1 red with the next commit's test;
  (5) `20f885e`, a test for each of the review's survivors, and a continuous line that
  runs no instance timing no round, as decision 111 says, so M4-4's round watchdog reads
  only rounds that run untimed programs; 12 rules, 11 red and 1 equivalent, the elapsed
  time's clamp at 0, which a monotonic clock never needs;
  (6) the documents, the commit after it: decision 122's "a round counts from its start
  to the next round's" read as from its start to its end, a millisecond at least, which
  the code did, since the runner's own work that runs past a millisecond is its own and
  counting it as the round's would give its own work more than its share; and §4.11's
  sentence on a tie, a poll that changes a trigger and a round due in the same
  millisecond going in either order, a run still repeating exactly.
  1404 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1382. The review's three
  equivalences hold for M4-3 and are to be looked at again when M4-5's forcing and edits
  through the runner land: a round's inputs kept, C's floor of 1, and the share's count
  with no untimed program.

  **Its verification, 2026-10-18.** A verification of those six commits re-ran the
  review's probes and 27 mutants, 26 red and the elapsed time's clamp equivalent, and
  found two low defects. Two commits on it, each gated and with its mutation table:
  (1) `a5d0b1a`, a call that reached the runner unanswered as `stop/2` stopped it with a
  reason of its own, `:abandoned`, exited its caller, an exit escaping the API: every
  reason the runner goes down with is now the runner not running, as the moduledoc says;
  1 rule, red;
  (2) `7cbe97b`, decision 132: a poll in the millisecond a round is due wrote the old
  outputs again just before the round wrote the new ones, twice the writes a 10 ms task
  on the default poll needs; a poll that finds a round due, come due less than a poll
  period before it and not yet run, now leaves its write to that round, the runner
  telling every device after each round when the next is due, and the device writing
  again at the round's end only where the round wrote nothing, counted from the poll;
  9 rules, all red. 1408 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1404.
  Decision 132 was taken without the maintainer, who may prefer its second option, the
  rule as landed with its cost stated.

  **The maintainer's answer, 2026-10-18,** "Fixed timer as Logix", replacing decision
  132: each device re-sends its last outputs every poll period on its poll grid, whether
  or not a round wrote to it within the period, as Logix re-sends outputs at the RPI, and
  the rounds write as before. Two commits on it, each gated:
  (1) `2203fa1`, decision 132's mechanism removed, `Device.due/2`, the runner's cast
  after each round and the wake at the poll's millisecond, and decision 130's skip with
  it: a device writes again at every poll once written, while its last refresh's
  deadline has not passed, one with no output point never written; tests that count a
  device a round writes every millisecond, 31 + 3 writes over 30 ms, and every 5, 10 or
  20 ms exactly, a device's process never written writing nothing at its polls, and busy
  devices' 201 writes each over 1,000 ms at 1, 4 and 16 devices beside the idle ones'
  101; 9 rules, all red;
  (2) the documents, the commit after it: decision 130 amended and 132 marked
  superseded in `docs/organisation.md` §7, with IEC's silence on a controller's I/O
  traffic, Logix's re-send at the RPI, an output module's fallback after missed RPIs
  left unverified *(both verified on 2026-10-20, 1756-UM058L pp.24–25 and 1756-PM015Q
  p.12, the fallback as a configured fault state on a communication fault, not phrased in
  RPIs; decision 130)*, and the cost, one adapter write a device a poll period, plus each
  round's; §4.11, the moduledocs, README's "On the clock", re-run, its output the same,
  and CLAUDE.md brought to it. 1407 tests pass on Elixir 1.20.4 (9 of them doctests),
  down from 1408: decision 132's four tests gone, three new.
- **M4-4 · The watchdogs and the fault path.** *Done when* each of these is a test on the
  manual clock, a hung device's deadline in real time and short:
  - a timed task whose run outlasts its watchdog trips before its round's write, naming
    it, and so does a round that outlasts the continuous task's (decisions 110 and 111),
    naming each of its steps with its time, a slow timed task's among them (decision
    126);
  - a stuck runner's devices zero themselves by the deadline their last refresh carried,
    a runner stuck in the conveyor's 50 ms step within 50 ms and a poll period of its
    start, not the plant's longest watchdog, and one stuck in its own work within its
    idle watchdog, `idle:`, and a poll period (decision 128), a step that takes exactly its watchdog
    leaving a poll period's margin (decision 125);
  - each kind of I/O fault trips, naming its device (decision 114);
  - a killed runner's devices zero and close (decision 115);
  - a hung device is killed, and opened again at a restart;
  - an exception out of the core trips `{:internal, message}`, reached through one hidden
    option of `start_link/1` that stands a module of the test's in for `Logex.Runtime`'s
    steps, the one seam the runner has for a fault no host can cause.

  In each, every device that answers is written 0 exactly once and nothing after; the
  resource is kept for `get/2`; and `restart/2`, cold and warm, resumes with the first
  round at once and the clock not counting the stopped time (decision 113). The manual
  clock gains what it needs to make time pass inside a task's run, where M4-1's `pass/2`
  cannot reach it. Its landing order:
  1. the trip and restart;
  2. each task's watchdog and the continuous task's per round;
  3. the devices' deadlines, carried by every refresh (decision 125);
  4. the I/O faults;
  5. the runner's death.

  **Status: DONE — landed 2026-10-18**, as seven commits, the five of its landing order,
  the manual clock's rule and the documents: (1) the trip and restart, with the hidden
  seam, `ef03273`; (2) each task's watchdog, the continuous task's round and the idle
  watchdog, `eddad44`; (3) the devices' deadlines, `9b0df68`; (4) the I/O faults,
  `b38dc72`; (5) the runner's death, with the trip's growth test, `58636bc`; (6) the
  manual clock advanced by a receiver as it handles a message, `3057a81`; (7) the
  documents, the commit after it. 1453 tests pass on Elixir 1.20.4 (9 of them doctests),
  up from 1409, most of them in `test/logex/trip_test.exs`. Each of (1) to (5) records its
  mutation table, every rule it adds reverted alone in a worktree of its commit and the
  full suite judged by its exit code: (1) 30 rules, 29 red and one equivalent there, a
  zero of a latched device writing 0 again, which nothing could do until (3)'s deadlines
  latch a device before a trip, and red there; (2) 16, all red; (3) 16, all red; (4) 28,
  27 red and one equivalent there, a close's raise not caught, red with (5)'s
  `terminate/2`; (5) 7, all red. Six survivors of the first runs were each given a test in
  their commit and are red: a trigger's change while tripped, a trip no wake brought, a
  stuck step after a device's wake had moved on, a device waiting on the runner for its
  own change (on the real clock, short), a device's own fault zeroing it with the runner
  suspended, and a clock that exits as it is read; and two pieces of code no rule needed
  were taken out of (1), a release that forgot what its device last wrote and the share's
  count set to 0 at a restart (the first back since the review, below). The growth test
  bounds a trip's work at 5.08 for 4x the devices, a fifth above the highest of 38 runs,
  4.233; M4-3's round test of the devices alone is bound at 1.39 now, a fifth above 1.156,
  the highest of 32 runs, since each device's write is answered within its deadline.
  `Logex.Runtime` is unchanged.

  Chosen while landing, each in its commit and in §4.11's landing note: the hidden option
  is `steps:`, a module with `cycle_steps/3`, `cycle_step/2` and `cycle_outputs/1`, an
  exception's message its own and a throw's or an exit's its banner; a test makes time
  pass inside a task's run through it, a stand-in that passes the manual clock, or, for a
  runner stuck in a step, advances it from inside the runner, which (6) makes the clock's
  rule; a tripped runner merges a device's changes into the next round's inputs, so the
  restart's first round takes them, keeps its first reason, and refreshes no device; a
  round that trips is not counted among the rounds; a request is timed against the idle
  watchdog from its start to its end, reading the clock twice, so M4-3's slot test on a
  clock whose every reading takes a millisecond serves three requests a 9 ms slot where it
  served nine, and a restart is not timed so; a device's refresh carries the time it was
  sent, `{:watchdog, {:device, device, ms}}` naming the span from it to the deadline; a
  device keeps one wake on its deadline, set again only where a refresh brings it sooner;
  a round's first act is to take a device's notice that waited, so a runner back from
  being stuck trips before it runs anything; a result of no shape `Logex.IO` gives is
  `{:raised, message}`; a device that answers after its deadline on the runner's clock is
  `:timeout` and killed (since the review, written its 0 instead); an init/3 or first read
  that raises, throws, exits, hangs or gives a value that does not fit is `{:io_init,
  device, cause}`, init/3's own reason given as before; a clock that goes down or fails
  stops the runner and each device as a shutdown, `{:shutdown, {:clock, reason}}`, which
  also ends a test's runner quietly when the test's manual clock goes down with it; and a
  device whose adapter was never opened is neither zeroed nor closed as it stops. Found
  while landing: a test that traced a device after the runner's start could see a refresh
  sent before it, still in the device's queue, and failed 2 of about 15 full runs under
  load; each trace now passes over what was sent before it. And the waits for an
  asynchronous event in `trip_test.exs` take 5 s, not ExUnit's 100 ms, which a killed
  runner's devices outlasted beside three suites.

  **Review, 2026-10-19, and its fixes.** An adversarial review of the seven commits found
  four defects, a process fault and the rules no test held, each fixed in a commit of its
  own after them, every commit gated by its exit code and backed up: (0) found while
  fixing them, a test that failed 3 of 20 runs alone at `da7e4df`, two devices latching in
  one millisecond on the manual clock, their notices reaching the runner in whichever
  order their processes ran: each notice now carries the time it was raised, and the
  runner takes every notice waiting together, by that time, ties in device-name order,
  `7f5222a`; (1) a cold restart could switch the conveyor back on for a moment, each
  poll's write again inside the restart's first round sending the outputs from before the
  trip, the code the landing's (1) took out as "no rule needed": a release forgets what
  the device last wrote, `3635a3a`; (2) a stop or a crash while a device waited on the
  runner for its own change zeroed and closed it twice: the close's state now comes out of
  the wait, `47682cd`; (3) a device that hung or died while the runner was tripped was
  dropped by the restart, which ran on without it: a restart releases first and then opens
  again every device down, one that does not answer its release among them, and one that
  cannot be opened leaves every device latched again, written 0 once more, `2f35bad`; (4)
  a device hung inside its own read or report was never seen while its outputs did not
  change, which decision 114 already makes a fault: each device tells the runner after
  every read and report that it is back from its adapter, and the runner trips `{:io,
  device, :timeout}` on one not heard within the idle watchdog and a poll period, checked
  as each round begins and at each wait's refresh, `2f1576d`; (5) a device that answered a
  round's write after its deadline on the runner's clock was killed, its outputs left at
  what it had just written: it is `:timeout` still, and written its 0 by the trip,
  `3fe9f97`; and (6) each rule the review found untested a test, `e6f6ca4`. A
  verification of the fixes then found (6) had taken out one piece of code that a rule
  needs, a latched device sending no notice at its later deadline, called equivalent
  below: a device the trip latched still told the runner once its last deadline passed,
  which a tripped runner passes over, but which a host's restart waiting in a busy
  runner's mailbox meanwhile is taken before, so that the restart answered `:ok` and its
  first round tripped `{:watchdog, {:device, device, ms}}` on a deadline from before it,
  on the manual clock every time and on the real clock 6 restarts in 800; (7) puts the
  clause back with that case as its test. A second verification then found the wider
  case (7) left: a restart a trip serves from its queue, one the host asked for while a
  round was owed, is answered inside that trip, and a latch or a fault raised by a device
  not yet latched as the trip began, taken with the notice that made it or come in while
  it ran, tripped the restarted runner after `restart/2` had answered `:ok`; and a "back"
  taken with the trip's notice, acted on only after the restart's first round, left its
  device unheard there, killed as hung, `{:io, device, :timeout}`, on the manual clock
  every time and on the real clock 20 restarts in 20. (8) gives every notice the count of
  restarts its device was released for, 0 from its opening, the runner passing over one
  from before its last restart, and acts on every notice taken together before the trip;
  the count makes (7)'s clause a rule's second place, so (8) takes it out. Its mutation
  table, each mutant judged by the full suite's exit code, one at a time: the count not
  checked, red in two tests, the notice that came in while the trip ran and (7)'s; the
  trip made inside the batch, red in the "back" taken with it; the runner's count not
  moved at a restart, red in the same two as the first; a release that does not give the
  device the count, red in a device latching after a restart; a device opened again at a
  restart given 0, red in its fault after it; and the whole fix reverted, red in the three
  new tests. 1474 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1453.

  The mutation tables of the landing's (1) to (5), above, overstate: three of their rows
  counted red only because a slow test timed out under load beside a parallel mutation
  run, runner_test's 100,000 rounds at ExUnit's 60 s or M4-3's 2 s on the real clock, and
  each survived run alone: (1)'s T2, a latched device still taking a round's write, (3)'s
  D3, a device latching a millisecond early, and (4)'s F25, a device opened again whose
  values were not merged. Each now has a test, as has each rule the review's own mutants
  found untested: a zero's time to answer, which of two faults in one read is named, a
  poll's write again at its deadline's millisecond, a device opened again whose first read
  does not fit, and a notice from a process that is not its device's. Every mutation row
  of the fixes' commits was judged by `trip_test.exs`'s exit code alone, one mutant at a
  time, and all thirty again by the full suite's, one mutant at a time, at the fixes' (6):
  every one red, each failing the test its row names, none red by a slow test alone. Three
  pieces of code were taken out as equivalent, each a rule's second place: a device marked
  down in a write that timed out or went down, where the trip's zero finds it so (the
  review's N10, in the fixes' (5)), a release's forgotten deadline, and a device latching
  itself on a round's write that failed, which the trip that write makes latches at once
  (each in the fixes' (6)). (6) took out a fourth, a latched device's later wake, as
  equivalent too, and it is not, as (7) above gives; and the fixes' (4) left out a
  fifth, the silent device marked down, for the same reason. Its table gives its B11, a
  "back" from a process no longer its device's, as equivalent; (6) gives it a test, and it
  is red there. The trip's growth test stays at 5.08, its highest of 48 runs 4.168;
  runner_test's round bounds go to 4.38 for both together and 1.40 for the devices, each a
  fifth above its highest of 48 runs, 3.643 and 1.165, since each round begins by checking
  every device heard. README's `a_trip.exs` re-run, its status fields now printed as a
  keyword list in the order named, since a map's keys came out in a different order on a
  re-run (the review's finding 8); and its status asked before its events are read, since the
  events, read straight from the mailbox, came empty once in some sixty re-runs, the trip
  made by the runner after the advance that failed the read had returned, and the status
  call is answered only once the runner has taken the panel's notice and tripped.

  **Answered by the maintainer, 2026-10-19,** each question below with its option (a),
  the one recommended and the one built, so nothing changes in the code: a restart of a
  runner that is running is the host's mistake (question 1, decision 133); a device hung
  inside its own read or report, a fault by decision 114, is tripped once not heard
  within the idle watchdog and a poll period, 510 ms by default, at the cost of a message
  a device a poll period (question 2, decision 134); a device whose own callback failed
  is zeroed through its adapter too, where it still takes a write (question 3, decision
  135); a restart that cannot open a device stays tripped and writes every other device
  its 0 once more (question 4, decision 136); and `{:watchdog, {:device, device, ms}}`
  names the heartbeat the device was given, from its last refresh to its deadline
  (question 5, decision 137).

  *Questions for the maintainer, 2026-10-19,* the builder's three of 2026-10-18 with the
  review's view of each, one the fixes raised and one the builder had left among its own
  choices, each answered (a) the same day, decisions 133 to 137. Words used: a *trip* is
  the runner stopping itself after a fault, every output switched off once and nothing run
  until a *restart*, the host's call that starts it again from the program's initial
  values; a *device* is one I/O card or drive the runner talks to through its *adapter*,
  the code for that hardware; a *poll period* is how often the runner's process for a
  device reads it, 10 ms unless set; the *idle watchdog*, `idle:`, is how long the runner
  may spend on its own work between steps, 500 ms unless set (decision 128); the plant is
  §4.4's, a conveyor on the panel card, a fan, and the "case full" lamp, with the drive's
  speed on the drive.
  1. *A restart while nothing has tripped.* The conveyor and the fan are running and the
     lamp is lit, and an engineer's program calls `restart/2`. (a) As built: refused, the
     engineer's program told "the runner is running", and the plant runs on untouched.
     (b) A trip and a restart in one: for a moment every output goes off, the conveyor and
     the fan stop and the lamp goes out, and then the program starts from its initial
     values, the conveyor staying off until start is pressed. (c) The program's values
     reset without the outputs being switched off first: the conveyor drops out on the
     next round, as its seal-in resets, the fan goes off if its program starts it off, and
     nothing is written 0 in between. IEC 61131-3 describes a cold and a warm restart as
     ways a resource starts, and says nothing of one already running; the conventional
     family has no restart of a running controller, the nearest being a change to Program
     mode and back, its outputs in their Program-mode state meanwhile (from memory,
     **unverified** in the manuals saved; the Program-mode state verified on 2026-10-20,
     1756-UM058L p.123, decision 133). The review agrees. Recommended: (a).
  2. *How soon a card stuck while it is read is a fault.* The panel card's adapter hangs in
     the middle of reading the buttons, while the conveyor runs steadily and no output
     changes. Decision 114 already makes it a fault, as the review pointed out, so the
     runner now trips on it; what is left is how soon. (a) As built: once the runner has
     not heard from the card for the idle watchdog and a poll period, 510 ms by default,
     the conveyor, the fan and the lamp go off about half a second after the card stuck,
     a press of stop on that card unseen until then; the same time the runner gives any
     call of its own to a card, so a card is given as long to answer as its deadline
     (decision 119's refinement); a busy machine that delays a card's read by more than
     that trips the plant. (b) A count of missed reads, Logix's way: the plant stops after
     four poll periods without a read, 40 ms by default, sooner, but a machine that holds
     a card's process back for 40 ms trips the plant. (c) A time set for each device in
     its binding: the panel's could be 50 ms and a slow network drive's two seconds, at
     the cost of one more setting a plant must get right. Either way the cost is one
     message from each card to the runner each poll period, 100 a second a card at 10 ms.
     IEC 61131-3 says nothing of how a controller talks to its I/O; the conventional
     family faults a connection that misses its timeout, its RPI times a multiplier of 4
     by default, which (b) matches (from memory, **unverified** in the manuals saved;
     **contradicted** on 2026-10-20: a timeout of 100 ms at least, 160 ms at the default
     20 ms RPI, 1756-UM001Q p.158, no default multiplier stated, decision 134).
     Recommended: (a), one time for every call to a card, until a plant needs (c).
  3. *The card that failed.* The drive's network cable comes loose and the runner's write
     of the drive's speed fails; the record's table says "every other device zeroed". (a)
     As built: the drive is written its 0 too where it still takes a write, as well as
     the panel, so where the cable is only flaky the drive's speed goes to 0. (b) The
     failed device is left alone, its outputs to what the drive does when its master goes
     quiet, the panel alone written 0: the drive keeps its last speed until its own
     timeout. IEC 61131-3 says nothing of it; in the conventional family a faulted
     module's outputs go to the fault state configured on the module, the module doing it
     rather than the controller (from memory, **unverified**; verified on 2026-10-20,
     1756-PM015Q p.12 and 1756-UM058L p.123, decision 135). The review agrees.
     Recommended: (a), every output that can still be written at 0, the milestone's done
     sentence.
  4. *A restart that cannot open a card.* The drive was unplugged while the plant was
     tripped, and the operator presses restart: the panel answers, the drive cannot be
     opened, and the plant stays tripped, the conveyor, fan and lamp off. (a) As built:
     the panel, released for the restart and then latched again, is written its 0 once
     more, as it is when a restart's first round trips again: nothing visible changes on a
     healthy panel, its outputs already off, but a panel that reset itself meanwhile, or
     one opened again in the same restart, is told 0. (b) The panel latched again without
     a second 0, every output written 0 exactly once a trip whatever the restarts in
     between: the same on a healthy panel, and a card opened again in that restart left
     to whatever it does at power-up until the next restart. IEC 61131-3 says nothing of
     it; the conventional family writes each module's outputs every RPI in every mode,
     so a module hears its state again and again (from memory, **unverified**; every RPI
     verified on 2026-10-20, 1756-UM058L pp.24–25, "in every mode" not stated, decision
     136). Recommended: (a), a 0 heard once more rather than a card left unsaid.
  5. *What time a card's own timeout reports.* The runner is stuck for 3 s inside the
     conveyor's step, whose watchdog is 50 ms; the panel hears nothing by its deadline,
     50 ms and a poll period after the step began, switches the conveyor, fan and lamp
     off itself, and the runner, back after 3 s, trips `{:watchdog, {:device, "panel",
     ms}}`. (a) As built: `ms` is the heartbeat the panel was given, 60, from the refresh
     it last heard to its deadline, so the operator reads "the panel heard nothing for
     60 ms", the time after which the plant went off, the same on every run. (b) The time
     the runner was gone, about 3,000, read when it came back: "the controller was stuck
     for 3 s", which says how long, but varies from run to run on the real clock and says
     nothing of when the plant went off. (c) No time at all, `{:watchdog, {:device,
     "panel"}}`, the reason naming only the card. IEC
     61131-3 says nothing of it; in the conventional family a module whose connection
     times out shows a connection fault code with no time in it, and a task's watchdog
     fault names the task (from memory, **unverified** in the manuals saved).
     Recommended: (a), the time after which the plant actually went off, the same on
     every run.
- **M4-5 · Edits and forcing through the runner.** *Done when* §4.4's plant, edited while
  it runs through `Logex.Runner`'s accept, test, untest, assemble and cancel, gives every
  report and every round's outputs that the same steps give taken over the resource
  directly; `slow` cut to 20 ms moves its next due time as decision 40 says, with no round
  lost or added; accept's work is done in the caller's process (decision 119); and
  forcing (decision 117) holds a forced input against its device and across a restart,
  a forced trigger making a round, refuses an output point or a value that does not fit
  in the caller, lists every force in the status, and on `unforce/2` puts back the
  device's last value. Forces are kept in a file (decision 127): `start_link/1` takes
  `forces:`, a path, and a runner started without it refuses `force/3` as the host's
  mistake; each force and unforce writes the whole set before it returns, to a file
  beside it, flushed and renamed over it, a write that fails changing nothing and
  returning `{:error, {:forces, reason}}`; every start reads it, `start_link/1` in the
  caller and `restart/2`, a file that does not exist being no force, so that a runner
  killed while the photo-eye is forced, and started again from the same file, comes back
  with it forced and listed in `status/1`; a force in the file on a point the
  configuration no longer has, on an output point or of a value that does not fit, and
  a file that cannot be read, are refused at start as the host's mistake, every such
  force named, the runner not started, and at `restart/2` raised in the caller with the
  runner left tripped; and `unforce_all/1` takes every force off and writes the file
  empty, a host with no runner deleting the file. The file's format, text a person can
  read, is this item's to settle.

  **Status: DONE — landed 2026-10-19**, as five commits: (1) forcing through the runner,
  `forces:`, `force/3`, `unforce/2` and `unforce_all/1`, the file written whole before
  each call returns, `a3b7971`; (2) the file read at every start, `start_link/1` in the
  caller and `restart/2`, a force it cannot take refused, `b659f00`; (3) an online edit's
  steps through the runner, accept's work in the caller, `26a4d08`; (4) the Done-when on
  §4.4's plant from files on disk, with the growth tests, `9206c02`; (5) the documents,
  the commit after it. 1519 tests pass on Elixir 1.20.4 (9 of them doctests), up from
  1474, most of them in `test/logex/force_test.exs` and `test/logex/runner_edit_test.exs`.
  Each of (1) to (3) records its mutation table, every rule it adds reverted alone in a
  worktree of its commit and the full suite judged by its exit code: (1) 21 rules, all red,
  two of them, an unforce's value for a point no device had given one and the file
  written in place rather than renamed over, red only once a test of their own was added;
  (2) 11, all red; (3) 14, 13 red and one equivalent, the configuration a step runs
  written into the runner's own state, which nothing read again, taken out, an
  overtaken accept not done again red only once the test of an accept another host's
  cancel overtakes was added. Each red row fails a test of its own file that names its
  rule; run three or four at a time, some rows also failed a slow runner test by its
  timeout, which is not counted. M4-3's review left three mutants equivalent until
  forcing and edits landed, and (4) judges them again: a round's inputs kept for the
  next and C without its floor of 1 are still equivalent; the share's count kept with
  no untimed program is not, since an edit that adds an untimed program would find the
  count the timed rounds left, and a test now kills it. The growth tests bound a force's
  write and 20 rounds merging every force at 4.0 and 4.61 for 4x the forces, and the
  runner's own work for an accept at 1.70 for 4x the instances, each a fifth above the
  highest of 52 runs, 18 beside two suites, 3.333, 3.844 and 1.416. `Logex.Runtime` and
  `Logex.Configuration.Edit` are unchanged.

  **Its review** (2026-10-19, at `3ee6e69`) found one blocking bug and three rules with no
  test, each fixed the same day in a commit of its own with its mutation table, every row
  red on the full suite by its exit code:
  (1) an edit's step that took away the last untimed program left the requests queued
  behind it for the share's slot unanswered for good, a slot never coming again: now,
  with no untimed program, every request that waited is served at once, in order, as
  each is from then on (decision 108), and so is the rest of a millisecond's that a step
  ran past, `c358efb`; (2) `unforce_all/1` that changed several triggers made one round
  for all of them, where decision 120 makes each change of a trigger its own round: now
  one round each, in device-name and then address order, each reading those before it at
  their new values and those after it as they were, `3ce7f57`; (3) the review's three
  surviving mutants each a test, a device opened again at a restart kept as its last
  value, a step's event sent while tripped, and the forces listed in the status before
  a first round that trips, with the growth bounds raised to a fifth above the highest
  of 118 runs, the review's 16 and 50 more among them, 3.391, 3.852 and 1.450, to 4.07,
  4.63 and 1.74, `c77030e`; and (4) these documents, question 2's arithmetic put right
  (counted from the edit, the fan's next run stays at 100), question 1 given the order
  of several triggers' rounds, and question 4 the edit another engineer's test leaves.
  1524 tests pass on Elixir 1.20.4 (9 of them doctests). The review's probes, re-run on
  the fixes, hold: the queued status answered, and two triggers unforced two rounds.

  Chosen while landing, each in its commit and in §4.11's landing note: the forces
  file's format, which the record left to this item, one force a line, `name value`, in
  name order, the empty file for none, written to `<path>.tmp` beside it, flushed and
  renamed over it (the directory is not synced after the rename); a refusal at a start
  names each problem `<path>: line <n>: ...`, a line each, in `force/3`'s words; a
  restart reads the file before it releases anything; an edit's steps give `{:ok,
  report}`, the design spike's shape; accept asks the runner for its resource with the
  count of steps it has taken, and the runner holds the edit accept gives only where no
  step came between; and after each step the rounds read the watchdogs and the untimed
  programs of the configuration the resource runs, and the next round is planned again
  from the last. Four more, the record silent, were built as the option closest to the
  record and to Logix and put to the maintainer below: a forced trigger's round, and
  since the review the order of several triggers' rounds across devices; decision 40's
  `now` with no untimed program; the forces file a person reads; and two hosts stepping
  one edit. The maintainer answered all four on 2026-10-19, decisions 138 to 141 (below).

  **Questions for the maintainer** (answered 2026-10-19, each answer after its question).
  In each, a *round* is one pass of the controller over
  its programs, reading the inputs, running the programs that are due and writing the
  outputs; a *trigger* is the input an *event task* watches, a task that runs when its
  trigger goes from off to on, here the e-stop button that runs the `trip` task, which
  stops the conveyor and lights the trip lamp; to *force* an input is to make the
  controller read a value of the technician's choosing, whatever the real signal says,
  until the force is taken off (*unforced*); a *periodic task* runs every so many
  milliseconds, its *interval*, here the fan's task every 50 ms; an *untimed program* is
  one in no periodic or event task, run again and again as fast as the controller can,
  here a box counter in the continuous task; and an *online edit* changes the programs or
  tasks of a plant while it runs, in steps: *accept* (checked, nothing changed yet),
  *test* (the new version running), *untest* (the old one back), *assemble* (the new one
  kept) and *cancel* (the edit dropped).
  1. *When a forced trigger runs its task.* The conveyor runs, the fan's task every 50 ms,
     and a technician forces the e-stop on from a laptop to test the trip lamp. (a) As
     built: the `trip` task runs once, at once, when the force changes what the
     controller reads, off to on, before the laptop's call returns, so the lamp is lit by
     the time the laptop says "done"; forcing it on again while it already reads on runs
     nothing; while it is forced, presses of the real e-stop button change nothing the
     controller reads and run nothing. Where one call changes several triggers, as
     "unforce all" can, say the e-stop and a guard door's switch on the panel and a lift
     limit switch on the drive, each runs its own round, one after the other, before the
     call returns, as several changes from one device already do: first by the device's
     name, then by the input's address on it (here the drive's lift first, then the
     panel's e-stop and door in address order), each round seeing the triggers before it
     at their new values and those after it as they were; the operator sees each task's
     lamp or alarm come on in that order, in the same instant. (b) Every force of a
     trigger makes a round at once, even to the value it already reads: an extra round in
     which nothing new happens, since a task runs on its trigger's rising edge; the round
     counter on the status screen moves, nothing else. (c) A force waits for the
     controller's next round on its schedule, so the trip lamp lights up to one fan
     period, 50 ms, later, and the laptop's call returns before it. For several triggers
     in one call, the alternative to (a)'s order is one round in which all of them change
     together, their tasks then running in priority order, which is what the builder
     first built and what a device's several changes do not do. IEC 61131-3 says nothing
     of forcing, and an event task in IEC runs on its trigger's rising edge, whatever
     caused it. In Logix a force changes the input as the program sees it from the next
     scan, and whether an event task triggered by a forced input runs at once, or in what
     order several do, is not in the manuals saved (**unverified**; checked on 2026-10-20,
     decision 138: a force *"immediately takes effect"*, 1756-PM004L p.51, and an event
     task fired by a force is not found). Recommended: (a), the
     review agreeing, with one round per trigger changed. *Answered: (a), as built, one
     round per trigger changed, in device-name then address order, a force that changes
     nothing making no round (decision 138).*
  2. *A task's interval cut while no untimed program runs.* The fan's task runs every
     50 ms, last at 50 ms, so it is next due at 100; the plant has no continuous task, so
     the controller's own clock stands at 50, the fan's last run, until its next run. At
     95 ms by the wall clock an engineer cuts the fan to 20 ms. Decision 40 sets the next
     due time to the earlier of the one it had and "now plus the new interval". (a) As
     built, "now" read on the controller's own clock, 50: the earlier of 100 and 50 + 20 =
     70, which the wall clock has passed, so the fan task runs at once, at 95, and the
     status screen shows one missed period, an overlap, though nothing ran late. (b)
     "Now" the wall clock's, 95, the runner first bringing the controller's clock up to
     it by a round that runs no program: the earlier of 100 and 95 + 20 = 115 is 100, so
     the fan runs at 100 as it would have, no missed period shown, and one round more
     appears in the log. (c) "Now" the wall clock's, 95, given to the edit's switch as a
     new argument, `Logex.Configuration.Edit` changed: next due at 100, unchanged, no
     missed period and no extra round. With §4.4's box counter in the continuous task, as
     in the Done-when, rounds come every millisecond, the controller's clock keeps up with
     the wall clock, and the three agree. IEC 61131-3 says nothing of a task's interval
     changed while running. In Logix a periodic task's period may be changed online, and
     when the new one takes effect is not in the manuals saved (**unverified**; partly
     verified on 2026-10-20, decision 139: the TASK object's Rate, which logic may write,
     1756-RM018A p.276, its taking effect not found).
     Recommended: (c), the screen showing no alarm the edit itself made and no round
     added, if a change to the edit's switch is acceptable, the review agreeing; (a) is
     what the record's rule says as written, and stays built until the maintainer says.
     *Answered: (c), then built (decision 139): the step's time on the runner's clock,
     given to the switch; used alone, `Logex.Configuration.Edit`'s `now` is the
     resource's unless the host gives the milliseconds since its last cycle.*
  3. *The forces file a person reads.* The file sits beside the plant's files, one force
     a line, `eye_1 1`, the photo-eye that counts boxes on the conveyor held on. (a) As
     built: the runner reads exactly what it writes, so a person who opens it sees every
     force, but one who adds a comment or a blank line, or writes `eye_1 01`, finds the
     next start refused, the line named, the plant not started, until the line is put
     right or the file deleted; a last line with no newline is read. (b) Comments and
     blank lines read and passed over, so a person may annotate it, though the runner's
     next write, at the next force, drops what was added. Beside it: a runner started
     with no file refuses "unforce" and "unforce all" as it refuses a force, in the same
     words, though it has nothing to take off; and an unforce of an input that is not
     forced is accepted and writes the set again. IEC 61131-3 says nothing of forcing. In
     Logix forces are kept in the project and changed only through the programming
     software, never by editing a file (**unverified**; forces held by the controller and
     kept in the project verified on 2026-10-20, 1756-PM004L pp.52–53, decision 140).
     Recommended: (a), the review
     agreeing: a strict file is the safest for a list that decides what the plant reads.
     *Answered: (a), as built, and an unforce of a point not forced accepted (decision
     140).*
  4. *Two engineers stepping one edit.* Engineer A accepts a change to the fan's
     interval from one laptop while engineer B, from another, takes a step of the edit
     the controller already holds. (a) As built: A's accept is worked out on A's laptop
     against the plant as it was; if B's step came first, the controller tells A's laptop
     so, and A's accept is worked out again against the plant as it is now, so A's
     laptop shows a forecast that is true when the edit is held, and B's edit is
     replaced by A's, as a second accept replaces a first. If B's step was a test, the
     plant as it is now runs B's new version, so A's edit takes B's tested version as
     its "old" version, the one A's untest would bring back: A would see B's change as
     already part of the plant. A change the controller refuses, a task added, leaves
     whatever edit was held as it was. (b) A is told the plant moved on, and accepts again
     by hand, seeing the plant as it now is before choosing. IEC 61131-3 says nothing of
     online edits. Logix's programming software lets one workstation at a time edit a
     controller online (**unverified**; not found, and probably contradicted, on
     2026-10-20, decision 141). Recommended: (a), the review agreeing, since it
     gives exactly what the same steps taken over the resource directly give
     (`Logex.Configuration.Edit`'s rule that a second accept supersedes the first).
     *Answered: (a), as built: an overtaken accept is redone against the plant as it
     now is (decision 141).*

  **The maintainer's answers** (2026-10-19), recorded as decisions 138 to 141 in
  `docs/organisation.md` §7, decision 40 amended to point to 139. Questions 1, 3 and 4
  were answered with what was built. Question 2's (c) was built in one commit, `5792089`:
  `Logex.Configuration.Edit`'s `accept/3`, `test/3` and `untest/3` take the step's time
  as `elapsed_ms`, the milliseconds since the resource's last cycle, counted and refused
  as `Logex.Runtime.cycle/3`'s, checked after the runtime, and decision 40's `now` is the
  resource's `now` plus it, the step moving no clock, a resumed timer's time still the
  resource's (decision 56). Used alone it is 0 unless given, so a direct call keeps the
  resource's `now`, the reading since OE-2, the record's answer for a host that holds the
  only clock; through `Logex.Runner` each step and accept's forecast are given the time
  since the last round on the runner's clock, 0 while tripped. The maintainer's example
  is a test on the manual clock, the fan cut to 20 ms at 95 next due at 100 with no
  overlap and no extra round, and the test that pinned the missed period now pins the
  cut counted from the edit. Its mutation table, every rule reverted alone in a copy of
  the tree and the full suite judged by its exit code, three at a time: 11 rules, all
  red, each failing a test of its own that names it (decision 40 reading the resource's
  `now`; accept's forecast, test's and untest's time ignored, each alone; the time not
  checked; untest checking the generation before it, and accept the candidate before it;
  the runner's step time 0 while running, read on the clock while tripped, not handed to
  accept, and not passed to a step); run three at a time, some rows also failed a slow
  real-clock test by its timeout, as an unmutated copy did once, which is not counted.
  Its verification found two rules no row reverted alone: test checking the generation
  before the time, and the runner passing the step time to a test but not to an untest,
  whose untest the existing tests took where both times give one answer. Each now has a
  test that fails on that mutant, which the full suite judges red, as it does untest's
  order and the runner passing no step time to either again. 1529 tests pass on Elixir
  1.20.4 (9 of them doctests), up from 1524.
- **M4-6 · The contract walk.** `api_contract_test.exs` gains a runner walk on the manual
  clock: seeded configurations with and without untimed programs, simulated devices that
  report and that do not, random waits and presses, injected faults, edits, forces and
  restarts, checked against a model that calls `cycle/3` directly with the recorded times
  and inputs, and a model of the watchdogs and the trip that knows nothing of the runner.
  *Done when* its reach is asserted, every event kind and every trip reason reached but
  `{:internal, message}`, which the host contract makes unreachable from a walk and M4-4
  reaches through its seam.

  **Status: DONE — landed 2026-10-19**, as three commits: (1) the fix the walk found,
  `81fedcb`; (2) the walk, `c591faa`; (3) these documents. 1531 tests pass on Elixir
  1.20.4 (9 of them doctests), up from 1529.

  The walk is `Logex.ApiContractTest.RunnerWalk`, a module of its own in
  `api_contract_test.exs`, so that it runs beside `Logex.ApiContractTest` rather than
  after its eleven walks: 30 seeded configurations of a fast task, now and then a slow
  one, an event task on a panel's or a drive's input, one on a trigger logic writes and
  the continuous task, about three in four with an untimed counter (22 of the 30 at its
  seed); each device reporting or only read;
  a forces file or none; and 70 steps each of waits, presses, forces and unforces, an
  online edit's steps, host mistakes, restarts, a crash and a fresh start from the forces
  file, and injected faults, a step slow by about a watchdog, a slow request, the runner
  stuck, a device killed or hung, and every way `Logex.IO.Sim` fails a read, a report or
  a write. The hidden seam, `steps:`, stands in a module that runs each step as the core
  does and tells the walk the elapsed time and inputs the runner gave the core; the model
  calls `cycle/3` with them, and each round's events, outputs and resource, each edit's
  report at the step's time, each restart and, after every step, `status/1`, `get/2` and
  each device's outputs must be the model's. The times and inputs are checked too, by
  the rules restated: the elapsed time the clock's since the last round, a forced input
  its force, a reporting device's input its value now and a read device's one it held
  within two poll periods, a scheduled round exactly when decisions 122 and 123 or the
  next due time put it, and a force of a trigger its round at once (decision 138). A
  model of the watchdogs and the trip gives each injected fault's reason, and every
  output is 0 once at a trip and nothing is written until the restart. The first walk
  runs again from fresh processes and repeats exactly. Its reach is asserted: every event
  kind, every trip reason but `{:internal, message}`, and 41 kinds of round, step, fault
  and mistake. No step reads the real clock, but the runner's waits for its devices are
  in real time (decision 125), which its review found the walk's margins too thin for;
  the times and seed families as its review left them are below. At this seed every
  atom is reached.

  Its mutation table (`c591faa`'s message): 58 mutants of `lib/`, each applied alone in a
  copy and the full suite judged by its exit code, 57 red and one green, equivalent (a
  round's inputs kept for the next, merged again at the same values). The walk fails 47
  of them, and every one but one also fails a per-rule test, mostly in `trip_test.exs`,
  `runner_test.exs`, `force_test.exs` and `runner_edit_test.exs`, which the table names;
  the one only the walk catches is a round that trips the continuous task's watchdog
  recording no longest run in `status/1`. The fix's three rules, reverted, fail the walk
  alone once the fix's own test is taken out *(until decision 142, since which they are
  equivalent, below)*. The ten it misses are each caught by a
  per-rule test, most of them out of the walk's reach by design: a write delayed, a
  host's call waiting for a slot, two bad addresses in one read, or equivalent on the
  manual clock.

  **The bug it found** (fixed in `81fedcb`, with a test in `trip_test.exs` that fails on
  its parent). A device took every change it passed on into the image it compares its
  reads with, whether the runner took the change or refused it as an I/O fault (decision
  114). So a card that goes on giving a value that does not fit, a broken encoder on the
  drive, tripped the runner once; after the restart its reads matched that image, nothing
  was passed on, and the runner ran on with the last speed it had taken, never tripping
  again. And a report refused for one bad value lost the good change beside it for good.
  The runner now answers a refused change `{:error, cause}`, and the device takes only a
  change the runner answered `:ok`, so its next read passes a refused one on again.
  Decision 114 makes each read's bad value a fault, so the record was not silent.

  **Its review** (of `e6b7410`, fixed 2026-10-20, four commits, these documents and a
  fifth commit, the last, which the fixes' own load runs called for):
  1533 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1531.
  1. *The walk could fail under load* (`763503a`). The runner waits for an open or a
     close for the idle watchdog and a poll period, in real time, and the walk drew an
     idle watchdog of 60 or 80 ms: beside three suites an open missed its wait, `{:io_init,
     "drive", :timeout}`, once in about 24 runs. It now draws 400 or 500 ms, and in about
     one start in six makes the first device opened late by 100 ms in real time, as a
     loaded machine is, which must trip nothing; with the old draws that stand-in fails
     as the review's run did. A hung device, whose trip waits up to that long, is injected
     in a third of the walks. The first fix, 300 or 400 ms with a stand-in of 150 ms,
     failed once in 6 runs of three suites at once on 4 cores, and once more, with the
     trip tests below, in 9 such runs instrumented: under that load an open alone took up
     to about 240 ms, the start of two devices 478 ms, so the fifth commit took the
     margin to 400 or 500 ms. The moduledoc states each real-time wait and its margin; a
     round's write keeps the least, what its step's deadline leaves on the manual clock,
     a poll period, 3 to 8 ms, where a step takes its watchdog exactly, which no load run
     missed and which a margin of the walk's cannot widen without changing the rule it
     tests.
  2. *A restart's refusal lost no reason the suite saw* (`98126e0`). Every restart a
     device refused said `:refused`, so a runner that answered `{:io_init, device,
     :refused}` whatever the device said passed. `trip_test.exs` now restarts past a
     device that answers `:unplugged` and then `{:no_route, 3}`, and the walk draws the
     reason; that mutant fails both.
  3. *Older real-time windows* (`d056e00`). Beside the walk, under load, three older
     tests failed now and then: `trip_test.exs`'s device that cannot be opened at start,
     at `idle: 20` (now 300; under six CPU burners the old test failed 3 runs of 3 with
     `:timeout`, the new one passed 3 of 3); `runner_edit_test.exs`'s traced accept, at
     ExUnit's 100 ms, which it takes 106 ms for alone (now 5 s); and `runner_test.exs`'s
     100,000 rounds, about 15 s alone, at ExUnit's 60 s (now 300 s). The walk stays
     async, so it adds no module to the suite's critical path. The fixes' load runs
     found two more of the kind in `trip_test.exs`, a device hung inside its read on the
     real clock at `idle: 50`, which tripped on the panel's heartbeat instead, and a
     device that cannot be opened again after the others' release at `idle: 30`, whose
     drive's open timed out; the fifth commit gives them and the two other tests of a short
     real-time deadline at `idle: 30` 300 ms. At its tip 9 runs of three suites at once
     on 4 cores all passed.
  4. *The input check loosened for good* (`fada5ca`). A read device's input was allowed
     two poll periods and the most time ever passed inside a step, which an idle
     injection raised to four times its lag for the rest of the walk. Each pass on the
     manual clock is now recorded with its time, and a check allows two poll periods and
     the time of each pass that ended within the window, which widens it in turn, and no
     more. A test of the check's own gives the core a read device's change late, from the
     first pass, by that pass's time less 10 ms, never later than the old allowance but
     later than two poll periods once the pass is behind it: it is caught in its first
     walk, and with the running maximum put back in none of 20.
  5. *Two numbers* (these documents). "Half with untimed programs" was about three in
     four, 22 of the 30 at the seed. The suite's time, measured three times each on one
     machine, one after another: 62.2, 65.2 and 68.1 s at `c7b0d1a`, 68.0, 70.3 and
     68.5 s at the fixes' tip before the fifth commit, so the review's fixes cost about
     3 s of wall time, within the runs' spread; after it the walk alone takes 5.6 to
     10.6 s over 31 seed families, 7.1 s at its own, most of it hung devices' real-time
     waits, and the check's own test about 1 s. Over 30 other seed families every walk
     passed and 22 reached every atom, the rest missing one: an interval cut a while
     after the last round (decision 139) in eight and a step taken while tripped in
     one.

  **A question for the maintainer** (answered 2026-10-20: (b), "Read cards first", then
  built, decision 142; it had been built as (a), as the record said). A
  *trip* stops the plant: every output switched off once, nothing run until a person
  presses restart. A *round* is one pass of the controller over its programs: the inputs
  read, the programs run, the outputs written. A *device* is an I/O card the controller
  reads and writes; one that cannot report its changes is read every *poll period*, 10 ms
  unless set.
  1. *Whether a restart reads every device before its first round.* The conveyor runs,
     the fan with it and the run lamp lit, and the drive's card starts giving a speed no
     dint holds. The controller trips: the conveyor, the fan and the lamp go off. The
     operator presses restart without the card mended. (a) As built: the restart lets
     every card go and runs its first round at once on the last values the controller
     took, so the conveyor's contactor and the fan pull in and the lamp lights; at the
     drive card's next read, within a poll period, the bad value trips the controller
     again and everything goes off. The operator sees the plant start and stop again in
     10 ms, a click of the contactors, and the trip screen again. (b) A restart reads
     every card once before its first round, as a start does, and one whose read fails or
     gives a value that does not fit leaves the controller tripped with its first reason,
     the restart answered with the card's fault, as a card that cannot be opened again
     answers it now (decision 136): nothing switches on, and the operator is told which
     card is at fault. (c) As (a), but the first round's outputs held back until every
     card has been read once since the restart: nothing switches on, the restart is taken
     and then trips again within a poll period. IEC 61131-3 says nothing of a restart
     after an I/O fault. In Logix a module whose connection faulted is reconnected before
     its inputs are used, and a major fault is cleared before the controller goes back to
     run (from memory, **unverified** in the manuals saved; since **verified** for a
     module set to "Major Fault On Controller If Connection Fails While in Run Mode": at
     the transition from Program to Run *"the controller makes one attempt to connect to
     a module"*, and where none occurs *"a fault occurs because at least one required
     connection is not established before going to Run mode. This is a 3/23 type fault
     code"*, 1756-PM015Q, Sept 2025, p.12; a module without that setting is not waited
     for). Recommended: (b), the same rule as a start, which the record has; nothing is
     switched on from a value the controller knows may be bad.
     *Answered: (b), "Read cards first"* (the maintainer, 2026-10-20), then built
     (decision 142): a restart reads every device once, in device-name order, as a start
     does, before its first round; one whose read fails, an error, a raise, a throw, an
     exit, a value that does not fit, an address that is no input point's, no answer in
     time or a process gone down, leaves the runner tripped with its first reason, the
     restart answered `{:error, {:io_init, device, cause}}`, the answer a device a restart
     cannot open gives (decision 136), and every device that answers latched again and
     written 0 once more, as decision 136 has it.

  **Decision 142, built** (2026-10-20), as two commits: (1) the code, its tests and the
  walk, with decision 142's record, `0cb2b61`; (2) these documents, with the record's
  claims of Logix checked against the manuals (below). 1538 tests pass on Elixir 1.20.4
  (9 of them doctests), up from 1533. `restart/2` releases every latch and then reads
  every device once, in device-name order: one up through its process's `reread/1`, one
  down opened again. `trip_test.exs` pins a card still bad leaving the runner tripped and
  written only 0, cold and warm, a card put right letting it run on what it gives now,
  read by no poll, each kind of read fault in the card's words, a card hung in the read
  killed and opened again at the next restart, and the first in device-name order; the
  walk refuses a restart now and then through a device up whose read fails, and holds a
  start's and a restart's first round to every device as it is then. Its mutation table
  (`0cb2b61`'s message): 13 mutants, each applied alone in a copy and the full suite
  judged by its exit code; the ten of decision 142's rules all red, the walk alone failing
  four of them, one, a device that kept its old image after the reread, the walk only; and
  M4-6's fix's three rules (above) green, equivalent since: a refusal always trips, and a
  restart now reads every device whole, so a device's image after a refusal no longer
  shows in any run, and the fix's own test now pins decision 142. Two rules first written
  were equivalent mutants and taken out: the runner marking down a device that did not
  answer its read, which its trapped exit does, and moving its heard time, which its
  "back" notices do.

  **Decision 142, verified** (2026-10-20, M4-6's third verification): the claim above that
  M4-6's fix's three rules were equivalent was false, and so was `0cb2b61`'s message,
  which made it. A device still took a restart's read as what it had passed on before the
  runner checked it, so an address that is no input point's, which no good read gives
  again, stayed in its image after the restart was refused, and the same fault read
  later was never passed on; and with any of the fix's three rules reverted a poll's
  refused change did the same across a restart. And a change a device read before a
  restart, waiting in the runner's mailbox behind it, was taken after the restart: a bad
  one tripped the runner just after a restart answered `:ok`, a good one put an older
  value over what the restart read, in the runner and in the device. Now what a device
  read at a restart is what it last passed on only once the runner has taken it, by a
  cast, `taken/2`, and each change carries the count of restarts it was read under, as a
  notice does, one from before the last restart answered `:stale` and taken by neither.
  `trip_test.exs` pins each, and a restart's read as the value an unforce puts back,
  which no test checked. Its mutation table, each applied alone in a copy, the full suite
  judged by its exit code: the fix's three rules, F1 to F3, now red; the reread taken
  before it is checked, red; no `taken/2`, red (the walk too); a stale change taken, red;
  the device taking a stale change, red; a restart's read not kept as each point's last
  value, red; a change carrying no count, red (the walk too); and `taken/2` replacing the
  image rather than merging into it, green, equivalent with `Logex.IO.Sim`, whose every
  read gives every input point (with an adapter that reads some, a point the restart's
  read left out would be passed on again once, unchanged). The walk, under the seed
  families `{2027, 3}` and `{2031, 7}` that found the first, passes all 30 walks. 1542
  tests pass on Elixir 1.20.4 (9 of them doctests), up from 1538.

  **Decision 142, verified again** (2026-10-20, M4-6's fourth verification): the count
  of restarts a change carries did not close the window it was for. A device heard the
  new count at its release, and the runner releases every device before it reads any
  again, so a reading a device took while the runner read the devices before it carried
  the new count, waited behind the restart and was taken after it, over the device's own
  newer reread: a bad one tripped the runner just after the restart answered `:ok`, on
  the manual clock and the real one. And a poll a device handled between its reread's
  answer and `taken/2` was compared against the image from before the restart, so a
  reading that differed only from the reread was lost. Now, from its release until the
  runner has taken its reread, a device passes nothing on, by a poll or a report: a
  reading before its reread is dropped, older than it, and one after it held, merged
  with any other, and passed on against the image the reread leaves once `taken/2`
  comes; a zero, a refused restart's, ends the hold. `trip_test.exs` pins each repro, a
  bad and an older reading in that window by a poll and by a report, on the manual
  clock and the real one, a reading between the reread and its taking, two of some
  points each merged, a restart's read of some points keeping the rest of the device's
  image with an adapter that reads some (so that `taken/2` replacing the image, which
  the paragraph above found equivalent with `Logex.IO.Sim`, is red), and a device whose
  restart is refused passing its changes on while tripped. README's "On the clock" now
  prints the status fields as a keyword list in a fixed order, the run repeated ten
  times from a built tree, every output the same. Its mutation table, each applied alone
  in a copy, the full suite judged by its exit code, every one red, and only by the new
  tests: the whole fix reverted (three tests); a reading before the reread passed on
  (two); a reading after it passed on at once, against the old image (one); `taken/2`
  replacing the image (one, the partial adapter's); a zero not ending the hold (one);
  `taken/2` passing nothing held (two); held readings replaced rather than merged (one);
  a report passed on unheld (one); a poll passed on unheld (three); and a release that
  starts no hold (two). 1548 tests pass on Elixir 1.20.4 (9 of them doctests), up from
  1542.

  **Decision 142, verified a third time** (2026-10-20, M4-6's fifth verification): the
  hold did not reach a report that waited in a device's mailbox while the device waited
  on the runner for its own change. That wait takes only the runner's answers and
  requests, so a report sent before the restart, or after the device's release and
  before its reread, was overtaken by the release, the reread and `taken/2`, handled
  once the stale change was answered, with the hold over, and passed on over what the
  reread read, the input wrong until the next poll, on the manual clock every run and on
  the real clock 200 runs in 200. It was there before the fourth verification's fix too.
  Now a reread that answers sends the device a fence, a message to itself behind every
  one already in its mailbox, and a report the device handles before that fence is
  older than the reread and dropped, the adapter's state kept; a fence an older reread
  sent, overtaken by a second restart's, is passed over. `trip_test.exs` pins it, the
  report sent before the release, before the reread, and before a refused restart that
  a second follows while the device waits throughout, with a report after the restart
  still passed on. Its mutation table, each applied alone in a copy, the full suite
  judged by its exit code, every one red by the new test: the fix reverted, a report
  before the fence passed on; the fence never lifted, red by the runner walk and a
  forces test too; an older fence given to the adapter as a report; and the fence sent
  at the release rather than at the reread.
  1549 tests pass on Elixir 1.20.4 (9 of them doctests), up from 1548.

  **Decision 142, verified a fourth time** (2026-10-20, M4-6's sixth verification): the
  fence was sent once the reread had read, so a report the device was sent while its
  adapter read, a message that may give what the read's sample missed, came before the
  fence and was dropped as older than the read, the input wrong until the next poll, and
  for good where the read does not give that point; with an adapter that is sent such a
  message as it reads, every run in 200 on the real clock. Now the reread sends the fence
  just before it reads, so a report in the mailbox before it was sent before the read
  began and is dropped, and one sent while the adapter reads is held and passed on once
  the reread is taken. `trip_test.exs` pins it on the manual clock. Its mutation table,
  each applied alone in a copy, the full suite judged by its exit code: the fence sent
  once the read is done, red by the new test alone; the fence sent but not kept, red by
  the fifth verification's test; no fence sent, the device waiting on one, red (four
  tests, the runner walk and a forces test among them); and a reread that fails keeping
  its fence too, green, since that only drops a report handled before it by a runner the
  refused restart leaves tripped, which the next restart's read replaces for every point
  the read gives. And the trip test whose 509 ms half found the runner tripped under load
  was a real-time margin, not a race: the panel, written after the drive's 509 ms write,
  had the shared deadline's last millisecond to answer in, a millisecond of real time on
  the manual clock, and tripped `{:io, "panel", :timeout}` 6 runs in 3000 under load; the
  half now writes the drive alone, 0 runs in 3000 under a heavier load, and still fails
  where an answer a millisecond early is judged late. 1550 tests pass on Elixir 1.20.4 (9
  of them doctests), up from 1549.

  **Decision 142, verified a fifth time** (2026-10-20, M4-6's seventh verification): a
  device dropped every reading between its release and its reread, safe only for the
  points the reread gives; `Logex.IO`'s `read/1` gives some or all of a device's points,
  so a report of a point the adapter's read leaves out, arriving in that window, was lost
  for good, the input wrong until that point was reported again. The lead treated it as a
  bug fix within decision 142, not a new policy, which the maintainer confirmed on
  2026-10-20: a device now holds every reading
  from its release, merged, and its reread answers with the read merged over them, so
  the read supersedes a reading for each point it gives, and each point it leaves out is
  given with its answer, which the runner checks as the restart's own read, a bad one
  refusing the restart with that device's fault, `{:io_init, device, cause}`, a good one
  among what the first round reads. `trip_test.exs` pins the verifier's repro, a bad
  report-only reading in the window (a value that does not fit and an address that is no
  input point's) refusing the restart, a report-only reading passed on before the release
  still stale, and an adapter whose reread gives one point, the other, both or neither,
  each against reports of both. Its mutation table, each applied alone in a copy, the
  full suite judged by its exit code: the window's readings dropped again, red (three
  tests); the reread answering its read alone, red (three); the readings merged over the
  read, red (two, the fourth verification's among them); the readings passed on after
  `taken/2` instead of with the answer, red (four); the runner taking a stale change, red
  (three, the new stale test among them); and the device taking a stale change into its
  image, red (three). The fence and its drop were kept as they were, so a report the
  device handles late, having waited on the runner, of a point the reread leaves out, was
  still lost, which the sixth verification below closes. 1554 tests pass on Elixir 1.20.4
  (9 of them doctests), up from 1550.

  **Decision 142, verified a sixth time** (2026-10-20, M4-6's eighth verification): a
  report-only reading was still lost three ways, in an ordinary race around a restart on
  the real clock in 200 runs of 200: a change passed on before the release, answered
  `:stale`, was dropped although the reread did not give its point; a report the device
  handled late, before the fence, was dropped whole, whether sent before the release or
  after it; and a restart refused, on the device's own reread or another device's, ended
  the hold and dropped what it held, though the same reading a moment before the
  release was taken while tripped. Two of the fifth verification's tests pinned the loss
  as correct. Now a device keeps each point's newest reading the runner has not taken,
  and passes on what of it differs from what the runner last took: its reread answers
  with the read merged over all of them; a report before the fence is dropped only for
  the points the reread, or a poll since, gives; a reread the runner refuses is told its
  cause, `Device.refused/2`, the refused point's reading dropped and the rest held; a
  zero that ends a hold passes on what was held; and a change refused in a round keeps
  its other points, passed on at the next reading, only a read that gives the refused
  point passing it on again, a call of the lead's that the maintainer confirmed on
  2026-10-20, decision 143. `trip_test.exs` pins the three losses (the stale change now
  given with the read, reports handled late against a reread of none or one of their
  points, a restart refused on another device with and without a stale change, a bad
  report in the window now keeping its good point) and the refused change's rest; the
  verifier's real-clock repros lose none in 200. Its mutation table, each applied alone
  in a copy, the full suite judged by its exit code: the reread answering its read
  alone, red (four decision-142 tests); a report before the fence dropped whole, red
  (two); a poll's read while the fence is up not marking its points, red (one, the new
  poll-and-fence test); a zero ending a hold without passing it on, red (two, and the
  runner walk); the runner not telling the device a refused reread's cause, red (one);
  the device keeping the refused point's reading from a refused reread, red (one); a
  change refused in a round keeping its refused point, red (two, and the runner walk);
  the device's untaken readings not set aside at its reread, red (seven); and a reading
  passed on while held, red (six, and the runner walk). A held device's passing on at
  the zero's message, checked against a hold since, was green, equivalent, since that
  message comes before any later release, and is now one clause. 1558 tests pass on
  Elixir 1.20.4 (9 of them doctests), up from 1554.

  **The lead's two calls, confirmed** (2026-10-20): the maintainer confirmed both calls
  the lead made in the verifications above, each already built: a report-only input's
  newest untaken reading surviving a restart, a bad one refusing it with its card's
  fault and a good one going into the first round, a bug fix within decision 142; and,
  outside a restart, a change refused for one bad point keeping its other good points,
  passed on with the device's next reading, recorded as decision 143
  (`docs/organisation.md` §7). No code changed. The contract walk, whole, under the seed
  families {2026, 10}, {2027, 3}, {2029, 1}, {2031, 7} and {2033, 12}: 14 tests of 14
  pass in each, the runner walk's reach whole in 2026 and 2033 and missing only
  `:next_due_from_step` in the other three, as in the runs before it. 1558 tests
  pass on Elixir 1.20.4 (9 of them doctests), unchanged.

  **The record's claims of Logix, checked** (2026-10-20, against the manuals' current
  PDFs, `docs/organisation.md` §8): verified, outputs sent at the RPI (1756-UM058L
  pp.24–25, decisions 130 and 136), an output module's configured fault state on a
  communication fault (1756-PM015Q p.12, 1756-UM058L p.123, decisions 130 and 135), a
  force taking effect at once (1756-PM004L p.51, decision 138), the FORCE status
  indicator and forces held by the controller (1756-PM004L pp.52–53, decisions 127 and
  140), a module's Program-mode output state (1756-UM058L p.123, decision 133) and a
  major fault's outputs (1756-UM900B p.242); contradicted, a connection's timeout of four
  RPIs by default (1756-UM001Q p.158: 100 ms at least, 160 ms at the default 20 ms RPI,
  decision 134); partly verified, a task's period changed online (the TASK object's Rate,
  1756-RM018A p.276, decision 139); and not found, a forced input firing its event task
  (decision 138) and one workstation editing online at a time, which Rockwell's help
  probably contradicts (decision 141). No decision's outcome changed.

  **The ninth verification** (2026-10-20, on the record above) found decision 143's first
  option overstated: it said the kept load is the one on the screen, but while tripped no
  round runs and `get/2` reads the resource, so the screen shows the load from before the
  change under either option, and a card still bad gives the bad speed again with each
  reading, so the load passes on at no reading and the restart is refused. The option and
  its scenario now say so, the two differing only from the restart on, and the decision's
  Logix paragraph now marks verified only the two quotes of p.11, which speak of a lost
  connection: that the data holds its last value, not 0, is a reading, and whether a
  connection delivers data good in part unverified. No decision's outcome changed, and no
  code. `trip_test.exs` pins the corrected scenario, the card good on its polls and still
  bad: the load shown from before the change while tripped, taken while tripped only from
  a card good again, and a still-bad card's restart refused. Its mutation table, each
  applied alone and judged by the full suite: a tripped runner's `get!/2` reading the
  runner's merged inputs, red 2, the new test and the hidden seam's while-tripped test; a
  device keeping a refused point's reading, red 3; one dropping the whole change, red 2;
  and one passing the rest on at once, not at its next reading, red 2: the new test red
  under each, the refused-change test beside it under the last three. 1559 tests pass on
  Elixir 1.20.4 (9 of them doctests).
- **M4-7 · The documents.** README's "Running a plant on the clock", with a real run, and
  "What logex is not", plainly; CLAUDE.md's Key Files; `docs/organisation.md` §4.5's
  adapter contract, §4.6's watchdog paragraph, §5's row and decision 14's annotation, as
  landed; and this status.

  **Landed** (2026-10-20), as three commits and a fourth for its review, no code in
  `lib/` changed. README: "On the clock" is
  "Running a plant on the clock", its three runs on the manual clock re-run on the tip,
  their output unchanged, and a fourth, `on_the_real_clock.exs`, the plant on the
  machine's clock: start pressed, three boxes passed, a second's run and a stop, its
  keyword list the same in five runs of five and its figures, said to be that run's,
  1,227 rounds in 1,231 ms, no period reported missed, and no more rounds than
  milliseconds, an average the rule needs but which does not prove it; with the spike's lateness and
  cost figures, for sizing a watchdog, and what is not guaranteed. A new section, "What
  logex is not": not a safety controller, not hard real-time, not certified, not a full
  guarantee of outputs off (a hung device's are the device's, and a VM that stops writes
  nothing), not a compiler to BEAM, no adapter for real I/O but the host's, not IEC
  61131-3's text, and what a controller has that logex lacks (one resource, bool and dint
  only, a forward jump only, no retained values, no output forcing), each checked against
  the code. The "Settled, not yet landed" bullet that still said M4-4 and M4-5 were to
  land is gone, and the intro names the runner. `docs/organisation.md`: §4.5, §4.6, §5's
  two rows, the runner's and forcing's, and decision 14 annotated as landed, and §4.11's
  two paragraphs for README marked said. CLAUDE.md's Key Files: README's sections and
  what stales them, and the status of `docs/organisation.md`. 1559 tests pass on Elixir
  1.20.4 (9 of them doctests), unchanged.

  Its review's fixes (2026-10-20): README's "What logex is not" and §4.6 say that a
  reported pulse is missed too, unless it is an event task's trigger or a round runs
  while it holds, the runner keeping only each input's latest value; §4.5's note says a
  trip latches a device, open for `restart/2`, and a stop or the runner's death closes
  it; README's real-clock run prints `no_more_rounds_than_milliseconds` for what it
  checks, run again, and says which real-clock tests the suite has; §5's row groups
  decision 128 with M4-1's review; and three tests check more, the plant's 2 s run on the
  real clock no more rounds than milliseconds, and a continuous round's watchdog trip and
  a report's fault each every output 0 once and nothing after, so that the table below
  cites no test for what it does not check.

  **Milestone 4's done sentence, checked** (2026-10-20, on M4-7's tip), clause by clause,
  with the test that shows each; a test named here is in `test/logex/`.

  | Clause | Shown by |
  |---|---|
  | §4.4's plant, from files on disk with a box counter in its continuous task, runs on the real clock through bound devices | `end_to_end_test.exs`, "on the real clock the plant runs for 2 s and stops in order": liveness only, running and untripped, 20 rounds at least, `now` 500 ms at least, `k1` on, and every output's last write 0 at the stop. README's `on_the_real_clock.exs` is a run, not a test |
  | its untimed programs back to back, one round a clock millisecond at most | on the manual clock, `runner_test.exs`, "while untimed programs exist, one round each clock millisecond, advance(n) running n, the first at once", "a round that takes a millisecond or more is followed at once, a wake on the clock" and "a round counts a millisecond at least". On the real clock only on average: the 2 s test asserts 20 rounds at least and no more rounds than milliseconds, `rounds <= now + 1`, as README's run prints; **no test asserts it round by round on the real clock** |
  | with the runner's share kept | on the manual clock, `runner_test.exs`, "the share's slots: after C ms of rounds that fill their milliseconds the runner serves the requests that waited, at 10%, 20%, 50% and 90%", "a slot serves the runner's own work for up to S ms, each request whole" and "the timed tasks' runs are left out of the share's count". None on the real clock |
  | each timed task's runs never before their times on its grid | on the manual clock, `api_contract_test.exs`'s runner walk, `Logex.ApiContractTest.RunnerWalk`, which checks after every step when each scheduled round comes, never before a step it waited; and `runner_test.exs`, "rounds on a periodic task keep their grid, absolute, a slow write's time not counted: 100,000 rounds, every one on time", which counts the rounds and checks none missed, not when each came; on the real clock only the clock's own rule, `clock_test.exs`, "wakes a process once, no sooner than its time, and a time already past at once". **No test runs a timed task on the real clock and checks its times** |
  | its runs and the periods it reports missed together one for each grid time passed | on the manual clock, the 100,000 rounds above, every grid time a run and none missed, and `runner_test.exs`, "subscribe/2: the resource's overlaps and faults by default, …", a 25 ms write making the run at 25 and `{:overlap, "fast", 1}` for the grid time at 20; and the runner walk against `cycle/3`. **None on the real clock** |
  | a host test drives the same plant on a manual clock with simulated devices, one reporting its changes and one only read, its outputs and events exactly those `cycle/3` gives for the same times and inputs | `end_to_end_test.exs`, "M4-3's Done-when: the plant through the runner on the manual clock, round for round the oracle's, from files on disk, repeating exactly", 600 seeded presses and waits; and `api_contract_test.exs`'s runner walk, `Logex.ApiContractTest.RunnerWalk`, over seeded configurations |
  | with no untimed program the plant rounds only when a task is due or a trigger changes | `runner_test.exs`, "with no untimed program, a round only at a due time or a trigger's change", on a configuration of a 10 ms relay and an event task over a panel that reports and a drive only read, **not §4.4's plant itself**, whose box counter is untimed; and the runner walk's configurations with no untimed program, about one in four |
  | a task that outlasts its watchdog leaves every output that can still be written at 0, written once | `trip_test.exs`, "a timed task's run that outlasts its watchdog trips before its round's write, naming it; one that takes exactly its watchdog does not", its panel's writes exactly the two zeros, and "a round that outlasts the continuous task's watchdog trips, naming each step with its time, …", its panel's output 0 once after the last count and nothing after (checked since M4-7's review) |
  | a device that fails does too | `trip_test.exs`, "each kind of fault in a poll's read trips, naming its device, every device written 0 once and nothing after", "a report's fault trips, naming its device, every device written 0 once and nothing after" (checked since M4-7's review) and "a round's write that fails trips, the devices after it not written, and the device that failed zeroed where it still takes a write" |
  | a runner that is stopped does too | `runner_test.exs`, "stop/2 writes every output 0 once and closes every device before it returns (decision 116)" |
  | a runner stuck does too | `trip_test.exs`, "a runner stuck in the conveyor's 50 ms step leaves every device at 0 within 50 ms and a poll period of the step's start, not before" and "a runner stuck in its own work leaves every device at 0 within its idle watchdog and a poll period, …" |
  | a runner killed does too | `trip_test.exs`, "a killed runner's devices write every output 0 once and close" and "a runner that crashes zeroes and closes every device, and its supervisor does not start it again" |
  | a tripped runner runs nothing again until the host restarts it | `trip_test.exs`, "while tripped a device's change is merged and makes no round, and a host's request is served at once", "a latched device writes nothing again at its polls, and a tripped runner refreshes no device" and "cold and warm each release the latches, restart the resource and run the first round at once, the clock not counting the stopped time" |
  | one stopped or killed is gone, its child spec `restart: :temporary` | `runner_test.exs`, "its child spec starts it once: restart: :temporary (decision 115)"; `trip_test.exs`, the crash test above, its supervisor starting nothing again |
  | a forced input holds across a restart and, kept in its file, across a crash and a fresh start | `end_to_end_test.exs`, "M4-5's Done-when: the photo-eye forced, against its device, across a restart, a crash and a fresh start from its forces file"; `force_test.exs`, "a runner killed while an input is forced, started again from the same file, comes back with it forced and listed, from its first round" |
  | an online edit is stepped through the running runner between rounds | `end_to_end_test.exs`, "M4-5's Done-when: the plant edited through the runner, every report and round the same steps give over the resource directly, from files on disk"; `runner_edit_test.exs` |

  So every clause is shown by a test on the manual clock, and the three of timing on the
  real clock, rounds back to back one a millisecond at most, the share and the grid with
  its missed periods, are not: the done sentence puts them on the plant's run on the
  real clock, and they are met there only under the milestone's own rule ("every rule is
  tested on the manual clock"; a test on the real clock "asserts liveness only"), the
  real clock's own wake no sooner than its time and the 2 s run's no more rounds than
  milliseconds aside. They are not claimed of the real clock beyond that, nor beyond
  README's one run; and the clause of a plant with no untimed program is shown on a
  smaller configuration than §4.4's plant. Whether that reading of the done sentence
  stands is the maintainer's. *(The maintainer accepted it on 2026-10-20, "Done as is":
  timing proven on the manual clock, the real clock checked for liveness, as the
  milestone's own rule says, so Milestone 4 is done.)*

**Milestone 4 is done when** §4.4's plant, loaded from files on disk with a box counter in
its continuous task, runs on the real clock through bound devices, its untimed programs
back to back, one round a clock millisecond at most, with the runner's share kept, and
each timed task's runs never before their times on its grid, its runs and the periods it
reports missed together one for each grid time passed; a host test drives the same plant
on a manual clock with simulated devices, one reporting its changes and one only read, and
its outputs and events are exactly those `cycle/3` gives for the same times and inputs;
with no untimed program the plant rounds only when a task is due or a trigger changes; a
task that outlasts its watchdog, a device that fails, and a runner that is stopped, stuck
or killed each leave every output that can still be written at 0, written once; a tripped
runner runs nothing again until the host restarts it, and one stopped or killed is gone,
its child spec `restart: :temporary`, so that the host starts a new one; a forced input
holds across a restart and, kept in its file, across a crash and a fresh start; and an
online edit is stepped through the running runner between rounds. *(Reworded 2026-10-18,
after M4-1's review: "each timed task on its grid as closely as the machine allows" could
not be tested, and "nothing runs again until the host restarts it" said a stopped or
killed runner could be restarted.)*

### Milestone 5 — data types

**Designed and decided 2026-10-21** (`docs/organisation.md` §4.12 and §7, decisions
144–167; "decision N" in this section is that §7's). The maintainer asked for 1-, 2-, 4-
and 8-byte integers, how IEC and the vendors handle signed ones, 32- and 64-bit reals,
arrays of all the others, and what else IEC and the vendors have. A design pass on
`0c55e36` read IEC 61131-3 Ed 2 and Ed 3 in full, the conventional family's manuals,
Siemens, CODESYS, Schneider and MatIEC, mapped where logex assumes bool and dint, and ran
the BEAM's float behaviour on Elixir 1.20.4 / OTP 28; its review corrected eight facts
and added decision 159. The maintainer took eleven answers as recommended and changed six:
integer overflow wraps with no power, in every width, the dint's included, superseding
decision 77's saturation (146); conversions take IEC's typed names, `real_to_int`, keeping
`docs/naming.md`'s "never hide a rounding mode inside a conversion name" (148); arrays
have up to three dimensions (151); the bit strings `byte word dword lword` come now, with
`and or xor not shl shr rol ror` on bit strings and integers alike (155); arrays may be
located, one point an element at consecutive addresses (156); and the counters and timers
get typed variants, IEC's `ctu_int` to `ctud_ulint` and long timers in nanoseconds (158).
A bit number may be a tag, `status.[n]`, and one out of range trips the plant, as an index
out of range does (160, 153). §4.12 then put ten readings back to the maintainer, where
two answers meet or an answer leaves a reading open, and left three rules open for the
item that meets them, all thirteen answered on 2026-10-21: seven readings as the record
took them, each a note on its decision; three otherwise, a real too large for its
integer target rounded and then wrapped, `real_to_int` of 40000.7 giving −25535 (161),
the truncations IEC's typed `real_trunc_int` and its fifteen siblings, not `trunc_int`
(162), and `ctu_dint`, `ctd_dint` and `ctud_dint` as aliases of `ctu`, `ctd` and `ctud`
(163); and the three rules, `sqrt` of a negative source 0.0 with no power and the minor
fault `:negative_sqrt` (164), a negative shift or rotate count acting as 0 with no
power, a count of the width or more shifting everything out and a rotate's count taken
modulo the width, with no fault (165), and an integer at a real point stored as the
nearest real, only a value beyond the real's range a bad value (166).

Each item lands as Milestones 3 and 4 did: its words surveyed in `docs/naming.md` first,
before any code, each new word reserved in any case and its commit naming what programs
and configurations it breaks; a gated series, each commit gated alone by `mix format
--check-formatted`, `mix compile --force --warnings-as-errors` in both environments and
`mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4, with its mutation
table in its message, every rule it adds reverted alone and the suite judged by exit
code, every survivor given a test. Throughout:
- **Each item extends `api_contract_test.exs`'s walks with its own rules as it lands**,
  as every item since M1-6 has, its oracles restating each range, wrap and rounding rule
  in Elixir without calling `Logex.Declarations`; M5-15 is only the walks' cross-type
  reach.
- **Each item brings README and `docs/naming.md` with it**: the syntax list, the
  instruction table and an example whose output is real, re-run, and "What logex is not"
  wherever it stops being true (CLAUDE.md: "Any change to the language stales it").
- **The data API refuses what the text cannot say, and widens in the same commit as the
  syntax** (decision 97's rule): `Logex.Tag.new!/4`, `Logex.Configuration.new!/1` and
  `Logex.Parser.well_formed!/1`.
- **A new syntax form** goes into `printer_test.exs`'s generator and `@required_shapes`
  before it lands, and the golden record is regenerated only in that commit, its diff
  read.
- **No float exception and no bad index or bit number leaves a scan**: a host mistake is
  an `ArgumentError` whose message a test pins, a source mistake a diagnostic.
- **Growth is tested in reductions** where a rule walks something: an element's read and
  write against a tag's, a per-element rule against the elements, a conversion family's
  checks against the program.
- **New state** states its rule across an online edit (`Logex.Program.initial_env/1`,
  `Logex.Configuration.initial/1`, §4.9's "One rule for new state").

Sizes use the design pass's key: **S** under about 30 lines of `lib/` and its
tests, **M** 30 to 150, **L** 150 to 500, **XL** more, or a spike first.

**The order** keeps every item gated by the ones before it, and every refusal naming only
what exists: the type table first, changing nothing; the wrap next, on the one width that
exists, so that logex never has two overflow rules; the widths with the integer conversions their refusals name, then their arithmetic; the typed counters and long
timers, which need only the widths; the based literals, which a bit mask wants; the bit
strings, and then the first major fault, on a bit number, before arrays need it; the
reals; then arrays, static before run time, their points, and their instances; and last
the walks' cross-type reach and the documents.

| Item | What | Decisions | Needs | Size |
|---|---|---|---|---|
| M5-1 | One table of types, no behaviour changed | 144 (the table) | — | M |
| M5-2 | The dint wraps: decision 77 superseded on purpose | 146 | M5-1 | M |
| M5-3 | The integer widths, declared everywhere, `move` and literals by Figure 11, and the 56 integer conversions | 144, 145, 147, 148, 156, 157, 159 | M5-2 | L |
| M5-4 | Arithmetic and comparison over every width | 145, 146, 147 | M5-3 | L |
| M5-5 | Typed counters, and `ctu_dint`, `ctd_dint` and `ctud_dint` as aliases | 158, 163 | M5-4 | M |
| M5-6 | Long timers in nanoseconds | 158 | M5-3 | M |
| M5-7 | Based literals and `_` separators | 149 | M5-3 | M |
| M5-8 | Bit strings, located too, the bitwise instructions, literal bit access, the 76 bit-string conversions | 147, 148, 155, 156, 165 | M5-4, M5-7 | L |
| M5-9 | A bit number in a tag, and the major fault, the runner tripping at the end of its step | 160, 153 (the fault), 99, 113 | M5-8 | L |
| M5-10 | Reals: literals, arithmetic, faults, points, forces, the 34 real conversions, the 16 truncations `real_trunc_<integer>` and `lreal_trunc_<integer>`, `sqrt`, a real's bit refused | 147–150, 155, 156, 157, 161, 162, 164, 166 | M5-4, M5-7, M5-9 | XL |
| M5-11 | Arrays of elementary types, up to three dimensions, literal subscripts | 151, 154 (bits), 157, 159 | M5-10 | XL |
| M5-12 | Tag subscripts and the index fault | 152, 153 | M5-9, M5-11 | L |
| M5-13 | Located arrays | 156 | M5-11 | M |
| M5-14 | Arrays of instances | 154 | M5-12 | L |
| M5-15 | The contract walk's cross-type reach | all | M5-14 | L |
| M5-16 | The documents' closing pass | all | M5-15 | S |

- **M5-1 · One table of types.** `Logex.Declarations` gains the type table (§4.12, "The
  types"), with only `bool` and `dint` in it, and every range message, article, guard and
  `fits?/2` in `lib/` reads it; `Logex.Configuration.Text` reads it for its type words and
  its did-you-mean; `Logex.Edit.Plan.word/1` goes through the articles. *Done when* the
  suite passes with no pinned message changed, `lib/` holds no `[:bool, :dint]` guard and
  no hand-written "32 bits" outside the table, a test grepping for both, and each message
  built from the table is pinned for both types. *Size M.*

  **Status: DONE — landed 2026-10-21**, as two commits, the code with its tests and then
  the documents. `Logex.Declarations.table/0` holds `bool` and `dint`, each its word, its
  value in a tag, its kind (`:boolean`, `:signed`), its width in bits, its range, its zero
  and its article; `is_elementary/1`, a guard, replaces the nine `type in [:bool, :dint]`
  guards; `fits?/2` is a clause per row; `a_type/1`, `misfit/2`, `initial_misfit/2`,
  `values/1` and `either/1` build every range message and article the thirteen
  hand-written ones gave, in `Logex.Compiler`, `Logex.Configuration`, its `Text` and
  `Edit`, `Logex.Edit.Plan` (whose `word/1` goes through the articles), `Logex.Runtime`
  and `Logex.Runner`; `Logex.Configuration.Text`'s type words, keywords and did-you-mean
  are the table's, and `Logex.Program.initial_env/1` and `Logex.Configuration.initial/1`
  read its zero. `type_table_test.exs` pins the table, `fits?/2` at each limit, every
  builder, and every message built from the table for both types, each as main gave it,
  and greps `lib/` for a `[:bool, :dint]` guard, for "32 bits", "0 or 1", ":bool or
  :dint", "a `bool` or a `dint`", "-2147483648 to" and "is a dint" in code, for the
  dint's lower limit outside `Logex.Declarations`, and for an article written by hand
  before a type; 60 of its 64 mutants are red, the four survivors equivalent while every
  row has its values (a literal slot of another type, the zeros, the printed word). No pinned message changed: the suite passed
  before a test was added. A differential run, outside the repository, ran the same
  generated programs (mostly refused, so their diagnostics are compared), programs that
  compile scanned with inputs that fit and that do not, Elixir declarations, online edits
  accepted, tested, assembled and untested, configurations from text and from data,
  started, cycled, read by `get/2`, printed and edited through `Logex.Configuration.Edit`,
  against `main` and this branch: ten seeds of 2,000 draws each, 698,809 results,
  each a SHA-256 of its `:erlang.term_to_binary/1`, byte-identical, every changed message
  reached; one message changed by a space made 36,888 of one seed's results differ. It
  found, on `main` as here, an `UndefinedFunctionError` that escapes
  `Logex.Configuration.compile/3` where a program's `var_external` names a global whose
  `var_global` line is broken (`var_global estop boo`), left to its own fix.

  *M5-1's review* (2026-10-22) found no regression and three things to mend, each its
  own commit after the item's two: that `UndefinedFunctionError`, reached by any broken
  `var_global` line a `var_external` names (no type, an unknown one, an instance's, a
  location missing), now passed over so the broken line's own diagnostic is the one
  mistake (decision 42), with the text's totality property given a program type that
  reads a global through a `var_external` and a source whose line for it is broken; the
  one article still written by hand, `Logex.Configuration`'s `"a #{name}"` for a connected
  member that holds an instance, which no text reaches but a program edited by hand does,
  now `Logex.Declarations.instance_of/1`'s, "an rto"; and the grep for a hand-written
  article, widened to an article before a backticked interpolation and to `"a " <>`, its
  allowed articles a section, a configuration element's kind, a program type's name and
  a one-shot's mnemonic. It noted for M5-3 the messages that name two types as an
  example, below, and that a `put_inputs/3` of 400 inputs costs about a tenth more
  reductions for the table's lookup, still linear.
- **M5-2 · The dint wraps.** Decision 146 on the one width there is, before any other
  lands: `add`, `sub`, `mul`, `div`, `neg` and `abs` keep a result's low 32 bits, two's
  complement, and pass no power where the stored value is not the exact one, with no fault
  and no event; a zero divisor is unchanged. The change is on purpose and breaks what
  pinned the old rule, each changed in this item and named in its commit:
  `arithmetic_test.exs`'s limits (`add`, `sub` and `mul` past either limit, a product far
  past one, `div` of −2147483648 by −1, `neg` and `abs` of −2147483648), the M3-3
  Done-when in `end_to_end_test.exs` (a total driven past 2147483647, its oracle's
  `clamp`), `api_contract_test.exs`'s arithmetic oracle, the `add sub mul div neg abs`
  stanzas' logex rows (an amendment line each, the stanzas being append-only), and README's
  instruction table and "Arithmetic", the wild meter's run re-run and its bullet saying
  that the total now wraps and that a lamp after `add` is off for the one scan, so a
  program that must remember latches it. *Done when* each of those pins the wrap, a test
  of each instruction at each limit fails when the wrap is reverted to the old
  saturation, the fill valve's oracle in `end_to_end_test.exs` wraps where it clamped,
  decision 77's note says the rule changed with this commit, and no other behaviour
  changes. *Size M.*

  **Status: DONE — landed 2026-10-22**, as two commits, the code with its tests and the
  stanzas' amendments, then the documents. `Logex.Runtime`'s one rule, `wrapped/1`,
  replaces `bounded/1`: a result inside the dint is itself, with power; any other keeps
  its low 32 bits, read signed, the width from the type table's row through a new
  `Logex.Declarations.width/1`, with no power, and no fault is recorded, so `add`, `sub`,
  `mul`, `div` (the minimum by −1), `neg` and `abs` (the minimum) all wrap; a zero
  divisor and the counters, which stop at a limit (decision 71), are unchanged. Changed on
  purpose, each pinning the wrap where it pinned the stop: `arithmetic_test.exs`'s limits
  (`add`, `sub` and `mul` past either limit, a product far past one, 65536 × 65536 giving
  0, `div` of −2147483648 by −1, `neg` and `abs` of −2147483648, a total run on past the
  top, a branch group, a block's body), with two tests added, a sum that wraps to 0
  passing no power and a wrap raising no fault; `end_to_end_test.exs`'s M3-3 Done-when,
  its oracle's `clamp` now `wrap`, `Integer.mod/2` over 2^32, its total driven past
  2147483647 giving −1294967296 with `total_ok` off for that one run, the oracle checked
  against the wild run too; `api_contract_test.exs`'s arithmetic oracle, which restates
  the wrap as a remainder by 2^32 taken back into the range, independent of the code's
  bit syntax, with a reach, `:far_past`, a result more than 2^32 out; the six stanzas'
  amendment lines; and README's instruction table and "Arithmetic", whose `fill.ld`
  gains `xio total_ok otl overflow` and whose run was re-run. The mutation table, 24
  mutants each judged by the full suite's exit code, every one red: saturation put back
  (15 tests), for `add sub mul` alone (12), `div` alone (2), `neg abs` alone (3), and for
  one instruction at one limit, each of the nine (2 to 8 each); a wrap passing power (15),
  read unsigned (13), not wrapped at all (15), kept to 31 bits (14) or 64 (15), its power
  judged by the stored value (14), recorded as a fault (2); the contract oracle clamping
  (1) or leaving its remainder out of range (1), the fill oracle clamping (2), and the
  `:far_past` reach dropped (1). No growth test: the wrap is one comparison and, past a
  limit, one binary match, whatever the program. 1577 tests (9 doctests), up from 1575.

  *M5-2's review* (2026-10-22) found the wrap right against an oracle of its own, a run
  against the parent and the README re-run, 32 of its 33 mutants red, and three things
  to mend, one commit for the test and one for the documents: a source a hand-built env
  holds outside the dint, read as the integer it is, the result computed exactly and then
  wrapped, was pinned by nothing, a mutant clamping it first green, now pinned in
  `arithmetic_test.exs` (5000000000, −5000000000 and 2^70 in `add v 0 r ote k` giving
  705032704, −705032704 and 0, no power and no fault), the reading provisional, a
  question for the maintainer; the Arithmetic survey table's Add row in
  `docs/naming.md`, which still said a result stops at the nearer limit, now amended
  under the table; and this status, which counted ten single-limit mutants for nine.
  1578 tests (9 doctests).
- **The maintainer's answers of 2026-10-22** to four questions M5-1's and M5-2's
  reviews left (`docs/organisation.md` §7, decisions 168 to 171), landed the same day as
  two commits, the code with its tests and the decisions, then the documents:
  - *168, a program type's name takes no article*: "`m1` runs `motor`, which declares no
    `strat`", as a user block's type is named; its entry is gone from
    `type_table_test.exs`'s allow-list, and every other message naming a program type was
    checked and takes none already.
  - *169, a var_input or var_output that holds an instance is the host's mistake*: one
    `ArgumentError` at the configuration check, a line a tag, the program left out of
    every diagnostic; on `main` a constant or an undeclared global connected to one let a
    `FunctionClauseError` or a `Protocol.UndefinedError` escape `check/1`, now refused.
  - *170, the type table's width is in bits*: §4.12's column renamed, 1 for a bool.
  - *171, a value a state holds outside its tag's type is the host's mistake*, refused
    where the state is handed in, after its owner, every such value a line of one
    message in path order, at any depth, through a guard built from the table,
    `Logex.Declarations.is_fitting/2`: linear in the state, about five reductions a tag, a
    growth test holding 4x the tags under 4.8x; paid on every scan, so M3-5's growth test
    of a skipped rung, 0.23 of running it, is 0.30 now, its bound moved on purpose. M5-2's
    test of a source computed exactly then wrapped is replaced by its refusal, and the
    tests that pinned an integer outside a bool read by value (M1-4's contacts, a
    one-shot's and a pulse coil's storage bit, a timer's `.en`), a plain swap's narrowed
    7 (decision 26's tests, the restart under a recompile) and the edit walk's plain swap
    (now `:swap_outside`, refused, the rule restated in the walk) are changed on purpose,
    each keeping what it pinned with a value that is no integer.

  The mutation table, 17 mutants each judged by the full suite's exit code, every one
  red: no value check (12 tests), the upper limit unchecked (12) or the lower (6), a
  built-in's members not looked into (2), a user block's body (1) or its held type (1),
  the lines unsorted (2), the values checked before the owner (1), the check made
  quadratic (9, the new growth test among them, 15.8x for 4x), a value that is no integer
  refused too (20); the port check gone (1), a var_output's unchecked (1), a held user
  block unnamed (1), the refused program kept for the diagnostics (1); the article put
  back (11); and the walk's swap oracle never (1) or always (1) saying outside. 1586
  tests (9 doctests), up from 1578.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix; answered 2026-10-22, decisions 172 to 174: the
  first and third kept, the second changed, a value that is no integer refused too):
  1. *A var_input or var_output holding an instance that nothing connects* (decision
     169). A *var_input* is a program's input, filled from a global by a *connection*
     line, `m1.run g`. The answer named the connected one; the record refuses the
     program whatever its connections, since no text could have compiled it either way.
     On the conveyor: a hand-edited `motor` whose `run` lamp output holds a timer is
     refused at start even if no line connects `m1.run`, so the operator's plant never
     starts with it, rather than starting and showing the lamp as never driven. IEC and
     Logix have no such program. The other reading refuses only a connected one and
     gives the unconnected one the usual "leaves its var_input unconnected" diagnostic.
  2. *A value that is no integer* (decision 171). The answer refuses a value outside its
     tag's type; the record refuses an integer outside the type's range, 5 in a bool or
     5,000,000,000 in a dint, and still reads a value that is no integer as before: a
     contact reads 2.5 as closed and `nil` as open, `add` reads `"x"` as 0 (M1-4, M3-3).
     On the conveyor: a host that hands in the fan's `speed` as 37.5 sees the fan run as
     if 0 were written, rather than an `ArgumentError`. IEC has no such value; Logix
     cannot store one. The other reading refuses every value `fits?/2` refuses, an
     `ArgumentError` for 37.5 too, retiring M1-4's totality for a state handed in.
  3. *Where a resource is checked* (decision 171). A `%Logex.Runtime{}` the host builds
     by hand is checked as each scan takes an instance, inside `cycle/3`, not on every
     call that takes a runtime, so a configuration edit's steps, which scan nothing,
     carry a bad value to the next cycle, which refuses it; and a global that no instance
     reads is never checked. On the conveyor: nothing an operator sees changes, since the
     runner never takes a runtime from a host; a test that hands `cycle/3` a doctored
     runtime gets the `ArgumentError` from that cycle. Checking every call would cost a
     walk of the whole resource every cycle, including the instances not due.
- **M5-3 · The integer widths.** The stanzas first, `sint int lint usint uint udint
  ulint`, `dint`'s amended (decisions 144 and 145). Each is declarable everywhere a dint
  is: a tag, a block's member, each section, `var_external` among them, a global, a
  located point (decision 156), a host's input, a value of `Logex.IO.Sim`, a force and the
  forces file. `move` and every literal follow decision 147, a refusal naming its
  conversion; the 56 conversions between integer types, `dint_to_int` and the rest
  (decision 148), each truncating and wrapping where its value does not fit, with no
  power, land here, their family stanza first, so that every refusal names one that
  exists; a `cal` formal and a connection widen, and a `var_external` binds exactly
  (decision 159); an edit of a width is refused and a changed initial value of each width
  reported (decision 157). *Done when* §4.4's plant reads its drive's speed as a `uint`
  point through the sim and moves it into a `dint`; each refusal, a literal that does not
  fit, a narrowing `move`, a sign change, a host's or a device's or a force's value that
  does not fit, a `cal` formal, a connection and a `var_external` of another width, is
  pinned in its type's words; an edit of a width is refused at its line; the messages that
  give two types as an example, "needs a type: `x bool` or `x dint`" (`Logex.Declarations`,
  `Logex.Compiler`, `Logex.Configuration.Text`) and the literal "a bool" in two of
  `Logex.Compiler`'s, are read again so that none reads as if bool and dint were every
  type there is (M5-1's review); the contract walk
  draws every width's limits, its oracle restating each range; `dint_to_sint` of 129
  gives −127 with no power, as Logix's truncation does (RM018A p.872); and the commit
  names what the seven reserved words and the 56 conversions break. *Size L.*

  **Status: DONE — landed 2026-10-22**, as four commits: the stanzas first, `sint int
  lint usint uint udint ulint` and one family stanza for the 56 conversions, its
  `**Members:**` line read as data by `naming_test.exs`, `dint`'s and `move`'s stanzas
  amended; then the code with its tests; then a test pinning the two articles below;
  then the documents. The type table holds `bool` and the eight integer widths, each row
  its kind (`:signed`, `:unsigned`), width, range, zero, article and `widens`, Figure
  11's "i" cells, read by `Logex.Declarations.widens?/2`, with `conversion/2` and
  `integers/0`. Each width is declared everywhere a dint is: a tag of each section,
  `var_external` among them, a block's member, a global from text and from data, a
  located point, a host's input, a device's value through the sim, a force and the
  forces file, every refusal in its type's words, a signed width's "does not fit in N
  bits" and an unsigned one's "is outside 0 to max". `move` computes in its
  destination's type, its source of that type or one Figure 11 widens into it, every
  other pair refused naming its conversion and a bool with an integer told that logex
  has none; a literal is judged by its slot. The 56 conversions are generated from the
  table in `Logex.Compiler` and `Logex.Runtime`, each writing its value where it fits,
  with power, and its low bits otherwise, two's complement where signed, with no power
  and no fault: `dint_to_sint` of 129 gives −127. A `cal` formal and a connection widen,
  a refusal naming the conversion, and a `var_external` binds only to a global of
  exactly its type, told so. An edit from `usint` to `uint` is refused at its line and a
  changed initial value of every width reported. The messages that gave two types as an
  example read as examples, "needs a type, as in `var x bool` or `var x dint`", logex's
  type words are listed in the table's order, a global's every width, and the two "a
  bool" of `Logex.Compiler` come from the table. The Done-when is
  `end_to_end_test.exs`'s "the integer widths in the plant (M5-3)": §4.4's plant from
  files on disk, `var_global fan_hz uint at drive.i.0` read through the sim into a
  `dint`, each value up to 65,535 whole, a force held to the uint and read back from the
  forces file, and 65,536 from the device tripping the plant as a bad value.
  `integer_width_test.exs` holds every rule above from source, among them `move` over
  all 64 ordered pairs, the 56 conversions over their limits against a wrap restated,
  and a point of each width through the runner, with the conversions' growth in
  reductions (400 against 100 rungs under 4.8x); the runtime contract walk draws
  programs of every width and a program of each width at each of its edges, its oracle
  restating each range and the wrap as a remainder by 2^N, reaching both limits of every
  width at every one of 13 seeds tried. Changed on purpose, each pinning the new rule:
  every message listing logex's type words, the configuration's keywords and its
  reserved-name refusal, `move`'s refusal of a bool and a dint (no longer "takes operands
  of one type"), the "needs a type" wording, and the tests that used `int` as an unknown
  type word (now `dintt`, or `:real` from Elixir, which M5-10 will change again).

  The mutation table, 35 mutants each judged by the full suite's exit code, every one red
  at the item's tip: `widens?/2` true for every pair (22 tests) or the same type only
  (7); a Figure 11 cell dropped (5), a narrowing (3), a sign change (3) or an unsigned
  into a signed of its width added (3); a `usint` range one too high (15), the `lint`'s
  one short (12), an `sint` article "a" (14), an unsigned misfit in signed words (8); a
  conversion's unsigned bits read signed (4) or signed read unsigned (19), passing power
  on a wrap (21), saturating (21), writing de-energised (2), wrapping into its source
  type (6), one missing (4); a `cal` var_output widened the wrong way (1) or a formal
  exact (1); a connection's copy-in exact (1), copy-out exact (1) or widened the wrong
  way (1); a `var_external` that widens bound (4); the preset hint for a dint alone (1);
  a non-integer input for an unsigned width told its range (2); no conversion named for a
  fixed slot (1), a conversion's slot given the generic hint (1), `move` naming none
  (2); the type words sorted (14); "needs a type" as before (5); each of the two "a
  bool" written by hand (1 each), the first green until the third commit pinned it, its
  change of no message seen by no test; `naming_test.exs` reading no family members (1);
  and the contract walk's oracle clamping (1) or widening an unsigned range by one (1).
  1614 tests (9 doctests), up from 1586.

  *Provisional readings* (each a question for the maintainer, below): the arithmetic and
  comparison slots stay dints until M5-4, another width there refused with the
  conversion that bridges it; a conversion's source is exactly its `from` type; an
  unsigned width's refusal is "is outside 0 to max"; a conversion of a literal draws no
  warning; and logex's type words are listed in the table's order.

  **Questions for the maintainer** (each taken provisionally as written; answered
  2026-10-22, decisions 175 to 179: the first and fifth kept, the second, third and
  fourth changed, a conversion's source widening, the range for every width, and a
  conversion of a literal warned):
  1. *Another width in an `add` or a comparison before M5-4.* A *slot* is the place an
     instruction takes an operand; `add`'s and `eq`'s read dints. The record puts `move`
     and literals in M5-3 and the arithmetic's widening in M5-4, so M5-3 refuses `add
     fan_hz 10 speed` with a `uint` `fan_hz`, telling the programmer to convert it first,
     `uint_to_dint`. On the conveyor: an engineer who adds a fan's `uint` register to a
     dint offset gets a compile error naming the conversion and writes one extra rung
     until M5-4; the operator sees nothing different. The other reading lets a `uint`
     into a dint slot now, as decision 147 would once M5-4 lands, which is what IEC's
     `ADD_DINT` and Logix's ranking both do.
  2. *A conversion's source of a narrower type.* `dint_to_int` is IEC's typed function
     DINT_TO_INT; Ed 3's rule 2 lets a typed function's input convert implicitly, so an
     `sint` could be given to `dint_to_int`. M5-3 takes the source as exactly the type
     the name says and tells the programmer the one that does the job, `sint_to_int`.
     On the conveyor: the box-count trim, an `sint`, put through `dint_to_int` is a
     compile error naming `sint_to_int`, rather than compiling and doing the same thing.
     Logix has no conversion instructions (MOV converts anything); MatIEC requires the
     exact type.
  3. *How an unsigned value that does not fit is told.* A signed width says "`40000`
     does not fit in 16 bits", as the dint always has; for an unsigned one that wording
     misleads, since −1 fits in 8 bits as a pattern, so M5-3 says "`-1` is outside 0 to
     255". On the conveyor: a host that writes −1 to the lamp-count `usint` sees "input
     `count` is a usint: -1 is outside 0 to 255". The alternative is one wording for
     both kinds, the range for every width ("is outside -32768 to 32767"), which would
     change every pinned dint message.
  4. *A conversion of a literal.* `dint_to_sint 129 trim` compiles and always writes
     −127 with no power, as `add 1 2 x` compiles with a warning that its result never
     changes. M5-3 gives the conversion no such warning. On the conveyor: an engineer who
     converts a constant by mistake sees the trim stuck at −127 and the "fits" lamp off,
     with nothing said at compile time. The other reading warns, as an all-literal
     arithmetic instruction does; IEC and Logix say nothing either way.
  5. *How `move` between a bool and an integer is refused.* Before M5-3, `move b d` with
     a bool `b` and a dint `d` was told "`move` takes operands of one type"; M5-3 tells
     it "a bool does not widen into a dint, and logex has no conversion between them",
     in the words every other narrowing `move` is told, since the record defers IEC's
     `BOOL_TO_*` and `*_TO_BOOL` (Tables 24 and 25: a contact and a coil do the work).
     The record does not ask for this wording; it was the builder's choice. On the
     conveyor: an engineer who moves the photo-eye's bool into the box count reads that
     there is no conversion, and writes `xic eye move 1 count` instead; the operator
     sees nothing different. The other reading keeps the older sentence for this one
     pair. IEC has `BOOL_TO_INT` and its kin; Logix's MOV takes no BOOL.

  **M5-3's review**, fixed on 2026-10-22, each with a test that fails when its fix is
  reverted, judged by the full suite: (1) a global a connection copies in is checked
  against its own type before the copy-in, which since decision 159 may widen into its
  var_input, so that a hand-built runtime holding 70000 in a `uint` global read by a dint
  var_input is refused by `cycle/3`, "runtime.globals holds `a` outside its type: it is a
  uint, and 70000 is outside 0 to 65535", a line each in name order, a global read twice
  told once, rather than copied on into a wider global (decision 171's reading; before
  M5-3 the two types were one, so the var_input's check covered it); its mutants, the
  check gone, the lines unsorted and a global read twice told twice, each red (1 test);
  (2) the forces file's test puts every width one past each of its limits, a file for
  each end, so that a forced `ulint` out of range in the file is refused, the review's
  surviving mutant, red now (1 test); (3) `integer_width_test.exs`'s reserved-word test
  is titled for what it checks, the type words no tag or global and the conversions no
  tag or label, a conversion being reserved in `.ld` files only, as every mnemonic is,
  and checks each conversion in upper case too. The review's other notes are for later
  items or need nothing: `Logex.Edit.Plan.changed/2`'s `!=` is noted in M5-10, and
  `dint_to_dint`, told "unknown instruction", is told as every unknown mnemonic is.
  1615 tests (9 doctests), up from 1614.
- **The maintainer's answers of 2026-10-22** to M5-3's five questions and decision 171's
  three (`docs/organisation.md` §7, decisions 172 to 179), landed the same day as two
  commits, the code with its tests and the decisions, then the documents:
  - *172, decision 169 kept*: a hand-edited program whose var_input or var_output holds
    an instance is refused whether or not it is connected; no code changed.
  - *173, a value that is no integer is the host's mistake*: 37.5, `nil`, `"x"` or a map
    in a bool or an integer tag or member is refused with decision 171's message, "it is
    a dint, and its value must be an integer, found 37.5", a bool's "only 0 or 1 fit,
    found nil", a resource's global as each scan takes it too, retiring M1-4's lenient
    reading for a state handed in; the walk is decision 171's, a guard a value, so
    linear. Changed on purpose, each keeping what it pinned with a value inside its type
    and pinning the refusal of what it read before: M1-4's contacts, the comparisons on
    a hand-built env, the one-shots' and pulse coils' storage bits, a timer's `.en` and
    hand-built bits, the arithmetic's sources and divisor that read 0, a hand-built
    timer's members, the restart under a recompile, a plain swap's map under a bool or a
    dint (now refused at its next call, where an edit's first test started it again,
    decision 26, which an integer under an instance's tag still reaches), and the edit
    walk's swap oracle.
  - *174, the checking place kept*, and *175, decision 147 kept until M5-4*: no code
    changed.
  - *176, a conversion's source widens*: `dint_to_int` takes any source Figure 11 widens
    into a dint, a tag's or a member's, and only one that does not is refused, told the
    conversion from its own type or `move`; the destination stays exact.
  - *177, every width's misfit gives its range*: "`128` is outside -128 to 127",
    "`5000000000` is outside -2147483648 to 2147483647", replacing "does not fit in N
    bits", every pinned message changed on purpose.
  - *178, a conversion of a literal warns*: "`dint_to_sint` reads a literal, `129`: its
    result never changes".
  - *179, M5-3's wording for `move` between a bool and an integer kept*: no code changed.

  The mutation table, 17 mutants each judged by the full suite's exit code, every
  one red: a value that is no integer read as before (17 tests), a global that is none
  passed (1), an integer type's told its range (8), a bool's shown unquoted (4), a
  built-in's members not looked into for one (4); the signed misfit in bits (34), with no
  value shown (6), a lint's alone (7); no conversion source widening (1), every integer
  source taken (2), the widening read backwards (1), the destination widening too (1,
  green until a test of a destination of another width was added), a member source
  never widening (1), every value slot of every instruction widening (1); no
  conversion warned (1), only the dint's (1); and the edit walk's swap oracle reading a
  value that is no integer as inside (1). One more, every read slot widening, is green
  and equivalent: every read slot takes a bool, which widens into nothing. 1617 tests (9 doctests), up from 1615. The README's `drive.exs` was run
  again and prints what the README shows.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix):
  1. *An instance's tag that holds no map* (decision 173). The answer refuses a value
     that is no integer in a bool or an integer tag or member. A tag that holds an
     *instance* of a function block, a timer `run_on`, is a map of its members, and one
     a host hands in holding 5 or `nil` is still read as a fresh instance, each member 0,
     as a plain swap from a dint `k` to a timer `k` leaves it (an edit's first test then
     starts it again, decision 26). On the conveyor: a host that hands in the fan's
     run-on timer as `nil` sees it read as a timer just started, its time and its done
     bit 0, so a run-on already under way starts over, rather than an `ArgumentError`. The other reading refuses it too, so
     that only a map reaches an instance's tag and a plain swap from a dint to a timer is
     refused at its next call. IEC and Logix have no such state.
  2. *How a value that is no integer is told in an integer type* (decision 173). logex
     says "it is a dint, and its value must be an integer, found 37.5", the words an input
     that is no integer is told, rather than decision 177's range, "37.5 is outside
     -2147483648 to 2147483647", which reads as if 37.5 were not between them. On the
     conveyor: a host that hands in the fan's speed as 37.5 reads that a dint's value must
     be an integer. A bool's says "only 0 or 1 fit, found 37.5" either way.
  3. *A built-in's internal member* (decision 173). A timer's `last`, the time it last
     ran, is no bool or integer member a program can name, so the check does not look at
     it, and one that is no integer adds no time, as before. On the conveyor: a host that
     hands in a timer whose `last` is `nil` sees it count from that scan. The other
     reading refuses a `last` that is no non-negative integer as the host's mistake.
- **M5-4 · Arithmetic and comparison over every integer width.** The signatures' slots take a type class, ANY_INT or ANY_NUM as data,
  unified across every operand of an instruction, so a three-operand `add` is checked
  whole; each computes in its destination's type, sources widened by decision 147, and
  wraps there (decision 146); `neg` into an unsigned destination is refused (decision
  145); `div` and `mod` keep decisions 78 and 99 in every width; comparisons of integers
  are by value. *Done when* `arithmetic_test.exs` holds every rule at
  every width's two limits, 127 + 1 in an `sint` giving −128 and 0 − 1 in a `usint` 255,
  each with no power; a three-operand mismatch fails when the unification is reverted;
  comparisons of a signed with an unsigned operand are exact at their limits; and the
  contract walk's arithmetic
  oracle covers every width from its own ranges. *Size L.*

  **Status: DONE — landed 2026-10-22**, as three commits: the stanzas' amendments first,
  the Arithmetic table, `add` with the departure decision 147 asks it to state, `sub`,
  `mul`, `div`, `mod`, `neg`, `abs`, `eq` and the seven type stanzas from `sint` to
  `ulint`; then the code with its tests; then the documents. The slots of `add sub mul div
  neg abs` and the six comparisons take IEC's ANY_NUM and `mod`'s ANY_INT, generic types
  as data in `Logex.Declarations`, each the kinds of rows it holds (`is_class/1`,
  `in_class?/2`, `a_class/1`, `class_range/1`), so that a real joins ANY_NUM by its row.
  `Logex.Compiler`'s `classed/3` holds an instruction's operands together: where it
  writes a destination of its class it computes in that type, each source tag of a type
  Figure 11 widens into it, any other told "`add` computes in `s`'s type, an sint, but `d`
  is a dint (declared on line 1): a dint does not widen into an sint, so convert it
  first, with `dint_to_sint`", and a literal source must fit it; `neg` into an unsigned
  destination is refused, told that alone; a comparison's two integers need nothing of
  each other. `Logex.Runtime` wraps each result into its destination's type, found at
  each scan in the routine's tag table (`type_at/2`), a member's by its built-in's
  schema, as a counter's kind is found, the IR unchanged; a comparison reads Elixir's
  integers, exact by value. The fixed integer slots the arithmetic and comparisons had
  are gone, and with them the hints "convert it first" and "write a dint and convert it"
  for a fixed slot. The Done-when is `arithmetic_test.exs`'s two new groups: every rule
  at every width's two limits, `add sub mul div mod` over each width's limits in its own
  type and `neg` and `abs` over the signed ones, against each range, Figure 11 and the
  wrap restated from IEC's tables, 127 + 1 in an `sint` giving −128 and 0 − 1 in a
  `usint` 255, each with no power; every Figure 11 pair computed in the destination's
  type and every other pair refused naming its conversion; the three-operand mismatch
  `add d i s`, red with the unification reverted; a literal source at each width's limits
  and one past them; `neg` into each unsigned width refused; the zero divisor and the
  minimum by −1 at every width and the remainder's sign at every signed one; a member's
  and a block's destination; the comparisons of all 64 ordered pairs of widths over their
  limits, exact by value; and the arithmetic's growth in reductions, 4x the instructions
  and tags under 4.8x. The contract walk's arithmetic gives every tag a width drawn from
  the eight, each source of a width Figure 11 widens into its destination's, its oracle
  wrapping in the destination's width, its reach a widened source and a wrap in each
  width, held at its seed and at {n, 10, 333}, n from 1 to 30, after a dividend and a
  divisor drawn for a width's minimum by −1. Changed on purpose: every message that said
  an arithmetic or comparison slot "reads a dint" says "reads a number", `mod`'s "an
  integer"; a literal source's misfit is told in its destination's type, "`add` computes
  in `d`'s type, a dint: …"; a comparison literal past a dint, `gt n 3000000000`, now
  compiles, and the compile walk's fragment is a literal past 2^64; and
  `integer_width_test.exs`'s test of another width in a dint slot pins the widening.
  Found on the way: the M5-3 contract walk drew widths from `Map.keys(@widths)`, an
  atom-keyed map whose keys come in the order of the atoms' indexes in the atom table, so
  its draws differed between a run of the one file and of the whole suite; every draw now
  reads a list, `@width_types`. README's `drive.exs` gained a `uint` doubled in a `uint`,
  an `add` and a `neg` refused, and was run again; its output is the README's.
  The mutation table, 24 mutants each judged by the full suite's exit code, every
  one red: the unification reverted (11 tests), every integer source taken (3), the
  widening read backwards (7), a literal source never held to the destination (4) or held
  to the dint (2), a literal with no type known never checked (3) or held to the dint (2);
  `neg` into an unsigned type taken (1), `abs` refused there too (3), a refused `neg` told
  its sources as well (1); a generic slot taking a bool tag (4) or member (3), `mod`
  ANY_NUM (1), no member suggested for an instance named whole (3), a bool read as of a
  class (7), the class range the signed types' alone (2); the runtime wrapping every
  result into a dint (7), a member's into a lint (1), a division's (4) or `neg`'s and
  `abs`'s (2) into a dint, a comparison read as 64 bits unsigned (2), the destination's
  type found by a linear walk of the tags (1, the growth test); the walk's oracle wrapping
  into a dint (1) and drawing no source of another width (1).
  1632 tests (9 doctests), up from 1617.

  *Provisional readings* (each a question below): a literal compared with a tag is taken
  by value whatever the tag's type, two literals each within −2^63 to 2^64 − 1; the slots'
  word in a message is the generic type's, "a number" for ANY_NUM before the reals land;
  and a `neg` refused for its unsigned destination is told that alone.

  **Questions for the maintainer** (each taken provisionally as written, the closest
  reading to the record and to Logix):
  1. *A literal compared with a narrower tag.* A comparison reads two integers by value
     whatever their types (decision 147); a literal is "judged by its slot", and a
     comparison's slot has no type of its own. logex takes `lt trim 200` with an `sint`
     `trim`, which can hold only −128 to 127, so the comparison always passes power. On
     the conveyor: an engineer who compares the fan's `sint` trim with 200 sees the lamp
     after it always lit, and nothing is said when the program compiles. The other
     readings refuse it, "`200` is outside -128 to 127", as IEC's typed `GT_SINT` would,
     its literal an SINT; or compile it with the warning a comparison of two literals
     gets, its result never changing. Logix takes it, converting both to the wider type
     and comparing.
  2. *The word for the arithmetic's slots in a message.* `add b 1 d` with a bool `b` is
     told "`add` reads a number, but `b` is a bool", and `mod b 2 d` "`mod` reads an
     integer", IEC's ANY_NUM and ANY_INT in words. Until the reals land a number is an
     integer, so the words differ only for the operator who reads them both. On the
     conveyor: an engineer who adds the photo-eye's bool into the box count reads that
     `add` reads a number. The other reading says "an integer" for both until M5-10, and
     changes `add`'s message when the reals come.
  3. *What a `neg` into an unsigned destination is told.* `neg level count` with a `usint`
     `count` is told "`neg` writes `count`, a usint, which holds no negative value: `neg`
     writes a signed type", and nothing of its source, whatever it is. On the conveyor: an
     engineer who negates the level into the box count is told to write a signed type, and
     on the next compile, if the level is a `dint` and the new destination an `int`, is
     told that the dint does not widen. The other reading names a signed type the source
     widens into, "write an int or wider", or tells both problems at once. IEC has no
     NEG; Logix's NEG into an unsigned tag is `unverified`.
- **M5-5 · Typed counters.** The stanzas, then `ctu_int ctu_lint ctu_udint ctu_ulint`,
  `ctd_*` and `ctud_*` of the same four (decision 158), rows of `Logex.FbType.rules/1`
  run by `ctu` and `ctd`, a preset judged in its instance's type, each stopping at its
  type's limits with `ov` or `un` latched, decision 71 by width, as the maintainer
  answered §4.12's fifth question; and `ctu_dint`, `ctd_dint` and `ctud_dint`, aliases of
  `ctu`, `ctd` and `ctud`, which are the same thing (decision 163), each a type word with
  its own stanza, which `naming_test.exs` checks, a declaration with either word giving
  the one type and keeping no spelling, so that every message and warning names the
  instance by the plain word. *Done when* a `ctu_int` count stops at 32,767 with `ov` on
  and a `ctd_udint` at 0 with `un` on, a `ctu_ulint` counts past 2^63, a preset outside
  its type is refused at its line, an edit that changes a counter's width is refused, its
  edge memory is on the block list as a `ctu`'s, the event task's warning names each, and
  the contract walk's counter oracle draws every width; `var boxes ctu_dint` and `var
  boxes ctu` compile to equal programs, `ctd_dint` and `ctud_dint` likewise, a test that
  fails when an alias is made a type of its own; an instance declared `ctu_dint` is named
  `ctu` in its unrun warning, its article (`instance_of/1`), the compiler's refusal of a
  second `ctu` on it, the event task's counter warning and an edit's refusal of a change to `ctu_int`, each
  pinned; an edit from `ctu` to `ctu_dint` is accepted with no report; and the commit
  names what the fifteen reserved counter words break. *Size M.*
- **M5-6 · Long timers in nanoseconds.** The stanzas, then `ton_ltime tof_ltime tp_ltime`
  and `rto_ltime` (decision 158, its last taken as the maintainer answered §4.12's
  seventh question), run by
  `ton`, `tof`, `tp` and `rto`, their `pre` and `acc` `lint` nanoseconds, the preset on
  the instruction in nanoseconds, 0 to 2^63−1, each scan's elapsed milliseconds counted as
  1,000,000 ns each, so that the resolution is a millisecond, said in each stanza, with a
  warning for a preset that is not a whole number of milliseconds; each stanza and
  README's timer section say that a preset's unit is its instance's, so that one rung's
  preset is a million times longer on a `ton` than on a `ton_ltime` (§4.12's routine
  choice). *Done when* a `ton_ltime` with a preset of 30 days in ns is done at exactly 30
  days of scans and never before, a preset of 1,500,000 ns is done at the 2 ms scan and
  warned of, the one rung `ton t 2000000` is done at 2,000,000 ms with `t` a `ton` and at
  2 ms with `t` a `ton_ltime`, a test that fails when either unit is taken for both, each
  long timer's rules of M3-2 hold for it from source through `call/4`, an edit resumes one
  by its type's `times` member, an edit from `ton` to `ton_ltime` is refused, and the
  contract walk's timer oracle draws them. *Size M.*
- **M5-7 · Based literals and separators.** `16#`, `2#` and `_` (decision 149), through
  the lexer, `well_formed!/1`, the printer, the generator and curated golden sources.
  *Done when* each form is in the golden record's curated sources, an entry that held
  `1_000` or `16#…` before changes and its diff is read, `16#ffff` is 65,535 in a `uint`
  and refused in an `int`, and `8#17`, `16#-1`, `16#_ff`, `1__0`, `1_`, `_1` (a name, not
  a number) and `1.5_` are pinned refusals or readings, and Logix's suffixes `5U` and `5L`
  pinned as B2's mistyped lexeme at their columns (decision 149, the vendors' suffixes
  refused), each a test that fails when its lexer clause is reverted. *Size M.*
- **M5-8 · Bit strings, the bitwise instructions and literal bit access.** The stanzas
  first: `byte word dword lword`, `and or xor not shl shr rol ror`, and the bit-string
  conversions' family stanzas, `docs/naming.md`'s `wand` rows amended (decision 155). The
  four types, with no arithmetic, comparing as unsigned, each declarable everywhere an
  integer is (M5-3): a tag, a block's member, each section, `var_external` among them, a
  global and a located point (decision 156), its value from a device, a host's
  `put_inputs/3`, `Logex.IO.Sim` and a force an integer from 0 to 2^N−1, checked by
  `fits?/2`, and the forces file spelling it as the integer; the eight instructions on bit
  strings and integers alike, computed in the destination's type, operands all of one kind,
  a mix refused naming its conversion (decision 147, §4.12's second question answered as
  recorded); a shift or rotate whose tag count is negative at run time acting as a count
  of 0, the source written unshifted, with no power out, a `shl` or `shr` count of the
  width or more writing 0 with its power in, and a rotate by its count modulo the width,
  none of them a fault (decision 165); a comparison of a bit string with an integer tag
  refused naming its conversion, a literal judged by its slot (§4.12's ninth question,
  answered as recorded); the 12 conversions between bit strings and the 64
  between a bit string and an integer, binary transfers; and `x.3` on every integer and
  bit string, read by a contact and written by a coil, a one-shot's storage bit and a
  pulse coil's two bits among them, the number checked against the width when the program
  compiles; a coil on a bit a write of its word in `Logex.Walk.writes/1`, the writer
  warnings and the input-point refusal; a bit of a `bool` refused, and a bit of a real
  with the reals (M5-10). *Done when* `shr` of an `int` −2 by 1 gives 32,767 (zero fill),
  `rol` of a `byte` 2#1001_0001 by 1 gives 2#0010_0011, a shift by the width gives 0, a
  negative literal shift count is refused, `shl` of a `word` 16#00ff by an `int` tag at
  −1 writes 16#00ff with no power and no fault and by 16 and by 40 writes 0 with its
  power in, `rol` of a `byte` by 9 gives what a rotate by 1 gives, and `ror` by an `int`
  tag at −3 writes its source with no power, each a test that fails when its rule is
  reverted (the count taken as its bit pattern, the power passed, a fault raised), every width's top bit is read and written in
  two's complement, `add` of a `word`, `and` of a `word` with an `int` destination and
  `eq` of a `word` with an `int` tag are pinned refusals naming what to use, a coil on a
  bit of a located input point is refused and one on a bit of a `var_external` makes it a
  writer of its global, `ote status.3` beside `move x status` draws the second-`ote`
  warning, an edit of a rung with `ons status.3` blocks it once; §4.4's plant reads the
  drive's status as a `word` point, `var_global drive_status word at drive.i.4`, through
  the sim, its `drive_status.3` lighting the run lamp against an oracle that knows nothing
  of logex; 65,536, −1 and a float for that point are pinned refusals from the device (a
  bad value that trips the runner, decision 114), a host's `put_inputs/3` and a force,
  each in the `word`'s words; a `word` force of 65,535 reads back from the forces file
  across a restart and a fresh start; a `bool`'s bit is a pinned refusal; and the contract
  walk draws bit strings, their points, bitwise instructions and bits. The commit names
  what `and`, `or`, `not`, `byte` and `word` break. *Size L.*
- **M5-9 · A bit number in a tag, and the major fault.** `status.[n]` (decision 160), an
  integer tag of any width, never an expression, refused on a one-shot's bit; a number
  outside the width at run time the first major fault: `%Logex.Fault{}` gains `severity`,
  `:minor` for a zero divisor, `:major` for `:bit_out_of_range`, with the number read,
  decision 99's placement, and `Logex.Runner` trips on the round's first major fault at
  the end of the step that raised it, running no later step of the round, before its
  write, `{:fault, task, instance, fault}`, on decision 113's one path (§4.12's "The major
  fault", its tenth question answered as recorded). *Done when* the run lamp follows `drive_faults.[sel]` in
  §4.4's plant on the manual clock against an oracle that knows nothing of logex; `sel` at
  16 in a `word` trips the runner with every output 0 once and nothing after, the trip
  naming the instance, file, line and number; a round whose first due task raises the
  fault runs none of its later steps, a later task's instance read through `get/2` after
  the trip as the round before left it, while a second instance of the faulting task's run
  is scanned, a test that fails when the runner runs the round's every step; a lone
  instance's `state.faults` holds the major fault and the scan ran on, the instruction
  doing nothing as §4.12 states it, a test per kind of instruction; a rung a jump skips
  and a block whose `cal` is false with `sel` at 16 raise nothing (decision 82);
  `fault_test.exs` pins the severity on both kinds; every host's pattern on
  `%Logex.Fault{}` in README and the tests is brought to the new field; the runner walk
  reaches the new trip reason, its model running a tripping round's steps up to the one
  that raised it; and an element read stays within a measured bound of a tag's in
  reductions. *Size L.*
- **M5-10 · Reals.** A spike first, on Elixir 1.20.4 and OTP 28, throwaway: the cost of a
  destination lookup and a single-rounding write, and the shortest spelling of a single
  that reads back to it, written and tested. Then the stanzas `real` and `lreal`, the 34
  real conversions, the 16 truncations `real_trunc_<integer>` and
  `lreal_trunc_<integer>` (decision 162) and `sqrt` (decisions 148 and 79); the literal
  (decision 149) through the lexer, the parser, `well_formed!/1`, the printer, the
  generator, `@required_shapes` and curated golden sources; arithmetic, comparisons and
  `move` (decision 147); decision 150's zero divisor, saturation, −0.0, subnormals and
  single rounding; a real's zero, 0.0; host, device and force values, the forces file's
  spelling and the configuration file's `print/1` (decision 156); real points; and a bit
  of a real, `fan_speed.3` or `fan_speed.[sel]`, refused (decision 155); a real into an
  integer rounded and then wrapped, with no power, where the rounded value does not fit
  (decision 161); `sqrt` of a negative source 0.0, no power and the minor fault
  `:negative_sqrt`, decision 99's kinds grown by one (decision 164); and an integer at a
  real point stored as the nearest real, silently, only a value beyond the real's range a
  bad value (decision 166). A literal negative source, `sqrt -4.0 x`, is refused when the
  program compiles, at its line, as decision 78 refuses a literal zero divisor (decision
  167). *Done when* no float exception leaves a scan
  under a seeded walk of values near each real's limits, at zero divisors and at
  subnormals; no state, output, `get/2` answer or forces file ever holds −0.0, an
  infinity's bits or a subnormal, each pinned by a test that fails when its guard is
  reverted (a `real` write of 3.5e38 the one that encodes an infinity silently); every
  write to a `real` rounds to the nearest single, `move 0.1 x` reading back through
  `get/2` as 0.10000000149011612 in a `real` and 0.1 in an `lreal`, and `add 16777216 1.0
  x` giving 16777216.0 in a `real` and 16777217.0 in an `lreal`, each failing when the
  rounding is reverted; a literal `0.0` or `-0.0` divisor and a `mod` of a real are
  refused at their lines; `1.`, `.5`, `1e5`, `1.5e+3` and Logix's `1.5L` are pinned
  refusals at their columns, each failing when its lexer clause is reverted; `fan_speed.3`
  and `fan_speed.[sel]` on a `real` and an `lreal` are pinned refusals at their lines;
  IEC's examples are tests, `real_to_int` of 1.5, 2.5, −1.5, −2.5, 1.6 and 1.4 giving 2,
  2, −2, −2, 2 and 1 and of 0.5 and 3.5 giving 0 and 4, so that a ties-away
  implementation, Elixir's `round/1`, fails them, `real_trunc_int` and `lreal_trunc_int`
  of −1.6 giving −1 and `trunc_int` a pinned unknown mnemonic; a value outside the target
  is rounded and then wrapped (decision 161), `real_to_int` of 32767.6 giving −32768, of
  32768.4 −32768, of 40000.7 −25535 and IEC's own case, 70000.4, 4464, each with no power,
  and of 32767.4 32767 with power, a test that fails when the value is truncated before
  it wraps, as the record first read it (32767.6 then giving 32767 and 40000.7 −25536),
  and `real_trunc_int` of 40000.7 giving −25536 with no power; `sqrt` of −0.25 writes 0.0
  with no power, its fault `:negative_sqrt`, minor, `instruction: :sqrt`, in a lone
  instance's `state.faults` and as a cycle's `{:fault, ...}` event, `fault_test.exs`
  pinning its kind and severity, a test that fails when the source is not checked; an
  integer of 16,777,217 at a `real` point, from the sim, a host's `put_inputs/3` and a
  force, reads back through `get/2` as 16777216.0 with no trip and no refusal, and 2^128
  at a `real` point trips the runner as a bad value from the sim and is refused from a
  host and a force, in the `real`'s words, while 2^53 + 1 at an `lreal` point reads back
  as 2^53, each a test that fails when its rule is reverted; a `real` forced
  or printed as `0.1` reads back exactly; a changed real initial value is reported as
  `:initial_changed`, `var x real 0` edited to `var x real 0.0` among them, `{0, 0.0}`,
  the running 0.0 kept (decision 157), a test that fails when the comparison is `!=`
  (`Logex.Edit.Plan.changed/2`'s, `!=` at M5-3, under which 0 and 0.0 are one value, as
  M5-3's review noted, so it becomes `!==`); the
  configuration file's round trip holds with reals; the contract walk's arithmetic oracle
  covers both reals; and the fan's speed in §4.4's plant is a `real` read from the sim,
  against an oracle that knows nothing of logex. *Size XL.*
- **M5-11 · Arrays of elementary types, literal subscripts.** A spike first, throwaway:
  the representation (a tuple, §4.12's routine choice) and the size limit, measured. Then
  decision 151 with literal subscripts only, one to three dimensions: the syntax through
  the front end (the two golden sources that hold `[` change, the diff read), the
  declaration and its initial list in the elements' order, the IR's element operand, the
  compile-time bound check, `Logex.Walk` and the warnings with a literal subscript as its
  element's path, every one-shot's storage bit and every pulse coil's two bits on an
  element (decision 154), the edit (a type, dimension or size change refused, elements
  moved by path, a changed initial list reported element by element, decision 157),
  `get/2` and connection paths, a host's array input checked, unlocated array globals and
  `var_external` arrays bound exactly (decision 159). *Done when* `weights[3]` and
  `grid[1,7]` run in a program from source against an oracle that knows nothing of logex;
  `weights[8]` in an `int[8]`, a declaration of four dimensions, `var cells int[2,2,2,2]`,
  refused at its line, an initial list of the wrong length, a host's list of the wrong
  length or shape and a `var_external` of another size or dimension are pinned refusals;
  an edit of a rung with `ons edge[2]` blocks it once; growth tests in reductions hold an
  element's read and write within a measured bound of a tag's; and the contract walk draws
  arrays of one, two and three dimensions with literal subscripts. *Size XL.*
- **M5-12 · Tag subscripts and the index fault.** Decisions 152 and 153: a tag subscript
  of any integer width, the run-time check where the element is read or written, the
  major fault `:index_out_of_range` with the subscripts read, on M5-9's path; a write
  through a tag subscript a write of the whole array (§4.12's routine choice); a tag
  subscript refused on a one-shot's storage bit, a pulse coil's bits and whatever runs an
  instance. *Done when* the box counter's `weights[slot]` runs in §4.4's plant on the
  manual clock against an oracle that knows nothing of logex; a `slot` of 8 trips the
  runner with every output 0 once, the trip naming the instance, file, line and index; a
  false `otl weights_bits[slot]`, a skipped rung and a frozen block with `slot` at 8 raise
  nothing (decision 82); `ons edge[slot]` is a pinned refusal; `fault_test.exs` pins the
  kind; and the runner walk reaches it. *Size L.*
- **M5-13 · Located arrays.** Decision 156's follow-up: `var_global temps real[8] at
  card.i.0` occupying `card.i.0` to `card.i.7`, in the elements' order, each element a
  point named `temps[3]`, grouped by `Logex.IO.points/1`, read, written and forced as its
  own point, the forces file naming it so; a range that overlaps another point refused,
  both named; an online edit's located-I/O refusal covering the range. *Done when* §4.4's
  oven card gives its eight zone temperatures as one located array through the sim,
  `temps[3]` forced against its device and across a restart, a crash and a fresh start
  from its forces file; an overlap and a range past an adapter's points are pinned
  refusals; and the runner walk draws a located array. *Size M.*
- **M5-14 · Arrays of instances.** Decision 154: `var lane_t ton[4]`, `var lanes
  seal[4]`, a literal subscript on every instruction that runs one, a tag subscript on a
  member's read or write. *Done when* each refusal is pinned, the one-run rule holds per
  element (`ton lane_t[2] 500` twice refused), decision 85's two counter rungs hold per
  element, an edit of a lane's timer resumes it by its path `lane_t[2]`, a counter's edge
  memory on an element is on the block list by its path, an event task's timer, counter
  and one-shot warnings name each element, a `cal` of an element runs only its instance,
  and the contract walk draws arrays of instances. *Size L.*
- **M5-15 · The contract walk's cross-type reach.** Each item above has extended the walks
  with its own rules; this one draws the types together: programs, configurations and
  runner walks that mix every type, `@junk` and `@edges` by type (`1.0` stops being junk
  for a real), mixed-type `cal`s and connections (decision 159), bits and arrays with
  literal and tag subscripts, and edits refused by type, against oracles that restate each
  rule. *Done when* the walks' reach covers every type, every refusal kind and every trip
  reason but `{:internal, message}`, repeating exactly from fresh processes. *Size L.*
- **M5-16 · The documents' closing pass.** Each item has brought its README sections,
  instruction table rows and stanzas; this one checks "What logex is not" (which says
  "bool and dint only, no real, no bit access, no arrays") against the code,
  `docs/naming.md`'s `bool`, `dint` and `at` stanzas and its deferred and rounding rows,
  `docs/organisation.md` §4.1, §4.5, §4.7, §4.8, §4.12 and §5 annotated as landed,
  `PLAN.md` M1-3 and §5's structured-addressing entry, CLAUDE.md's Key Files, and
  Milestone 5's done sentence clause by clause against the tests. *Size S.*

**What stays deferred**, each a later item or milestone (§4.12): the TIME and LTIME types,
the dates and `T#` literals; strings and characters; enumerations, named values and
subranges; structures, UDTs and directly derived types; typed literals, `int#5`, and
octal; references; IEC's array bounds, `ARRAY[*]`, more than three dimensions and
whole-array `copy` and `fill`; IEC's byte and word partial access, `w.%B1`; online
widening; `round`, `ceil` and `floor`; the BOOL, BCD and real-to-bit-pattern conversions;
and nanoseconds in the core's clock. Not adopted: pointers, unions, target-width integers
and Logix's literal suffixes.

**Milestone 5 is done when** a program and a configuration of §4.4's plant, loaded from
files on disk, declare and run every type decision 144 and 155 name, the fan's speed a
`real` from the drive card and its eight zone temperatures a located `real[8]`, the box
counter a typed counter and its weights an array indexed by a tag, through `Logex.Runner`
on the manual clock against an oracle that knows nothing of logex; an integer result past
its width wraps with no power, a real's saturates, and no infinity, NaN or −0.0 ever
reaches a state; every mixed-type operand Figure 11 does not widen is refused naming its
conversion, and every conversion rounds as IEC's examples say; an index or a bit number
out of range trips the runner with every output 0 once, and a negative square root is a
minor fault, `:negative_sqrt`; an online edit of a type or a
size is refused, and a changed initial value of every type is reported; and the contract
walks reach every type, refusal and trip reason, repeating exactly.

---

## 4. Backlog

- **B1 · Punctuation branch delimiters. LANDED.** The three lexer rules are
  `BST = (\()`, `NXB = (\|)`, `BND = (\))`, the grammar is untouched, and the migration
  diagnostic shipped with them. What follows is the finding as written, in the past tense
  where it describes what was fixed.

  A missing space before `nxb` silently turned OR into
  AND. `bst`/`nxb`/`bnd` were bare alphanumeric words (`ladder_lexer.xrl:7-9`) drawn from
  the same character set as `NAME`, and leex's maximal munch swallows them into an
  adjacent identifier. `nxb` is the only structural token that does not affect
  `bst`/`bnd` balance, so removing it always leaves a *grammatically legal* rung:

  ```
  bst xic aa nxb xic bb   bnd ote dd   aa=0,bb=1  ->  dd=1      (correct: OR)
  bst xic aa     nxb→"aanxb"…          aa=0,bb=1  ->  dd=0      (silently: AND)

  bst mov src dst  nxb xic bb bnd ote ee  ->  %{"dst" => 9}
  bst mov src dstnxb   xic bb bnd ote ee  ->  %{"dstnxb" => 9, "dst" => 0}
  ```

  Not fixable in the lexer — `aanxb` is a legitimate identifier. Fix at the language
  surface. **§5 settled the characters as `(` `|` `)`, not `[` `,` `]`** — see there for
  why. The leex rules are, with every metacharacter escaped (verified: compiles clean, and
  `xic aa ( xic bb | xic cc ) ote dd` with `aa=1,cc=1` gives `dd=1`):

  ```
  BST = (\()
  NXB = (\|)
  BND = (\))
  ```

  Do not transcribe these unescaped — `BST = (()` is `bad regexp 'unterminated ('`, which
  at least fails loudly; a half-escaped variant is the dangerous one. Nothing in the grammar
  changes: the yecc terminals are already the atoms `bst nxb bnd`.
  Whichever characters are used, every deletion around a punctuation delimiter becomes a
  no-op or a loud error, which is the point. M0-4 was the prerequisite and has landed;
  before it, `a-zA-z` in `NAME` swallowed `]` into identifiers.

  **Settled by §5, and taken: `(` `|` `)` rather than `[` `,` `]`.** It was a
  source-language break, not a contained lexer tweak.
  `bst`/`nxb`/`bnd` stopped being keywords and became ordinary tag names, so every branching
  program was rewritten: `lex_and_parse_test.exs:6`, every branching source in
  `end_to_end_test.exs` (including the three unbalanced-token cases, which still stay parse
  errors), README's syntax list, instruction table and worked example, and the branching
  examples in this document. The migration is *silent*, not loud — an old `bst …` program is
  no longer a syntax error; it would reach `instructionize/1` and die as
  `MatchError: no match of right hand side value: nil` with no mnemonic and no line, the
  exact failure M1-2 exists to remove — so it shipped *with* that diagnostic, a guard clause
  on the name head saying "line N: `bst` is no longer a keyword — branches are written
  `( … | … )`". Only mnemonic position is claimed: `bst` is a perfectly good tag name now,
  which `printer_test.exs` pins.

  Two consequences recorded elsewhere in this document: M0-4's keyword-precedence check is
  moot (§2·M0-4), and §5's case-folding is unblocked (§5).

  **Why not `[ , ]`.** Borrowing neutral text's brackets without its parentheses forecloses
  array subscripts: with `[`/`]` freed from `NAME` by M0-4 they would belong to branch
  structure alone, making the `[3]` addressing wanted in §5 and §8·6 unlexable (verified
  with the bracket delimiters applied: `tokenize("xic aa[3]")` → `name, name, bst,
  int_lit, bnd`). Real neutral text avoids the clash only because operands are
  parenthesised — `XIC(aa[3])`. `( … | … )` leaves `[`, `]`, `,` and `.` unspent, and reads
  as "a AND (b OR c)" to anyone who has seen a regex. Note also that `BST`/`NXB`/`BND` are
  **not** neutral-text spellings — they occur zero times in the instruction-set reference or
  the import/export reference. They *are* vendor mnemonics, from the same vendor's **earlier**
  controller family, whose ASCII rung format spells a branch `SOR BST … NXB … BND … EOR`.
  The destination this bullet argued for was right; its stated origin was the wrong
  generation, not the wrong vendor.

- **B2 · Digit-led lexemes split instead of erroring. FIXED** in the hand-written lexer:
  `tokenize("mov 1bst aa")` is `{:error, {{1, 5}, Logex.Lexer, {:missing_separator,
  "1bst"}}, 1}`, naming the whole run; `mov 123 hh`, a bare `1`, tags ending in digits and
  `1(` still lex. The leex-rule prescription below is history — the fix is an explicit
  clause after the digits, so the longest-match subtlety it relied on no longer arises.
  Guarded in `frontend_test.exs`; the golden record's regenerated diff (on 1.20.4) was
  exactly the 139 inputs with a digit running into a letter or `_`. The finding as written: a digit-led
  lexeme splits silently
  rather than erroring, then dies much later with an unlocated `FunctionClauseError`:
  `tokenize("mov 1bst aa bnd")` is `int_lit(1)` + `name("bst")` + … , where the user
  plainly meant one tag. *B1 blunted the original framing without closing the finding:* the
  example used to read `int_lit(1)` + **a genuine `bst` token** — a branch-start
  materialising from the middle of a word — which is no longer possible, because the
  delimiters are punctuation. The nearest survivor is `tokenize("1(")` → `int_lit(1), bst`,
  which is a split but arguably the right reading. The finding stands on the silent split
  itself; the fix is unchanged. One leex rule fixes
  it; leex is longest-match, so a digit-led lexeme running on into letters beats the
  digit-only `{INT}` match wherever the rule sits in the file:

  `[0-9]+[a-zA-Z_][a-zA-Z0-9_]* : {error, "missing separator after integer: " ++ TokenChars}.`

  Note leex's `{error, _}` action takes a **string**, not a term: it is wrapped as
  `{user, S}` and the generated `format_error({user, S}) -> S` hands it back verbatim, so
  a tuple there makes `format_error/1` return non-iodata and blows up the very error path
  M1-5 commits to calling. The trailing `[a-zA-Z0-9_]*` matters too — without it only the
  first letter is consumed and the message names `1b` instead of `1bst`. `mov 123 hh`,
  bare `1`, and identifiers ending in digits (`bst1`, `tag1`) are unaffected.

- **B3 · CI. LANDED.** `.github/workflows/ci.yml` runs on every push and pull request,
  on `ubuntu-latest`, with `erlef/setup-beam@v1.24.1` giving Erlang/OTP 28 and Elixir
  1.20.4, the pair `mix.exs` and `shell.nix` pin, `deps` and `_build` cached on the
  versions it resolved and `mix.exs` (there is no `mix.lock`). Four steps, each judged by
  its exit code: `mix format --check-formatted`, `mix compile --force
  --warnings-as-errors`, `MIX_ENV=test mix compile --force --warnings-as-errors` and
  `mix test --warnings-as-errors`; CONTRIBUTING's "Before you commit" lists the same four.
  The red island in history below stays where it is: CI keeps a new one from landing
  unseen. What follows is the item as written.

  *Since the hand-written front end (§6), three lines:
  `mix compile --force --warnings-as-errors`, `mix format --check-formatted`,
  `mix test --warnings-as-errors` (the flag since M1-5's second review: `mix compile` never
  compiles the tests, so a warning in one passed the plain `mix test` for six commits),
  each judged by exit code. The grammar-conflict gate below went with yecc; there is no
  grammar left to check.* As first written, four lines: `mix compile --warnings-as-errors`,
  `mix format --check-formatted`, `mix test`, and a grammar-conflict gate:

  ```
  erl -noshell -eval 'case yecc:file("src/ladder_parser.yrl",
        [{parserfile,"/tmp/conflictcheck.erl"},{report,false},{return,true}]) of
      {ok,_,[]} -> halt(0); _ -> halt(1) end.'
  ```

  The fourth line is not redundant, and this is the one that matters: **`mix compile
  --warnings-as-errors` does not catch a shift/reduce conflict.** yecc emits a working,
  silently disambiguated parser and mix reports it as a warning that
  `--warnings-as-errors` does not upgrade. Verified by adding one ambiguous production
  (`elems -> elems elem` alongside `elems -> elem elems`): yecc reports 6 shift/reduce
  conflicts, and `mix compile --warnings-as-errors`, `mix format --check-formatted` and
  `mix test` **all exit 0**. Only reduce/reduce fails the build. `{parserfile, …}` keeps
  the check from dropping a stray `src/ladder_parser.erl` into the checkout. This gate is
  what makes §6's "keep yecc for its conflict-freedom alarm" argument actually true.

  *Before §6:* all four passed after M1-1 (`27 tests, 0 failures`, and zero conflicts
  against the post-M0-5 grammar), and with `src/` tracking only the `.xrl` and `.yrl`,
  leex/yecc were a hard prerequisite of all four — the image had to carry
  `erlang-parsetools`. *Since:* the three gates pass on 1.20.4, and no parsetools are
  needed (README, "Running it").

  On history: `mix test` fails at `ec0534a` and `35fe1b9` (`list_to_string(list)` was
  written with a lowercase Erlang *atom* instead of the variable `List`, silently repaired
  inside the unrelated `0f7d77f`). Those two are an interior island, not a prefix —
  `d47eb21` before them is green (`1 doctest, 1 test, 0 failures`), so `git bisect` does
  have a clean baseline. Only the two root commits (`b8e8f8a`, `d319fb3`) predate the mix
  project; every commit after them is bisectable.

- **B4 · nix dev shell has bit-rotted.** **Landed `9c1a7bd`**, with the lock refresh still
  owed. `shell.nix` now pins `beam.packages.erlang_28` with `elixir_1_20`, and `flake.nix`
  tracks `nixos-26.05` instead of `master`. The original diagnosis — `erlangR26` deleted
  from nixpkgs on 2024-05-24 — was overtaken before it was acted on: nixpkgs now `throw`s
  on `erlang_26`, `elixir_1_15` and `elixir_1_16` as EOL, so the rename to `erlang_26` this
  item proposed would also have failed. What decided the versions was the 2026-09-07 CVE
  check: OTP 26 left support on 2026-05-26 and every 2026 OTP advisory was fixed only on
  27/28/29; Elixir 1.15 left the last-five-minors window on 2026-06-03 and is
  affected-and-unpatched by CVE-2026-75758. Nothing in logex's own code paths is reachable
  by any of them (no deps; runtime is `kernel`/`stdlib` only), so this is toolchain
  hygiene, not a fix. Still open: `flake.lock` is the 2024-01-19 lock and does not match
  the new input — the first `nix develop` re-locks it; run `nix flake update` and commit.
  Not evaluated in the session that landed it (no `nix` on that machine).

- **B5 · Split `Logex.Compiler` along the pipeline** once M1-2 and M1-5 exist and the module
  is doing five jobs instead of four. The front end is already out, as `Logex.Lexer` and
  `Logex.Parser` (§6); what remains is `Ast`, `Instruction`, `Analyzer` and `Runtime`
  (`Logex.Diagnostic` exists since M1-2; `Logex.Program`, `Logex.Tag` and
  `Logex.Declarations` since M1-3). Note the recursion of `evaluate/2`
  is currently written as extra **public** clauses of the same function (M1-2 made
  `instructionize/1`'s private), so `Logex.Compiler.evaluate([{:xic, …}], {true, env})` on a
  half-formed IR is a supported entry point. Make every recursive clause a `defp` with a
  distinct name.
  *The narrow part landed with M1-5 (`d0870b3`): the evaluator is in `Logex.Runtime`,
  every clause private, the recursion split into `rung/2`, `series/2` and `element/2`, and
  `runtime_test.exs` pins the public surface of `Logex`, `Logex.Runtime` and
  `Logex.Compiler`; M1-5 also added `Logex.Warnings`, `Logex.Instance` and
  `Logex.Scan`. What remains is the lowering (`Ast`, `Instruction`, `Analyzer`), still in
  `Logex.Compiler`. M1-6 made them `rung/3`, `series/3`, `element/3` and `evaluate/3`, and
  added `Logex.FbType`, whose surface the same test pins.* *(Milestone 2's design,
  2026-10-02: the part Milestone 2 needs, one walk of a program's IR in place of the
  compiler's, `Logex.Warnings`' and `Logex.Edit`'s, answering which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, lands as M2-4's first
  commit. Until then M2-5 adds a `cal` clause to each walk; §3.)* *(M2-5 landed so: its
  second commit gave the two walks one lookup of an instruction's slots,
  `Logex.Compiler.signature/2`, and its third taught that lookup `cal`, whose slots are
  its block's.)* *(M2-4 landed the walk, `Logex.Walk`, its second commit, `2a03b52`: the
  compiler, `Logex.Warnings` and `Logex.Edit` read it, and `Logex.Configuration` reads
  which tags a program type writes there. The lowering, `Ast`, `Instruction` and
  `Analyzer`, is still in `Logex.Compiler`.)*

- **B6 · Project metadata. LANDED.** `mix.exs` has a `description`, a `package`
  (`licenses: ["Apache-2.0"]`, a link to the GitHub repository) and a `source_url`, which
  `mix hex.build` reads back with no warning; `extra_applications: [:logger]` is gone, as
  nothing in `lib/` or `test/` uses Logger; `Logex.Compiler` has a `@moduledoc` naming its
  stages and why each is public (no `@spec`s: the docs state each function's shapes). The
  Elixir requirement, `~> 1.20`, is unchanged. `mix test --cover` reports 99.24% on 1.20.4,
  `Logex.Compiler` 98.42%, every module 100% but `Logex.FbType` (97.30%), `Logex.Walk`
  (97.56%), `Logex.Compiler`, `Logex.Configuration` (99.09%), `Logex.Declarations`
  (99.13%), `Logex` (99.18%), `Logex.Runtime` (99.51%) and `Logex.Edit.Plan` (99.67%).
  The CI it once listed is B3's. What follows is the finding as written.

  No `@spec`/`@moduledoc` on `Logex.Compiler`; no
  `description`/`package`/`licenses` in `mix.exs` despite a full Apache-2.0 `LICENSE`;
  unused `extra_applications: [:logger]`. `mix test --cover` reported a meaningless ~54%
  while it counted the generated scanners (`Logex.Compiler` 90%, `:ladder_lexer` 30%).
  With the front end hand-written (§6, `65d9bc4`) it reported 97.92% on 1.20.4
  (`Logex.Compiler` 94.59%); after M1-5's first review (`b8a9bd8`) it reported 99.17%,
  every module 100% but `Logex.Diagnostic` (90.00%) and `Logex.Declarations` (97.69%).

- **B7 · Style.** Five `{false, env}` clauses with identical *bodies*
  (`xic`, `xio`, `otl`, `otu`, `move` — the heads differ) collapse to one guard clause
  `when op in [:xic, :xio, :otl, :otu, :move]`; `ote`'s own `{false, env}` clause
  writes 0, so it stays. The guard keeps it from shadowing `{:routine, …}`, `{:rung, …}`
  or `{:branches, …}`, so it is safe anywhere in the clause list. It does **not** remove
  the new-instruction trap, it *moves* it. M0-3 landed the mandatory-`{false, env}` warning
  in CLAUDE.md's "New instructions, step 2" bullet, which
  already closes it: an opcode added per the current recipe — both clauses — evaluates a
  de-energised rung fine, while one added with only the `{true, env}` clause still raises
  `FunctionClauseError`, because the new atom was never added to the whitelist. So if B7 is
  taken, the only doc change left is an addendum to that bullet: "or add the opcode to the
  `{false, env}` guard list instead, when de-energising does nothing". Do not widen the guard to a bare
  catch-all. Since M1-2 an instruction is `{op, line, operands}`, so `{_op, _, _}` can no
  longer swallow `{:branches, …}`, and validation rejects the truncated instructions it
  used to let through; but it would still turn a forgotten de-energised clause, loud
  today, into a silent do-nothing — wrong for any coil that must write on a false rung,
  as `ote` does.
  `Enum.any?(outputs, fn o -> o == true end)` →
  accumulate the boolean directly and drop the reversed intermediate list in the
  `{:branches, _}` reducer — but keep the fold
  non-short-circuiting: any form that puts `evaluate` on the right of `or`/`||`, or that
  bails once the accumulator is true, skips a later branch's OTE/MOV side effects and
  still passes every CI gate. §6 explains why that matters. The `{:rung, branch}`
  clause `{:rung, branch}` names the `{power_flow, env}` pair `env`.
  *B5 (`d0870b3`, 2026-09-29) took part of this with it: the `== true` is gone
  (`Enum.any?(powers)`), `Enum.map_reduce` keeps the legs in order with no reversed list,
  `rung/2` names the env map `env`, and `evaluate/2` has no routine, rung or branches clause
  left for a guard to shadow. The five identical `{false, env}` bodies stand, and so does
  the intermediate `powers` list in `element({:branches, _}, _)`. M1-6 made these
  `evaluate/3` and `element/3`, and the six comparisons share one guarded clause pair.*

- **B8 · A lone `\r` never delimits a rung, so a CR-only file is silently one rung.**
  **Status: DONE — landed 2026-09-30, as the fix below says.** A CRLF is still one
  newline located at its `\n`, a lone `\r` is a newline of its own, and `\r\r\n` is two
  newlines in one run. The golden record changed in exactly the 165 entries predicted,
  each an input with a lone CR; `frontend_test.exs` and `end_to_end_test.exs` now pin it
  too, so the golden test is no longer the only one to see it.
  *Written against leex; `Logex.Lexer` kept the behaviour on purpose (its whitespace
  clause takes `?\r`), so the finding stands and only the fix below changes form.*
  `WHITESPACE = [\s\t\r]` (`ladder_lexer.xrl:6`) claims `\r` before `RND = (\r?\n)`
  can, so a classic-Mac line ending is skipped as whitespace rather than ending the
  rung. The same text then means different things in CR and LF:

  ```
  tokenize("ote aa\rote bb")  -> [name, name, name, name]        # no :rnd at all
  tokenize("ote aa\note bb")  -> [name, name, rnd, name, name]

  "xic gg ote r1\rote r2"  gg=0  ->  r2=0     # one rung: flow is false throughout
  "xic gg ote r1\note r2"  gg=0  ->  r2=1     # two rungs: second is independent
  ```

  Silent and wrong, not loud — every other malformed file shape (BOM, `\f`, `\v`,
  U+2028) is an `{:illegal, …}` error. **Fix:** in `Logex.Lexer`, take `?\r` out of the
  whitespace clause and treat `\r\n` and a lone `\r` as a newline. The line counter is
  the lexer's own, so a CR-only file gets real line numbers — the caveat the leex fix
  carried (leex counted only `\n`) no longer applies. The golden record will change: on
  1.20.4, 165 of its 1,362 entries, every one an input with a lone CR (256 have one). Made
  as a mutation, with a CRLF newline still located at its `\n`, the change fails the
  golden test and nothing else; locating it at the `\r` also moves an error location
  `frontend_test.exs` pins. Predates M0; M0-5's `\r?` in `RND` makes it *look* handled,
  which is why it is worth recording.

- **B9 · An Elixir-embedded `defladder` DSL — proposed, not adopted.** `docs/defladder.md`
  is the study: what Nx's `defn` actually does (call-time tracing, which a static ladder
  routine has no use for), an executed spike (a 71-line macro producing this parser's AST,
  byte-identical scan output, located compile errors), a judged design panel and two
  adversarial refutations. Its recommendation: one macro that emits the parse-stage AST and
  owns no vocabulary — mnemonics from `instructions/0`, tags via `tokenize/1` — with a
  parallel group spelled `branch(leg, leg)` rather than an infix operator, because `|||`
  and `|` both bind looser than `|>` and an unparenthesised seal-in silently becomes
  OR-of-AND (B1's defect class on a surface no gate sees). Preconditions if adopted: M1-2
  (one validator) and M1-5 (a `%Program{}` and a runtime for `name/1` to sit on; both
  met, M1-5 on 2026-09-29), and a
  re-run of the whole study on Elixir 1.20, the floor in `mix.exs` — every receipt is from the 1.14
  sandbox. The report's §15 lists the decisions this item is waiting on, and they are still
  open. One seam came forward on its own: M1-3, decided 2026-09-28, provides the
  Elixir-side declarer (`instructionize(ast, declared)` and `Logex.Tag.new!/4`) that §11's
  M1-3 row asks for; §15's decision 3 (head declarations in the DSL's output) stays B9's.
  Nothing else in §3 or §5 changes until they are made. No codegen backend: the second backend the spike built
  disagreed with `evaluate/2` on 5,708 of 20,000 seeded envs and on 0 text-reachable ones.
  *(Re-scoped 2026-10-01, `docs/organisation.md` §4.9: a running controller is edited as
  data, so a DSL can only write a first version. Its output must be a whole program,
  name, declarations and rungs, as text that `Logex.compile/2` accepts or as data that
  the data API accepts (`docs/organisation.md` §4.9), which settles §15's decision 3; and nothing writes a later edit back into the `.ex` file.
  Spark was considered for the same role and is not adopted inside logex: as a separate
  authoring package it works (a probe produced a `%Logex.Program{}` equal to the text
  path's), but its rungs are wordy, its autocomplete is ElixirLS-only, and it is a
  dependency.)*

- **B10 · `Logex.Warnings.second_otes/3` orders by a map. LANDED.** It walks the `ote`
  uses in rung order, keeping each tag's first `ote` in a map that is only looked up, as
  M1-6's storage-bit pass walks its uses; "second ote warnings on one line come in rung
  order, however many there are" in `validation_test.exs` pins it with 40 tags given their
  second `ote` on one line in the reverse of their names' order, and fails with the
  grouping put back. What follows is the finding as written.

  It grouped the `ote` uses with
  `Enum.group_by/3` and walked the groups, so two second-`ote` warnings on one line came
  out in the map's order: the names' order for 32 names or fewer, no order past that
  (CONTRIBUTING's "32 keys or fewer"), and never rung order. The final sort by line keeps
  lines in order, not the warnings within one. M1-6's own passes walk the uses in rung
  order, and a test with 40 storage bits on one line pins that; do the same here, with a
  test past 32 names. Found by the M1-6 design panel; not M1-6's to change. *(M1-6 gave
  the function a third argument, the `ons` storage bits it leaves to their own warning.)*

---

## 5. Settled decisions

*Several decisions below are written as leex rules (`//` comments, `QUALIFIED` names,
negative literals, line continuations). The lexer is hand-written now (§6); each rule
becomes a clause in `Logex.Lexer`, and the behaviour it specifies still stands.*

**How does Elixir declare a controller, and how is a running one changed?**

**Decided 2026-10-01: as data, staged, and never through the Elixir compiler** (design,
measurements and sources in `docs/organisation.md` §4.9; its decisions 15–20, and 21–29
for OE-1's design; work items OE-1 and OE-2 in §3).
- One model, held as data: `%Logex.Program{}` and, from M2-1, `%Logex.Configuration{}`.
  Their saved form is `.ld` and `.logex` text, which printers write, and a data API refuses
  what the text cannot say.
- Nothing compiles a user's program to BEAM, and no front end puts the Elixir compiler on
  the path that changes a running program (§6).
- Spark is not adopted inside logex. An authoring package outside it may come later, as a
  one-way seed that emits the same data (B9).
- Online edit is staged from its first version, as the conventional family's is: accept,
  test, untest, assemble, cancel (landed for one program instance with OE-1, 2026-10-01). State moves by name: an added tag starts at its initial
  value, a removed one is pruned at assemble, a type change is refused while running, a
  timer's `.pre` follows its preset where logic left it alone, and an `ons` the edit adds,
  or whose rung it changes, does not fire on the first scan after the switch.
- While running, a task's interval and priority may change; moving an instance to another
  task, and adding or removing a task, are refused.
- An output an edit leaves undriven holds its last value, as the conventional family's
  do, and every step's report lists each one with the value it holds.

**Does logex aim to ingest a vendor export format, or to be its own dialect?**

**Decided: its own dialect.** logex does not aim to import neutral text and will not
become an importer. Its surface is lowercase, space-separated, unparenthesised and
newline-delimited, which real neutral text is not. The *vocabulary* is borrowed from the
a conventional ladder mnemonic set; the *syntax* is not.

Being a dialect is a licence to choose names, not to choose them carelessly. **Every new
instruction is surveyed before it is written** — against IEC 61131-3 and against the major
vendor toolchains — and named deliberately in that light. The survey lives
in `docs/naming.md`, one stanza per mnemonic, and `test/logex/naming_test.exs` fails if a
mnemonic reaches `@instructions` without one. The rule, in order: **(1)** if IEC names the
operation, take the IEC name lowercased; **(2)** if IEC supplies only a graphical element,
take the clearest vendor mnemonic and say which; **(3)** never invent a readable word for
a thing that already has a standard name.

Two survey findings are why the rule has two tiers, and both are load-bearing. IEC
61131-3 names ladder contacts and coils only as **graphical elements with English
phrases** ("Normally open contact", "SET (latch) coil"), so for `xic`/`ote` there is no
standard name to conform to. And **Edition 4.0 (2025) removed Instruction List from the
standard entirely** — there is no longer any IEC textual mnemonic vocabulary at all. A
mnemonic ladder language is *necessarily* a dialect.

### What the decision settles

Each of these was blocked on the dialect question. Full rationale and sources in
`docs/naming.md`.

- **§4·B1 branch delimiters — take B1, as `( … | … )`.** Unblocked: the objection was that
  punctuation was a half-step into a vendor export format foreclosing `[3]` addressing. The
  bracket form is unavailable to logex — it works only because there the operands are
  parenthesised, so a subscript `[` is always inside parens. `( | )` reads as
  "a AND (b OR c)" to anyone who has seen a regex, and leaves `[`, `]`, `,` and `.`
  unspent. Three lexer rules, **zero grammar edits** — the token atoms are still
  `bst nxb bnd`, now produced by `(`, `|` and `)`. **LANDED**, with the migration
  diagnostic, per §4·B1.
  *(Correction to B1's wording when it lands: `BST`/`NXB`/`BND` are **not** vendor
  neutral-text spellings — but they are vendor mnemonics, from the earlier controller
  family's ASCII rung format. The "no vendor reference surveyed" phrasing this note once
  carried was a negative scoped to one generation and worded as though it covered the vendor;
  see the survey-scope note in `docs/naming.md`. Landing B1 therefore trades a real vendor
  spelling for a coined one — still the right call on the fusion hazard, but say so in the
  migration hint rather than implying the words were logex's own.)*
- **M1-4 nonzero-is-true — keep as a totality guarantee, reject as a language rule.** Land
  `bit/2` so `xic`/`xio` are complementary by construction, then once M1-3's tag table
  exists make a non-BOOL operand a located diagnostic rather than a coercion (that half
  **landed with M1-3**; `bit/2` **landed with M1-4**). The survey
  is unanimous against nonzero-is-true, with no vendor precedent: even Mitsubishi's
  untyped devices require a *bit* (`D.b`), not a word. The escape hatch every vendor gives
  is bit addressing — `xic setpoint.3`.
- **Structured addressing — adopt `.`, resolved in the lexer.** One rule,
  `QUALIFIED = {NAME}(\.({NAME}|{INT}))*`, so `t1.dn` and `word.3` lex as one `name`
  token; **no grammar edit**. `env` holds a per-instance record, since `.acc` and `.dn`
  must update together in one scan. Array subscripts defer cleanly, because `[`/`]` stayed
  free. Two traps: the token no longer round-trips to a flat `env` key, and `.` in the
  lexer is safe only while there are no float literals. **The lexer rule landed
  2026-09-30**, as a `Logex.Lexer` clause: `a.1b` is B2's mistyped lexeme, named whole, and
  a `.` with no name or integer after it is illegal. Since a tag name is whatever lexes as
  one name, the same commit forbids a `.` in a declared tag's name. **Members landed with
  M1-6:** `t1.dn` is a member of the timer `t1`, resolved in the compiler and lowered to
  `{:member, line, path}`; a dotted name that is not a declared member is a diagnostic;
  `word.3`, bit access, is refused with its own message until it lands.
- **Comments — `//` to end of line.** `//[^\r\n]* : skip_token.` — it must **not**
  consume the newline, or `ote a // note\note b` silently becomes one rung. Test exactly
  that. Keep `;` a lex error: it is the rung *terminator* in neutral text and reusing it
  would mislead. Later, promote a comment above a rung into a structural
  `%Logex.Rung{comment:, elements:}` — a compiler that only skips comments can never print
  `rung 4 ("seal-in for main motor"): unknown instruction`. **Landed 2026-09-30** as a
  `Logex.Lexer` clause that stops before `\n` or `\r`; a comment may hold any character,
  but invalid UTF-8 in one is still a located error, and the printer drops comments (the
  structural form above is still later work).
- **Negative literals — one lexer rule**, `-[0-9]+`, sign glued to the digits, no leading
  `+`. Widen §4·B2's digit-led rule to `-?[0-9]+…` in the same change. logex has no infix
  operators, so `-` can only be a sign; record that this must move to the grammar when
  infix arithmetic arrives. *(OE-1: until this lands, `Logex.Parser.well_formed!/1`
  refuses a negative literal in a tree built as data, and `Logex.Declarations.check/1` a
  negative initial value from Elixir. Landing it widens both, in the same change.)*
  *(Landed with M3-3, 2026-10-14, `docs/organisation.md` decision 97: both widened, with
  `Logex.Configuration`'s checks, whose file can say a negative number now; and a sign
  begins a lexeme, so `a-5` and `5-3` are one mistyped lexeme each, named whole, as
  B2's `1bst` is.)*
- **Case — mnemonics case-insensitive, tags case-sensitive.** **Landed with M1-2.** One
  `String.downcase/1` at `instructionize/1`'s mnemonic lookup. IEC and every vendor are case-*insensitive*, so a user arriving from
  any of them has a correct prior. M1-3 added the rest (**landed**): two declared tags
  differing only in case are an error, and a tag used in the wrong case gets `did you mean
  `motor`? (tags are case-sensitive)`. **Unblocked — B1 has landed.** The blocker was that while `bst`/`nxb`/`bnd` were
  keywords, case-folding made `BST` a name and `bst` a keyword. The delimiters are
  punctuation now, so there is no keyword left to fold.
- **Mnemonics are reserved words, in any case.** Decided with M1-2 (September 2026): no
  tag may be spelled like a mnemonic, so `ote`, `OTE` and `Ote` are never tags. It is
  what closes `mov src ote`, where the operand list ran on into the next instruction and
  wrote a tag called `ote`; an operand-signature table alone cannot tell that tag from
  the instruction. The alternative, leaving every name legal until M1-3's declarations
  catch an undeclared `ote`, left the worst case open for a milestone. The cost, accepted:
  each new instruction reserves its name when it lands, and breaks any program with a
  tag of that name. IEC reserves its keywords case-insensitively too. M1-3 reserved five
  more words the same way, the section and type words `var var_input var_output bool
  dint`, and M1-6 eight, `ons eq ne lt gt le ge ton`, `ton` as a type word too.
- **Program organisation follows IEC's software model, in logex's dialect.** Decided
  2026-09-28: logex is heading for IEC's hierarchy (configuration, tasks, program
  instances, function-block instances, globals), its task-style execution (continuous,
  periodic, event) and I/O mapping in the configuration, not in program bodies.
  `docs/organisation.md` sets out the model, the conventional family's hierarchy mapped
  onto it, the logex form and Milestone 2. Its fourteen open decisions were taken as
  recommended on 2026-09-28, with its Milestone-1 changes (M1-3, M1-5 and M1-6 record
  them) and Milestone 2 (§3). In one line: a file is a POU type, state is an instance, a
  configuration instantiates, wires and schedules; no routines, no controller scope, no
  preemption. Milestone 2 was designed on 2026-10-02 (§3), adding the document's
  decisions 30–40, all taken as recommended but the configuration file's extension,
  `.logex`, the maintainer's own choice. **Routines are deferred by decision** —
  subroutines that share their
  program's scope, called with JSR, have no IEC counterpart, and a program's logic is
  factored with function blocks instead; revisit only if that proves too heavy.
- **`mov` → `move`.** **Landed with M1-2**, with no alias: `mov` is an unknown
  instruction whose diagnostic says *"did you mean `move`?"*. The one existing name the survey changed. The conventional
  toolchain renamed MOV→MOVE in its 2024 conformance sweep *"to conform to IEC
  61131-3 and PLCopen standards"*, and `MOVE` is a genuine IEC standard function; keeping
  `mov` pins logex to a spelling that convention has itself retired.
  A source-language break, so scheduled with M1-2, whose unknown-mnemonic diagnostic can
  carry *"did you mean `move`?"* — cheaper than an alias, and it exercises the validator.

The existing five bit instructions stay. That is the survey's most useful negative result:
there is no better vocabulary to migrate to, so `xic xio ote otl otu` are a closed,
grandfathered borrowing — **not** a precedent that the next instruction should also come
from that same source.

---

## 6. Deliberately not changing

**~~Keep leex/yecc.~~ Reversed, September 2026: the lexer and parser are hand-written**
(`lib/logex/lexer.ex`, `lib/logex/parser.ex`; `src/` is gone). The argument below rested on
yecc's conflict check being wired in as a gate, and two measured studies on the pinned
Elixir 1.20.4 / OTP 28 showed that gate could not be made to hold at a sensible price.
Five front ends were prototyped against the suite (leex+yecc as-is and fixed, hand lexer +
yecc, NimbleParsec, Pegasus, hand-written); then the best yecc option — hand lexer + yecc +
a Mix guard compiler — was hardened over three adversarial rounds. Holding "a conflicted
grammar never builds green" took a 221-line guard coupled to about eight Mix behaviours and
an 87-second test suite, and a final review still built a conflicted parser green: two
`mix compile` runs with different `TMPDIR`s share no build lock, because Mix 1.20.4 keys it
under `System.tmp_dir!()` (`mix/sync/lock.ex:132-134`). NimbleParsec and Pegasus were
6.9-8.3x slower, silent on grammar mistakes, and dependencies. What replaces the alarm:
`test/fixtures/frontend_golden.txt`, a record of what the yecc grammar accepted and produced
on ~1,400 sources, which the hand-written front end matched exactly when it landed (B2 has
since rewritten 139 entries, on purpose); the
printer's round-trip generator, which must reach every production; and the suite — every
meaning-changing overlap planted in the prototype parser failed it. The cost accepted: an
ambiguity no test exercises is now caught by nothing.

Keeping leex beside it as an alternative lexer was considered and declined (September 2026).
Once its lexemes stopped being grown a byte at a time (`2b00370`), the hand-written lexer
took 0.78-1.12x leex's time on the densest artificial inputs and was 2.5x or more faster on
real programs and the README example (on 1.20.4; leex's scanner alone, handed a ready
charlist, still wins on 200k lines of short names).
A second lexer would need every lexer change, which covers B8 and all of §5, made twice,
and a token adapter. It would also bring back parsetools, Mix's leex warning and generated
`src/*.erl`. What it would offer is already held elsewhere: the golden record is its
behaviour, and `bf59167` has its source for anyone benchmarking against it.

The original reasoning follows.

**Keep leex/yecc.** The `rnd = \n` terminal looks like the classic argument for a
hand-written or combinator parser, but the entire fix is one grammar production and one
lexer rule (M0-5), and the grammar's conflict-freedom is the one tool that will say when
the language becomes ambiguous — **provided that check is wired into CI as its own step
(§4·B3).** Nothing in the default `mix compile` pipeline fails on a shift/reduce conflict,
so the check M0-5 runs by hand has to become a gate, or this guarantee lapses the first
time a production is added for comments, negative literals or structured addressing (§5).

Keep every whitespace and newline subtlety inside the lexer (now `Logex.Lexer`) and keep
the grammar newline-naive — that part of the reasoning survives the reversal. Line
continuations, when wanted, are one `Logex.Lexer` clause that skips a `\` followed by
blanks and a newline, and zero grammar changes. *(OE-1: `Logex.Parser.well_formed!/1`
holds every rung of a tree built as data to one line, as the parser gives them today; the
clause widens it in the same change.)*

One known limit to accept alongside this: the grammar declares no `error` productions, so
`parse/1` aborts at the first syntax error — three independent errors yield one
diagnostic. That is *why* M1-5's front-end error is singular while M1-2's validation
returns a list.

**Nothing compiles a user's program to BEAM, and no front end puts the Elixir compiler on
the path that changes a running program** (decided 2026-10-01, `docs/organisation.md`
§4.9). Every front end ends in `%Logex.Program{}` (and from M2-1 `%Logex.Configuration{}`)
data that `Logex.Runtime` interprets. A generated-code backend was rejected once already:
the defladder spike's disagreed with the interpreter on 5,708 of 20,000 seeded envs (B9).
An edit through the Elixir compiler was measured on 2026-10-01 and fails every test that
matters for a running controller: a Spark-defined module recompiled with
`Code.compile_string/2` took 74–95 ms for 4 tags and 0.5–0.7 s for 200, against 22 µs and
1.7 ms for `Logex.compile/2` on the same two programs; it ran arbitrary code written in the edit; an edit that
failed validation unloaded the running module; and where names are atoms, as Spark
entities' usually are, every new name is an atom that is never collected.

**Keep mnemonics out of the grammar.** They arrive as ordinary `name` tokens and resolve
against the `@instructions` module attribute, so adding an instruction touches a map
plus two `evaluate/3` clauses and never the front end. That is the right dividing line.

**Keep the sequential `env` threading through parallel branches** (the
`element({:branches, legs}, _, _)` clause in `Logex.Runtime`, an `Enum.map_reduce` that
runs every leg from the power flowing into the group) and the non-short-circuiting fold
along a rung (`series/3`, an `Enum.reduce` over `element/3`). Both look like accidents of using
`Enum.reduce` and are in fact faithful controller behaviour. *(Until B5, 2026-09-29, these
were the `{:branches, _}` and `is_list(branch)` clauses of `Logex.Compiler.evaluate/2`.)*

---

## 7. Findings register

Every defect the review and the audit after Milestone 0 (`440bc83`) turned up, with the
milestone item or backlog bullet that closes it, and its status as of M1-5 and its two
reviews (2026-09-29). `B1`–`B10` are the §4 backlog bullets; B9 is proposed work, listed for
its status. Other items that are pure forward work rather than defects (M1-3, M1-6, B5)
have no row, and the later reviews of M1-3 and M1-5 are recorded in those items' Status
blocks instead. An ID of `—` means the finding has no plan item yet. Locations are current
as of `1b1b1df` unless a cell says otherwise.

| ID | Sev | Area | Finding | Location | Status |
|---|---|---|---|---|---|
| M0-1 | high | evaluate | `get_arg/2` matches `:lit_int`; every other stage emits `:int_lit` | `get_arg/2` | **closed** `690fc2d` |
| M0-3 | med | docs/build | `CLAUDE.md` promises regeneration that does not happen; a grammar edit is silently ignored on a fresh clone | `CLAUDE.md` compile + Key Files + step-2 bullets | **closed** `dde8c1d` — fresh-clone case; the generated front end's same-second trap went with it (§6), and CONTRIBUTING records the narrow residue left for `.ex` files |
| M0-2 | med | tests | No test crosses a stage seam; per-stage fixtures are hand-typed and contradict each other | `end_to_end_test.exs` | **closed** `03c10e0` |
| M0-5 | med | grammar | `rnd` is a strict infix separator, and a branch leg cannot be empty | `ladder_parser.yrl:8,12,16,21` | **closed** `b65e756` |
| B1 | med | lexer | Missing space before `nxb` fuses into an identifier — parallel silently becomes series | `ladder_lexer.xrl:8` | **closed** — delimiters are `(` `\|` `)`; guarded by "deleting a space around a delimiter is a no-op" in `end_to_end_test.exs` |
| M1-2 | med | lowering | No validation pass: unknown mnemonic → bare `MatchError`; short arity → truncated IR; and `mov src ote` silently eats the next mnemonic as a tag, no error, energised rung | `instructionize/1`, name clause | **closed** `e569113` — a located diagnostic for each case, every mistake in a routine reported (`validation_test.exs`) |
| M1-4 | med | semantics | `xic`/`xio` are independent positive tests — a non-bit or undefined tag reads false for both | the xic and xio clauses of `evaluate/3` (were `evaluate/2`'s) | closed: unreachable from source (`2b093de`, M1-3); complementary by construction (M1-4) |
| B8 | med | lexer | A lone `\r` never delimits a rung, so a CR-only file is silently one rung and disagrees with the same text in LF | `Logex.Lexer`, the whitespace clause (was `ladder_lexer.xrl:6,10`) | **closed** 2026-09-30 — a lone `\r` is a newline |
| M0-4 | low | lexer | `NAME` regex: `+` rejects single-char tags; `a-zA-z` typo admits ``[ \ ] ^ ` `` | `ladder_lexer.xrl:5` | **closed** `3f3b104` |
| — | low | tests | M0-4's fix was unguarded: no test used a single-character tag or a bracketed name, so reverting `ladder_lexer.xrl:5` left `mix test` fully green | `end_to_end_test.exs` | **closed** `b8fc743` |
| M1-5 | low | API | No public entry point and no `Logex` module; no scan loop | — | **closed** (M1-5) — `Logex.compile/2`, `compile_file/1` and `Logex.Runtime`; the host calls each scan, and a scheduler is Milestone 2's |
| M1-5 | low | errors | Three error conventions across four stages; `format_error/1` never called; empty program reports line `999999` | `tokenize/1`, `parse/1` | **closed** — `999999` by `b65e756`; for a host, M1-5: `Logex.compile*` return `%Logex.Diagnostic{}` only, the front end's through its `format_error/1`. The stage functions keep their own shapes on purpose, for the golden record |
| M0-3 | low | tooling | Generated `src/*.erl` tracked, embedding absolute `/nix/store` paths → ~700-line cross-OTP churn | `src/ladder_lexer.erl:1` (at `c9c7f51`; untracked since) | **closed** `dde8c1d` |
| B4 | low | tooling | nix dev shell bit-rotted: `erlangR26` alias removed from nixpkgs master 2024-05-24; flake tracked `master`; lock from 2024-01-19 | `shell.nix`, `flake.nix` | **landed** `9c1a7bd` — OTP 28 / Elixir 1.20 on `nixos-26.05`; lock refresh owed |
| B2 | low | lexer | Digit-led lexeme splits rather than erroring: `1bst` → `int_lit(1)` + `name("bst")` | `Logex.Lexer`, the integer clause (was `ladder_lexer.xrl:20`) | **closed** — a located `:missing_separator` lex error naming the whole run |
| B3 | low | history | 2 commits ship a red suite (`ec0534a`, `35fe1b9`) — an interior island; `d47eb21` is a clean bisect baseline | `.github/workflows/ci.yml` | **closed** — CI runs the four gates on every push and pull request; the island stays in history |
| B6 | low | project | No CI, no `@spec`/`@moduledoc`, no mix.exs metadata, unused `:logger` | `mix.exs` | **closed** — metadata, a `@moduledoc` on `Logex.Compiler`, no `:logger`; CI is B3's |
| B7 | nit | style | 5 `{false, env}` clauses with identical bodies; `Enum.any?(o, &(&1==true))`; intermediate list in branch reducer | `Logex.Runtime`, the evaluate clauses (was `Logex.Compiler.evaluate/2`) | open — B5's `Enum.map_reduce` took the `&(&1==true)` with it; the rest stands |
| M1-1 | nit | IR | AST nodes were keyword-list-shaped with duplicate keys where order is the meaning; `Keyword.get/2` would silently return only the first | the `elem ->` productions | **closed** `a22bf39` — elems are `{kind, line, value}` 3-tuples, not pairs |
| §5 | nit | domain | No comments, no negative literals, no structured addressing (`Timer.DN`, `Arr[3]`) | `Logex.Lexer` (was `ladder_lexer.xrl:3`) | **partly closed** — `//` comments and the `.` lexer rule landed 2026-09-30, members with M1-6, and negative literals with M3-3; bit access and arrays open, decided for Milestone 5 on 2026-10-21 (§3, M5-8, M5-9 and M5-11) |
| B9 | low | surface | An Elixir-embedded `defladder` front end: studied, spiked, judged; recommendation and open decisions in `docs/defladder.md` | — | proposed; re-scoped 2026-10-01 as a one-way seed that emits a whole program as data |
| B10 | nit | warnings | Second-`ote` warnings on one line come in map order, not rung order | `Logex.Warnings.second_otes/3` | **closed** — the uses walked in rung order; guarded by a 40-tag test in `validation_test.exs` |

---

## 8. Domain gaps, in priority order

The execution model — rung-condition-in, series AND, parallel OR, non-retentive OTE vs
retentive OTL/OTU, top-to-bottom rungs with immediate data-table updates — is faithful.
The mnemonic set is authentic ladder vocabulary rather than invented. What is missing:

1. **Timers and counters (TON/TOF/RTO, CTU/CTD/RES)** — decisive. Essentially no real
   routine exists without them, and they are why the scan model matters. *`ton` landed with
   M1-6, as a declared instance on the injected clock; TOF, TP, RTO, RES and the counters
   are open, and reuse its `%Logex.FbType{}`.* *(Milestone 3, decided 2026-10-14: IEC's
   counters `ctu`, `ctd` and `ctud` in M3-1, reset and loaded through their `r` and `ld`
   inputs rather than a RES, landed 2026-10-14; `tof`, `tp` and `rto` in M3-2, landed
   2026-10-14, the `rto` cleared through its `r` input.)*
2. **A scan loop and I/O image.** The input image, the clock and the first-scan bit landed
   with M1-5 (`put_inputs/3`, `%Logex.Scan{}`). The scheduler landed with M2-1:
   `Logex.Runtime.cycle/3` steps a configuration's resource by the time the host says has
   passed, merging the input points that changed into a kept image, running the due
   tasks' instances by priority and returning every output point. A wall-clock runner,
   the only code that will read a clock, comes after Milestone 2 (`docs/organisation.md`
   §5). *(Milestone 4, designed and decided 2026-10-17, §3: decisions 108–121, and
   122–128 after M4-1's review, 2026-10-18.)* *(Landed with Milestone 4, M4-1 to M4-7, by
   2026-10-20: `Logex.Runner`, decisions 108–143.)*
3. **A tag table with types.** Landed with M1-3.
4. **Comparisons (`eq ne lt gt le ge` — IEC names, see `docs/naming.md`)** — high value,
   low cost. *Landed with M1-6, on dints.*
5. **Math (ADD/SUB/MUL/DIV), one-shots (ONS/OSR/OSF), then control flow (JMP/LBL/MCR).**
   ONS is the canonical instruction that cannot exist without cross-scan state. *`ons`
   landed with M1-6; OSR and OSF are open.* *(Milestone 3: arithmetic in M3-3, landed
   2026-10-14, `add sub mul div mod neg abs`; `osr` and `osf` in M3-4, landed 2026-10-14;
   forward `jmp`/`lbl` in M3-5, landed 2026-10-15, and no MCR, decision 83.)* JMP/LBL
   do *not* require abandoning the `Enum.reduce` over rungs — widening the accumulator
   from `env` to `{skip, env}` is enough for forward jumps; only backward jumps need an
   indexed loop. *(M3-5 replaced both reduces, a program's and a block body's, with one
   recursion over the rungs, which a jump turns into a skip, the jump's record riding in
   the env under an atom key; a scan with no jump costs fewer reductions than before.)*
6. **Surface syntax: comments, negative literals, structured addressing.** See §5.
   *(Negative literals landed with M3-3, 2026-10-14.)*
7. **Program organisation: configurations, tasks, program instances, I/O mapping.**
   Decided in §5; Milestone 2 (§3), designed 2026-10-02, its first item, M2-1, landed the
   same day, and M2-5, user function blocks, on 2026-10-04; the model in
   `docs/organisation.md`.
