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
  `%Logex.Diagnostic{}`; a lex or parse error becomes one diagnostic with its column.
  Since M2-5 `compile/2` takes `types:` too, the function blocks a source may declare
  instances of (decision 34), and a source whose first rung is `function_block <name>`,
  the name matching the one compiled under, gives `{:ok, %Logex.FbType{}}`;
  `compile_file/1` sets a program's `file`, and a block body's (fix F15), and loads each
  block a file names from `<word>.ld` beside it, once a call, stopping at a broken one,
  a chain of files that holds itself, or a program's file named as a type, and hands back
  each loaded block's warnings after the program's, each with its block's file, while
  `compile/2` gives only the program's (decision 34). Since M2-2 `compile_file/1` takes a
  `.ld` path only, exactly, any other a `:file` diagnostic before anything is read, and
  `compile_files/1` is that loader over several paths with one memo, each path compiled as
  `compile_file/1` compiles it, so a block several of them hold is compiled once and its warnings
  handed back once, by the first program among them that holds it and compiles, a block's
  own file handing back nothing, and a chain of files that holds itself cited from each
  path as that path's `compile_file/1` cites it; `Logex.Configuration.compile_file/1`
  loads a configuration's program types through it, one call a configuration
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
  in its moduledoc. Since M2-4 a scan merges each `var_external`'s global into its
  instance's state before `call/4` and splits it off after, back into the global, before
  the copy-out (decision 47), so the resource holds one copy of each global and no
  instance's state holds a var_external between cycles (decision 49, which a test pins
  by looking inside); `get/2` reads `m1.estop` as the global, and a program run alone
  keeps a var_external as its own tag at 0. Since M2-6 a cycle samples each task's
  `single`, its trigger, once, after the input image and before any scan: a rising edge
  makes an event task due at the cycle's `now`, a trigger already 1 in the first cycle
  among them; a task with an interval too runs at most once a cycle, its due times under
  a high trigger skipped and not counted (decisions 39, 51 and 52); the trigger's last
  sample is resource state, 0 from `start/1` and `restart/2`, in the one-rule section;
  and `next_due_in/1` counts periodic due times only (decision 50). Since OE-2 the
  resource also holds `generation`, the count of a configuration edit's steps, 0 from
  `start/1` and kept by a cycle and `restart/2`, and `aside`, the instances an edit's
  switch set aside, never scanned and dropped by `restart/2` (decisions 60, 64 and 65),
  each in the one-rule section; and `edited/2`, internal (no doc), is the one writer of an
  edit's step into the resource, deriving the wiring again and moving the generation, so
  that the opaque struct's fields are written in this module alone.
  `lib/logex/instance.ex` and `lib/logex/scan.ex` hold its two structs, each with
  `ons_blocked` since OE-1: the storage bits whose `ons` the next scan blocks, the hook an
  online edit's switch uses to keep a new or changed one-shot from firing, a bit inside a
  function block's instance named by its path and kept until a scan runs its body
  (decision 32). The instance also has `switched`, which an edit's switch sets and a scan
  clears, and the scan `tags` (M2-5), the tag table of the routine it runs, which `cal`
  narrows to its block's. Every entry point that takes a program refuses a function block
  type with one message, `Logex.Declarations.not_a_program/1`'s.
