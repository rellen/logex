# CLAUDE.md

Logex is a Ladder Logic compiler/interpreter in Elixir (~> 1.15, Erlang R26). No external dependencies.

## Commands

- `mix compile` — compile. leex/yecc regenerate `src/*.erl` from `.xrl`/`.yrl` only when
  the `.erl` is absent or at least one whole second older. **After editing a `.xrl` or
  `.yrl`, run `rm -f src/*.erl && rm -rf _build` first**, or your edit is silently
  ignored: `mix compile` prints nothing and `mix test` stays green. To prove an edit is
  live, tokenize something only the new rule accepts — `PLAN.md` M0-3 has a worked
  before/after. `mix test` alone will not tell you.
- `mix test` — run tests (must pass before committing)
- `mix format` — format code before committing

## Key Files

- `lib/logex/compiler.ex` — all compiler stages: tokenize, parse, instructionize, evaluate
- `src/ladder_lexer.xrl` / `src/ladder_parser.yrl` — lexer and parser definitions. The
  generated `src/*.erl` are build artifacts, not tracked; never edit them.
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`
- `test/logex/end_to_end_test.exs` drives source to an environment and names no IR tag —
  the only test that can catch a mismatch between stages
- `README.md` — what logex is, the dialect stance, the instruction table and a worked
  example. **Any change to the language stales it:** a new instruction adds a row and may
  clear a "Settled, not yet landed" bullet; a syntax change touches the syntax list, the
  instruction table and the example (whose output is real — re-run it). Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic; append-only

## Conventions

- `evaluate/2` clauses take `(instruction, {power_flow_bool, env_map})` and return `{new_power_flow_bool, new_env_map}`
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
