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
§1 and §3·M1-1 to M1-3 have been brought current. M1-4 onward is still forward work.

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
them and holds everything downstream; `Logex.Printer` turns a parse AST back into source.

```
 source string
   │  Logex.Compiler.tokenize/1        Logex.Lexer              binary pattern matching
   ▼  {:ok, tokens, endline}
 [{:name,{1,1},"xic"}, {:name,{1,5},"aa"}, {:bst,{1,8}}, {:name,{1,10},"mov"}, {:int_lit,{1,14},123}, …]
   │  Logex.Compiler.parse/1           Logex.Parser             recursive descent
   ▼  {:ok, ast}
 {:routine, {:rungs, [{:rung, [{:name, 1, "xic"}, {:name, 1, "aa"}, {:branches, [[…]]}]}]}}
   │  Logex.Compiler.instructionize/1  lowering, checked against each operand signature
   ▼  {:ok, ir} | {:error, [%Logex.Diagnostic{line:, message:}]}
 {:routine, {:rungs, [{:rung, [{:xic, 1, [{:name, 1, "aa"}]}, {:ote, 1, [{:name, 1, "bb"}]}]}]}}
   │  Logex.Compiler.evaluate/2        the evaluate/2 clauses         {power_flow, env} fold
   ▼  {true, %{"aa" => 1, "bb" => 1}}
```

### What works

- Series contacts, parallel branches to arbitrary nesting depth.
- `xic`, `xio`, `ote`, `otl`, `otu`, `move` with **correct** latch/unlatch retention semantics.
- Multi-rung routines, with power flow correctly reset per rung.
- Driven one `evaluate/2` call per scan, a correct seal-in motor circuit.

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
unusable error; only the first is still open.

- **`xic` and `xio` are not complementary.** Two independent *positive* tests, so a tag
  holding anything outside `{0,1}` — or no value at all — reads false for both. Reachable
  from source: `move 250 sp xic sp ote hi` → `hi=0`, and `move 250 sp xio sp ote lo` →
  `lo=0`. See M1-4.
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
`evaluation_test.exs:14` and `:59` now read `{:int_lit, 2, 123}`, the 3-tuple since M1-1
(`a22bf39`) — and the `:lit_int` atom appears nowhere in the tree.

---

## 2. Milestone 0 — make a green test run mean something — DONE

