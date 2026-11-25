# Dialyzer and CI

This page is for a contributor. It gives the fifth gate, `scripts/dialyzer.sh`, and the 2
workflows of CI that run the gates on each push. Read it before you change a spec, a flag
of Dialyzer or a workflow. [The toolchain and the gates](toolchain.md) gives the pinned
versions, the install and the first 4 gates.

## What the part does

Dialyzer, the type checker of Erlang/OTP, compares the code of logex with its `@spec`
declarations. CI runs the 5 gates and the build of the site on GitHub Actions. A commit is
green only when its run of `ci.yml` is green.

## How it is built

### `scripts/dialyzer.sh`

`scripts/dialyzer.sh` runs `dialyzer`, the type checker of Erlang/OTP. It adds no
dependency. It compiles logex in the `dev` environment. Then Dialyzer compares each
module with its `@spec` declarations and with the PLT. The PLT holds `erts`, `kernel`,
`stdlib` and `elixir`. Its file is under `_build/dialyzer/`, and its name holds the
versions of the toolchain and the applications.

- The script uses the default warnings of Dialyzer and 6 more: `-Wextra_return`,
  `-Wmissing_return`, `-Wunderspecs`, `-Woverlapping_contract`, `-Wopaque_union` and
  `-Wunmatched_returns`.
- It prints `DIALYZER-OK`, or `DIALYZER-FAIL rc=<n>`. Code 2 means that Dialyzer found
  a warning. Code 1 is a run of Dialyzer that failed for another cause. Code 127 means
  that no `dialyzer` is on the path. If the compile fails, the script exits with the code
  of Mix.
- The first run builds the PLT and takes about 1 minute. A later run took 17 s to 27 s on
  a computer of 4 cores.

`scripts/gate.sh` runs it as its fifth step, after the suite passes (decision 549), and
`ci.yml` runs it as its last step. A red fifth step prints `GATE-FAIL rc=<n>`, then a line
that names the step and the log. With `-Wunmatched_returns`, Dialyzer refuses a call
whose answer the code drops. Write `_ = ...` where the code drops an answer on purpose,
and add its line to `test/logex/dropped_answers_test.exs` with the reason (decision 550).
Correct a warning in the code.
Do not hide it with an `@dialyzer` attribute, a wider `@spec` or `no_return()`.

### The 2 workflows

GitHub Actions runs 2 workflows on each push and each pull request. Each workflow uses
`ubuntu-latest`, Erlang/OTP 28 and Elixir 1.20.4.

`ci.yml`, the workflow "CI":

- Its steps are the 5 gates, 1 step each.
- It is red when a step exits with a code that is not 0.
- Its step of the suite does the same as `scripts/gate.sh`. It deletes the failures
  manifest, runs `mix test --warnings-as-errors` and then `elixir scripts/failed.exs
  --exit` with its code. Thus the log of a red run ends with each test that failed.
- No step of `ci.yml` has `if:` or `continue-on-error:`.
  `test/logex/scripts_test.exs` compares `ci.yml` with these rules and runs its step of
  the suite.

`docs.yml`, the workflow "Docs":

- Its steps are `scripts/docs.sh`, then the publish of the site.
- It is red when `scripts/docs.sh` fails. For example, the build gives a warning or a
  dead link that `docs/site-warnings.txt` does not list. Or `docs/site-warnings.txt`
  lists a warning that the build does not give.
- It publishes the site only on a push to `main`. It first asks GitHub for the source of
  Pages. If the source is not GitHub Actions, the run publishes nothing, shows a notice
  and stays green.

To publish the site from your fork, set Settings, Pages, Build and deployment, Source:
GitHub Actions. [Add and check a page](../check-a-page.md) gives `scripts/docs.sh`.

A push runs CI on its last commit only. Push each commit that you want CI to check, and
read its run. If the run of `ci.yml` is red, the commit is red. This is true also when
`scripts/gate.sh` was green on your computer.

## Why it is built this way

- **Exit codes, not output** (decisions 337 and 515 (e)). Elixir 1.20 prints
  `Result: 1/2 passed` for a run of 2 tests with 1 failure. The line names no test, and a
  search for `[0-9]+ passed` reads it as a pass. Thus `scripts/gate.sh` and `ci.yml` read
  the failures manifest and name each test that failed.
- **Dialyzer of Erlang/OTP** (decision 515 (c)). It checks the `@spec` of the
  [host contract](../../guides/reference/glossary.md#host-contract) and adds no
  dependency. Correct the code until Dialyzer gives no warning (decision 551). No mark
  hides a warning.
- **`if:` and `continue-on-error:` in `ci.yml`** (decision 515 (e)). An `if:` can skip a
  step. With `continue-on-error: true`, a step that fails is green.
- **ExDoc only in `docs`** (decisions 546 and 548). Mix needs Hex to read an entry of
  Hex, in each environment. Thus an entry with `only: :docs` makes each build need Hex.
  A function `deps/1` of `mix.exs` gives ExDoc to the `docs` environment only.

## How to change it

To change a flag of Dialyzer, change `scripts/dialyzer.sh` and the stand-in test of it in
`test/logex/scripts_test.exs`. Then run `scripts/dialyzer.sh`. It must print
`DIALYZER-OK`.

These tests fail on a wrong change:

| Change | Test that fails |
|---|---|
| `docs.yml` with versions that are not those of `ci.yml`, or not `28` and `1.20.4` | `docs_test.exs`: `its toolchain is the pair CI pins, set up as CI sets it up` |
| A step of `ci.yml` removed, or with `if:` or `continue-on-error:` | `scripts_test.exs`: `CI's workflow (decision 515 (e))` |

## See also

- [0022. Typespecs and Dialyzer](../adr/0022-typespecs-and-dialyzer.md).
- [The toolchain and the gates](toolchain.md): the pinned versions and `scripts/gate.sh`.
- [Add and check a page](../check-a-page.md): `scripts/docs.sh`, which `docs.yml` runs.
- [The words of the contributor pages](words.md): gate, CI, PLT and failures manifest.
