# Contributing to logex

**What this file is.** Working practices, distilled from things that actually went wrong in
this repository. It is prescriptive rather than descriptive: most of it postdates the
commits it cites, and it is a small single-maintainer project, so treat it as advice with
receipts rather than as established ceremony. Every rule below exists because something
specific broke.

**What it is not.** A workflow. There is no CI, no branch protection and no review
requirement; recent history is direct-to-main. Do not invent process here.

---

## Read this first

| Question | File |
|---|---|
| What is logex, what works, how do I run it? | `README.md` |
| How do I build it without falling into the trap? | `CLAUDE.md` |
| What is broken, what is next, in what order, and why? | `PLAN.md` |
| What should this instruction be called? | `docs/naming.md` |
| How do I work on it? | this file |

`PLAN.md` is long and half-archive. Its §2 is a completed milestone kept for the
*diagnoses* — it explains why the grammar carries an empty-rung filter and why `CLAUDE.md`
documents an `rm -f` loop. Read §1 for current state, §3 for the next work, §5 for
decisions you must not relitigate, §6 for code that looks wrong and is not.

---

## The one rule

**Verify by executing, not by reasoning.**

Every claim in this repository's documents that turned out to be wrong was arrived at by
reasoning; every one that survived was executed. That is not a figure of speech — it is the
observed pattern across four separate audits of these documents. A plausible-sounding
statement about this codebase is roughly a coin flip.

So: run it. Paste the real output. If you cannot run it, say so and mark the claim
`unverified` — `docs/naming.md` does this in eight places and is more trustworthy for it.
Never close the gap with a guess.

---

## Working on the code

### The build will lie to you

leex and yecc regenerate `src/*.erl` only when the `.erl` is absent or a whole second
older. An edit to `src/*.xrl` or `src/*.yrl` in the same second as the last build is
**silently ignored**: `mix compile` prints nothing and `mix test` stays green.

    rm -f src/*.erl && rm -rf _build && mix compile

Do that before every grammar compile. `mix test` alone will never tell you your change did
not take effect — prove it by tokenizing something only the new rule accepts. `PLAN.md`
§2·M0-3 has a worked before/after. This is the single most expensive trap in the project;
it caught the author of `747d630` mid-session, with the warning already written.

### A fix needs a test that fails when the fix is reverted

Check by reverting, not by reasoning.

`3f3b104` fixed two real bugs in one regex and shipped with no test. Reverting it left
`mix test` fully green while `tokenize("ote a")` was a hard lex error again. It took
`b8fc743` to close, with one test per bug — each failing only for its own half:

    NAME = [a-zA-Z_][a-zA-Z0-9_]*   (as shipped)   0 failures
    NAME = [a-zA-Z_][a-zA-Z0-9_]+   quantifier     1) single-character tag
    NAME = [a-zA-Z_][a-zA-z0-9_]*   char class     1) brackets
    NAME = [a-zA-Z_][a-zA-z0-9_]+   both           1) and 2)

A single test asserting "tags work" would have passed with half the regex broken. Make each
test fail for exactly one reason.

### Beware of a green suite

`690fc2d` fixed an atom that no stage in the pipeline could produce — `get_arg/2` matched
`:lit_int` while everything upstream emitted `:int_lit`, so the entire integer-literal
feature was dead end to end. The suite was green for eight commits because the evaluation
fixtures hand-wrote the same misspelling, cancelling it out.

`test/logex/end_to_end_test.exs` exists because of that: it drives source to an environment
and names no IR tag, so it can only pass if the stages genuinely agree. **Add to it when
you change behaviour** — the per-stage tests hand-type their inputs and cannot catch a
seam.

Also beware assertions that cannot see the bug. `b65e756`'s acceptance block printed only
the environment, which is provably identical with and without the phantom-rung defect it
was meant to verify. Assert on the thing that changed.

### New instructions

Two steps, in `CLAUDE.md`, and step 1 has a test behind it.

1. **Survey the name first** — add a stanza to `docs/naming.md`. `test/logex/naming_test.exs`
   fails if a mnemonic reaches `@instructions` without one.
2. **Then the code** — `@instructions` plus **two** `evaluate/2` clauses. The de-energised
   `{false, env}` clause is mandatory; without it the instruction works on an energised rung
   and raises `FunctionClauseError` the moment a contact opens.

---

## Working on the documents

### Anchor on names, not line numbers

`PLAN.md`'s line references have gone stale three times. The third was self-inflicted:
`6802f9c` anchored every `compiler.ex` reference on clause heads — and in the same commit
edited `CLAUDE.md`, shifting every `CLAUDE.md` line reference in `PLAN.md`. `747d630`
cleaned that up.

Cite `the {:xic, [name: arg]} clause of evaluate/2`, not `compiler.ex:79`. Clause heads,
function names, grammar productions and bullet titles survive edits above them. §1 and §2
keep their numbers deliberately; §2 is explicitly historical.

### Landing work stales the plan

`PLAN.md` §1's counts, §7's Status column and the README's "Settled, not yet landed" list
all go out of date when you ship. This repo brings them current in a separate audit pass
(`440bc83`, `4e256ff`) rather than in the same commit — either is fine, but the pass has to
happen. A plan that disagrees with the code is worse than no plan, because it is trusted.

The README has no test behind it. Any language change stales it: a new instruction adds a
row, a syntax change touches the syntax list, the instruction table *and* the worked
example — whose output is real, so re-run it.

### Do not restore vendor names

`docs/naming.md`'s Conventional column is unattributed on purpose, and the policy extends
to prose in every document. Rule 2 of the naming rule says to name which vendor a mnemonic
came from; for that one column, "the conventional set" *is* the name. This is a project
choice, not an oversight to fix.

---

## Things that will bite you

- **Do not relax `mix.exs`.** On an older toolchain `mix compile` aborts and the obvious
  fix is to loosen `elixir: "~> 1.15"`. Install a newer Elixir instead. An automated audit
  of this repo recommended relaxing it, having mistaken a test rig's patched copy for the
  repository's own — a wrong conclusion from real evidence.
- **`mix compile --warnings-as-errors` does not fail on a grammar conflict.** yecc emits a
  silently disambiguated parser and mix reports a warning the flag does not upgrade.
  Verified: six shift/reduce conflicts, all three checks exit 0. `PLAN.md` §4·B3 has the
  gate command; run it after any `.yrl` change.
- **Never skip, disable or quarantine a test to get to green.**
- **Some code that looks wrong is not.** The non-short-circuiting `Enum.reduce` and the
  sequential `env` threading through parallel branches both look like accidents and are
  faithful controller behaviour. `PLAN.md` §6 lists them; read it before "fixing" one.

---

## Before you commit

    rm -f src/*.erl && rm -rf _build
    mix compile --warnings-as-errors
    mix format --check-formatted
    mix test

All three must pass. After a `.yrl` change, also run the conflict gate in `PLAN.md` §4·B3.
