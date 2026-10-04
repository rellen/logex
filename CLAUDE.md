# CLAUDE.md

Logex is a Ladder Logic compiler/interpreter in Elixir. The toolchain is Elixir ~> 1.20 on OTP 28, pinned in `mix.exs` and `shell.nix` (`nix develop`). No external dependencies.

## Commands

- `mix compile` — compile.
- `mix test --warnings-as-errors` — run tests (must pass before committing; the flag fails
  on a warning in a test file, which `mix compile` never sees). Judge a run by its exit code, not by
  grepping its output: Elixir 1.20 prints `Result: 39/40 passed`, which a grep for
  `[0-9]+ passed` reads as a pass.
- `mix format` — format code before committing
- Requires Elixir ~> 1.20; on anything older `mix` aborts before it runs. **Never relax
  `mix.exs`** — the constraint is deliberate, and a loosened version bound is the kind of
  edit that lands by accident. If you cannot install a newer Elixir, run the suite in the
  throwaway sandbox in `CONTRIBUTING.md` ("Running the suite on an older toolchain"), which
  patches a *copy*. That is how most receipts in these documents were produced, on Elixir
  1.14; those that ran on the pinned 1.20.4 say so.

## Key Files

- `lib/logex.ex` — the public way in (M1-5): `compile(source, name:)` and
  `compile_file/1`, giving a named `%Logex.Program{}` or every mistake as a
  `%Logex.Diagnostic{}`; a lex or parse error becomes one diagnostic with its column
- `lib/logex/runtime.ex` — runs a program as instances (M1-5): `instance/1`, `call/4` (one
  scan of one instance, at a given `%Logex.Scan{}`), `put_inputs/3` with `scan/2,3` (the
  task-less sugar) and `restart/3`, with the host contract in its moduledoc: a host
  mistake raises `ArgumentError`. The evaluator lives here too, private (B5): `rung/3`,
  `series/3`, `element/3`, and the instruction clauses of `evaluate/3`, each threading the
  scan's read-only `%Logex.Scan{}`.
  Since M2-1 it also runs a configuration as one resource, `%Logex.Runtime{}`, opaque:
  `start/1`, `cycle/3` (time, the input image, the due tasks by priority, then due time,
  then declaration, each instance copied in, scanned by `call/4` and copied out, the
  task-less instances last, the output points), `next_due_in/1`, `overlaps/1`, `get/2`
  and `get!/2`, an access path (`{:ok, value}` or `{:error, reason}`, or the value or a
  raise, decision 41), and `restart/2`, which keeps the clock and the input image as
  `restart/3` keeps an instance's var_inputs; their rules, events and the host's loop are
  in its moduledoc.
  `lib/logex/instance.ex` and `lib/logex/scan.ex` hold its two structs, each with
  `ons_blocked` since OE-1: the storage bits whose `ons` the next scan blocks, the hook an
  online edit's switch uses to keep a new or changed one-shot from firing. The instance
  also has `switched`, which an edit's switch sets and a scan clears.
- `lib/logex/configuration.ex` — `%Logex.Configuration{}` (M2-1, `docs/organisation.md`
  §4.4 and §4.10): the program types, tasks, globals (located at `<device>.i|q.<address>`
  or not), program instances and connections, as plain data and lists in declaration
  order, under a name it must have, and `warnings`, empty until a check gives one;
  `check/1`, the one validator, giving a mistake a configuration's text could make as a
  `:configure` diagnostic at its element's line in the configuration's file, and raising
  one `ArgumentError` for the host's mistakes no text can make, a line each (decision 36:
  a bad name, file or programs, a part that is not a proper list of its struct, a struct
  that lacks one of its keys, a bad line, lines neither all nil nor rising, a name no
  lexer reads as one token, a negative number); `new!/1`, from Elixir, raising one
  `ArgumentError` with every problem, an element that brings a line among them;
  `location/1`; and `initial/1`, the one rule for a new global's value, as
  `Logex.Program.initial_env/1` is a tag's
- `lib/logex/edit.ex` — a staged edit of one program instance (OE-1, `docs/organisation.md`
  §4.9): `accept/3` (refusing a type change as `:edit` diagnostics, with a forecast),
  `test/2`, `untest/2`, `assemble/2`, `cancel/2`, `running/1` and `stage/1`, each step
  returning a report. Accept builds a plan per direction from the two programs; a switch
  and a prune are per-instance functions of a plan, the edit's record and the state,
  private until OE-2 calls them. Its moduledoc gives every rule, report kind and host
  mistake; §4.9 the reasons
