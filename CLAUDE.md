# CLAUDE.md

Logex is a Ladder Logic compiler and interpreter in Elixir: ladder text compiled to plain
data, a `%Logex.Program{}`, which `Logex.Runtime` interprets one scan at a time; programs
run as instances, configurations as resources on tasks, `Logex.Runner` on a clock through
device adapters, with online edit, forcing and retained values. No dependencies, no
generated code.

This file is an index of what is there now. It holds no history and no rule a module's
own documentation holds:

- **The present rules** of each module are its moduledoc and function docs; a module
  marked `@moduledoc false` keeps them in the comment at its head.
- **The design and the reasons** are `docs/organisation.md`: §4 the design, §7 every
  numbered decision and fix (`decision 271`, `fix F11`), §8 the sources. Read it before
  designing anything that adds a data type (§4.12), retains a value (§4.13), names a
  program, schedules one, binds I/O, changes a running controller (§4.9) or runs one on
  the clock (§4.11).
- **The plan and the history** are `PLAN.md`; the review of the whole codebase, every
  finding with its repro, is `docs/review-2026-11-01.md`.
- **The names** are `docs/naming.md`, one stanza a word. Read `docs/instruction-sets.md`,
  the reference it cites, before writing a stanza: it carries the IEC feature numbers a
  stanza should cite.
- **How to work here**, each practice with what broke it, is `CONTRIBUTING.md`; what logex
  is and how to use it is `README.md`, whose examples the suite runs.

## Commands

- `mix compile` — compile.
- `mix test --warnings-as-errors` — run the suite; it must pass before a commit. Judge it
  by its exit code, never by grepping its output: Elixir 1.20 prints `Result: 39/40
  passed`, which a grep for `[0-9]+ passed` reads as a pass.
- `mix format` — format before a commit; CI runs `mix format --check-formatted`.
- `scripts/gate.sh [log]` — the four gates of `CONTRIBUTING.md`'s "Before you commit" in
  order, by exit code, printing `GATE-OK` or `GATE-FAIL rc=<n>` and the tests that failed;
  `elixir scripts/failed.exs` names the failures ExUnit's manifest holds, which keeps a
  test's failure until a run passes it, so after runs by hand it may name an earlier
  run's; the scripts delete the manifest before each run.
- `scripts/mutate.sh [-t file]... [-N] patch...` — a mutation table: each patch applied,
  the named files and the full suite run, the tree restored, a Markdown row a patch.
- `scripts/load.sh [-n runs] [-l loops] [mix test args]` — runs under busy loops on every
  core, for a new real-clock or runner test (`-n 50`) before it lands.
- `mix run test/fixtures/generate_frontend_golden.exs && git diff test/fixtures/` —
  regenerate the golden record, only in a commit that changes the language on purpose,
  and read the diff.
- The toolchain is Elixir 1.20.4 on Erlang/OTP 28, pinned in `mix.exs`, `.tool-versions`,
  `shell.nix`, `flake.nix` and CI: `nix develop`, or `asdf install` / `mise install` from
  `.tool-versions`. On anything older `mix` aborts before it runs. **Never relax
  `mix.exs`**: the bound is deliberate, the code needs it, and a loosened bound is the
  kind of edit that lands by accident.

## lib/

- `lib/logex.ex` — `Logex`, the public way in: `compile/2` (source and `name:`, `types:`
  the user blocks it may hold) and `compile_file/1`, a `.ld` file named after it, its
  blocks loaded from `<word>.ld` beside it, and `compile_files/1`, several files over one
  memo; a program, a block's type or every mistake as diagnostics.
- `lib/logex/lexer.ex` — `Logex.Lexer`, source text to tokens by binary pattern matching,
  each with `{line, column}`; names with `.` parts, bits and subscripts, signed, based and
  real literals with their spellings, and every lex error located.
- `lib/logex/parser.ex` — `Logex.Parser`, tokens to the parse AST by recursive descent
  (its moduledoc gives the grammar); `well_formed!/1` defines a well-formed tree, and the
  literal guards and readers (`is_int_lit/1`, `is_literal/1`, `value/1`, `spelling/1`).
- `lib/logex/printer.ex` — `Logex.Printer`, the parse AST back to canonical text, one rung
  a line, each literal as written.