**All five items are landed and merged; nothing in this section is waiting to be done.**
M0-1 `690fc2d`, M0-2 `03c10e0`, M0-3 `dde8c1d`, M0-4 `3f3b104` (PR #3, merge `22bc81a`);
M0-5 `b65e756` (PR #4, merge `863af6f`). Re-verified on `main` after M1-1: `mix test` →
`27 tests, 0 failures`. M1-1, M1-2 and M1-3 have landed since; the next unstarted work is
§3·M1-4.

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
`instructionize/1` returns `{:ok, ir}` or `{:error, diagnostics}`: every
`%Logex.Diagnostic{line:, message:}` in the routine, in source order. `@instructions` maps
each mnemonic to an operand signature (`"move" => {:move, [:value, :tag]}`), and every case
in the table below is a located diagnostic, each pinned in `validation_test.exs`. The open
call at the end of this item was decided for the instruction tuple: it is
`{symbol, line, operands}` now, so a later pass can cite a line too. One decision was
added: **mnemonics are reserved words**, in any case (§5), which is what closes
`mov src ote`. Mnemonics are matched case-insensitively (§5). `%Program{}` stayed with
M1-5: `ir` is the same routine tuple as before. What follows is the item as written.

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
107 tests pass on Elixir 1.20.4, and each code commit's message records its mutation
table. Where the landing departs from the text below: the note for a program with no
declaration line reads "each is now declared before the first rung", naming no plan item;
it is given only when there is no declaration line at all, not when every declaration was
wrong; and an undeclared tag cites its operand's own line. Every recommendation of the
design panel was adopted, together with `docs/organisation.md` §6.1's four additions. A
spike of this design on a copy of `37b7932`, on Elixir 1.20.4 / OTP 28, passed 90 tests
(76 migrated, 14 new) with the README output byte-identical; it is a receipt, not code in
the repository.

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
  something to survive; `retain` itself stays unreserved.
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
  the seam `docs/defladder.md` §11's M1-3 row asks for, and M1-5's `compile/1` does not
  expose it. defladder.md §15's decisions stay open; its decision 3 (head declarations in
  the DSL's output) stays B9's.
- **Deferred:** warnings (declared but unused, a `var_output` never written, duplicate
  coil) go to M1-5's `warnings:`; a declaration-inferring migration aid is not built.

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
reach `env`. What is left of M1-4 is `bit/2`, for values the host supplies — an env built
by hand rather than by `Logex.Program.initial_env/1` can still hold a 5 or leave a tag out
— until M1-5's `scan/2` checks them.

### M1-5 · A real public API

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
`%Logex.Program{}` below is also still this item's: `instructionize/1` returns the routine
tuple wrapped in `{:ok, _}`.* As first written: normalise errors while here: `tokenize/1` returns
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

**Decided 2026-09-28, from `docs/organisation.md` §6.1 and §4.6:**
1. `evaluate/3` threads a read-only `%Logex.Scan{now:, first:}`; the accumulator stays
   `{power_flow, env}`. CLAUDE.md's `evaluate/2` convention changes with it.
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
   entries. B8 is fixed before any configuration file exists.

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

**Milestone 1 is done when a seal-in circuit written in a `.ld` file on disk can be
compiled once into a named, stateless value you can hold, run for N scans as an instance
against a typed tag table, and report a located diagnostic — `line 3: unknown instruction
"xyz"` — instead of raising.** (Amended 2026-09-28 per M1-5.) That single sentence
exercises M1-1 through M1-5; M1-6 is what proves the design was right rather than merely
plausible.

### Milestone 2 — program organisation

**Decided 2026-09-28** (§5; design and rationale in `docs/organisation.md`, whose §7
decisions were all taken as recommended). Each item surveys its new words in
`docs/naming.md` first, lands green, and pins every rule with a test that fails when the
rule is reverted. M2-5 needs only M1-6 and B5, so it may move ahead of M2-1.

- **M2-1 · The scheduler, from Elixir data, no syntax.** `%Logex.Configuration{}`,
  `Logex.Runtime.start/cycle/next_due_in/get`, periodic and task-less instances,
  copy-in/copy-out, overlap events. *Done when* a configuration built in Elixir with a 10
  ms task, a 30 ms task and a task-less instance, cycled for one simulated second by an
  injected clock, runs each instance exactly as often as its task dictates, in priority
  order; a late cycle yields one `{:overlap, …}` and no lost phase; the README program
  gives identical outputs through `scan/2` and through a one-instance configuration.
- **M2-2 · The configuration file, task-less.** A separate `.lcf` file (the extension is
  still a placeholder; choose it before this item lands): `var_global`, plain and located
  (`at panel.q.0`), `program <inst> <type>`, arrow-free connections (`m1.start
  pb_start_1`), every `var_input` connected, one driver per sink. *Done when* two instances
  of one `.ld` program type, wired in a configuration file to different input and output
  points, run for N cycles from one input image and keep independent state; a mis-wired,
  unknown, undriven-input or mistyped connection is a located diagnostic naming its file
  and line.
- **M2-3 · Periodic tasks in text.** `task <n> interval <ms> priority <p>` and `with`.
  *Done when* the plant of `docs/organisation.md` §4.4 without its event task, its `motor`
  the §4.2 one plus `var t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`,
  `var_external` or `cal`, which arrive with M2-4 and M2-5), driven for one simulated
  second, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  the one clock.
- **M2-4 · Shared globals.** `var_external` in `.ld`; type agreement (Ed 2 §2.4.3); no
  writes to an input point; a two-writer warning. *Done when* an e-stop declared once as
  a `var_global` and read by two instances through `var_external` stops both in the same
  cycle; a `var_external` with no matching global, or of another type, is a located
  diagnostic.
- **M2-5 · User function blocks.** `function_block <name>` as a file's first line,
  matching the file name;
  instances (`var s1 seal`); `cal` with positional operands, rung power as EN, and nothing
  copied on a false EN; nesting; recursion is a diagnostic. *Done when* a seal-in written
  once as a function block and instantiated three times in one program behaves as three
  independent seal-ins, `m1.s2.run` reads one of them, a false EN freezes only its own
  instance, and a recursive type, an unknown FB type or a `cal` of a non-instance is a
  located diagnostic.
- **M2-6 · Event tasks.** `task <n> single <g> [interval <ms>] priority <p>`, fired by a
  rising edge, and in the first cycle if the trigger is already true; with `interval` too,
  it runs periodically only while the trigger is 0, plus a run on each edge (IEC rule 2). *Done when* an event task triggered
  from an input point runs once per rising edge, before lower-priority tasks due in the
  same cycle, and runs in cycle 1 if its trigger is already true.

The scheduling rules are decided too: PRIORITY on every task, 0 the highest; ties go to
the earlier due time, then declaration order; no preemption; missed periods coalesced,
counted and reported; time injected in milliseconds, never read from a clock; reserved
words scoped by file kind. Once a wall-clock runner exists, a watchdog fault is to stop
scheduling, zero the output image once, report, and require an explicit restart: the
recommended choice, confirmed when the runner is designed (`docs/organisation.md` §7,
decision 14).

**Milestone 2 is done when** a configuration file on disk instantiates one `.ld` program
type twice, with a function block inside it; wires the instances to declared I/O points
and to a shared global; schedules them under a periodic task, an event task and no task;
runs deterministically for N cycles from an injected clock and input image, with the same
outputs on every run; and reports every wiring, typing or scheduling mistake as a located
diagnostic naming its file and line.

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

- **B3 · CI.** *Since the hand-written front end (§6), three lines:
  `mix compile --force --warnings-as-errors`, `mix format --check-formatted`, `mix test`,
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

- **B6 · Project metadata.** No `@spec`/`@moduledoc` on `Logex.Compiler`; no
  `description`/`package`/`licenses` in `mix.exs` despite a full Apache-2.0 `LICENSE`;
  unused `extra_applications: [:logger]`. `mix test --cover` reported a meaningless ~54%
  while it counted the generated scanners (`Logex.Compiler` 90%, `:ladder_lexer` 30%).
  With the front end hand-written (§6) it reports 97.92% on 1.20.4: `Logex.Compiler`
  94.59%, and `Logex.Lexer`, `Logex.Parser` and `Logex.Printer` 100%.

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

- **B8 · A lone `\r` never delimits a rung, so a CR-only file is silently one rung.**
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
  (one validator) and M1-5 (a `%Program{}` and a runtime for `name/1` to sit on), and a
  re-run of the whole study on Elixir 1.20, the floor in `mix.exs` — every receipt is from the 1.14
  sandbox. The report's §15 lists the decisions this item is waiting on, and they are still
  open. One seam came forward on its own: M1-3, decided 2026-09-28, provides the
  Elixir-side declarer (`instructionize(ast, declared)` and `Logex.Tag.new!/4`) that §11's
  M1-3 row asks for; §15's decision 3 (head declarations in the DSL's output) stays B9's.
  Nothing else in §3 or §5 changes until they are made. No codegen backend: the second backend the spike built
  disagreed with `evaluate/2` on 5,708 of 20,000 seeded envs and on 0 text-reachable ones.