- `lib/logex/configuration.ex` — `%Logex.Configuration{}` (M2-1, `docs/organisation.md`
  §4.4 and §4.10): the program types, tasks, globals (located at `<device>.i|q.<address>`
  or not), program instances and connections, as plain data and lists in declaration
  order, under a name it must have, and `warnings` (since M2-2, a global nothing uses and
  an output point read and not driven; since M2-3, a task that runs no instance), which
  stop nothing; `check/1`, the one validator, giving a mistake a configuration's text
  could make as a `:configure` diagnostic at its element's line in the configuration's
  file, in the configuration file's words whether
  the element came from text or from Elixir (M2-2: its keywords name nothing, a dotted
  name is told its reading, a refused name's uses are silent, decision 42, and an
  instance's unconnected var_inputs are one diagnostic), and raising one `ArgumentError`
  for the host's mistakes no text can make, a line each (decision 36:
  a bad name, file or programs, a part that is not a proper list of its struct, a struct
  that lacks one of its keys, a bad line, lines neither all nil nor rising, a name no
  lexer reads as one token, a negative number); `new!/1`, from Elixir, raising one
  `ArgumentError` with every problem, an element that brings a line among them;
  `compile/3` (M2-2), a configuration file's text against program types given as data,
  through `Logex.Configuration.Text.read/1` and `check/1`'s rules, what a broken line
  names declared by it; `compile_file/1` (M2-2), the configuration file on disk
  (`.logex`, decision 35), named after it, each program type a `program` line names
  loaded from `<type>.ld` beside it through `Logex.compile_files/1`, one memo for the
  configuration, and a type that is missing, a block's file (the one block-type message)
  or a file that does not compile cited once at its first instance's line, the last
  naming the files its mistakes are cited in, which follow once each, every
  diagnostic naming its file; `location/1`; and `initial/1`, the one rule for a new
  global's value, as `Logex.Program.initial_env/1` is a tag's. Since M2-4 `check/1` binds
  each `var_external` of a program type an instance runs to the global of its name and
  type, once a type at its first instance's line, naming the type's own file and line,
  refuses a write through one to an input point, from `Logex.Walk.writes/1`, and a
  connection that names one, and gives the two writer warnings on `warnings` (decision
  48); a var_external uses its global and a write through one drives it, for M2-2's
  warnings. Since M2-6 `check/1` takes a task with an interval, a `single` or both, its
  single a bool global, read where a global is wanted as a connection's is, a name with
  `.` parts told its reading, its did-you-mean among the bool globals, a single counting
  as a use; and `warnings` names each timer, a block's by its path, of each instance an
  event task runs, from `Logex.Walk.timers/1`, once a type, citing its `ton`'s own file
  and line.
  `lib/logex/configuration/text.ex` is a configuration file's text (M2-2, its task lines
  and `with` since M2-3, `single` on a task line since M2-6): its words as data, `keywords/0`, which `naming_test.exs`
  reads; `read/1`, a recursive descent over
  `Logex.Lexer`'s tokens, not `Logex.Parser`'s, giving the elements of a configuration in
  line order, each with its line, or a `:configure` diagnostic with its column for each
  line it cannot read, a placeholder for what a broken line names among the entries;
  `entries!/1`, what a line can say; and `print/1`, of a configuration or its entries,
  whose text reads back to the very entries it printed, and through `compile/3` to the
  very configuration, each element on its line: the exact round trip. It checks no word's
  meaning, which is `check/1`'s
- `lib/logex/edit.ex` — a staged edit of one program instance (OE-1, `docs/organisation.md`
  §4.9): `accept/3` (refusing a type change as `:edit` diagnostics, in the candidate's
  `file` (fix F15), with a forecast),
  `test/2`, `untest/2`, `assemble/2`, `cancel/2`, `running/1` and `stage/1`, each step
  returning a report. Accept builds a plan per direction from the two programs; a switch
  and a prune are per-instance functions of a plan, the edit's record and the state.
  Since OE-2 the type-change refusals, the plans, the record, the switch and the prune
  are `lib/logex/edit/plan.ex`'s, `Logex.Edit.Plan`, internal (no moduledoc), which
  `Logex.Edit` and `Logex.Configuration.Edit` call, the latter one plan per program type:
  `plans/3` takes what a program's var_externals are, `:tags` for a lone instance and
  `:globals` in a resource, where no start rule starts one, and `switch/5` the clock a
  timer resumes from, the resource's (decision 56), fix F11's undo reading the instance's
  own `now` first. A stale edit of a lone instance stays outside the contract, the host's
  duty (decision 60). Since M2-5 (decisions 31 and 32) a function block's type,
  for the edit, is its name and its members' kinds: a member whose kind changes is refused
  by its path, and a switch moves an instance member by member, by path, `p.count`, a
  plan built once per block type; an `ons` inside an instance is blocked where any rung of
  its chain, from the program's `cal` rung down to the body's, changed, a `cal` keyed by
  the formals its operands fill, and stays listed until a scan runs it; a timer inside
  meets the timer rules by its path, resumed only where the program stopped does not run
  it and last scanned. Its moduledoc gives every rule, report kind and host mistake; §4.9
  the reasons
