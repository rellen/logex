# Runs and tables of the records: the practice

This page is for a contributor who reads a decision record about the practices of the code and of the suite. It holds the
runs, the measurements and the long tables of record 0009, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0009. Clauses, not conditionals

These tables and runs support
[0009. Clauses, not conditionals](../adr/0009-clauses-not-conditionals.md).

### The steps of the rule

The rule covered more code in 5 steps after the first `CLAUDE.md`:

| Date | Commit | Change |
|---|---|---|
| 2026-02-28 | `9ff6b5d` | The first `CLAUDE.md` gives the rule |
| 2026-10-25 | `a9ae919` | 7 `case` expressions of `lib/` become clauses. A search of lines holds `lib/` to the 4 older ones |
| 2026-10-26 | `c5c8fff`, `6453938` | Decision 264 puts the oracles of the walks and of the end-to-end tests under the rule. `clauses_test.exs` checks them |
| 2026-11-01 | `c994b75`, `1ab6d89` | The harness of the examples, and the code outside each module |
| 2026-11-12 | `21ad039`, `1d0ec85` | `lib/` read as syntax trees, and each script under `examples/` |
| 2026-11-15 | `edc27ae` | `scripts/page.exs`, and each Elixir script under `scripts/` |

### The count of conditionals

On `main` at `263fc95`, `clauses_test.exs` counted these conditionals:

| Code | Count |
|---|---|
| `lib/` | 3, the `case` expressions of `parser.ex` |
| The walks, `api_contract_test.exs` | 137, all in draws |
| `end_to_end_test.exs`, `readme_test.exs`, `scripts/page.exs` and the scripts under `examples/` | 0 |
| Each other Elixir script, `scripts/*.exs` | 22 `case` in 5 scripts |
| The 21 files under `test/` that the check does not read | 82 |

### The forms that the check counts

The check counts only the 4 words. Runs of `clauses_test.exs` on a copy of the
repository, with 1 form added to `lib/logex/real.ex` each time, gave these results:

| Form added | Result |
|---|---|
| `def probe(x), do: if(x, do: 1, else: 0)` | Fails |
| `def probe(x), do: Kernel.if(x, do: 1)` | Fails |
| `@doc "if x, do: y; case z"` on a function | Passes: the words are in a string |
| `def probe(x), do: (with {:ok, y} <- x, do: y)` | Passes |
| An anonymous function with 2 clauses | Passes |
| `def probe(x), do: x && 1 \|\| 0` | Passes |
| A `receive` with 1 clause and `after 0` | Passes |

### What a failure names

The failure names the file or the module. Only the check of the scripts names the form
and the line. Runs on a copy gave these failures:

| Where the conditional is | What the failure names |
|---|---|
| `lib/` | The file and the word, `{"lib/logex/real.ex", :if}` |
| A walk | The module, `Logex.ApiContractTest: a conditional outside the draws` |
| `end_to_end_test.exs`, `readme_test.exs` or `page.exs` | The module, such as `Logex.EndToEndTest` |
| A script under `examples/` | The file and the form, `examples/fan.exs: "the file's top level"` |
| A script under `scripts/` | The file, module, function, line and word, `{"draw.exs", Draw, :probe, 29, :if}` |

### A clause that is not there

A missing clause does not give a wrong value. It stops the
[scan](../../guides/reference/glossary.md#scan). A run on a copy of the repository
removed this clause of `Logex.Runtime`:

<!-- fragment: the clause that the run removed, from lib/logex/runtime.ex -->
```elixir
defp evaluate({:xic, _, _}, {false, env}, _scan) do
  {false, env}
end
```

The program of the run has 1 rung, `xio stop xic start ote motor`. The run gives 1 new
[instance](../../guides/reference/glossary.md#instance) 2 scans. In scan 1, `stop`
is 0, and `motor` becomes 1. In scan 2, `stop` is 1, so the
[contact](../../guides/reference/glossary.md#contact) `xio stop` opens and the
[power flow](../../guides/reference/glossary.md#power-flow) to `xic start` is false. The
first line that the run prints gives the inputs and the
[outputs](../../guides/reference/glossary.md#output) of scan 1:

<!-- unchecked: the output of a run on a copy with 1 clause of evaluate/3 removed, 2026-11-23 -->
```text
%{"start" => 1, "stop" => 0}  %{"motor" => 1}
** (FunctionClauseError) no function clause matching in Logex.Runtime.evaluate/3

    The following arguments were given to Logex.Runtime.evaluate/3:

        # 1
        {:xic, 5, [{:name, 5, "start"}]}

        # 2
        {false, %{"motor" => 1, "start" => 1, "stop" => 1}}
```

The Elixir compiler printed nothing about the missing clause. Thus a new instruction needs
its `{false, env}` clause together with its `{true, env}` clause.
[Add an instruction](../implementation/adding-an-instruction.md) gives that step.

`scripts/mutate.sh` took the same clause as 1 patch of 4 deleted lines, on a copy, on
2026-11-23. With `end_to_end_test.exs` named, the named file failed 6 of 137 tests, and
the full suite failed 34 of 3,836 tests in 13 files. With only `evaluation_test.exs` and
`jump_test.exs` named, those 39 tests passed.

The 2 test files of the evaluator do not find the missing clause. Only the full suite
finds it. For this reason, `scripts/mutate.sh` judges a mutant by the full suite
([0020. Verify by a run](../adr/0020-verify-by-executing.md)).

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