---

## 5. Settled decisions

*Several decisions below are written as leex rules (`//` comments, `QUALIFIED` names,
negative literals, line continuations). The lexer is hand-written now (§6); each rule
becomes a clause in `Logex.Lexer`, and the behaviour it specifies still stands.*

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
  **landed with M1-3**). The survey
  is unanimous against nonzero-is-true, with no vendor precedent: even Mitsubishi's
  untyped devices require a *bit* (`D.b`), not a word. The escape hatch every vendor gives
  is bit addressing — `xic setpoint.3`.
- **Structured addressing — adopt `.`, resolved in the lexer.** One rule,
  `QUALIFIED = {NAME}(\.({NAME}|{INT}))*`, so `t1.dn` and `word.3` lex as one `name`
  token; **no grammar edit**. `env` holds a per-instance record, since `.acc` and `.dn`
  must update together in one scan. Array subscripts defer cleanly, because `[`/`]` stayed
  free. Two traps: the token no longer round-trips to a flat `env` key, and `.` in the
  lexer is safe only while there are no float literals.
- **Comments — `//` to end of line.** `//[^\r\n]* : skip_token.` — it must **not**
  consume the newline, or `ote a // note\note b` silently becomes one rung. Test exactly
  that. Keep `;` a lex error: it is the rung *terminator* in neutral text and reusing it
  would mislead. Later, promote a comment above a rung into a structural
  `%Logex.Rung{comment:, elements:}` — a compiler that only skips comments can never print
  `rung 4 ("seal-in for main motor"): unknown instruction`.