- `lib/logex/compiler.ex` — the stages: `tokenize/1` and `parse/1` delegate to the two
  modules below; `instructionize/2` first checks its routine against
  `Logex.Parser.well_formed!/1` and raises `ArgumentError` on a tree no text could say
  (OE-1), then takes the declaration lines off into a tag table,
  checks every instruction against its operand signature and every operand against the
  table, members included (M1-6), gives each timer the preset on the one `ton` that runs
  it, refuses a second `ons` on one storage bit and anything after a `ton` on its path,
  and returns `{:ok, %Logex.Program{}}` (warnings included) or
  `{:error, [%Logex.Diagnostic{}]}`. The stage functions stay public for the golden
  record, the Elixir-side declarer and the naming test.
- `lib/logex/warnings.ex` — the warnings a compiled program carries: a tag used by no
  rung, a `var_output` no rung writes, a second `ote` on one tag, and since M1-6 another
  write to an `ons` storage bit, a comparison of two literals, a timer no `ton` runs
- `lib/logex/declarations.ex` — declaration lines to a tag table, after parsing: the
  section and type words as data (`@sections`, `@types`, and the function block type
  words of `Logex.FbType.builtins/0`), `reserved/1`, `fits?/2`, `preset?/1` (a `ton`'s
  preset range, 0 to 2147483647 ms), and `check/1`, the one validator for a declaration
  line and for `Logex.Tag.new!/4`, so from Elixir too it refuses what no line can say: an
  initial value on an instance, and a negative one (OE-1)
- `lib/logex/tag.ex` — `%Logex.Tag{}`, whose type is `:bool`, `:dint` or, for an instance
  of a function block such as `var t1 ton`, the `%Logex.FbType{}` itself; and `new!/4`,
  which declares a tag from Elixir. Since OE-1 it takes no timer preset (the
  `%{"pre" => ms}` M1-6 allowed: a preset is the number on the `ton` that runs the
  timer) and no negative initial value
- `lib/logex/fb_type.ex` — `%Logex.FbType{}`, a function block type's schema (M1-6), which
  M2-5's user function blocks reuse: its members, each a `%Logex.FbType.Member{}` with a
  type, a role (`:input`, `:output`, `:internal`) and whether logic may write it;
  `ton/0`, the built-in timer; `initial/2`, a new instance's state, a map keyed by member
  name; `member/2` and `public/1`, which never give an internal member
- `lib/logex/program.ex` — `%Logex.Program{name:, source:, rungs:, tags:, warnings:}`, a
  program type, named and stateless, with `initial_env/1` for an instance's first env
- `lib/logex/lexer.ex` / `lib/logex/parser.ex` — the front end, written by hand: binary
  pattern matching, and recursive descent (the parser's moduledoc gives the grammar and
  which function parses each production). `Logex.Parser.well_formed!/1` is the definition
  of a well-formed parse tree, exactly what `parse/1` can produce, which
  `instructionize/2` checks on entry (OE-1). There is no generator, so nothing reports a
  grammar conflict: **a new syntax form goes into `printer_test.exs`'s generator and
  `@required_shapes` before it lands**, and the golden record below must stay green.
