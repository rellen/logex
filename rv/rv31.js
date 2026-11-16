export const meta = {
  name: 'rv-31-global-answers',
  description: 'RV-31: decisions 576, 577, 580 and 583: Global.new!/3 refusing every mistake of the one global at once, a long number cut in a host\'s refusal, CI\'s comment on its caches made true, the marks 575-583 settle; review; fix',
  phases: [{ title: 'Build' }, { title: 'Review' }, { title: 'Fix' }],
}
const S = '/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad'
const W = `${S}/rv/land31`
const COMMON = `
You work on logex, an Elixir ladder-logic compiler/interpreter. main is at ${args.base}. The whole-codebase review after Milestone 6 is docs/review-2026-11-01.md; PLAN.md's section "The review after Milestone 6" holds the items RV-1 to RV-31; decisions 347-583 are in docs/organisation.md §7. ${args.landed} Your item is RV-31: decisions 576, 577, 580 and 583, the maintainer's answers to RV-30's questions that ask for building. Read PLAN's paragraph "RV-30's questions answered, 2026-11-16" and RV-31's entry, RV-30's entry whole ("RV-30 as built", "RV-30's review", its questions), decisions 549-555 and 575-583, the moduledocs and head comments of Logex.Configuration (Global, new!/2,3, check/1, new!/1, the nested Initial judge, what check/1 says of a global's name, type, location and initial value), Logex.Tag (new!/4,5 and what it refuses at once), Logex.Declarations (check/1, the type messages, how a compile cuts a long literal it quotes) and Logex.Refusal, configuration_test.exs's tests of decision 555 and of RV-30's review (the pinned messages, the walk over names, types and values, the growth test), typespec_test.exs's tests of Global.t() (the four structs kept outside it), type_table_test.exs and validation_test.exs where they pin a number quoted in a refusal, runtime_test.exs's pin of Logex.Configuration's public surface, .github/workflows/ci.yml's comments on its caches and scripts_test.exs's hold of the workflow, CHANGELOG.md and CONTRIBUTING.md's "Between releases" FIRST, and build exactly what the record says.
Work in ${W}, branch rv31. Clone https://github.com/rellen/logex.git there if it does not exist; fetch origin main; rv31 should equal origin/main or be ahead of it with this item's work only.
${args.parallel} Before your last commit fetch origin main and, if it has moved, merge origin/main into rv31 (a merge message of your own, with the trailers) and re-gate.
CLAUDE.md is an index: a line per lib/ and test/ file, no history (claude_md_test.exs enforces it). Edit it only to add a line for a new file or to keep a line true; present rules go in moduledocs (decision 358), history in PLAN.md and docs/organisation.md.
Before running mix: source ${S}/toolchain/env.sh. Gate each commit by exit code: bash scripts/gate.sh <log> from the clone must print GATE-OK (five steps, Dialyzer the fifth), and bash scripts/docs.sh <log> must print DOCS-OK before any commit that changes a module's text or a page (CONTRIBUTING.md; RV-30's two red commits). Never relax mix.exs, and set no version in it.
CLAUDE.md conventions apply:
- a test fails when its fix is reverted (check by reverting; scripts/mutate.sh gives the table);
- mutation tables are TRUE, judged by the full suite, and by Dialyzer where a mutant changes lib/;
- host mistakes are pinned ArgumentErrors, their messages pinned whole, and nothing else escapes the public API (api_contract_test.exs);
- function clauses, not conditionals, in lib/ and in oracles (clauses_test.exs);
- every answer lib/ throws away is marked and listed (dropped_answers_test.exs);
- a spec on every public function of the host contract, each held to its values (typespec_test.exs), and Logex.Configuration's public surface as runtime_test.exs pins it;
- cost tests as CONTRIBUTING.md has them: same-run bounds, growth by reductions at two sizes, never a widened bound; the cost of Global.new!/3, of check/1 and of a configuration's new!/1 held against the parent;
- CHANGELOG.md held at every commit (decision 542): a change to what a host's call refuses or tells gets its item under "The host's API";
- the documents stay true: README's passages on a global from Elixir, Logex.Configuration's moduledoc, and README's "What logex is not" checked claim by claim at the end. The pages under guides/ and docs/ that DOC-1's second step is writing are not yours: they are in other clones and the step's close reconciles them with main.
NEVER delete or weaken an existing test, walk or oracle; justify every removed test line. The leave given, and only as each decision says: a pin of a struct that Global.new!/3 keeps today and decision 576 or 577 now refuses (a wrong name, an unknown type, a location that is no text, an initial value beside a location) changed to its refusal, the message pinned whole; a pin of a long number quoted whole in a refusal changed to the number cut (583); scripts_test.exs's pin of ci.yml changed by the comment alone (580). List every changed test file with its count of lines changed. Run one full suite at a time.
Commits end with exactly:
Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xkYDGU3foa6GtikDf5Ub7
Merge commits too: write every commit message yourself, never git's default. No model identifiers anywhere. Never push main, and never make or push a tag. Back up after each commit with git -C ${W} push -f https://github.com/rellen/logex.git HEAD:refs/heads/backup/rv31, verify it with git ls-remote, and check CI and Docs on the backup's tip (/usr/local/bin/gh api "repos/rellen/logex/actions/runs?head_sha=<full sha>"): a red run is a red commit whatever ran locally, and your report says so.
Append progress notes to ${S}/rv/progress31.md under "## RV-31" after each step; if work exists, read it and continue.
Where the record is silent, take the reading closest to the record, IEC and Logix, mark it provisional, and list it as a plain-language question with a conveyor, fan, lamp or box-counter example and the options by what a host or an operator sees.
`
phase('Build')
const b = await agent(`${COMMON}
Build RV-31, in order:

1. Decisions 576 and 577: Global.new!/3 judges the one global whole at the line that declares it. A name that is no global's name, a type that is no global's type, a location that is no text, and any initial value beside a location each raise an ArgumentError at once, in exactly the lines check/1 gives of the same struct built by hand, joined by newlines, from the one place both read (the judge RV-30 made for the value, grown; not a second copy of any rule). Mistakes in the options come first, as now. What needs the other globals, a program or a device to judge (two globals of one name, a location no device has, a point two globals take) stays check/1's. new!/2 as new!/3. Every struct new!/2,3 gives is a Global.t(): typespec_test.exs's four structs kept outside t() become refusals, and the test says so for every type at its ends. Pin each message whole: each of the three examples of decision 577 and decision 576's; several mistakes in one call, told as check/1 tells them, in its order; a name of each wrong kind (not a text, empty, a reserved word of a configuration file where check/1 refuses one, a name with a space); a type of each wrong kind (an unknown atom, a text, an array of no elementary type, an array of a bad size); a location of each wrong kind. The walk RV-30's review added (names x types x values) grown by locations, its reach asserted, letting only a struct or an ArgumentError out of new!/3 and holding new!/3's lines to check/1's for every draw.
2. Decision 583: a long number quoted cut. Find how a compile cuts a long literal it quotes (the one place) and what it shows; a refusal of Global.new!/3, of Logex.Tag.new!/5 and of check/1 quotes a number through that same place, so that Global.new!("total_boxes", :dint, initial: 10 ** 100_000) raises a message of bounded length that still says what was wrong and how long the number was. A long value that is no number (RV-30's review, M21: shown whole and pinned) is read again against the decision: the decision names a number; say what you did with a long text or list and why, provisional. A growth test: the refusal's cost and its message's length bounded as the number grows. Each pin of a number quoted whole changed so and only so.
3. Decision 580: .github/workflows/ci.yml's comments say what the two caches hold as they are (the _build cache holds the PLT too; a PLT is named by the toolchain's versions and its applications, so a copy from either cache is the right one or is not used); no key, path or step changes; scripts_test.exs's pin of the workflow changed by the comment alone, if it pins the comment at all.
4. The marks: every "provisional" RV-30's questions left (in lib/, the tests, scripts/, README, CHANGELOG.md, CONTRIBUTING.md and docs/organisation.md) made the number of the decision among 575-583 that settles it; each mark listed with its decision; a mark none of them settles left as it stands and listed.
5. The documents: Logex.Configuration's moduledoc and new!/3's doc, README's passage on a global from Elixir, CHANGELOG.md's items under "The host's API" for 576, 577 and 583, PLAN's RV-31 entry ("RV-31 as built") and decisions 576, 577, 580 and 583 each with a landed note; CLAUDE.md's lines true.
Each change with a test that fails when reverted and a mutant. Gate, build the site, commit in sensible steps and back up. Return:
- the tip and the test count, and CI and Docs on it;
- each decision and what it became, with its test and its mutants;
- a table: each kind of mistake in a call of Global.new!/3, what the host read before and reads now;
- the files the leave touched, each with its count of lines changed, every removed test line justified;
- the marks made and left;
- the cost of Global.new!/3, check/1 and new!/1 against the parent;
- the CLAUDE.md lines changed;
- the provisional readings, and the questions in plain language.`, { label: 'RV-31:build', phase: 'Build' })
phase('Review')
const v = await agent(`${COMMON}
You are an adversarial reviewer of RV-31. Clone ${W} to ${S}/rv/review31 (remove it first if it exists). Do not modify ${W}.
Builder's report:\n---\n${b}\n---
By running things, try to break it:
1. Decisions 576 and 577: call Global.new!/2,3 with every kind of wrong name, type, location, initial value and option you can make, alone and several at once (atoms, tuples, improper lists, binaries that are not UTF-8, huge terms, structs, pids, nested lists, floats and -0.0, a location with and without an initial value, an array type with a list of the wrong length). Does anything but a struct or an ArgumentError come out? Is every struct that comes out accepted by check/1 as a lone global, and a Global.t() by its spec? Are new!/3's lines exactly check/1's for the same struct built by hand, in every case and in the same order? Is anything refused at once that check/1 accepts, or kept that check/1 refuses of the one global?
2. Decision 583: every refusal of Global.new!/3, Logex.Tag.new!/5 and check/1 that quotes a value: a number of 10, 1,000 and 1,000,000 digits, negative, a float of many digits, a based literal where one can be given; is each message bounded, true and useful (does it still say what is wrong and what the limit is)? What does a long text, list or tuple give? Is a compile's own cut unchanged (the golden record, validation_test.exs)?
3. Decision 580: read ci.yml's comments against what the keys and paths do; is each sentence true? Did any key, path or step change?
4. The marks: grep every "provisional" against 575-583; any left that one settles, or one made a number no decision settles?
5. The leave: diff test/ against the base and judge every changed and removed line.
6. Plant at least 12 mutants in the new code, judged by the full suite, and by Dialyzer for those in lib/.
7. Measure Global.new!/3, check/1, new!/1 and a configuration's compile against the parent; CHANGELOG.md's check; the site's build; README's "What logex is not", claim by claim.
Return findings, most severe first.`, { label: 'RV-31:review', phase: 'Review' })
phase('Fix')
const f = await agent(`${COMMON}
The review of RV-31 reported:\n---\n${v}\n---
Fix every finding, with tests that fail when reverted or with documents made true. Then fetch origin main and, if it moved, merge origin/main into rv31 (a merge message of your own, with the trailers), resolve, and re-gate. Make gated commits, build the site, back up and check CI and Docs. Add RV-31's review to PLAN (each finding, the mutation table, cost, questions). Don't settle the maintainer's questions yourself. Return:
- the tip and the test count, and CI and Docs on it;
- what each finding became;
- the CLAUDE.md lines changed;
- the questions in plain language, each with a conveyor, fan, lamp or box-counter example, the options by what a host or an operator sees, and what IEC and Logix do.`, { label: 'RV-31:fix', phase: 'Fix' })
return { b, v, f }
