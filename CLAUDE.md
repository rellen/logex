# CLAUDE.md

Logex is a Ladder Logic compiler/interpreter in Elixir (~> 1.15, Erlang R26). No external dependencies.

## Commands

- `mix compile` — compile (regenerates `.erl` from `.xrl`/`.yrl`)
- `mix test` — run tests (must pass before committing)
- `mix format` — format code before committing

## Key Files

- `lib/logex/compiler.ex` — all compiler stages: tokenize, parse, instructionize, evaluate
- `src/ladder_lexer.xrl` / `src/ladder_parser.yrl` — lexer and parser definitions (edit these, not the generated `.erl` files)
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`

## Conventions

- `evaluate/2` clauses take `(instruction, {power_flow_bool, env_map})` and return `{new_power_flow_bool, new_env_map}`
- New instructions: add to `@instructions` map in `compiler.ex` + matching `evaluate/2` clauses
- Use pattern matching with multiple function clauses, not conditionals