- `lib/logex/compiler.ex` — `Logex.Compiler`, the stages: `instructionize/3` checks a tree,
  takes the declarations into a tag table, checks every instruction against
  `instructions/0`'s signatures and every operand against the table, lowers to the IR and
  gives a program, a block type or diagnostics; `signature/2` for the walks; `lowered?/1`
  and `recompiled/4` for a type given.
- `lib/logex/declarations.ex` — `Logex.Declarations`, declaration lines to tags: sections,
  qualifiers, the one table of elementary types (`table/0`) with Figure 11's widenings,
  IEC's generic classes, arrays' sizes and initial lists, `check/1` for a line and for
  `Logex.Tag.new!/5`, reserved words and the type messages.
- `lib/logex/tag.ex` — `Logex.Tag`, a declared tag (name, section, type, initial value,
  qualifier, line), and `new!/4,5` to declare one from Elixir.
- `lib/logex/fb_type.ex` — `Logex.FbType` and `Logex.FbType.Member`, a function block
  type's schema: the built-in timers and counters, `rules/1` each built-in's behaviour as
  data, user blocks built from their bodies, `user?/1` and `check/2` for a type given, and
  an instance's first state.
- `lib/logex/fb_type/builtins.ex` — `Logex.FbType.Builtins`, internal: the built-in types'
  table, built once as logex compiles.
- `lib/logex/program.ex` — `Logex.Program`, a compiled program type: rungs, tags, the one
  table of the blocks it holds, warnings, and the routine facts settled once (`units`,
  `reals`, `arrays`, `retained`); `initial_env/1`, `typed_tags/1`, `destination/2,3` and
  `edited_by_hand/1`, the check of a program edited after it compiled.
- `lib/logex/walk.ex` — `Logex.Walk`, the one walk of a program's IR: instructions, uses,
  writes, member, bit and element writes, presets, timers, counters and one-shots, at any
  depth of `cal`.
- `lib/logex/warnings.ex` — `Logex.Warnings`, the warnings a compiled program carries.
- `lib/logex/diagnostic.ex` — `Logex.Diagnostic`, the one error and warning type of every
  stage, and `format/1`.
- `lib/logex/array.ex` — `Logex.Array`, internal: an array's type, shape, values, element
  names and a host's list form, the one place they are read and made.
- `lib/logex/real.ex` — `Logex.Real`, internal: the one place a real's value is made,
  read, rounded and spelled.
- `lib/logex/name.ex` — `Logex.Name`, internal: the one reading of a lexed name's parts,
  an element's word and subscripts (`element/1`), a subscript (`subscript/1`), a bit number
  in brackets (`bracketed/1`), a type word's base (`base/1`) and a host key's word
  (`word/1`), each total on a text.
- `lib/logex/source_file.ex` — `Logex.SourceFile`, internal: how both loaders read a
  source file, a FIFO or a device refused before it is read, and tell what is beside one,
  a link to nothing or one that loops among it.
- `lib/logex/runtime.ex` — `Logex.Runtime`, the core: a program run as an instance
  (`instance/1,2`, `call/4`, `put_inputs/3`, `scan/2,3`, `restart/3`, `retained/2`) and a
  configuration as an opaque resource (`start/1,2`, `cycle/3`, `next_due_in/1`,
  `overlaps/1`, `get/2`, `get!/2`, `restart/2`, `retained/1`); the evaluator, private; the
  host contract; reads no clock.
- `lib/logex/instance.ex` — `Logex.Instance`, a program instance's state: its program's
  `type`, `env`, `now`, `first`, `ons_blocked`, `switched` and `faults`.
- `lib/logex/scan.ex` — `Logex.Scan`, the read-only facts one routine run reads: `now`,
  `first`, `ons_blocked`, `tags`, `blocks`, `units`, `reals`.
- `lib/logex/fault.ex` — `Logex.Fault`, a minor or major fault a scan met and ran on
  through, plain data.
- `lib/logex/image.ex` — `Logex.Image`, internal: the retained image, taken out of an
  instance or a resource, checked, and laid over a new one by name and type.
