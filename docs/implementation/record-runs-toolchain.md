# Runs and tables of the records: the toolchain

This page is for a contributor who reads the decision record about the pinned toolchain
and the gates. It holds the runs and the long tables of record 0021, so that the record
stays short. The record links to this section.

## 0021. A pinned toolchain and the gates

These runs and tables support
[0021. A pinned toolchain and the gates](../adr/0021-pinned-toolchain-and-gates.md). A
test on this page is an ExUnit test, and a warning is a warning of the Elixir compiler.

### The problems before the decision

Each item gives the commit or the decision that records it.

1. **A toolchain out of support** (`9c1a7bd`, `PLAN.md` B4). Until September 2026 the
   repository named Erlang/OTP 26 and Elixir 1.15. OTP 26 left support on 2026-05-26,
   and Elixir 1.15 left the window of security fixes on 2026-06-03. The oldest pair that
   still had security fixes was Elixir 1.16 on OTP 27. The old `shell.nix` named
   `erlangR26`, which nixpkgs removed on 2024-05-24. In nixpkgs, `erlang_26` and
   `elixir_1_15` also give an error.
2. **2 answers to 1 question** (`37b64c9`). `9c1a7bd` gave Elixir 1.20 in `shell.nix`,
   but `mix.exs` kept `~> 1.15`. The repository named 2 versions of Elixir.
3. **A sandbox that cannot build the code** (decision 359). `CONTRIBUTING.md` and
   `CLAUDE.md` offered a sandbox of Elixir 1.14. The code calls `Map.split_with/2`, which
   Elixir 1.15 added. The early recorded outputs of runs that `PLAN.md` quotes came from
   that sandbox, on Erlang/OTP 25 and Elixir 1.14.
4. **Red commits on `main`** (`PLAN.md` B3). The suite fails at `ec0534a` and `35fe1b9`.
   No CI ran, so nothing showed it.
5. **A red run that names no test** (decision 337). In 7 full runs of the suite, 1 run
   failed 1 test. Its last line was `Result: 2406/2407 passed`. The output named no
   test. A red run of CI also printed only `Result: 2938/2939 passed` (decision 515).
6. **No version and no changelog** (decision 515). `mix.exs` said 0.1.0 across changes
   that alter what a running program writes to its
   [outputs](../../guides/reference/glossary.md#output). No changelog and no tag recorded
   them.

### A search of the output

A search of the output cannot judge a run. A run on 2026-11-23 in a scratch project had
41 tests, and 1 test failed. `mix test` exited with 2, and a search of its output for
`[0-9]+ passed` found this line:

<!-- unchecked: the line that a search for [0-9]+ passed found, in a run of 2026-11-23 in a scratch project -->
```text
Result: 40/41 passed
```

The line names no test, and the search reads it as a pass.

### The newest call of `lib/`

On 2026-11-23 a script read the calls of the compiled modules of `lib/`. The newest
function that `lib/` calls is `Process.set_label/1`, which Elixir 1.17 added. `lib/`
calls no function that Elixir 1.18, 1.19 or 1.20 added.

### A warning in a test file

From `ee91fe5` to `4a1079c`, 6 commits passed while the type checker gave 2 warnings in
`runtime_test.exs`. On 2026-11-23, a scratch project of 42 tests had a test file with an
unused variable. Each test passed. Plain `mix test` exited with 0. With
`--warnings-as-errors`, it exited with 1, and its last line was this:

<!-- unchecked: the last line of mix test --warnings-as-errors on a test file with an unused variable, a run of 2026-11-23 in a scratch project -->
```text
ERROR! Test suite aborted after successful execution due to warnings while using the --warnings-as-errors option
```

The message says that each test passed and that a warning makes the run red.

### The refusal of the changelog

On 2026-11-23, a copy of the repository had 1 more decision in section 7. The script
printed this line and exited with 1:

<!-- unchecked: the refusal of scripts/changelog.exs on a copy with decision 575 added to section 7, a run of 2026-11-23 -->
```text
changelog: decision 575 is recorded in §7 and named by no entry
```

### The patch releases

`.tool-versions` names OTP 28.5.0.6. CI resolved 28.5.0.7 on 2026-10-14 (`970dede`). The
machine that wrote the record ran 28.5.0.8.

### Each option not taken

| Alternative | Why logex does not use it |
|---|---|
| Keep the bound `~> 1.15` and recommend 1.20 (`9c1a7bd`) | The repository then named 2 versions. Elixir 1.15 and OTP 26 were out of their windows of security fixes |
| Bound at the oldest supported pair, Elixir 1.16 on OTP 27 | The code calls `Process.set_label/1`, which Elixir 1.17 added. That pair cannot build logex |
| A matrix of versions in CI | No contributor runs logex on an older toolchain, and decision 359 drops everything before Elixir 1.20 |
| Keep the sandbox of Elixir 1.14 (decision 359) | It cannot build the code, which calls `Map.split_with/2` |
| Loosen the bound on a machine with an older Elixir | No check runs that build. The edit goes into a commit by accident |
| Judge a run by its output | `Result: 40/41 passed` reads as a pass to a search for `[0-9]+ passed` |
| Plain `mix test` as gate 4 | It exits with 0 on a warning in a test file, and when a test stops the suite |
| Look for the cause of the 1 failed run in 7 (decision 337) | The runs after it passed. The manifest names the failure if it comes again |
| An `if:` or `continue-on-error:` on a step of CI | A skipped step, or a failed suite that CI shows green |
| Name each decision in the changelog at the release, all at 1 time (decision 542) | A release can then omit a decision. At each commit, the suite finds the omission |
| A first release, 0.2.0, with its tag pushed (decision 541) | The maintainer plans no release |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The toolchain and the gates](../contributing/toolchain.md): the steps.