- `lib/logex/printer.ex` — the parse AST back to canonical source text
- `lib/logex/diagnostic.ex` — `%Logex.Diagnostic{stage:, line:, message:, file:, column:,
  severity:}`, the one error and warning type of every stage, and `format/1` for the
  `motor.ld: line 3, column 5: …` form
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`; `validation_test.exs` holds every diagnostic and warning `instructionize/2` gives, driven from source. `test/logex_test.exs` pins `Logex` (and walks Milestone 1's done sentence), `runtime_test.exs` every message the runtime raises and the exact public surface, `edit_test.exs` every message, diagnostic and rule of `Logex.Edit`, `configuration_test.exs` every diagnostic and host mistake of `Logex.Configuration`, as whole lists from data, `scheduler_test.exs` a test at least per rule of a cycle, and `api_contract_test.exs` a seeded property over the host contract, which since M1-6 checks every accepted scan against an oracle for `ton` and `ons` and makes every accepted call twice, and since OE-1 walks online edits too, and since M2-1 configurations run as resources, against a model that scans each instance through `call/4` alone
- `test/logex/frontend_golden_test.exs` holds `tokenize/1` + `parse/1` to a recorded AST,
  end line or error line for ~1,400 sources (`test/fixtures/frontend_golden.txt`). It
  catches front-end changes the rest of the suite cannot see: B8, making a lone CR end a
  rung, failed it and nothing else until B8's own tests came with it. It keeps the AST and error lines, not the tokens or
  columns, so newline coalescing, columns and messages are pinned in
  `test/logex/frontend_test.exs` instead. Regenerate it only in a commit that changes the
  language or the generator on purpose, and read the diff:
  `test/fixtures/generate_frontend_golden.exs`.
- `test/logex/edit_test.exs` pins `Logex.Edit`: every host-mistake message and the order of
  its checks, every `:edit` diagnostic, a test per rule of §4.9 (grouped by the decision,
  fix or §4.9 rule it answers), and four growth tests in reductions (F16): accept, test,
  untest, test and assemble at two sizes and two depths, the scan right after a switch at
  two numbers of blocked one-shots, and a second edit before any scan at two numbers of
  pending blocks; and a test that `lib/`, `test/` and this file cite no lettered hazard or
  numbered review finding, and no fix or decision number `docs/organisation.md` §7 does
  not define. Its programs come from source, an unnamed one through `instructionize/2`,
  never from editing a struct.
  `api_contract_test.exs`'s edit walk checks the same rules restated from the programs'
  text, and carries oracles that know nothing of them
- `test/logex/end_to_end_test.exs` drives source to an environment, through `Logex.compile/2`
  and `Logex.Runtime.call/4` on an instance whose env the test chooses, or several scans
  of one instance; its *assertions* name no IR tag (one helper matches the
  `{:routine, {:rungs, _}}` wrapper to count rungs). It was the first test to cross every
  stage boundary, and is where a behaviour change is pinned, `ton`'s, PLAN M1-6's
  decision-6 test, PLAN OE-1's Done-when and PLAN M2-1's Done-when among them, the last
  through `Logex.Runtime.cycle/3` with `scan/2` beside it; `validation_test.exs` and
  `printer_test.exs` also run source to an environment in places.
  `lex_and_parse_test.exs` starts from a source string and so crosses the tokenize→parse
  seam, but no further; the other two hand-type one stage's input and cannot see a seam at
  all.
- `README.md` — what logex is, the dialect stance, the instruction table and worked
  examples, among them a configuration built from Elixir and run by the scheduler, and a
  running program changed by `Logex.Edit`. **Any change to the language stales it:** a
  new instruction adds a row and may clear a "Settled, not yet landed" bullet; a syntax
  change touches the syntax list, the instruction table and the examples (whose output is
  real — re-run it). So does a change to a configuration's checks or a cycle's rules,
  through "A configuration", and to an edit's rules or report, through "Changing a
  running program". Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic or declaration
  word; append-only
- `docs/organisation.md` — where logex is heading above one program: IEC's configuration,
  tasks, program instances and I/O mapping, in logex's dialect. Decided (PLAN §5; the
  work is PLAN's M1-3, M1-5, M1-6, OE-1, Milestone 2 and OE-2; OE-1 and M2-1 have landed,
  and Milestone 2 was designed on 2026-10-02, §4.10 and decisions 30–40). Read it
  before designing anything that names a program, schedules one, binds I/O, or changes a
  running controller (§4.9, online edit, decided 2026-10-01).
- `docs/instruction-sets.md` — reference: IEC's LD elements and standard library by table number,
  Instruction List (withdrawn in Ed 4), and the free-software instruction sets. Read it before
  writing a naming.md stanza; it carries the IEC feature numbers a stanza should cite.

## Conventions

- `evaluate/3` clauses, private in `Logex.Runtime`, take `(instruction, {power_flow_bool, env_map}, %Logex.Scan{})` and return `{new_power_flow_bool, new_env_map}`. The scan is read-only and the same for every instruction of one call: a clause that needs the time reads `scan.now`, one that needs the first scan reads `scan.first`, and every other clause ignores it as `_scan` (M1-6). `ons` reads `scan.first` and `scan.ons_blocked`, the storage bits whose `ons` passes no power on this one scan, which `call/4` builds from the instance's `ons_blocked` list as a map of those bits, each to `true`, so that each `ons` looks its bit up rather than walking the list, emptying the instance's list after the scan (OE-1); a host never fills it in. No test calls the evaluator: a test runs a program through `Logex.Runtime.call/4`, on a hand-built `%Logex.Instance{}` when it needs a particular env
- A mistake in the source is a `%Logex.Diagnostic{}`, returned; a mistake by the host is an `ArgumentError`, raised, whose message a test pins. Nothing else may escape the public API (`api_contract_test.exs`)
- An operand in the AST is `{:name, line, tag}` or `{:int_lit, line, value}` — a 3-tuple, not a keyword pair. Destructure the line as `_`; never drop it from the AST, it is what diagnostics will cite. `Logex.Parser.well_formed!/1` states the whole tree `parse/1` can produce, and `instructionize/2` raises `ArgumentError` on any other (OE-1): every line a positive integer, every element of a rung on its one line, each rung on a line after the last, a name that lexes as one name token, a literal of 0 or more, a rung of one element or more and a group of one leg or more. A test that builds a tree by hand builds one of those. The lexer's tokens carry `{line, column}`; the parser keeps only the line, because the suite pins that shape. An instruction in the IR is `{symbol, line, operands}`, carrying its mnemonic's line; a `{:branches, legs}` node carries no line of its own. In the IR, and only there, a member of an instance is `{:member, line, path}`, `t1.acc` becoming `{:member, 3, ["t1", "acc"]}` (M1-6): the runtime's `read/2` and `write/3` take it as they take a tag, and anything that walks IR operands must handle it
- New instructions, step 1 — **survey the name before writing any code**: add a
  ``### `mnemonic` `` stanza to `docs/naming.md` (IEC 61131-3 element, function or
  function block with clause and table number, then the major vendor toolchains, then the
  logex name and why, then `Checked:` with sources). The rule, in
  order: **(1)** if IEC names the operation, take the IEC name lowercased; **(2)** if IEC
  supplies only a graphical element, take the clearest vendor mnemonic and say which;
  **(3)** never invent a readable word for a thing that already has a standard name. Mark
  what you could not verify `unverified`; never guess. `test/logex/naming_test.exs` fails
  if a mnemonic reaches `@instructions` unsurveyed.
- New instructions, step 2: add the mnemonic and its operand signature (one
  `{access, type}` per operand: access `:read` or `:write` for a tag, `:value` for a tag
  or a literal, `:instance` for an instance the instruction runs, whose type is then the
  function block type's name (`{:instance, "ton"}`), `:preset` for a literal number of
  milliseconds; type `:bool`, `:dint` or `:any`; a tag may be a member, `t1.acc`, which
  has its schema's type) to the `@instructions` map in
  `compiler.ex` **and** two
  `evaluate/3` clauses in `runtime.ex` — one for `{true, env}` and one for `{false, env}`. The map also
  reserves the name: no tag may be spelled like a mnemonic, in any case, so a new
  instruction breaks any program with a tag of that name — say so in the commit. The
  de-energised clause is mandatory: without it the instruction works on an energised
  rung and raises `FunctionClauseError` the moment a contact opens. If what power the
  instruction passes on is not settled, the compiler refuses anything after it on its
  path, as it does after `ton` (M1-6), rather than let a program depend on either reading.
- Every tag a program uses is declared (M1-3): in the source, `var aa bool` before the first
  rung, or from Elixir, `Logex.Tag.new!/4` passed to `instructionize/2`. A test that only
  needs tags to exist declares them either way; `validation_test.exs`'s `@declared` is the
  Elixir form. A new section or elementary type word is a row in `Logex.Declarations`,
  and a function block type word a key of `Logex.FbType.builtins/0`; either is reserved in
  any case and owes a `docs/naming.md` stanza, which `naming_test.exs` checks.
- New state in an instance (a field of `%Logex.Instance{}`, a member of a function block
  type, an M2 item's piece of state) states its rule across an online edit. A tag or member
  starts by `Logex.Program.initial_env/1`, the one rule, whose doc and §4.9's "One rule for
  new state" list the edit's exceptions. A field of `%Logex.Instance{}` gets a check in
  the runtime with a message a test pins, a value from `instance/1`, and a rule for each
  of a scan, `restart/3` and a switch, as `ons_blocked` and `switched` have. A piece of a
  resource's state, in the opaque `%Logex.Runtime{}`, which no host hands in and so needs
  no entry check, gets a value from `start/1` and a rule for each of a cycle, `restart/2`
  and OE-2's switch instead, in `Logex.Runtime`'s one-rule section, with the edit's
  exceptions listed; a global's one rule is `Logex.Configuration.initial/1`, beside
  `initial_env/1` for a tag (M2-1). A new report
  kind is a row in `Logex.Edit`'s table and §4.9's, and in `api_contract_test.exs`'s
  `@report_kinds`, whose reach the walk asserts
- Nothing compiles a user's program to BEAM: every front end (the text, an Elixir data
  API, any later macro) ends in `%Logex.Program{}` data that `Logex.Runtime` interprets,
  and no front end puts the Elixir compiler on the path that changes a running program
  (`PLAN.md` §6; online edit, `docs/organisation.md` §4.9)
- A fix needs a test that **fails when the fix is reverted**. Check it by reverting, not by
  reasoning: `mix test` stayed fully green after the `NAME` regex was corrected, because
  no test used a single-character tag. `PLAN.md` §2·M0-4 has the worked mutation table.
- Use pattern matching with multiple function clauses, not conditionals