- `lib/logex/retain.ex` — `Logex.Retain`, internal: the store's text, encoded and decoded,
  and the atomic write it shares with the forces file.
- `lib/logex/configuration.ex` — `Logex.Configuration` with `Task`, `Global`, `Instance`
  and `Connection`: a configuration as data, `check/1`, the one validator, `new!/1`,
  `compile/3` and `compile_file/1` from text, and its warnings.
- `lib/logex/configuration/text.ex` — `Logex.Configuration.Text`, a configuration file's
  text: its words, `read/1` to entries, `print/1` back, an exact round trip.
- `lib/logex/edit.ex` — `Logex.Edit`, a staged online edit of a lone instance: `accept/3`,
  `test/2`, `untest/2`, `assemble/2`, `cancel/2`, each a report; its moduledoc gives every
  rule and report kind.
- `lib/logex/edit/plan.ex` — `Logex.Edit.Plan`, internal: the type-change refusals, the
  plans, the edit's record, the switch and the prune, per instance, for both edits.
- `lib/logex/configuration/edit.ex` — `Logex.Configuration.Edit`, a staged edit of a
  running resource, the same steps over a `%Logex.Runtime{}`.
- `lib/logex/io.ex` — `Logex.IO`, the adapter behaviour, `points/1` and `bind!/2`.
- `lib/logex/io/point.ex` — `Logex.IO.Point`, a device's point as an adapter is given it.
- `lib/logex/io/sim.ex` — `Logex.IO.Sim`, the simulated device every runner test drives.
- `lib/logex/runner.ex` — `Logex.Runner`, the wall-clock runner, a GenServer: rounds,
  devices, watchdogs and the trip, forcing, an edit's steps, the store and its period.
- `lib/logex/runner/device.ex` — `Logex.Runner.Device`, internal: one bound device's
  process, its reads, writes again at every poll, latch and close.
- `lib/logex/runner/paths.ex` — `Logex.Runner.Paths`, internal: the store and forces files
  each runner of the VM holds, claimed at its start and given up as it ends.
- `lib/logex/runner/writer.ex` — `Logex.Runner.Writer`, internal: the process that writes
  the store every period, and every other file call of the runner's, each in a process of
  its own limited to the idle watchdog and a poll period of real time.
- `lib/logex/runner/clock.ex` — `Logex.Runner.Clock`, the clock behaviour the runner reads
  time through.
- `lib/logex/runner/clock/monotonic.ex` — `Logex.Runner.Clock.Monotonic`, the machine's
  clock.
- `lib/logex/runner/clock/manual.ex` — `Logex.Runner.Clock.Manual`, a clock a test moves.

## test/

Each file holds the rules of its part, a host mistake's message pinned whole; a walk
asserts its reach, and a growth test compares reductions at two sizes, never time.

- `test/test_helper.exs` — starts ExUnit.
- `test/logex_test.exs` — `Logex`'s API and loader, and Milestones 1 to 3's done
  sentences from files on disk.
- `test/logex/lex_and_parse_test.exs` — the lexer and parser from source strings.
- `test/logex/frontend_test.exs` — the front end's columns, newlines and messages.
- `test/logex/frontend_golden_test.exs` — `tokenize/1` and `parse/1` held to the recorded
  AST or error line of every source in `test/fixtures/frontend_golden.txt`.
- `test/fixtures/frontend_golden.txt` and `test/fixtures/generate_frontend_golden.exs` —
  the golden record and its generator, run by hand.
- `test/logex/lexer_binaries_test.exs` — the lexer cuts each name and number as a heap
  binary.
- `test/logex/printer_test.exs` — the printer's round-trip properties over every
  production (`@required_shapes`), each loss pinned.
- `test/logex/instructionize_test.exs` — the compiler's stage on hand-typed input.
- `test/logex/validation_test.exs` — every diagnostic and warning `instructionize/2`
  gives, from source.
- `test/logex/compile_total_test.exs` — every source text compiles or is told why: the
  name readers, a number's bounds, a rung that writes nothing, the compile's cost against
  recorded figures, and a seeded mutation walk that nothing escapes.
- `test/logex/review_lows_test.exs` — the compiler's, the warnings', the walk's and the
  loader's lesser fixes, each by its reviewer's label.