- `lib/logex/configuration/edit.ex` — a staged edit of a running configuration (OE-2,
  `docs/organisation.md` §4.9, "OE-2's design"; decisions 55–65): `accept/2` takes the
  `%Logex.Runtime{}` that runs the original and a candidate configuration, checks the
  candidate as `start/1` does (decision 63) and refuses what changes only with a restart as
  `:edit` diagnostics, in the candidate's file at their lines, a removed element last,
  then each kept program type's own in its file, with a forecast; `test/2`, `untest/2`,
  `assemble/2`, `cancel/2`, `running/1` and `stage/1` as `Logex.Edit`'s, each step taking
  and returning the runtime, switched between two cycles through `Logex.Runtime.edited/2`.
  A switch moves each kept instance by its type's plan between decision 45's merge and
  split, starts, sets aside, brings back (its timers resumed, decision 57) and retypes
  instances (decisions 43 and 61), starts and keeps globals (decision 44), moves a changed
  interval's next due time (decision 40), holds each global nothing drives any more
  (decisions 20 and 58), and reports a section change of a shared global, `:joined` and
  `:left` (decision 55), a priority and a reorder (decision 62); assemble and cancel prune.
  A step checks the edit, the runtime, the generation, the configuration the resource
  runs, then the stage. Its moduledoc gives every rule and report kind
- `lib/logex/compiler.ex` — the stages: `tokenize/1` and `parse/1` delegate to the two
  modules below; `instructionize/2` first checks its routine against
  `Logex.Parser.well_formed!/1` and raises `ArgumentError` on a tree no text could say
  (OE-1), then takes the declaration lines off into a tag table,
  checks every instruction against its operand signature and every operand against the
  table, members included (M1-6), names as a location an operand shaped like one whose
  first part is not declared, as `panel.i.0` (M2-2), gives each timer the preset on the
  one `ton` that runs it, refuses a second `ons` on one storage bit and anything after a `ton` on its path,
  refuses a `var_external` in a function block's file (M2-4), at its line, or as an
  `ArgumentError` for one declared from Elixir, and returns `{:ok, %Logex.Program{}}` (warnings included) or
  `{:error, [%Logex.Diagnostic{}]}`. Since M2-5 `instructionize/3` takes the function
  block types a routine may hold, each checked at full depth, one version per name; a
  routine headed `function_block <name>` gives `{:ok, %Logex.FbType{}}`; a block never
  holds itself, at any depth; a declaration refused for its type word, unknown or
  recursive, has its uses excused, so a misspelled block name is one message; `cal` is
  checked formal by formal, and one `cal` runs an instance. `lowered?/1` is the
  definition of a compiled body, which a type given has, as `well_formed!/1` is of a
  parse tree, and `recompiled/4` (decision 54) a block's body from its source text over
  the types it names, trusted, which a type given must be. The stage functions stay
  public for the golden record, the Elixir-side declarer and the naming test, and
  `signature/2` (M2-5) for the walks: an IR instruction's slots, its mnemonic's signature
  from `instructions/0`, or for a `cal` its block's, given the program's tag table, and
  none for anything no mnemonic gives, so it never raises.
- `lib/logex/warnings.ex` — the warnings a compiled program carries: a tag used by no
  rung, a `var_output` no rung writes, a second `ote` on one tag, and since M1-6 another
  write to an `ons` storage bit, a comparison of two literals, a timer no `ton` runs, and
  since M2-5 an instance of a user function block no `cal` runs
