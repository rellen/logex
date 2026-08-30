# CLAUDE.md

Logex is a Ladder Logic compiler/interpreter in Elixir (~> 1.15, Erlang R26). No external dependencies.

## Commands

- `mix compile` — compile. leex/yecc regenerate `src/*.erl` from `.xrl`/`.yrl` only when
  the `.erl` is absent or at least one whole second older. **After editing a `.xrl` or
  `.yrl`, run `rm -f src/*.erl && rm -rf _build` first**, or your edit is silently
  ignored: `mix compile` prints nothing and `mix test` stays green.
- `mix test` — run tests (must pass before committing)
- `mix format` — format code before committing

## Key Files

- `lib/logex/compiler.ex` — all compiler stages: tokenize, parse, instructionize, evaluate
- `src/ladder_lexer.xrl` / `src/ladder_parser.yrl` — lexer and parser definitions. The
  generated `src/*.erl` are build artifacts, not tracked; never edit them.
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`
- `test/logex/end_to_end_test.exs` drives source to an environment and names no IR tag —
  the only test that can catch a mismatch between stages
- `PLAN.md` — reviewed findings and the ordered plan of work

## Conventions

- `evaluate/2` clauses take `(instruction, {power_flow_bool, env_map})` and return `{new_power_flow_bool, new_env_map}`
- New instructions: add to the `@instructions` map in `compiler.ex` **and** two
  `evaluate/2` clauses — one for `{true, env}` and one for `{false, env}`. The
  de-energised clause is mandatory: without it the instruction works on an energised
  rung and raises `FunctionClauseError` the moment a contact opens.
- Use pattern matching with multiple function clauses, not conditionals