- `test/logex/diagnostic_test.exs` — what each stage stamps on a diagnostic, and
  `format/1`.
- `test/logex/naming_test.exs` — every mnemonic and keyword has its `docs/naming.md`
  stanza; the keyword list pinned whole.
- `test/logex/evaluation_test.exs` — the evaluator on hand-typed IR, through `call/4`.
- `test/logex/end_to_end_test.exs` — source to an environment through the public API:
  each item's Done-when and Milestones 5 and 6's done sentences, from text and files on
  disk, against oracles that know nothing of logex; its assertions name no IR tag.
- `test/logex/runtime_test.exs` — every message the runtime raises, the exact public
  surface and the checks made where a program is first handed in.
- `test/logex/walk_test.exs` — each fact of `Logex.Walk`, at depth, with its growth.
- `test/logex/counter_test.exs` — the counters `ctu`, `ctd` and `ctud`.
- `test/logex/typed_counter_test.exs` — the typed counters at every width.
- `test/logex/timer_test.exs` — `tof`, `tp` and `rto`.
- `test/logex/long_timer_test.exs` — the long timers in nanoseconds.
- `test/logex/arithmetic_test.exs` — the arithmetic and comparisons at every width.
- `test/logex/integer_width_test.exs` — the integer widths, `move` by Figure 11 and the 56
  integer conversions.
- `test/logex/type_table_test.exs` — the one table of elementary types and every message
  built from it.
- `test/logex/bit_string_test.exs` — the bit strings, bitwise instructions, bit access and
  the 76 bit-string conversions.
- `test/logex/tag_bit_test.exs` — a bit whose number a tag holds.
- `test/logex/element_bit_test.exs` — bits of array elements.
- `test/logex/real_test.exs` — `real` and `lreal`: literals, arithmetic, conversions,
  `sqrt` and their host contract.
