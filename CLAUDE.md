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
  `lib/logex/instance.ex` and `lib/logex/scan.ex` hold its two structs.
- `lib/logex/compiler.ex` — the stages: `tokenize/1` and `parse/1` delegate to the two
  modules below; `instructionize/2` takes the declaration lines off into a tag table,
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
  line and for `Logex.Tag.new!/4`
- `lib/logex/tag.ex` — `%Logex.Tag{}`, whose type is `:bool`, `:dint` or, for an instance
  of a function block such as `var t1 ton`, the `%Logex.FbType{}` itself; and `new!/4`,
  which declares a tag from Elixir
- `lib/logex/fb_type.ex` — `%Logex.FbType{}`, a function block type's schema (M1-6), which
  M2-5's user function blocks reuse: its members, each a `%Logex.FbType.Member{}` with a
  type, a role (`:input`, `:output`, `:internal`) and whether logic may write it;
  `ton/0`, the built-in timer; `initial/2`, a new instance's state, a map keyed by member
  name; `member/2` and `public/1`, which never give an internal member
- `lib/logex/program.ex` — `%Logex.Program{name:, source:, rungs:, tags:, warnings:}`, a
  program type, named and stateless, with `initial_env/1` for an instance's first env
- `lib/logex/lexer.ex` / `lib/logex/parser.ex` — the front end, written by hand: binary
  pattern matching, and recursive descent (the parser's moduledoc gives the grammar and
  which function parses each production). There is no generator, so nothing reports a
  grammar conflict: **a new syntax form goes into `printer_test.exs`'s generator and
  `@required_shapes` before it lands**, and the golden record below must stay green.
- `lib/logex/printer.ex` — the parse AST back to canonical source text
- `lib/logex/diagnostic.ex` — `%Logex.Diagnostic{stage:, line:, message:, file:, column:,
  severity:}`, the one error and warning type of every stage, and `format/1` for the
  `motor.ld: line 3, column 5: …` form
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`; `validation_test.exs` holds every diagnostic and warning `instructionize/2` gives, driven from source. `test/logex_test.exs` pins `Logex` (and walks Milestone 1's done sentence), `runtime_test.exs` every message the runtime raises and the exact public surface, and `api_contract_test.exs` a seeded property over the host contract, which since M1-6 checks every accepted scan against an oracle for `ton` and `ons` and makes every accepted call twice
- `test/logex/frontend_golden_test.exs` holds `tokenize/1` + `parse/1` to a recorded AST,
  end line or error line for ~1,400 sources (`test/fixtures/frontend_golden.txt`). It
  catches front-end changes the rest of the suite cannot see: B8, making a lone CR end a
  rung, failed it and nothing else until B8's own tests came with it. It keeps the AST and error lines, not the tokens or
  columns, so newline coalescing, columns and messages are pinned in
  `test/logex/frontend_test.exs` instead. Regenerate it only in a commit that changes the
  language or the generator on purpose, and read the diff:
  `test/fixtures/generate_frontend_golden.exs`.
- `test/logex/end_to_end_test.exs` drives source to an environment, through `Logex.compile/2`
  and `Logex.Runtime.call/4` on an instance whose env the test chooses, or several scans
  of one instance; its *assertions* name no IR tag (one helper matches the
  `{:routine, {:rungs, _}}` wrapper to count rungs). It was the first test to cross every
  stage boundary, and is where a behaviour change is pinned, `ton`'s and PLAN M1-6's
  decision-6 test among them; `validation_test.exs` and `printer_test.exs` also run source to an environment
  in places. `lex_and_parse_test.exs` starts from a
  source string and so crosses the tokenize→parse seam, but no further; the other two
  hand-type one stage's input and cannot see a seam at all.
- `README.md` — what logex is, the dialect stance, the instruction table and a worked
  example. **Any change to the language stales it:** a new instruction adds a row and may
  clear a "Settled, not yet landed" bullet; a syntax change touches the syntax list, the
  instruction table and the example (whose output is real — re-run it). Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic or declaration
  word; append-only
- `docs/organisation.md` — where logex is heading above one program: IEC's configuration,
  tasks, program instances and I/O mapping, in logex's dialect. Decided (PLAN §5; the
  work is PLAN's M1-3, M1-5, M1-6 and Milestone 2). Read it before designing anything
  that names a program, schedules one, or binds I/O.
- `docs/instruction-sets.md` — reference: IEC's LD elements and standard library by table number,
  Instruction List (withdrawn in Ed 4), and the free-software instruction sets. Read it before
  writing a naming.md stanza; it carries the IEC feature numbers a stanza should cite.

## Conventions

- `evaluate/3` clauses, private in `Logex.Runtime`, take `(instruction, {power_flow_bool, env_map}, %Logex.Scan{})` and return `{new_power_flow_bool, new_env_map}`. The scan is read-only and the same for every instruction of one call: a clause that needs the time reads `scan.now`, one that needs the first scan reads `scan.first`, and every other clause ignores it as `_scan` (M1-6). No test calls the evaluator: a test runs a program through `Logex.Runtime.call/4`, on a hand-built `%Logex.Instance{}` when it needs a particular env
- A mistake in the source is a `%Logex.Diagnostic{}`, returned; a mistake by the host is an `ArgumentError`, raised, whose message a test pins. Nothing else may escape the public API (`api_contract_test.exs`)
- An operand in the AST is `{:name, line, tag}` or `{:int_lit, line, value}` — a 3-tuple, not a keyword pair. Destructure the line as `_`; never drop it from the AST, it is what diagnostics will cite. The lexer's tokens carry `{line, column}`; the parser keeps only the line, because the suite pins that shape. An instruction in the IR is `{symbol, line, operands}`, carrying its mnemonic's line; a `{:branches, legs}` node carries no line of its own. In the IR, and only there, a member of an instance is `{:member, line, path}`, `t1.acc` becoming `{:member, 3, ["t1", "acc"]}` (M1-6): the runtime's `read/2` and `write/3` take it as they take a tag, and anything that walks IR operands must handle it
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
  Elixir form. A new section or type word is a row in `Logex.Declarations`, is reserved in
  any case, and owes a `docs/naming.md` stanza, which `naming_test.exs` checks.
- A fix needs a test that **fails when the fix is reverted**. Check it by reverting, not by
  reasoning: `mix test` stayed fully green after the `NAME` regex was corrected, because
  no test used a single-character tag. `PLAN.md` §2·M0-4 has the worked mutation table.
- Use pattern matching with multiple function clauses, not conditionals