- **Negative literals — one lexer rule**, `-[0-9]+`, sign glued to the digits, no leading
  `+`. Widen §4·B2's digit-led rule to `-?[0-9]+…` in the same change. logex has no infix
  operators, so `-` can only be a sign; record that this must move to the grammar when
  infix arithmetic arrives.
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
  dint`.
- **Program organisation follows IEC's software model, in logex's dialect.** Decided
  2026-09-28: logex is heading for IEC's hierarchy (configuration, tasks, program
  instances, function-block instances, globals), its task-style execution (continuous,
  periodic, event) and I/O mapping in the configuration, not in program bodies.
  `docs/organisation.md` sets out the model, the conventional family's hierarchy mapped
  onto it, the logex form and Milestone 2. Its fourteen open decisions were taken as
  recommended on 2026-09-28, with its Milestone-1 changes (M1-3, M1-5 and M1-6 record
  them) and Milestone 2 (§3). In one line: a file is a POU type, state is an instance, a
  configuration instantiates, wires and schedules; no routines, no controller scope, no
  preemption. **Routines are deferred by decision** — subroutines that share their
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
blanks and a newline, and zero grammar changes.

One known limit to accept alongside this: the grammar declares no `error` productions, so
`parse/1` aborts at the first syntax error — three independent errors yield one
diagnostic. That is *why* M1-5's front-end error is singular while M1-2's validation
returns a list.

**Keep mnemonics out of the grammar.** They arrive as ordinary `name` tokens and resolve
against the `@instructions` module attribute, so adding an instruction touches a map
plus two `evaluate/2` clauses and never the front end. That is the right dividing line.

**Keep the sequential `env` threading through parallel branches** (the `{:branches, _}`
clause of `evaluate/2`)
and the non-short-circuiting reduce (the `is_list(branch)` clause). Both look like accidents of using
`Enum.reduce` and are in fact faithful controller behaviour.

---

## 7. Findings register

Every defect the review turned up, with the milestone item or backlog bullet that closes
it, and its status as of `1b1b1df`. `B1`–`B8` are the §4 backlog bullets. Items that are
pure forward work rather than defects (M1-3, M1-6, B5) have no row. An ID of `—` means the
finding has no plan item yet. Locations are current as of `1b1b1df` unless a cell says
otherwise.

| ID | Sev | Area | Finding | Location | Status |
|---|---|---|---|---|---|
| M0-1 | high | evaluate | `get_arg/2` matches `:lit_int`; every other stage emits `:int_lit` | `get_arg/2` | **closed** `690fc2d` |
| M0-3 | med | docs/build | `CLAUDE.md` promises regeneration that does not happen; a grammar edit is silently ignored on a fresh clone | `CLAUDE.md` compile + Key Files + step-2 bullets | **closed** `dde8c1d` — fresh-clone case; the generated front end's same-second trap went with it (§6), and CONTRIBUTING records the narrow residue left for `.ex` files |
| M0-2 | med | tests | No test crosses a stage seam; per-stage fixtures are hand-typed and contradict each other | `end_to_end_test.exs` | **closed** `03c10e0` |
| M0-5 | med | grammar | `rnd` is a strict infix separator, and a branch leg cannot be empty | `ladder_parser.yrl:8,12,16,21` | **closed** `b65e756` |
| B1 | med | lexer | Missing space before `nxb` fuses into an identifier — parallel silently becomes series | `ladder_lexer.xrl:8` | **closed** — delimiters are `(` `\|` `)`; guarded by "deleting a space around a delimiter is a no-op" in `end_to_end_test.exs` |
| M1-2 | med | lowering | No validation pass: unknown mnemonic → bare `MatchError`; short arity → truncated IR; and `mov src ote` silently eats the next mnemonic as a tag, no error, energised rung | `instructionize/1`, name clause | **closed** `e569113` — a located diagnostic for each case, every mistake in a routine reported (`validation_test.exs`) |
| M1-4 | med | semantics | `xic`/`xio` are independent positive tests — a non-bit or undefined tag reads false for both | `evaluate/2`, xic+xio clauses | open |
| B8 | med | lexer | A lone `\r` never delimits a rung, so a CR-only file is silently one rung and disagrees with the same text in LF | `Logex.Lexer`, the whitespace clause (was `ladder_lexer.xrl:6,10`) | open |
| M0-4 | low | lexer | `NAME` regex: `+` rejects single-char tags; `a-zA-z` typo admits ``[ \ ] ^ ` `` | `ladder_lexer.xrl:5` | **closed** `3f3b104` |
| — | low | tests | M0-4's fix was unguarded: no test used a single-character tag or a bracketed name, so reverting `ladder_lexer.xrl:5` left `mix test` fully green | `end_to_end_test.exs` | **closed** `b8fc743` |
| M1-5 | low | API | No public entry point and no `Logex` module; no scan loop | — | open |
| M1-5 | low | errors | Three error conventions across four stages; `format_error/1` never called; empty program reports line `999999` | `tokenize/1`, `parse/1` | **partly closed** — `999999` by `b65e756`; the other two clauses open |
| M0-3 | low | tooling | Generated `src/*.erl` tracked, embedding absolute `/nix/store` paths → ~700-line cross-OTP churn | `src/ladder_lexer.erl:1` (at `c9c7f51`; untracked since) | **closed** `dde8c1d` |
| B4 | low | tooling | nix dev shell bit-rotted: `erlangR26` alias removed from nixpkgs master 2024-05-24; flake tracked `master`; lock from 2024-01-19 | `shell.nix`, `flake.nix` | **landed** `9c1a7bd` — OTP 28 / Elixir 1.20 on `nixos-26.05`; lock refresh owed |
| B2 | low | lexer | Digit-led lexeme splits rather than erroring: `1bst` → `int_lit(1)` + `name("bst")` | `Logex.Lexer`, the integer clause (was `ladder_lexer.xrl:20`) | **closed** — a located `:missing_separator` lex error naming the whole run |
| B3 | low | history | 2 commits ship a red suite (`ec0534a`, `35fe1b9`) — an interior island; `d47eb21` is a clean bisect baseline | — | open |
| B6 | low | project | No CI, no `@spec`/`@moduledoc`, no mix.exs metadata, unused `:logger` | `mix.exs` | open |
| B7 | nit | style | 5 `{false, env}` clauses with identical bodies; `Enum.any?(o, &(&1==true))`; intermediate list in branch reducer | `evaluate/2` | open |
| M1-1 | nit | IR | AST nodes were keyword-list-shaped with duplicate keys where order is the meaning; `Keyword.get/2` would silently return only the first | the `elem ->` productions | **closed** `a22bf39` — elems are `{kind, line, value}` 3-tuples, not pairs |
| §5 | nit | domain | No comments, no negative literals, no structured addressing (`Timer.DN`, `Arr[3]`) | `Logex.Lexer` (was `ladder_lexer.xrl:3`) | open |
| B9 | low | surface | An Elixir-embedded `defladder` front end: studied, spiked, judged; recommendation and open decisions in `docs/defladder.md` | — | proposed |