- `lib/logex/walk.ex` — B5's one walk of a program's IR (M2-4): `instructions/1`, every
  instruction in rung order, groups' legs included; `uses/2`, every tag operand with its
  slot's access, a member as its instance; `writes/1`, which tags a program writes, each
  to the lines of its writes, a `cal`'s instance and the tags its var_outputs fill among
  them; and `timers/1`, which timers it runs, each to its `ton`'s line and preset. The
  last two reach into every block a `cal` runs, at any depth, by path (`p.s.t1`), each
  block type read once a call. The compiler, `Logex.Warnings` and `Logex.Edit` read it in
  place of walks of their own, and `Logex.Configuration.check/1` what a program type
  writes through its var_externals
- `lib/logex/declarations.ex` — declaration lines to a tag table, after parsing: the
  section and type words as data (`@sections`, `@types`, and the function block type
  words of `Logex.FbType.builtins/0`), `kinds/0` (M2-5: the words that head a file of
  another kind, `function_block`), `reserved/1`, `block_name?/1`, `fits?/2`, `instance_of/1`
  and `not_a_program/1` (M2-5: how a message names an instance's type, a user block's
  with no article of its own, and the one message for a block type given where a program
  goes), `preset?/1` (a `ton`'s
  preset range, 0 to 2147483647 ms), and `check/1`, the one validator for a declaration
  line and for `Logex.Tag.new!/4`, so from Elixir too it refuses what no line can say: an
  initial value on an instance, and a negative one (OE-1). Since M2-4 `var_external` is a
  row of `@sections`: a bool or a dint with no initial value and no instance, and no
  configuration file's keyword (`Logex.Configuration.Text.keywords/0`) names one
- `lib/logex/tag.ex` — `%Logex.Tag{}`, whose type is `:bool`, `:dint` or, for an instance
  of a function block such as `var t1 ton` or `var s1 seal`, the `%Logex.FbType{}` itself,
  one `Logex.FbType.user?/1` accepts for a user block, except in a compiled program or
  block's body, where an instance of a user block names its type, `{:block, name}`, which
  the program's or the outermost type's one table holds (decision 53); and `new!/4`,
  which declares a tag from Elixir. Since OE-1 it takes no timer preset (the
  `%{"pre" => ms}` M1-6 allowed: a preset is the number on the `ton` that runs the
  timer) and no negative initial value. Its section may be `:var_external` (M2-4)
