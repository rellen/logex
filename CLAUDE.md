# CLAUDE.md

Logex is a Ladder Logic compiler/interpreter in Elixir. The toolchain is Elixir ~> 1.20 on OTP 28, pinned in `mix.exs` and `shell.nix` (`nix develop`). No external dependencies.

## Commands

- `mix compile` — compile.
- `mix test` — run tests (must pass before committing). Judge a run by its exit code, not by
  grepping its output: Elixir 1.20 prints `Result: 39/40 passed`, which a grep for
  `[0-9]+ passed` reads as a pass.
- `mix format` — format code before committing
- Requires Elixir ~> 1.20; on anything older `mix` aborts before it runs. **Never relax
  `mix.exs`** — the constraint is deliberate, and a loosened version bound is the kind of
  edit that lands by accident. If you cannot install a newer Elixir, run the suite in the
  throwaway sandbox in `CONTRIBUTING.md` ("Running the suite on an older toolchain"), which
  patches a *copy*. That is how every executed receipt in these documents was produced.

## Key Files

- `lib/logex/compiler.ex` — the pipeline: `tokenize/1` and `parse/1` delegate to the two
  modules below; `instructionize/1` and `evaluate/2` live here
- `lib/logex/lexer.ex` / `lib/logex/parser.ex` — the front end, written by hand: binary
  pattern matching, and recursive descent with one function per grammar production (the
  grammar is in the parser's moduledoc). There is no generator, so nothing reports a
  grammar conflict: **a new syntax form goes into `printer_test.exs`'s generator and
  `@required_shapes` before it lands**, and the golden record below must stay green.
- `lib/logex/printer.ex` — the parse AST back to canonical source text
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`
- `test/logex/frontend_golden_test.exs` holds `tokenize/1` + `parse/1` to a recorded AST,
  end line or error line for ~1,400 sources (`test/fixtures/frontend_golden.txt`). It
  catches front-end changes the rest of the suite cannot see — a lone-CR or leading-`_`
  change to the lexer leaves all 40 other tests green. Regenerate it only in a commit that
  changes the language or the generator on purpose, and read the diff: `test/fixtures/generate_frontend_golden.exs`.
- `test/logex/end_to_end_test.exs` drives source to an environment; its *assertions* name
  no IR tag (one helper matches the `{:routine, {:rungs, _}}` wrapper to count rungs), so it
  is the only test that crosses every stage boundary. `lex_and_parse_test.exs` starts from a
  source string and so crosses the tokenize→parse seam, but no further; the other two
  hand-type one stage's input and cannot see a seam at all.
- `README.md` — what logex is, the dialect stance, the instruction table and a worked
  example. **Any change to the language stales it:** a new instruction adds a row and may
  clear a "Settled, not yet landed" bullet; a syntax change touches the syntax list, the
  instruction table and the example (whose output is real — re-run it). Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic; append-only
- `docs/instruction-sets.md` — reference: IEC's LD elements and standard library by table number,
  Instruction List (withdrawn in Ed 4), and the free-software instruction sets. Read it before
  writing a naming.md stanza; it carries the IEC feature numbers a stanza should cite.

## Conventions

- `evaluate/2` clauses take `(instruction, {power_flow_bool, env_map})` and return `{new_power_flow_bool, new_env_map}`
- An operand in the AST is `{:name, line, tag}` or `{:int_lit, line, value}` — a 3-tuple, not a keyword pair. Destructure the line as `_`; never drop it from the AST, it is what diagnostics will cite. The lexer's tokens carry `{line, column}`; the parser keeps only the line, because the suite pins that shape. A `{:branches, legs}` node and an instruction tuple `{symbol, args}` carry no line of their own
- New instructions, step 1 — **survey the name before writing any code**: add a
  ``### `mnemonic` `` stanza to `docs/naming.md` (IEC 61131-3 element, function or
  function block with clause and table number, then the major vendor toolchains, then the
  logex name and why, then `Checked:` with sources). The rule, in
  order: **(1)** if IEC names the operation, take the IEC name lowercased; **(2)** if IEC
  supplies only a graphical element, take the clearest vendor mnemonic and say which;
  **(3)** never invent a readable word for a thing that already has a standard name. Mark
  what you could not verify `unverified`; never guess. `test/logex/naming_test.exs` fails
  if a mnemonic reaches `@instructions` unsurveyed.
- New instructions, step 2: add to the `@instructions` map in `compiler.ex` **and** two
  `evaluate/2` clauses — one for `{true, env}` and one for `{false, env}`. The
  de-energised clause is mandatory: without it the instruction works on an energised
  rung and raises `FunctionClauseError` the moment a contact opens.
- A fix needs a test that **fails when the fix is reverted**. Check it by reverting, not by
  reasoning: `mix test` stayed fully green after the `NAME` regex was corrected, because
  no test used a single-character tag. `PLAN.md` §2·M0-4 has the worked mutation table.
- Use pattern matching with multiple function clauses, not conditionals