---

## 8. Domain gaps, in priority order

The execution model — rung-condition-in, series AND, parallel OR, non-retentive OTE vs
retentive OTL/OTU, top-to-bottom rungs with immediate data-table updates — is faithful.
The mnemonic set is authentic ladder vocabulary rather than invented. What is missing:

1. **Timers and counters (TON/TOF/RTO, CTU/CTD/RES)** — decisive. Essentially no real
   routine exists without them, and they are why the scan model matters. See M1-6.
2. **A scan loop and I/O image.** See M1-6.
3. **A tag table with types.** Landed with M1-3.
4. **Comparisons (`eq ne lt gt le ge` — IEC names, see `docs/naming.md`)** — high value,
   low cost. See M1-6.
5. **Math (ADD/SUB/MUL/DIV), one-shots (ONS/OSR/OSF), then control flow (JMP/LBL/MCR).**
   ONS is the canonical instruction that cannot exist without cross-scan state. JMP/LBL
   do *not* require abandoning the `Enum.reduce` over rungs — widening the accumulator
   from `env` to `{skip, env}` is enough for forward jumps; only backward jumps need an
   indexed loop.
6. **Surface syntax: comments, negative literals, structured addressing.** See §5.
7. **Program organisation: configurations, tasks, program instances, I/O mapping.**
   Decided in §5; Milestone 2 (§3); the model in `docs/organisation.md`.