- `lib/logex/fb_type.ex` — `%Logex.FbType{}`, a function block type's schema (M1-6), which
  M2-5's user function blocks reuse: its members, each a `%Logex.FbType.Member{}` with a
  type, a role (`:input`, `:output`, `:internal`, and a user block's own `var`, `:local`)
  and whether logic may write it; `body`, nil for the built-in `ton` and a user block's
  compiled `%Logex.Program{}`; `ton/0`, the built-in timer; `initial/2`, a new instance's
  state, a map keyed by member name; `member/2` and `public/1`, which give only the inputs
  and outputs. Since M2-5 `of/1` builds a user type from its body, `signature/1` is
  `cal`'s operands, `user?/1` says whether a value is the type a compile gives for its
  body's source text, which it compiles again, with every type its table holds, each once
  a call (decision 54), and `check/2` is `user?/1` across the types one compile is given
  and the types of its tags declared from Elixir, a type their tables share compiled
  again once a compile;
  `same?/2` whether two are one version of a block (warnings, and the file a body was
  read from, aside), the one definition a compile's one-version check uses, and a
  member holding an instance of a user block has the type `{:block, name}`, as the
  instance's tag in the body has. Since decision 53 the type a compile gives holds every
  user block type below it, at any depth, once, in one table, its body's `blocks`, each
  held with no table of its own (`held/1`), so a type copied flat grows with the number of
  distinct types it holds, whatever the shape; `type_of/2` finds a member's type there,
  read inside the table (`within/2`), so the types below it are found in turn
- `lib/logex/program.ex` — `%Logex.Program{name:, source:, file:, rungs:, tags:,
  blocks:, warnings:}`, a program type, named and stateless, with `initial_env/1` for an
  instance's first env; `source` is its text, from which a block's body is compiled again
  wherever its type is given (decision 54); `file` is the path `compile_file/1` read it
  from (fix F15);
  `blocks` is the one table of the user block types a program, or a block's body, holds:
  every type its instances reach, at any depth, once, by name, each held with no table of
  its own, every instance's tag at any depth naming its type (decision 53, §4.10 "Held
  types"); and `typed_tags/1` gives the tag table with each instance's type itself, read
  inside the table, the table the compiler and the walks read, and that `initial_env/1`,
  the runtime's `get/2` and input check and `Logex.Edit` read, so a body run as a program
  reads each instance it holds as a compile does
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
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`; `validation_test.exs` holds every diagnostic and warning `instructionize/2` gives, driven from source. `test/logex_test.exs` pins `Logex` (and walks Milestone 1's done sentence and, from files on disk, Milestone 2's), `runtime_test.exs` every message the runtime raises and the exact public surface, `walk_test.exs` each fact of `Logex.Walk` from source, at depth, with its growth, `edit_test.exs` every message, diagnostic and rule of `Logex.Edit`, `configuration_test.exs` every diagnostic, warning and host mistake of `Logex.Configuration`, as whole lists from data and again from source, the loader of `compile_file/1` from files on disk, and the configuration file's round trip, seeded, its totality over every argument and its growth, `configuration_text_test.exs` every line a configuration file's reader refuses, as whole lists from source, and what a line can say, `scheduler_test.exs` a test at least per rule of a cycle, one copy of a global shared through `var_external` among them, and an event task's edges with decision 39, `function_block_test.exs` every diagnostic, host mistake and rule of M2-5's user function blocks, from source, the loader of `compile_file/1` among them, an online edit of a program that holds them among them, with its growth tests in the block list's bytes (decision 32), `config_edit_test.exs` every host mistake, refusal and rule of `Logex.Configuration.Edit` on §4.4's plant, the refusals as whole lists from source and from data, with its growth tests in the instances, the types and a program's size (OE-2), and `api_contract_test.exs` a seeded property over the host contract, which since M1-6 checks every accepted scan against an oracle for `ton` and `ons` and makes every accepted call twice, and since OE-1 walks online edits too, and since M2-1 configurations run as resources, against a model that scans each instance through `call/4` alone, and since M2-5 online edits of programs that hold blocks, two deep, with a one-shot oracle on every scan from the programs' text, and since M2-4 resources whose programs share globals through `var_external`, against a model that runs each program as Elixir over one map of globals, and since M2-6 configurations with event tasks, alone and with an interval, against a model of decision 39 in phase points and oracles that know only each trigger's samples, and since OE-2 staged edits of a running configuration, on a slow task that skips cycles among them, each step's writes rebuilding the resource, against a model of the scheduler seeded from the resource after every step and oracles for timers and one-shots that know nothing of the edit
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
  decision-6 test, PLAN OE-1's Done-when, and PLAN M2-1's, M2-5's, M2-2's, M2-3's and
  M2-4's Done-whens among them, the last five through `Logex.Runtime.cycle/3`, M2-1's with
  `scan/2` beside it, M2-5's reading `m1.s2.run` through `Logex.Runtime.get/2`, from text
  and from files on disk through `Logex.compile_file/1`, M2-2's from a configuration file
  and its program type on disk through `Logex.Configuration.compile_file/1`, against an
  oracle that knows nothing of logex, M2-3's from §4.4's plant read by
  `Logex.Configuration.compile/3`, and M2-4's, §4.4's plant with §4.3's motor, whose
  `estop` is a `var_external`, from text and from files on disk, beside a test that an
  e-stop pulse shorter than `m2`'s interval never reaches it (decision 46), and M2-6's,
  from data, beside the tie-break of an event task and a late periodic one writing one
  global, and from §4.4's plant whole, its `trip` task among them, from text and from
  files on disk, and OE-2's, §4.4's plant whole edited while it runs through
  `Logex.Configuration.Edit`, from text and from files on disk; `validation_test.exs` and
  `printer_test.exs` also run source to an environment in places.
  `lex_and_parse_test.exs` starts from a source string and so crosses the tokenize→parse
  seam, but no further; the other two hand-type one stage's input and cannot see a seam at
  all.
- `README.md` — what logex is, the dialect stance, the instruction table and worked
  examples, among them a function block loaded from beside the program that runs it, a
  configuration file loaded with its program type and run by the scheduler, the same
  configuration built from Elixir, an e-stop shared through `var_external`, an event task
  on the e-stop's edge, a running
  program changed by `Logex.Edit`, its blocks included, and a running plant changed by
  `Logex.Configuration.Edit` ("A running plant"). **Any change to the language stales it:** a
  new instruction adds a row and may clear a "Settled, not yet landed" bullet; a syntax
  change touches the syntax list, the instruction table and the examples (whose output is
  real — re-run it). So does a change to a block's rules or the loader, through "A
  function block", to a configuration's checks or a cycle's rules, through "A
  configuration", which also holds a configuration file's syntax and its loader, and to
  an edit's rules or report, through "Changing a running program".
  Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic, declaration
  word, word that heads a file or configuration file's word; append-only
- `docs/organisation.md` — where logex is heading above one program: IEC's configuration,
  tasks, program instances and I/O mapping, in logex's dialect. Decided (PLAN §5; the
  work is PLAN's M1-3, M1-5, M1-6, OE-1, Milestone 2 and OE-2; OE-1, Milestone 2,
  M2-1, M2-5, M2-2, M2-3, M2-4 and M2-6, and OE-2 have landed, Milestone 2 designed on
  2026-10-02, §4.10 and decisions 30–40, and OE-2 on 2026-10-13, §4.9's "OE-2's design"
  and decisions 55–65). Read it before designing anything that names a program, schedules one, binds I/O, or changes a
  running controller (§4.9, online edit, decided 2026-10-01).
- `docs/instruction-sets.md` — reference: IEC's LD elements and standard library by table number,
  Instruction List (withdrawn in Ed 4), and the free-software instruction sets. Read it before
  writing a naming.md stanza; it carries the IEC feature numbers a stanza should cite.

## Conventions

- `evaluate/3` clauses, private in `Logex.Runtime`, take `(instruction, {power_flow_bool, env_map}, %Logex.Scan{})` and return `{new_power_flow_bool, new_env_map}`. The scan is read-only and the same for every instruction of one routine run, a program's rungs or one run of a block's body: a clause that needs the time reads `scan.now`, one that needs the first scan reads `scan.first`, and every other clause ignores it as `_scan` (M1-6). `ons` reads `scan.first` and `scan.ons_blocked`, the storage bits whose `ons` passes no power on this one scan, which `call/4` builds from the instance's `ons_blocked` list as a tree of those bits, each to `true` and each instance holding one to a tree of its own, so that each `ons` looks its bit up rather than walking the list, emptying the instance's list after the scan but for the bits inside an instance whose body did not run (OE-1, decision 32); a host never fills it in. `cal` (M2-5) reads `scan.tags`, the routine's tag table, and `scan.blocks`, the program's one table of block types (decision 53), which `call/4` fills from the program, and runs its block's body with the scan narrowed to its instance, `tags` the body's and `ons_blocked` the instance's own tree, `now`, `first` and `blocks` unchanged; a clause that looks a tag up in `scan.tags` uses the routine's table. No test calls the evaluator: a test runs a program through `Logex.Runtime.call/4`, on a hand-built `%Logex.Instance{}` when it needs a particular env
- A mistake in the source is a `%Logex.Diagnostic{}`, returned; a mistake by the host is an `ArgumentError`, raised, whose message a test pins. Nothing else may escape the public API (`api_contract_test.exs`)
- An operand in the AST is `{:name, line, tag}` or `{:int_lit, line, value}` — a 3-tuple, not a keyword pair. Destructure the line as `_`; never drop it from the AST, it is what diagnostics will cite. `Logex.Parser.well_formed!/1` states the whole tree `parse/1` can produce, and `instructionize/2` raises `ArgumentError` on any other (OE-1): every line a positive integer, every element of a rung on its one line, each rung on a line after the last, a name that lexes as one name token, a literal of 0 or more, a rung of one element or more and a group of one leg or more. A test that builds a tree by hand builds one of those. The lexer's tokens carry `{line, column}`; the parser keeps only the line, because the suite pins that shape. An instruction in the IR is `{symbol, line, operands}`, carrying its mnemonic's line; a `{:branches, legs}` node carries no line of its own. In the IR, and only there, a member of an instance is `{:member, line, path}`, `t1.acc` becoming `{:member, 3, ["t1", "acc"]}` (M1-6): the runtime's `read/2` and `write/3` take it as they take a tag, and anything that walks IR operands must handle it. A walk that reads what an instruction's operands do looks its slots up through `Logex.Compiler.signature/2`, given the program's tag table, never in a table of its own (M2-5), as `Logex.Walk` does, which `Logex.Warnings` and `Logex.Edit` read: a `cal`'s slots are its block's, so the outputs it fills are writes
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
  `compiler.ex` (`cal`'s entry is the marker `{:cal, :block}` instead, M2-5: its signature
  is its block's, built per compile) **and** two
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
  any case and owes a `docs/naming.md` stanza, which `naming_test.exs` checks. A word that
  heads a file of another kind, an entry of `Logex.Declarations.kinds/0` (`function_block`,
  M2-5), owes a stanza too, which the same test checks; `Logex.Compiler` reserves it in
  that kind of file only, in any case (`docs/organisation.md` §4.8). A word of a
  configuration file's lines is a row of `Logex.Configuration.Text`'s, and owes one too.
  A user function block's name is no row and owes no stanza: it is a type word only where
  a compile is given the block, through `types:` or a tag's type, and is not reserved.
- New state in an instance (a field of `%Logex.Instance{}`, a member of a function block
  type, an M2 item's piece of state) states its rule across an online edit. A tag or member
  starts by `Logex.Program.initial_env/1`, the one rule, whose doc and §4.9's "One rule for
  new state" list the edit's exceptions. A field of `%Logex.Instance{}` gets a check in
  the runtime with a message a test pins, a value from `instance/1`, and a rule for each
  of a scan, `restart/3` and a switch, as `ons_blocked` and `switched` have. A piece of a
  resource's state, in the opaque `%Logex.Runtime{}`, which no host hands in and so needs
  no entry check, gets a value from `start/1` and a rule for each of a cycle, `restart/2`
  and a configuration edit's switch instead, in `Logex.Runtime`'s one-rule section, with
  the edit's exceptions listed, as `generation` and `aside` have (OE-2); a global's one rule is `Logex.Configuration.initial/1`, beside
  `initial_env/1` for a tag (M2-1). A new report
  kind is a row in `Logex.Edit`'s table and §4.9's, or `Logex.Configuration.Edit`'s for
  a configuration's, and in `api_contract_test.exs`'s `@report_kinds`, whose reach the
  walks assert, one only a configuration's edit gives also in `@configuration_kinds`
- Nothing compiles a user's program to BEAM: every front end (the text, an Elixir data
  API, any later macro) ends in `%Logex.Program{}` data that `Logex.Runtime` interprets,
  and no front end puts the Elixir compiler on the path that changes a running program
  (`PLAN.md` §6; online edit, `docs/organisation.md` §4.9)
- A fix needs a test that **fails when the fix is reverted**. Check it by reverting, not by
  reasoning: `mix test` stayed fully green after the `NAME` regex was corrected, because
  no test used a single-character tag. `PLAN.md` §2·M0-4 has the worked mutation table.
- Use pattern matching with multiple function clauses, not conditionals