- `test/logex/array_test.exs` — arrays of elementary types in a program.
- `test/logex/tag_subscript_test.exs` — subscripts held in tags and the index fault.
- `test/logex/instance_array_test.exs` — arrays of timers, counters and blocks.
- `test/logex/located_array_test.exs` — located arrays at I/O points.
- `test/logex/array_configuration_test.exs` — arrays in a configuration.
- `test/logex/pulse_coil_test.exs` — `osr` and `osf`.
- `test/logex/jump_test.exs` — `jmp` and `lbl`, and what a skipped rung keeps.
- `test/logex/fault_test.exs` — the faults a scan meets, alone and as a cycle's events.
- `test/logex/function_block_test.exs` — user function blocks and their loader.
- `test/logex/edit_test.exs` — every message, diagnostic and rule of `Logex.Edit`, its
  growth, and the labels this work cites (only `docs/organisation.md` §7's).
- `test/logex/configuration_test.exs` — every diagnostic, warning and host mistake of
  `Logex.Configuration`, the loader and the file's round trip.
- `test/logex/configuration_text_test.exs` — every line a configuration file's reader
  refuses.
- `test/logex/scheduler_test.exs` — the rules of a cycle.
- `test/logex/config_edit_test.exs` — every rule of `Logex.Configuration.Edit` on §4.4's
  plant.
- `test/logex/retain_test.exs` — the qualifiers, `Program.retained` and the warm restart.
- `test/logex/retain_configuration_test.exs` — retained globals.
- `test/logex/retain_image_test.exs` — the retained image and its matching.
- `test/logex/retain_store_test.exs` — the store on the manual clock at every end and
  start.
- `test/logex/retain_period_test.exs` — the store's periodic writer.
- `test/logex/retain_edit_test.exs` — an online edit of a qualifier.
- `test/logex/stalled_disk_test.exs` — every file write the runner makes on a stalled
  disk, the file server held, and each write's `.tmp` its own.
- `test/logex/clock_test.exs` — the two clocks.
- `test/logex/io_test.exs` — `Logex.IO.Sim`, `Logex.IO.points/1` and `bind!/2`.
- `test/logex/runner_test.exs` — the runner on the manual clock.
- `test/logex/trip_test.exs` — the watchdogs, the trip and `restart/2`.
- `test/logex/force_test.exs` — forcing and the forces file.
- `test/logex/runner_paths_test.exs` — the files a runner holds: two runners of one VM on
  one file refused, each path resolved once, and a refused start writing nothing.
- `test/logex/runner_edit_test.exs` — an online edit stepped through the runner.
- `test/logex/api_contract_test.exs` — the seeded contract walks over the host contract,
  the edits, the resource, the runner, the cross-type reach, the store's life and a
  configuration edit's holds, each against oracles restated from the programs' text, each
  asserting its reach.
- `test/logex/clauses_test.exs` — the clauses rule (Conventions) read from the syntax
  trees of the walks, the end-to-end tests and the README harness.
- `test/logex/readme_test.exs` — every example in `README.md`, each `elixir` block a
  `$ mix run` follows, run in a fresh VM and its output compared with README's, and every
  other `elixir` block a fragment it names and parses, and runs in a setup it makes where
  it gives one, held to README's prose (`CONTRIBUTING.md`, "Landing work stales the
  plan").
- `test/logex/scripts_test.exs` — `scripts/failed.exs` over the manifests ExUnit writes.
- `test/logex/claude_md_test.exs` — this file: under its size cap, naming every `lib/` and
  test file, holding no history.

## Conventions

- **A mistake in the source is a `%Logex.Diagnostic{}`, returned; a mistake by the host is
  an `ArgumentError`, raised, its message pinned by a test.** Nothing else escapes the
  public API (`api_contract_test.exs`).
- **Verify by executing, not by reasoning** (`CONTRIBUTING.md`). A fix needs a test that
  fails when the fix is reverted: check it by reverting, and for new code revert each
  rule the diff adds (`scripts/mutate.sh`). Never skip, disable or weaken a test to get to
  green.
- **Clauses, not conditionals.** Use pattern matching with multiple function clauses, not
  `case`, `cond`, `if` or `unless`, in `lib/` and in every walk's and end-to-end test's
  oracle and harness, README's included; only a draw a walk's module names in `@draws`
  may hold one, never a `setup`, a macro or an attribute's function, nor one written
  `Kernel.if` (`clauses_test.exs`, decision 264).
- **Nothing compiles a user's program to BEAM.** Every front end ends in
  `%Logex.Program{}` data that `Logex.Runtime` interprets, and none puts the Elixir
  compiler on the path that changes a running program (`PLAN.md` §6, `docs/organisation.md`
  §4.9).
- **The evaluator.** `evaluate/3`, private in `Logex.Runtime`, takes `(instruction,
  {power, env}, %Logex.Scan{})` and gives `{power, env}`. The scan is read-only and one for
  a routine's run; a clause that needs none of it takes `_scan`, and the clauses for
  `units: nil` and `reals: nil` come first, so a routine of neither pays no look-up. A
  record a scan keeps in a routine's env lives under an atom key, `:faults`, `:jump` or
  `:ran`, which no tag can be, and is taken out when the routine is done; a new key joins
  `Logex.Runtime`'s `@own_keys`, which a `cal`'s drop, the refusal of a host's env and its
  message read. No test calls the evaluator: a test runs a program through
  `Logex.Runtime.call/4`, on a hand-built `%Logex.Instance{}` where it needs an env.
- **The trees.** An operand in the AST is `{:name, line, tag}`, `{:int_lit, line, value}`
  or `{:real_lit, line, value}`, with the spelling as a fourth element where it is not the
  value's plain text; read a literal through `Logex.Parser`'s guards and `value/1`, and
  quote it through `spelling/1`. Destructure the line as `_`, never drop it: diagnostics
  cite it. `Logex.Parser.well_formed!/1` states every tree `parse/1` can give, and
  `instructionize/3` refuses any other, so a test that builds a tree by hand builds one of
  those. Tokens carry `{line, column}`, the AST the line alone. An IR instruction is
  `{symbol, line, operands}`; a `{:branches, legs}` node has no line. In the IR a member
  is `{:member, line, path}`, and a walk over IR operands handles it, a label
  `{:label, line, name}`, a bit, an element and an element's member as the compiler lowers
  them. A walk reads an instruction's slots through `Logex.Compiler.signature/2`, never a
  table of its own: a `cal`'s slots are its block's.
- **A new instruction, step 1: survey the name before any code.** Add a ``### `mnemonic` ``
  stanza to `docs/naming.md`: the IEC 61131-3 element, function or function block with
  clause and table, the major vendors, the logex name and why, and `Checked:` with
  sources. The rule, in order: (1) where IEC names the operation, its name lowercased;
  (2) where IEC has only a graphical element, the clearest vendor mnemonic, saying which;
  (3) never a new readable word for what has a standard name. Mark what you could not
  verify `unverified`; never guess. `naming_test.exs` fails on a mnemonic unsurveyed.
- **A new instruction, step 2.** Add its mnemonic and operand signature to `@instructions`
  in `compiler.ex`, one `{access, type}` an operand (access `:read`, `:write`, `:value`,
  `:instance` with its kind or kinds, `:preset` or `:label`; type an elementary type, a
  generic class of `Logex.Declarations.is_class/1` or `:any`; `cal`'s entry is
  `{:cal, :block}`), **and** two `evaluate/3` clauses, one for `{true, env}` and one for
  `{false, env}`: without the de-energised clause the instruction raises
  `FunctionClauseError` the moment a contact opens. A built-in type it runs is a row of
  `Logex.FbType.rules/1`. The mnemonic is reserved in any case, so it breaks a program with
  a tag of that name: say so in the commit. Where the power it passes on is not settled,
  the compiler refuses anything after it on its path, as after `ton`.
- **Every tag is declared,** in the source, `var aa bool` before the first rung, or from
  Elixir with `Logex.Tag.new!/4,5` (`validation_test.exs`'s `@declared`). A new section,
  qualifier or elementary type word is a row of `Logex.Declarations` and a built-in block
  type a key of `Logex.FbType.builtins/0`, each reserved in any case in a program and in
  a block's file, as a mnemonic is; a word that heads a file of another kind is an entry of
  `Logex.Declarations.kinds/0`, reserved in any case in that kind of file only, so that
  `var function_block bool` compiles in a program and not in a block's file; and a
  configuration file's word is a row of `Logex.Configuration.Text`'s, which reserves it in
  any case in a configuration file only, where it names no task, global, instance, program
  type or device, so that `var task bool` compiles in a program. Each owes a `docs/naming.md`
  stanza, which `naming_test.exs` checks against its pinned list. A user block's name is
  no row, owes no stanza and is not reserved.
- **New state states its rule across an online edit.** A tag or member starts by
  `Logex.Program.initial_env/1`, whose doc and §4.9's "One rule for new state" list the
  edit's exceptions; a global's by `Logex.Configuration.initial/1`. A field of
  `%Logex.Instance{}` gets a check in the runtime with a pinned message, a value from
  `instance/1` and a rule for a scan, `restart/3` and a switch; a piece of the opaque
  `%Logex.Runtime{}` a value from `start/1` and a rule for a cycle, `restart/2` and a
  configuration edit's switch, in `Logex.Runtime`'s one-rule section. A new report kind is
  a row of its edit's table and §4.9's, and of `api_contract_test.exs`'s `@report_kinds`
  (and `@configuration_kinds` where only a configuration's edit gives it).
- **A new syntax form** goes into `printer_test.exs`'s generator and `@required_shapes`
  before it lands, and the golden record stays green; nothing checks the grammar for
  ambiguity but those.
- **The README is checked.** A language change stales its syntax list, instruction table
  and examples; each example's output is compared by `readme_test.exs`, a file an example
  reads is marked `<!-- file: path -->` above its block, and an `elixir` block shown with
  no output is a fragment the test names (`CONTRIBUTING.md`). Its prose has no test: its
  "What logex is not" says plainly what logex does not do, a safety function first, each
  claim checked against the code, so a change that adds what it says logex lacks, an
  adapter, output forcing, a backward jump or a type among them, stales it.
- **Cite decisions and fixes by `docs/organisation.md` §7's numbers alone**, never a label
  only a design pass's notes define (`edit_test.exs`, "the labels this work cites").
- **Keep this file an index.** A module's rules go in its moduledoc, the reasons in
  `docs/organisation.md`, the history in `PLAN.md`; a new module or test file gets one
  line here. `claude_md_test.exs` holds it under its cap.
