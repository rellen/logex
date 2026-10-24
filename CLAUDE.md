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
  mistake raises `ArgumentError`. The evaluator lives here too, private (B5): `rungs/3`,
  the one rung loop, a program's and a block body's (M3-5), `series/3`, `element/3`, and
  the instruction clauses of `evaluate/3`, each threading the scan's read-only
  `%Logex.Scan{}`.
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
  that the opaque struct's fields are written in this module alone. Since M4-2 a cycle
  runs the continuous task's instances, with no `with` or `with` it, with the task-less
  ones, last, once a cycle, in the order declared, each `{:ran, "main", ...}`, `:none`
  where none is declared (decision 111); it is never due, uncounted by `next_due_in/1`,
  and never overlaps, listed at 0 by `overlaps/1`; and a cycle reads no watchdog. Since
  M4-3 `cycle/3` is the composition of three internal steps (no doc), `cycle_steps/3`, the
  clock, the image and the triggers sampled, giving each due timed task's run and then
  the untimed instances' where any exists, `cycle_step/2`, one run with its events, and
  `cycle_outputs/1`, which `Logex.Runner` calls to time each task's run (decision 118).
  Since M3-1 it runs IEC's counters: `ctu` and `ctd`, each a side of its counter, its kind
  the tag's type in the routine's table, R before LD before a rising edge, never on a first
  scan, stopping at the dint's limits with `ov` or `un` latched, the edge memory kept by a
  reset or load (decisions 69 to 71), and an edge memory on the instance's block list
  blocking its side's next run, which records itself as a `cal` does so that the scan drops
  the block (decision 87); since M5-5 IEC's typed counters too, `ctu_int` to `ctud_ulint`,
  each read through its type's rules, its `family` the kind it counts as and its `counts`
  the type whose limits it stops at, 32767 with `ov` for a `ctu_int` and 0 with `un` for a
  `ctd_udint`, decision 71 by width (decision 158). Since M3-2 it runs the other timers: `tof`, IEC's TOF, `.dn` its
  Q, on through the delay a falling rung starts (decision 93); `tp`, IEC's TP, a pulse on
  `.tt` from a rising edge, never on a first scan nor where the block list holds its `.en`,
  an edge during it ignored and `.dn` set as it ends while the rung holds (decisions 74,
  75 and 94); and `rto`, the conventional RTO, keeping `.acc` and `.dn` across a false rung
  and cleared by its `r` input at its next run (decisions 76, 90 and 95); each stamping
  `last` on every run, so a frozen block's timer catches up; since M5-6 the long timers
  too, `ton_ltime` to `rto_ltime`, each its kind's rules, each millisecond of the scan's
  clock adding its type's `per_ms` to `.acc`, 1,000,000 ns, so its resolution is a
  millisecond (decision 158), and since decision 197 each timer's unit read from the
  routine's `units`, which the compiled program carries (`Logex.Program`) and the scan
  holds, a `cal` narrowing it to its body's: a timer of a routine whose `units` are nil,
  every routine of plain timers, matches that in its clause's head and pays no look-up,
  as before long timers, and only a routine holding a long timer looks each of its timers
  up (`unit/3`), one whose unit is no positive whole number, or units that are no map,
  which only a program edited by hand after its check holds, raising a pinned
  `ArgumentError` there (decision 194). Since M3-3 it runs IEC's
  arithmetic on dints, `add sub mul div mod` and the vendors' `neg` with IEC's `abs`: the
  result computed exactly and, since M5-2, wrapped into the dint, its low 32 bits kept in
  two's complement (`Logex.Declarations.width/1`), with no fault, superseding decision
  77's saturation (decision 146), and since M5-4 into its destination's type, of any
  integer width, which `type_at/2` finds in the scan's tag table, a member's by its
  built-in's schema, through `Logex.Program.destination/2`, 127 + 1 in an `sint` giving
  -128 (decision 147); since decision 182 a program whose arithmetic destination has no
  integer type, its tag retyped or taken out of the table, which only a program edited by
  hand gives, is refused a line each (`Logex.Program.edited_by_hand/1`, "`m`'s `add` on line 7
  computes in the type of `d`, a bool, which is no integer type: `m` was edited by hand
  after it compiled"), where M5-4's review read the dint, and since decision 190 once,
  where the program is first handed in, `instance/1`, an edit's accept,
  `Logex.Edit.accept/3`, since decision 200 the program running and then the candidate,
  and `Logex.Configuration.check/1` (so `start/1`, which makes each
  instance with the internal `fresh/1`, as a configuration edit's switch does), every
  other entry point taking only its shape, so a scan costs what it did at `23a5136`: a
  program swapped in by hand after its check is trusted, and a scan that reaches such a
  destination raises a pinned `ArgumentError` there ("a scan's `add` on line 7 computes
  in the type of `d`, …: the program was edited by hand after it was handed in and
  checked", decision 194), `type_at/3` reading the one rule with no tuple; and since
  decision 197 so is one whose `units` its tags do not give, a line each, each routine's
  before its rungs; the power out IEC's
  ENO, false on the scan it left its type or met a zero divisor, which writes 0 (decision 78), `div` truncating toward zero and `mod` taking the dividend's sign, a
  source a hand-built env leaves out reading 0; and a zero divisor is a minor fault,
  a `%Logex.Fault{}` (`lib/logex/fault.ex`), recorded in the routine's env under an atom
  key and placed when the routine is done: `call/4` gives the scan's in the state's
  `faults`, oldest first, a block's by its instance's path and in its body's file, and a
  cycle each as an event, `{:fault, task, instance, fault}`, just after its scan's
  `{:ran, ...}`, keeping none in the resource (decision 99). Since M3-4 it runs the pulse
  coils, IEC's transition-sensing coils in the conventional set's form: `osr s1 pulse` and
  `osf s1 pulse`, the storage bit first, each run writing the pulse bit and then the
  storage bit with the power it receives, read as a contact reads a bit, the pulse set on
  the run that power rises for `osr` or falls for `osf`, `osf`'s seen by its de-energised
  clause, never on a first scan nor where the block list holds the storage bit, as for
  `ons`, and passing that power on (decisions 80 and 100 to 102); in a block whose `cal` is
  false both bits are held, so a pulse stays on until the body runs again, as the
  maintainer confirmed, and a block whose first run comes after the instance's first scan
  reads each storage bit as declared there, so an `osf` declared 1 pulses on a false rung
  (decision 102). Since M3-5 it runs the forward jump: an energised `jmp done` records its
  label in the routine's env under an atom key, `:jump`, and passes on the power it
  receives, so the rest of its rung runs, IEC's rule 3; once the rung is done `rungs/3`
  takes the record out and skips the rungs after it up to the one `lbl done` heads, which
  runs; de-energised a `jmp` does nothing and passes no power, and `lbl` passes on what it
  receives (decision 104). A skipped rung runs nothing, so it is frozen as a block whose
  `cal` is false is: its outputs hold, an `ote`'s among them, its counters and one-shots
  keep their edge memory, a zero divisor on it raises no fault, and a timer, whose `last`
  only its own run stamps, catches up when next run (decision 82); where the block list
  holds a memory, a skipped rung marks each storage bit and counter side it holds in the
  routine's `:ran` record, so that the scan keeps it listed until a scan runs its
  instruction (decision 106), and with the list empty a skipped rung is passed over, never
  walked.
  `lib/logex/instance.ex` and `lib/logex/scan.ex` hold its two structs, each with
  `ons_blocked` since OE-1: the storage bits whose `ons` the next scan blocks, the hook an
  online edit's switch uses to keep a new or changed one-shot from firing, a bit inside a
  function block's instance named by its path and kept until a scan runs its body
  (decision 32), and since M3-1 a counter's edge memory by its path, `boxes.cu`, since
  M3-2 a `tp`'s, `horn_pulse.en`, and since M3-4 an `osr`'s or an `osf`'s storage bit, by
  its name as an `ons`'s, each, since M3-5, kept on a rung a jump skips until a scan runs
  its instruction (decision 106). The instance also has `switched`, which an edit's switch sets and a scan
  clears, and since M3-3 `faults`, its last scan's minor faults, `[]` from `instance/1`,
  which each scan replaces and `put_inputs/3`, `restart/3` and a switch keep, each entry
  point that takes a state refusing one that is not a proper list of `%Logex.Fault{}`,
  before it checks the state's owner, and which a resource's states hold as `[]` between
  cycles, a cycle reporting them as events and dropping them (decision 99), and the scan
  `tags` (M2-5), the tag table of the routine it runs, which `cal`
  narrows to its block's. Every entry point that takes a program refuses a function block
  type with one message, `Logex.Declarations.not_a_program/1`'s. Since M3-5's review every
  entry point that takes a state, `Logex.Edit`'s steps among them, refuses one whose env
  holds a key the runtime keeps a scan's records under, `:faults`, `:jump` or `:ran`, all
  it holds named in one message, checked with the env's shape, before the clock and the
  owner, since a record left there would change the run; and a `cal` drops those keys from
  its instance's map before its body runs, a value no scan checks. Since decision 171
  every entry point that takes a state, `Logex.Edit`'s steps among them, refuses one that
  holds an integer outside its tag's or member's type, at any depth, 5000000000 in a dint
  or 5 in a bool, after the state's owner, every such value a line of one message in path
  order (`state.env holds `t1.acc` outside its type: ...`), each tag of the program looked
  up in the state through `Logex.Declarations.is_fitting/2`, a guard a value, so linear in
  the state (a growth test in `runtime_test.exs`), and since decision 173 a value that is
  no integer in a bool or an integer tag or member, 37.5, nil or `"x"`, in the same
  message ("it is a dint, and its value must be an integer, found 37.5"), retiring M1-4's
  lenient reading for a state handed in, and since decision 184 an instance's tag that
  holds no map, 5 or nil ("it is a ton, and its value must be a map of its members, found
  5"), and since decision 186 a timer's `last` that is no integer ("it is a clock, and
  its value must be an integer, found nil"), and since decision 188 one later than the
  instance's own `now` ("it is a clock, and 5000 is later than the instance's now,
  1000"), any integer up to it taken; a resource's instance is checked as each scan takes it, inside
  `call/4`, and since M5-3's review each global a connection copies into it first, against
  the global's own type, narrower than its var_input where the connection widens
  (`runtime.globals holds `a` outside its type: ...`), so a `cycle/3` or `restart/2` of a
  runtime the host built raises before it returns; and a plain swap that narrows a tag over such a value is refused at its next
  call. It replaces M5-2's provisional reading of a hand-built source outside the dint.
  Since M5-3 it runs the 56 integer conversions, `<from>_to_<to>`, each a symbol to the
  type it writes, generated from the type table: energised, the value written where it
  fits, with power, and otherwise its low bits, two's complement where signed, with no
  power and no fault, `dint_to_sint` of 129 giving -127, `wrapped/2` keyed by the
  destination's type (decisions 146 and 148); de-energised, nothing. Since M5-8 it runs
  the 76 bit-string conversions, binary transfers (`transfer/2`, generated): the source's
  pattern, two's complement where signed, kept to the destination's width and read as
  its type, never sign-extended, `int_to_dword` of -1 giving 16#0000ffff, always with
  power (decision 204); `and or xor`, in the destination's type
  (`bits_at/3`, through `Logex.Program.destination/3` with `:bitwise`), an integer by its
  two's-complement pattern, and since decision 206 a bool's, a bit's among them, one bit,
  always with power; `not` and `shl shr rol ror` since decision 214 in their source's
  type, IEC's typing (`source_bits/3`, a tag's by one guard, a bit's a bool's, a literal's
  the destination's), the result widened into the destination by value (`widened/3`),
  `not` of a bool 1 into a word 16#0000 and `rol` of a byte into a word within 8 bits, a
  shift of the source's width or
  more writing 0, a rotation by the count modulo the width, and a negative tag count
  writing the source unshifted with no power and no fault (decision 165); and a bit
  operand, `{:bit, line, path, n, mask, name}`, read as `bit_set/2` and written as
  `with_bit/3`, leaving every other bit, its storage bit blocked by its name `w.3`. Since
  M5-9 it runs a bit whose number a tag holds, `{:bit_at, line, path, {:name, line, n},
  {width, top}, name}` (decision 160), its mask computed from the number the tag holds as
  it is read or written (`bit_mask/3`), a signed type's top bit `top`, and a number
  outside 0 to width − 1 the first major fault (decisions 153 and 160): thrown to the
  instruction's own catch in `element/3`, which only an instruction with such a bit among
  its first three operands and every `cal` have, told by their clause heads, so any other
  scans in what it did at `1ee676b` and a `cal` one reduction more a run, the instruction
  then doing nothing, writing nothing and passing no power, the rung running on, its
  fault `{:bit_out_of_range, symbol, line, n}` in the routine's env under `:faults` and
  placed as a zero divisor's, `%Logex.Fault{severity: :major, kind: :bit_out_of_range,
  read: n}`, a `cal` whose operand is out of range dropping its body's run; an instruction
  that reads and writes nothing, a de-energised contact or latch, a rung a jump skips or a
  block whose `cal` is false, checks nothing (decision 82).
  Since M5-10 it runs the reals, `real` and `lreal` (`docs/organisation.md` §4.12,
  decisions 147 to 150, 161, 162, 164 and 166): every write into one through
  `Logex.Real.stored/2`, its type's nearest value, a `real`'s a single, past its range
  its largest finite value, the sign kept, with no power, −0.0 and a subnormal 0.0; the
  arithmetic computing a real destination's result on floats, a BEAM `ArithmeticError`
  of an `lreal` caught as an overflow; a zero divisor writing 0.0 into a real; the 34
  real conversions rounding to the nearest, a tie to the even one (`Logex.Real.round_even/1`),
  then wrapping, and the 16 truncations, `real_trunc_int` and the rest, truncating, with
  no power where it does not fit; `sqrt`, a negative source writing 0.0 with no power and
  the minor fault `{:negative_sqrt, at, value}` in the routine's env, placed as
  `%Logex.Fault{kind: :negative_sqrt, read: value}`; a host's real input, a connection's
  and a device's stored as its nearest real, one past the range refused; and a state's
  real held to one of its type's values, a float, never −0.0 nor a subnormal. A routine's
  real tags are the program's `reals`, by name, which the scan holds, nil where it holds
  none, so `move`'s first clause and a zero divisor's match `%Scan{reals: nil}` and a
  program of no real scans in exactly what it did at `5eac41f`; a `cal` narrows it to its
  body's, and a host's scan that sets it is refused. Since M5-10's review (provisional) a
  real literal is a value of the real its slot computes in, settled by the compiler
  (`slot_operands/4`, `real_operand/4`), the destination's, a comparison's other operand's
  or a conversion's `from` type, so that `eq sp 37.1` is true after `move 37.1 sp` in a
  `real`, and the scan reads it as any literal.
  Since M5-11 it runs arrays of elementary types (`docs/organisation.md` §4.12, decisions
  151, 154 and 157): an element operand, `{:element, line, array, index, name}`, read as
  `elem/2` of its array's tuple and written as `put_elem/3`, a 1-D array's in one clause
  and more dimensions through `Logex.Array.fetch/2` and `put/3`, an element's type found
  through the program's `arrays`, nil where it holds none, so a program of no arrays
  scans in exactly what it did; a host's array var_input a list of the declared shape,
  every element checked, and since decision 222 one element alone set by its name,
  `%{"steps[3]" => 5}`, the rest kept, its subscripts one a dimension and each within it,
  a whole key beside an element key or an element set twice refused, looked at only for a
  program holding an array (`untagged/2`, `clashes/2`); since decision 221 a bit of an
  element, its container the element's operand, read and written through the element; an
  array var_output given as a
  list; a state's array a tuple of its sizes, one lacking an array refused; a resource's
  array connections copied whole or element by element, `get/2` naming an array whole,
  as a list, or an element, `m1.temps[3]` or `temps[3]`, and a resource's instance
  restarted with its var_externals' globals in its state, and since decision 223 a
  connection's far end an element of a global array, `{:at, array, index}` in the
  wiring, copied in and out element by element, and since M5-13 (decision 156) a located
  array's elements each an input or output point of its own, a cycle's input keyed
  `"temps[3]"` and placed in its array, a few in place and more, up to every element, laid
  over the array in one pass (`placed/4`, provisional at 16), each output element given
  by its name, a restart keeping a located input array as an input point, the array
  named whole or an element it lacks refused in pinned words, wiring fields `elements`,
  `element_outputs` and `located` nil where no array is located, so a configuration of
  none cycles in what it did at `a8af419`. Since M5-11's review a state's
  integer, bit-string or bool array is checked by one guard an element (`all_fit?/3`), its
  shape looked at only on a misfit, about a reduction an element each time a state is
  handed in, a real's by its rule; a host's list is shown as a list, never a charlist; and
  an array's misfits, a host's, a state's or an initial list's, are listed to ten, the
  rest counted (`Logex.Array.capped/2`, provisional). Since M5-12 (decisions 152 and 153)
  it runs an element a tag subscripts, `{:element_at, line, array, index, dims, name}`,
  each subscript read as the element is read or written, a one-dimensional element of
  one tag in a clause of its own (`one_subscript/2`), and one outside its dimension the
  major fault `:index_out_of_range`, thrown to the instruction's catch as M5-9's bit is,
  `read` every subscript, since decision 233 a tuple, `{8}` or `{1, 9}`, which no
  `inspect/1` shows as a charlist, the instruction doing nothing
  and passing no power, a bit of such an element its element's subscripts checked first;
  an instruction with one among its first three operands, or a bit of one, is told by its
  clause's head, so a program of none scans in exactly what it did at `e00ae03`.
- `lib/logex/array.ex` — `Logex.Array`, internal (no moduledoc, M5-11, decision 151), the
  one place an array's shape and values are read and made: its type `{:array, type,
  dims}`, one to three sizes, 65,536 elements at most (the spike's limit, provisional),
  `is_array/1` (a guard), `started/2`, an array's first value, the one rule, a tuple of
  tuples in the elements' order, the rightmost subscript fastest, `fetch/2`, `put/3`,
  `to_list/2` and `from_list/3`, a host's form, since M5-13 `points/3`, a located
  array's elements with their addresses, `name/2`, an element's name by its
  subscripts' values, `grid[1,7]`, and `split/1` and `subscript/1`, a name's subscripts
  as written, a tag's `{:tag, name}`, which since M5-12 a scan reads
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
  lexer reads as one token, a number that is not an integer); `new!/1`, from Elixir, raising one
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
  and line, and since M3-1 each counter after them, from `Logex.Walk.counters/1`
  (decision 72); since M3-2 each timer in its own type's words, a `tof`, `tp` and `rto` as
  well as a `ton`, read in the routine whose text holds it, since M5-6 a long timer by its
  kind's rule in its own word, "a ton_ltime times across the task's runs"; and since M3-4's review each
  one-shot after the counters, an `ons`, an `osr` or an `osf`, a block's by its storage
  bit's path, from `Logex.Walk.one_shots/1`, once a type, in its own words, citing its
  instruction's own file and line (decision 103, as the maintainer answered it on
  2026-10-15, superseding its "no warning"). Since M3-4 the writer
  warnings name a global's one-shot, `ons`, `osr` or `osf`, the first writer's in line
  order whose storage bit it is, from `Logex.Walk.storage_bits/1`. Since M3-3 a negative number is
  one a configuration's line can say, so a negative interval or priority is told its range
  in the file's words, as one too large is, and no longer raised as the host's; a dint's
  negative initial value and constant are taken (decision 97). Since M5-3 a global may be
  of any integer width, a connection's copy-in and copy-out widen by Ed 3 Figure 11, a
  refusal naming the conversion a program would make, and a `var_external` binds only to
  a global of exactly its type, told so (decision 159). Since M4-2
  (`docs/organisation.md` §4.11, decisions 109 to 111) a task has `watchdog`, 1 to
  2147483647 ms or nil for 500, which `watchdog/1`, the one rule for it, gives and the
  runner will read, raising, since M4-2's review, for a watchdog out of that range as for
  one that is no integer, and `continuous`, false unless set, `name` alone enforced: `check/1`
  tells a watchdog of 0 that every task has one and one out of range its range, refuses
  a second continuous task, told the first, and one given a single, an interval or a
  priority, all of them in one diagnostic shown `task main continuous watchdog 200`, and
  runs every instance with no timed task, those with no `with` and `with main` alike, in
  the continuous task, which a task warning counts; a task that needs a priority is shown
  its own watchdog, and one with nothing, where no continuous task is declared, is offered
  it; a watchdog that is not an integer and a continuous that is not a boolean are the
  host's, the latter read as neither kind. Since decision 169 a program given whose
  var_input or var_output holds an instance, which no text declares, so one edited by hand
  after it compiled, is a host mistake, a line for each such tag, connected or not, the
  program left out of every diagnostic, and since decision 182 one whose arithmetic
  destination has no integer type, and since decision 197 one whose timer units its tags
  do not give, a line each after the ports', in the runtime's words
  (`Logex.Program.edited_by_hand/1`); and since decision 168 a program type's name in a
  message takes no article: "`m1` runs `motor`, which declares no `strat`". Since M5-11 a
  global may be an array, `var_global limits int[3] 10 20 30`, located since M5-13, its
  sizes and initial list judged as a declaration's (`Logex.Declarations.array_misfits/3`),
  a name with brackets refused, a `var_external` array bound only to a global array of
  exactly its type and sizes, and a connection naming an array whole, to a global array of
  its sizes whose elements widen, or an element, `m1.temps[3]`, an array var_input
  connected whole or at every element, a constant filling an element alone. Since M5-11's
  review a global named by an element where a global is wanted, a connection's far end or
  a task's single, `ws[0]`, is told a global is named whole, a single that is an array is
  refused as no bool, and decision 48's writer warnings take an array global by element
  (`written_of/2`), so two instances that write different elements are told nothing, a
  bit of an element its element's write (`Logex.Walk.element_writes/1`, decision 221).
  Since decision 223 a connection's far end may be an element of a global array,
  `m2.speed speeds[1]`, a global of its elements' type widening by decision 159, its
  subscripts judged at the connection's line, one connection driving each element and
  one driving the array whole driving them all (`first_driver/2`), the writer warnings
  element by element, an element a use of its array; a task's single is still a global
  named whole. Since decision 236 a writer through a tag subscript, which may write any
  element, is told, and tells another writer, by the element they may share, "`f2` writes
  `speeds[1]` through its var_external, as `f1` may", two such writers at the array, both
  "may", each element writer no longer counted a writer of the array whole. Since
  decision 227 `compile/3` and `compile_file/1` warn of a real initial
  value a `var_global` line writes with more digits than its real keeps, read from the
  text's tokens (`Logex.Configuration.Text.read_rounded/1`, internal). Since M5-13
  (decision 156) an array global may be located, `var_global temps real[8] at card.i.0`,
  each element a point at the next address in the elements' order, its location's last
  field counting up (`Logex.Array.points/3`, the hierarchical reading provisional),
  named by its element, `temps[3]`, in a location's message too; a range overlapping
  another point refused naming both, once a pair, at the first address they share, an
  array refused for its sizes taking no address; no initial list, told the range; an
  array of output points nothing drives, or drives only by element, warned of each
  element left at 0, ten then a count; an input array driven by a var_output or written
  through a var_external refused naming its range (`a_point/2`); and an element of a
  global whose line was refused silent, as its name is (decision 42).
  `lib/logex/configuration/text.ex` is a configuration file's text (M2-2, its task lines
  and `with` since M2-3, `single` on a task line since M2-6, `continuous` straight after
  a task's name and `watchdog` after its priority since M4-2, each once): its words as data, `keywords/0`, which `naming_test.exs`
  reads; `read/1`, a recursive descent over
  `Logex.Lexer`'s tokens, not `Logex.Parser`'s, giving the elements of a configuration in
  line order, each with its line, or a `:configure` diagnostic with its column for each
  line it cannot read, a placeholder for what a broken line names among the entries;
  `entries!/1`, what a line can say, a number negative too since M3-3 (decision 97); and
  `print/1`, of a configuration or its entries,
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
  it and last scanned. Since M3-1 the
  preset rules are every built-in's, a counter's `.pv` by decisions 23 and 27, its forecast
  `:dn_drops` and `:dn_rises` of `q` (decision 88), and no resume; and a counter's edge
  memory is on the one-shots' block list by path, its rung compared without any preset,
  with no writes test (decision 87). Since M3-2 a member input logic wrote, a counter's `r`,
  `ld` or `pv`, an `rto`'s `r` or a timer's `.pre`, that the candidate writes through no
  instruction keeps its value and is reported `:unwritten` by its path (decision 96). Since M3-2 a timer resumes by its type's `times`
  member (`.en` for a `ton` and an `rto`, `.tt` for a `tof` and a `tp`), its `.dn`
  forecast follows its type's rule (`forecast`), and a `tp`'s `.en` is on the block list
  as a counter's edge memory is (decisions 93 to 95). Since M3-4 an `osr`'s or an `osf`'s
  storage bit is on it by name as an `ons`'s is, by every rule of an `ons`'s, its rung,
  its kind and its pulse bit among it, compared without presets (decisions 80 and 87), so
  an edit of its pulse bit alone blocks it and may cost one real press (decision 101), one
  whose storage bit the program that last scanned also writes another way blocked as an
  `ons`'s is, and its pulse bit an ordinary bool, held where an edit stops driving it.
  Since M3-5 a rung is compared whole, its `lbl` and `jmp` among it, so an edit that
  labels a one-shot's or a pulse coil's rung or adds a `jmp` to it blocks it once, at the
  cost of one possible press, as the maintainer confirmed after M3-5's review, and a
  memory blocked on a rung a jump skips stays listed until a scan runs its instruction, a
  ctud's two sides each by its own rung (decision 106); labels are names, so an edit that
  moves rungs leaves every jump as it was; and since decision 202 a literal is compared by
  its value, so an edit that only respells one, `16#ff` for `255`, changes no rung; and since M5-11
  (decision 157) an array's type, dimensions or sizes changed are refused, elements move
  by path, a changed initial list is reported element by element, `{:initial_changed,
  "lim[1]", {20, 25}}`, and an array added or a var_input array reported as a list, as
  `Logex.Configuration.Edit` reports a global array. Its moduledoc gives every rule, report kind and
  host mistake; §4.9 the reasons
- `lib/logex/configuration/edit.ex` — a staged edit of a running configuration (OE-2,
  `docs/organisation.md` §4.9, "OE-2's design"; decisions 55–66): `accept/2` takes the
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
  Since M4-2 (decision 129) a switch reports a watchdog changed, `:watchdog`, in ms, 500
  for none, and writes nothing for it; accept refuses the continuous line added or
  removed as any task, a task made continuous or timed as its kind, once, and an instance
  moved between a timed task and the continuous one, while an instance with no task and
  one `with` the continuous task are one place and one order, under its name, so `with
  main` added or taken away moves nothing; and since M4-2's review the tasks' order is
  the timed tasks', the continuous task never due nor in a tie, so its line moved among
  the task lines reports nothing. Since M4-5 (decision 139) `accept/3`, `test/3` and
  `untest/3` take the step's time, `elapsed_ms` since the resource's last cycle, 0 unless
  given, refused in `Logex.Runtime.cycle/3`'s words, decision 40's `now` the resource's
  plus it, moving no clock; `Logex.Runner` gives the time since its last round.
  Since decision 232 an array driven whole and then by connections to some of its
  elements holds each element no longer driven, by name, `{:held, "speeds[3]", v}`, and an
  element of an array var_output at a connection's near end, `m2.o[1] speeds[2]`, drives
  where its program writes that element (`Logex.Walk.element_writes/1`).
  A step checks the edit, the runtime, its `elapsed_ms`, the generation, the configuration
  the resource runs, then the stage. Since M5-13 a located array's located-I/O refusal
  names the range its elements take, `card.i.0` to `card.i.7`, so that one grown is
  refused for its range beside its type (provisional), and an element it stops driving
  is held by its name, `{:held, "lamps[4]", 1}`. Its moduledoc gives every rule and
  report kind
- `lib/logex/compiler.ex` — the stages: `tokenize/1` and `parse/1` delegate to the two
  modules below; `instructionize/2` first checks its routine against
  `Logex.Parser.well_formed!/1` and raises `ArgumentError` on a tree no text could say
  (OE-1), then takes the declaration lines off into a tag table,
  checks every instruction against its operand signature and every operand against the
  table, members included (M1-6), names as a location an operand shaped like one whose
  first part is not declared, as `panel.i.0` (M2-2), gives each timer the preset on the
  one `ton` that runs it, refuses a second `ons` on one storage bit and anything after a `ton` on its path,
  since M3-4 a second one-shot of `ons`, `osr` and `osf` on one, in the two's words, an
  `osr` or `osf` keeping its storage bit in a member, and a coil whose pulse bit is its
  storage bit (decision 101), a coil's operands two bools it writes and nothing refused
  after it on its path (decision 100),
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
  none for anything no mnemonic gives, so it never raises. Since M3-1 its one-run rule, the
  preset it gives an instance and its path rule range over every instruction that runs a
  built-in (`Logex.FbType.rules/1`), `ton`, `ctu` and `ctd`, and since M3-2 `tof`, `tp`
  and `rto`, each message in the words of its type's kind: one
  `ctu` and one `ctd` an instance, a ctud's two agreeing on its preset (decision 85), a
  counter of the other kind told to declare a `ctud`, nothing after a counter on its path
  (decision 73), and no `ons` on a counter's `r` or `ld`, nor on an `rto`'s `r`; since M5-5
  an instance slot takes a kind, each type's `family`, so `ctu` runs every up counter,
  `ctu_int` among them, a counter of the other kind told the up-down counter of its own
  type, `var c ctud_lint`, and a preset judged in its instance's type, since decision 191
  any value of it for a counter, a signed one's negatives among them, "`ctu` takes a
  preset of -32768 to 32767 for a counter of ints", an unsigned one's 0 to its top and a
  timer's 0 to 2147483647 ms, and a preset from a tag told the `move` where the tag widens
  into the `pv` (decision 158); since decision 192 an instance slot of several kinds is
  named by every type word it runs in every message, the plain words first and then each
  width in the type table's order, "`ctu` runs a ctu, ctud, ctu_int, ctud_int, …", the
  aliases left out; since M5-6 a timer's slot names its kind, `{:instance, ["ton"]}`, so
  `ton` runs a `ton_ltime`, "`ton` runs a ton or ton_ltime", a counter given to it told no
  `ctud`, and a long timer's preset judged 0 to 2^63−1 ns, "`ton` takes a preset of 0 to
  9223372036854775807 ns for a ton_ltime", one from a tag told its unit, "a number of
  nanoseconds for a ton_ltime" (decision 158). Since M3-3
  the arithmetic, two dint values then a dint written for `add sub mul div mod`, one then
  a dint written for `neg abs`, with no rule on its path, its power out settled (decision
  98), and a literal zero divisor of `div` or `mod` refused at its line (decision 78).
  Since M3-5 `jmp` and `lbl` take one operand each in a label slot, `{:label, nil}`,
  lowered to the IR operand `{:label, line, name}`: a name with no `.` and no reserved
  word, never a tag nor a literal, of a namespace of its own (decision 105); and one pass
  over a routine's lowered rungs, `jumps/2`, refuses a `lbl` not first on its rung, which
  still labels it, a label used twice or two that differ only in case, a second `jmp` in
  a rung, a `jmp` that names no label of its routine, the nearest on a later rung
  suggested (since M3-5's review), and one back or to its own rung (decisions 81 and
  104), each at its line, a block's body its own routine, and since M3-5's review, in a
  block's body, a label spelled as the word that heads its file, in any case (§4.8,
  decision 105); `lowered?/1` holds a body's jumps to the same rules. Since M5-3
  `@instructions` holds the 56 integer conversions, `dint_to_int` and the rest, generated
  from the type table, `{:value, from}` then `{:write, to}` (decision 148); `move`'s two
  `:any` operands meet by Ed 3 Figure 11 (`Logex.Declarations.widens?/2`), every other
  pair refused naming its conversion, a bool with an integer told there is none (decision
  147); a `cal` formal widens, a var_input from a narrower tag and a var_output into a
  wider one (decision 159); a conversion's own slot is told the conversion that does the
  whole job; since decision 176 a conversion's source takes any type Figure 11 widens into
  its `from` type, a tag's or a member's, `dint_to_int` an `sint`, its destination exactly
  its `to` type. Since M5-4 (decisions 145 to 147) the slots of `add sub mul div neg abs`
  and the six comparisons take IEC's ANY_NUM and `mod`'s ANY_INT, generic types as data
  (`Logex.Declarations.is_class/1`), whose operands `classed/3` holds together: an
  instruction computes in its destination's type, so each source tag must be of a type
  Figure 11 widens into it, any other told "convert it first, with `dint_to_sint`", and a
  literal source must fit it, a three-operand `add` checked whole; `neg` into an unsigned
  destination is refused, told since decision 181 the narrowest signed type its source
  widens into, or, since decision 189, a literal source and its negation fit, `neg -128
  count` "an int", "so declare `count` a dint", a `ulint` told to convert first; and a comparison's two integers compare by value whatever their types,
  a literal beside a tag, since decision 183, a value of the tag's type, "`lt` compares
  `200` with `s`, an sint (declared on line 1), which never holds it: …", on either side,
  one at the type's own limit taken, and warned in `Logex.Warnings` where its result never
  changes (decision 187), and two literals, or one beside a tag
  not resolved, only within every integer type's values, -2^63 to 2^64 - 1. Since M5-8
  (decisions 147, 148, 155, 156 and 165) a bit string is no number: an arithmetic slot
  refuses one told the unsigned conversion of its width (`word_to_uint`, `uint_to_word`);
  the comparisons take `:any_elementary`, two bit strings or two integers, a bit string
  with an integer tag refused naming both conversions; `and or xor not` take
  `:any_bitwise`, all bit strings or all integers, held together by `classed/3` as the
  arithmetic is, and since decision 206 a bool, IEC's ANY_BIT holding BOOL, three bools
  computing in a bool and a bool widening into a bit string by Figure 11, a bool beside an
  integer refused, "and logex has no conversion between them"; `shl shr rol ror` a source and destination so and a
  count of `:any_int`, its own class, a negative literal refused; `@instructions` holds
  the 76 bit-string conversions beside the 56, generated over `convertible/0`; and a
  dotted operand whose last part is digits, `status.3` or `t1.acc.3`, is a bit of a tag
  or member of an integer or bit-string type, a bool in its slot, its number checked
  against the width ("`w.16` names bit 16 of `w`, a word (declared on line 1), which has
  bits 0 to 15"), a bool's refused ("which has no bits"), lowered to `{:bit, line, path,
  n, mask, name}`, `mask` 2^n or, a signed type's top bit, -(2^n), and since M5-8's
  review `name` the operand as written, `w.03`, which every message naming the bit
  quotes, its number keyed by its value (decision 209); a one-shot may keep its
  storage bit in a bit of a tag of its own, never of a member. Since M5-9 a dotted name
  whose last part is a tag's name in brackets, `status.[n]` or `t1.acc.[n]`, is a bit whose
  number the tag holds (decision 160), resolved as the bool it reads and writes, its
  container an integer, a bit string or such a member, a bool's or an instance's told it
  has no bits, and its tag declared and of an integer type, any width, a bit string told
  its conversion ("so convert it first, with `word_to_uint`"), lowered to `{:bit_at, ...}`
  as `as_bit/4`'s guard reads the name's last byte, so a member lowers in what it did, and
  refused as a one-shot's storage bit or a pulse coil's pulse bit, which take a literal
  number (decision 154). Since M5-8's review each
  name is split once as it lowers, an instruction whose operands hold one class is
  checked with no grouping, and a program of no bit strings compiles, against its own
  parse, in no more reductions than before M5-8 (a test in `bit_string_test.exs`). Since
  M5-11 (decision 151) a name ending in brackets is an element, resolved as a tag of its
  elements' type, its subscripts literal and each within its dimension, lowered to
  `{:element, line, array, index, name}`, `name` by the subscripts' values; an array named
  whole where an instruction takes one tag, a count of subscripts not its dimensions', a
  subscript out of its dimension and a member past an element, `w[1].3` until decision
  221, each refused at its line; since M5-12 (decision 152) a subscript may be an integer
  tag of any width, `weights[slot]` or `grid[1,c]`, a literal beside it judged as before
  in the one pass that gathers the tags (`outside/4`), each tag declared and of an integer
  type, a bit string told its conversion, an array, an instance or a reserved word
  refused, a `cal` operand's too, lowered to `{:element_at, line, array, index, dims,
  name}` and a bit of one holding it as its container, and refused as a one-shot's storage
  bit or a pulse coil's pulse bit (decision 154), "`ons` keeps its storage bit in
  `edge[slot]`, whose subscript `slot` holds"; since decision 221 a bit of an
  element, `faults[2].3` or `faults[2].[n]`, is a bit by every rule of a tag's, lowered
  to `{:bit, line, {:element, ...}, n, mask, name}`, its container the element's
  operand, told from a tag's bit by the container's last byte in `bit_ir_of/4`'s head, a
  one-shot's storage bit a literal one only; an array may not be a block's var_input or
  var_output, which a `cal` fills with one value. Since M5-11's review a dotted name with
  a subscript, `t.acc[0]` or `x.y[0]`, is a member's diagnostic, its lowering passing it
  as a member, an array named whole by `cal` or written whole with a literal is told so,
  and a label is a name with no subscript, `jmp a[0]` refused. Since
  decision 216 a real literal its slot's real would flush to 0.0 is refused by the literal
  rules, `move 1.0e-40 r` into a `real`, "it is too near 0.0 for a real, whose smallest
  above 0.0 is 1.1754943508222875e-38: it would be written as 0.0", in every slot they
  judge, a block's formal among them; and since decision 219 `literal_real/4` (no doc) is
  the one rule for the real a real literal's slot computes in, which the lowering reads
  over a rung's operands and `Logex.Warnings` over the IR's.
- `lib/logex/warnings.ex` — the warnings a compiled program carries: a tag used by no
  rung, a `var_output` no rung writes, a second `ote` on one tag, and since M1-6 another
  write to an `ons` storage bit, a comparison of two literals, a timer no `ton` runs, and
  since M2-5 an instance of a user function block no `cal` runs; since M3-1 the unrun
  warning is in its type's words, a counter no `ctu` or `ctd` runs "never counts", a timer
  no instruction of its type runs "never times", and a
  second `ote` is told by its target's path, a ctud's `r` and `ld` two bits; since M3-3 an
  arithmetic instruction whose every source is a literal: its result never changes, and
  since decision 178 a conversion of a literal in the same words; since
  M3-4 another write to an `osr`'s or an `osf`'s storage bit, as to an `ons`'s, each told
  its one-shot, and a coil's pulse bit written as an `ote` writes its tag, so that a second
  coil on it, an `ote` among them, is the second-`ote` warning, told the first in its words;
  since M3-5 a label no `jmp` names: nothing jumps to its rung (decision 105); and since
  decision 187 a comparison of a tag with a literal at its type's limit whose result never
  changes, the eight pairs `ge x lo`, `lt x lo`, `le x hi`, `gt x hi` and their mirrors
  with the literal on the left, in the all-literal warning's words; and since M5-6 a long
  timer's preset that is no whole number of milliseconds, at its instruction's line: "it
  times as the next whole millisecond, 2 ms" (§4.12's routine choice), and since decision
  196 a literal that is no whole number of milliseconds which `move`, a conversion, a
  comparison, `add` or `sub` takes beside a long timer's `.pre` or `.acc`, the first such
  member named: "`ge` compares `cure.acc` with `3000`, where `cure.acc` is a ton_ltime's
  time in nanoseconds: 3000 ns is no whole number of milliseconds, …"; and since M5-8 a
  bitwise instruction of literals in the all-literal warning's words, a coil on a bit of
  a word another instruction writes whole, either first, as the second-`ote` warning
  (decision 207), and another write to a word holding a one-shot's storage bit as one to
  the bit (provisional); and since M5-8's review a coil on a bit of a member and a write
  of the member whole, `ote c.pv.3` and `move x c.pv`, the second-`ote` warning too
  (decision 207), a bit quoted as written, `w.03` (decision 209), and decision 187's
  warning for a bit string, which compares as unsigned, `ge status 0` on a `word`
  (decision 208); a bitwise write of a bool or a bit is a write as `move`'s, no coil
  (decision 206, provisional); since M5-9 a coil on a bit a tag numbers, `ote w.[n]`, a
  coil on its word whole, two of them or one beside a coil on a bit of the word the
  second-`ote` warning, and since M5-9's review one beside any write of the word whole,
  `move x w`, either first, as decision 207 has it for `ote w.3`, and any write of one a
  whole write of its word, of each storage bit in it among them (provisional); since M5-12
  a coil on an element a tag subscripts, `ote lamps[slot]`, or on a bit of one, a coil in
  its array whole, keyed `{:array, "lamps"}`, beside another or a coil on a literal
  element or a bit of one, `ote lamps[2]`, in either order, the second-`ote` warning,
  "`lamps[2]` is in `lamps`, which the `ote` on line 5 may write through a tag subscript",
  after a literal one "`lamps[i]` is in `lamps`, as `lamps[2]` is, which already has an
  `ote` on line 5", and any write through a tag subscript a write of each storage bit kept
  in the array (provisional), and since M5-12's review a write of a word array's element
  whole beside a coil on a bit of one, `move x w[i]` beside `ote w[2].1` or `move x w[2]`
  beside `ote w[i].1`, either first, the second-`ote` warning by decisions 207 and 221, a
  bool array's element still warned of nothing beside a coil (provisional reading 3),
  until decision 235, since which a write through a tag subscript beside a coil on an
  element of a bool array, `move 0 lamps[slot]` beside `ote lamps[2]`, and a write of an
  element beside a coil through one, either first, any instruction's write but a coil's,
  is the second-`ote` warning, as for a word array, a write of an element beside its own
  coil still none; a program with no coil on a
  bit or an element looks for no whole write, and one with no one-shot for no storage bit's write. A rung a
  jump may skip is read as any rung, so two `ote`s on one tag in sections a jump makes
  exclusive are still the second-`ote` warning (decision 107, confirmed by the maintainer
  after M3-5's review); and since decision 219 a real literal with more digits than the
  real its slot computes in keeps, where the number it writes is neither the value held
  nor that value's shortest decimal (`Logex.Real.held_as/3`): "`16777217.0` is more
  precise than a real keeps: it is held as 16777216.0" (decision 224), `0.1` and `37.1`
  not, two literals compared not looked at, and since decision 227 a declaration's real
  initial value warned so at its line, `initials/2`, which the compiler hands the parse
  tree's rungs, whose literal leaves keep the spelling the tag table does not, a routine
  of no real tag reading none, a body's read again by `lowered?/1` from its source;
  since decision 221 a bit of an element a bit of its element's word for the
  second-`ote` and storage-bit warnings, a write of the element whole a whole write of it
  (`container_of/1`); each instruction holding one
  told by `by_literal/2`'s guards, so a program of none compiles in exactly what it did at
  `a8a4f8f`
- `lib/logex/walk.ex` — B5's one walk of a program's IR (M2-4): `instructions/1`, every
  instruction in rung order, groups' legs included; `uses/2`, every tag operand with its
  slot's access, a member as its instance, and since M3-4 `uses_of/2`, one instruction's;
  since M3-4 `one_shots/0`, `ons`, `osr` and `osf`, the instructions that keep a storage
  bit as their first operand, which the compiler, `Logex.Warnings` and `Logex.Edit` read,
  and `storage_bits/1`, each one-shot's bit with its line and symbol, which
  `Logex.Warnings` and the configuration's writer warnings read; `writes/1`, which tags a program writes, each
  to the lines of its writes, a `cal`'s instance and the tags its var_outputs fill among
  them; and `timers/1`, which timers it runs, each to the line and preset of its `ton`, or
  since M3-2 its `tof`, `tp` or `rto`. Since M3-1
  `presets/1`, every built-in instance it runs, which `Logex.Edit` reads, and `counters/1`,
  the counters among them, which M2-6's event-task warning reads beside `timers/1`, now the
  timers alone. Since M3-2 `member_writes/1`, the member inputs of built-in instances a
  program writes through an instruction, which an edit reads for `:unwritten` (decision 96).
  Since M3-4's review `one_shots/1`, which one-shots a program runs, each storage bit to
  the line and symbol of its `ons`, `osr` or `osf`, which the event-task warning reads
  beside `timers/1` and `counters/1` (decision 103). `writes/1` and every fact after it
  reach into every block a `cal` runs, at any depth, by path (`p.s.t1`), each
  block type read once a call. Since M3-5 a label is no use of a tag, and a rung a jump
  may skip is a rung, whose writes are writes (decision 107). Since M5-8 a bit operand
  is a use of its word, `bit_name/1` its name, `w.3`, and `bit_writes/1` each bit a
  program writes by name, which an edit reads to block a one-shot whose word the program
  that last scanned writes whole. Since M5-9 a bit a tag numbers is two uses in
  `uses_of/2`, its word's with its slot's access and its number's tag read, by a recursion
  over the slots and operands that replaced a comprehension over their zip, so a compile
  is a little cheaper than before; its write is its word's, and no bit's in
  `bit_writes/1`. The compiler, `Logex.Warnings` and
  `Logex.Edit` read it in place of walks of their own, and `Logex.Configuration.check/1`
  what a program type writes through its var_externals. Since M5-11 an element is a use
  of its array, and its write a write of its array, its name, `edges[1]`, a one-shot's
  storage bit; since decision 221 a bit of an element too, `faults[2].3` its name, and
  `element_writes/1` each element a program writes, a bit's write its element's; and
  since M5-12 an element a tag subscripts is a use of its array with its slot's access and
  of each subscript's tag read, and its write a write of the array whole, named by the
  array in `element_writes/1` (§4.12's routine choice)
- `lib/logex/declarations.ex` — declaration lines to a tag table, after parsing: the
  section and type words as data (`@sections`, the elementary types' table, and the
  function block type words of `Logex.FbType.builtins/0`); since M5-1 (`docs/organisation.md`
  §4.12, decisions 144 and 145) `table/0`, the one table of elementary types, `bool` and,
  since M5-3, IEC's eight integer widths, `sint int dint lint` (`:signed`) and `usint uint
  udint ulint` (`:unsigned`), each its word, value in a tag, kind, width in bits, range,
  zero, article and, since M5-3, `widens`, Ed 3 Figure 11's "i" cells (decision 147),
  read by `widens?/2`, with `conversion/2`, the mnemonic between two integer types, and
  `integers/0`, which every range message, article, guard and `fits?/2` in `lib/` reads, through
  `is_elementary/1` (a guard, imported where it is used), since decision 171
  `is_fitting/2` (a guard built from the table's ranges, `fits?/2`'s rule), `word/1`, `kind/1`, `range/1`,
  `zero/1`, `a_type/1`, `misfit/2`, `initial_misfit/2`, `values/1` and `either/1`, and
  `Logex.Configuration.Text` its type words, so a new type is a row there; since M5-4 IEC's
  generic types an instruction's slots take, `:any_int` and `:any_num`, as data, the kinds
  of rows each holds, read by `is_class/1` (a guard), `in_class?/2`, `a_class/1` and
  `class_range/1`; since M5-8 (decisions 147, 148 and 155) IEC's four bit strings, `byte
  word dword lword`, kind `:bit_string`, 8 to 64 bits, 0 to 2^N - 1, a bool widening into
  each and each into a wider one, with `bit_strings/0`, `convertible/0` (the integers and
  bit strings, between which `conversion/2` names the mnemonic), `unsigned_of/1` and the
  classes `:any_bitwise` and `:any_elementary`; since M5-10 IEC's two reals, `real lreal`,
  kind `:real`, 32 and 64 bits, zero 0.0, an `int` or `uint` widening into a `real` and a
  `dint` into an `lreal` only, with `reals/0`, the class `:any_real`, `holds?/2`, a
  literal's rule (an integer exactly in a real, a real literal in a real's range and in no
  integer's, since decision 216 none a write would flush to 0.0, 0.0 itself taken), beside `fits?/2`, a host's, a device's and a force's (decision 166), and
  `literal_misfit/3`, "`16777217` is no value of a real, which holds integers exactly only
  to 2^24: the nearest it holds is 16777216.0"; `kinds/0` (M2-5: the words that head a file of
  another kind, `function_block`), `reserved/1`, `block_name?/1`, `fits?/2`, `instance_of/1`
  and `not_a_program/1` (M2-5: how a message names an instance's type, a user block's
  with no article of its own, and the one message for a block type given where a program
  goes), and `check/1`, the one validator for a declaration
  line and for `Logex.Tag.new!/4`, so from Elixir too it refuses what no line can say: an
  initial value on an instance (OE-1), and until M3-3 a negative one: since a negative
  literal lexes a line can say one, so a dint's may be negative, `var tare dint -120`, a
  bool's still 0 or 1 (decision 97). Since M2-4 `var_external` is a
  row of `@sections`: a bool or a dint with no initial value and no instance, and no
  configuration file's keyword (`Logex.Configuration.Text.keywords/0`) names one. Since
  M5-11 a declaration's type word may hold sizes, `int[8]`, `{:array, type, dims}`, one to
  three dimensions of one element or more, 65,536 in all, and an initial list of one
  literal an element, each judged as a tag's value, an array of instances or sized by a
  tag refused, every rule in `array_misfits/3` too, which a configuration's global reads;
  `a_type/1` names one "an array of 4 by 8 ints" and `a_global/1` "a global array of 8
  ints"
- `lib/logex/tag.ex` — `%Logex.Tag{}`, whose type is `:bool`, `:dint` or, for an instance
  of a function block such as `var t1 ton` or `var s1 seal`, the `%Logex.FbType{}` itself,
  one `Logex.FbType.user?/1` accepts for a user block, except in a compiled program or
  block's body, where an instance of a user block names its type, `{:block, name}`, which
  the program's or the outermost type's one table holds (decision 53); and `new!/4`,
  which declares a tag from Elixir. Since OE-1 it takes no timer preset (the
  `%{"pre" => ms}` M1-6 allowed: a preset is the number on the `ton` that runs the
  timer), and since M3-3 a dint's negative initial value, which it refused until a negative
  literal lexed (decision 97). Its section may be `:var_external` (M2-4)
- `lib/logex/fb_type.ex` — `%Logex.FbType{}`, a function block type's schema (M1-6), which
  M2-5's user function blocks reuse: its members, each a `%Logex.FbType.Member{}` with a
  type, a role (`:input`, `:output`, `:internal`, and a user block's own `var`, `:local`)
  and whether logic may write it; `body`, nil for a built-in and a user block's
  compiled `%Logex.Program{}`; `ton/0`, the built-in timer; since M3-1 `ctu/0`, `ctd/0` and
  `ctud/0`, IEC's counters with IEC's pins lowercased (decisions 67 and 68), logic writing
  only `r`, `ld` and `pv` (decision 86); since M3-2 `tof/0`, `tp/0` and `rto/0`, timers
  with the `ton`'s members, an `rto` with its reset input `r` too, which logic writes
  (decision 90); since M5-6 `ton_ltime/0`, `tof_ltime/0`, `tp_ltime/0` and `rto_ltime/0`,
  the long timers, each its kind's members with `pre` and `acc` lints of nanoseconds and
  its kind's rules under its `family`, its `counts` `:lint` and its `per_ms` 1,000,000, a
  plain timer's `:dint` and 1, a counter's `per_ms` nil (decision 158); since M5-5 `ctu_int/0` to `ctud_ulint/0`, IEC's twelve typed counters, each
  its kind's members with `pv` and `cv` of its integer type and named by its word, and in
  `builtins/0` `ctu_dint`, `ctd_dint` and `ctud_dint`, each the very type of its plain
  word, so an instance keeps no spelling (decisions 158 and 163), a table built once as
  logex compiles, by `lib/logex/fb_type/builtins.ex`'s `Logex.FbType.Builtins`, internal
  (no doc), from `built/0`, hidden, since M5-5's review: built on each call it made a
  compile 3.3x dearer; and `rules/1`, each built-in type as data, its
  kind, preset member, done member, the member that says it is timing (`times`), the rule
  its forecast follows (`forecast`) and each instruction that runs it with its edge memory,
  which the compiler, the walks, the warnings and the edit read rather than match on a
  name, since M5-5 its `family`, the kind an instruction's slot takes (`family/1`), and a
  counter's `counts`, the type of its `pv` and `cv`, with `runners/0` and `runs?/2`; `initial/2`, a new instance's
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
  reads each instance it holds as a compile does; since decision 182 `destination/2`, the
  one rule for the type an arithmetic instruction computes in, its destination's, `{:ok,
  type}` an integer type or `{:error, what}`, which the scan reads, and since M5-8
  `destination/3`, `:arithmetic` or `:bitwise`, the latter an integer or bit-string type,
  "which is no integer or bit-string type" where a hand edit leaves none; since decision 197
  `units`, each timer's unit where it is not the millisecond, by name, nil where the
  routine holds none, which the compiler settles from the tag table by `units/1`, the one
  rule, a block's body holding its own; and `edited_by_hand/1` (`unwritable/1` until
  decision 197), a line for each arithmetic instruction of the program or a body it holds
  whose destination has none, and for each routine whose `units` its tags do not give,
  which only a program edited by hand gives, the check made once where a program is first
  handed in since decision 190, `Logex.Runtime.instance/1`, `Logex.Edit.accept/3` for the
  program running (decision 200) and its candidate, `Logex.Configuration.check/1` and
  `Logex.Configuration.Edit.accept/3` for the program types the resource runs (decision
  200): one walk of the rungs, a clause an element, each body once; and since M5-10
  `reals`, each real tag by name to its type, nil where the routine holds none, settled
  with `units` by `settled/1` in one pass of the tag table, a body holding its own, and
  held to its tags by `edited_by_hand/1` as `units` are; and since M5-11 `arrays`, each
  array tag by name to its type, nil where the routine holds none, settled with them, a
  real array's name among the `reals`, held to its tags by `edited_by_hand/1` too
- `lib/logex/lexer.ex` / `lib/logex/parser.ex` — the front end, written by hand: binary
  pattern matching, and recursive descent (the parser's moduledoc gives the grammar and
  which function parses each production). `Logex.Parser.well_formed!/1` is the definition
  of a well-formed parse tree, exactly what `parse/1` can produce, which
  `instructionize/2` checks on entry (OE-1). Since M3-3 a `-` glued to digits is a
  negative literal's sign, one `int_lit` token at the `-`, and a sign begins a lexeme, so
  `a-5` and `5-3` are one mistyped lexeme each, `{:signed_inside, run}`, as B2 names
  `1bst` (decision 97); a `-` with no digit straight after it, `- 5` or `--5`, is still
  illegal, and there is no `+`; `well_formed!/1` takes any integer. Since M5-7 (decision
  149) a number may be based, `16#ff`, `16#FF` or `2#1010`, in base 16 or 2 alone, with no
  sign, or hold a single `_` between two digits, `1_000`, one `int_lit` token holding the
  value it spells, a plain decimal still read by `String.to_integer/1`; another base, a
  sign, a misplaced `_`, a digit outside its base or, since M5-7's review, a second `#`,
  `16#ff#`, is a located lex error naming the number whole, `{:base, run}`,
  `{:signed_based, run}`, `{:separator, run}`, `{:digits, base, run}` or `{:hash, run}`,
  a base judged before a sign, so `-8#17` is `{:base, run}`, and `5U` B2's. Since decision
  202 a rung keeps a literal's spelling: a literal written as the plain decimal of its
  value is the token `{:int_lit, loc, 255}` and the leaf `{:int_lit, line, 255}` it always
  was, and one written any other way, `16#ff`, `1_000`, `007` or `-0`, keeps its text as a
  fourth element, `{:int_lit, line, 255, "16#ff"}`, in the token, the tree and the IR,
  told from a plain decimal by its first two bytes in the lexer's clause head, so a plain
  one costs what it did; `well_formed!/1` takes a spelled leaf whose spelling lexes as one
  literal token of its value that holds it, `Logex.Parser.spelled?/2`, the one rule, which
  `Logex.Compiler.lowered?/1` reads too, and `Logex.Parser` gives the guard
  `is_int_lit/1`, `value/1` and `spelling/1`, which every message quoting a literal reads,
  so it is quoted as written, "`move` writes `16#ffff` into `i`". Since M5-9 (decision 160)
  a name's last part may be a tag's name in brackets, `status.[n]`, the name one token
  ending at its `]`; since decision 213 a literal in them, `s.[4]`, `s.[16#4]`, `s.[1_0]`
  or `s.[-1]`, any one number the lexer reads closed by its `]`, is a name token too, kept
  as written, which `Logex.Compiler` reads as the bit `s.4` (`literal_number/1`), a
  negative one refused there as outside the bits, and brackets that begin as a number and
  hold no one number, `s.[3x]` or `s.[8#3]`, `{:bracketed, run}`; anything glued after the `]`
  `{:after_bracket, run}`; and since M5-9's review brackets no one name fills and closes,
  `s.[]`, `s.[n` or `s.[ n ]`, `{:bracket, run}`, and a bracket held apart from its
  name's `.`, `s. [n]` or `s .[n]`, `{:detached, run}`, where until then each ended the
  name before its `.`, an illegal character; each named whole, through its `]` on the
  line (provisional). There is no generator, so nothing reports a
  Since M5-10 (decision 149) a real literal is digits, a `.`, digits and an optional
  exponent, `37.5`, `-0.25`, `1.5e3` or `2.5E-3`, `_` between two digits as an
  integer's, the token and leaf `{:real_lit, line, float}`, or with its spelling as a
  fourth element wherever it is not `Float.to_string/1` of its value, `-0.0` lexing as
  0.0 spelled; `1.` and `.5` are `{:point, run}`, `1e5` `{:no_point, run}`, `1.5e+3`
  `{:plus, run}`, `1.5e` `{:exponent, run}`, one past an lreal `{:real_range, run}`, since
  decision 216 one nearer 0.0 than an lreal's smallest normal value `{:real_small, run}`,
  until decision 228, since which a subnormal double, `1.0e-310`, is read as itself, its
  slot refusing it, and only one no double holds but 0.0, `1.0e-400`, its digits not all
  0, is `{:real_small, run}`, until decision 231, since which it is read as 0.0 spelled,
  `{:real_lit, line, 0.0, "1.0e-400"}`, no new shape, `Logex.Parser.underflowed?/1` the
  one rule that tells it from a zero by its spelling and `is_zero_real/1` its guard, each
  slot refusing it in decision 228's words, a configuration file's reader giving it as
  `{:real_small, run}` still and a forces file no force (provisional), and
  `1.5L` B2's mistyped lexeme, "missing separator after a real"; `Logex.Parser` gives
  `is_real_lit/1` and `is_literal/1`, a literal of either kind, beside `is_int_lit/1`.
  Since M5-11 (decision 151) a name may end in one pair of brackets straight after it,
  subscripts split by `,` with no space, each a number the lexer reads or a tag's name,
  `grid[1,7]`, `int[4,8]` or `w[slot]`, one name token, a `.` part allowed after the `]`,
  so the parser and `well_formed!/1` are unchanged; brackets no subscripts fill and close,
  or held apart, `{:subscripts, run}`, and anything but a `.` glued after the `]`
  `{:after_subscripts, run}`, each named whole.
  grammar conflict: **a new syntax form goes into `printer_test.exs`'s generator and
  `@required_shapes` before it lands**, and the golden record below must stay green.
- `lib/logex/printer.ex` — the parse AST back to canonical source text, one rung a line
  and single spaces, each literal exactly as it was written (decision 202), `16#00ff`,
  `1_000` and `007` among them, where until then it wrote each in decimal, and since M5-10 a
  real literal as written, `1.5e3`
- `lib/logex/diagnostic.ex` — `%Logex.Diagnostic{stage:, line:, message:, file:, column:,
  severity:}`, the one error and warning type of every stage, and `format/1` for the
  `motor.ld: line 3, column 5: …` form
- `lib/logex/fault.ex` — `%Logex.Fault{severity:, kind:, instruction:, path:, file:, line:,
  read:}` (M3-3, decision 99; `severity` and `read` since M5-9, decisions 153 and 160), a
  fault a scan met and ran on through: `:minor`, a zero divisor of `div` or `mod`,
  `:divide_by_zero`, `read` nil, and `:major`, a bit whose number a tag holds out of its
  word's bits, `:bit_out_of_range`, `read` the number, since M5-12 an index out of its
  dimension, `:index_out_of_range`, `read` every subscript, since decision 233 a tuple,
  `{8}`, on which `Logex.Runner` trips: `path` nil on the program's own rungs, or
  the block instance it ran in, `s1` or `s1.inner`, and `file` and `line` those of the
  routine that holds it, a block's its body's; plain data, in a lone instance's `faults`
  and a cycle's `{:fault, task, instance, fault}` events, `task` `:none` for a task-less
  instance, never raised; since M5-10 a third kind, `:negative_sqrt`, `:minor`, `read` the
  source `sqrt` met (decision 164)
- `lib/logex/real.ex` — `Logex.Real`, internal (no moduledoc, M5-10, decisions 150, 156,
  161 and 166), the one place a real's value is made, read and spelled: `stored/2`, the
  value a number takes in a real type with the power it passes, `nearest/2`, a `real`'s
  through the BEAM's 32-bit encoding and an integer's rounded once from the integer
  itself, `in_range?/2` (decision 166's rule), `exact?/2` (decision 147's literal rule),
  `value?/2` (what a state may hold), `round_even/1`, `spelled/2`, the shortest text that
  reads back to the value, a single's for a `real`, and since decisions 216 and 219
  `flushed?/2`, whether a write would flush a number to 0.0, the literal's refusal, and
  `held_as/3`, a real literal's warning, `{:rounded, shortest}` where the number its text
  writes is neither the value held nor that value's shortest decimal, each judged exactly
  as a fraction; `read/2`, which took only the runner's spelling, gone with decision 218. A float past a single's range has no single, the 32-bit encoding giving
  infinity's bits, so every caller holds a `real`'s value to `in_range?/2` first
- `lib/logex/runner/clock.ex` — `Logex.Runner.Clock` (M4-1, `docs/organisation.md`
  §4.11), the behaviour the wall-clock runner will read time through, so that a test can
  move time: `now_ms/1`, `wake_at/4`, a message to a pid at an absolute time and no
  sooner, and `cancel/2`, a clock being `{module, term}`; its three checks, hidden,
  `receiver!/1`, `time!/1` and `timer!/1`, give both clocks one message a rule.
  `lib/logex/runner/clock/monotonic.ex`, `Logex.Runner.Clock.Monotonic`, is the
  machine's: `System.monotonic_time/1` in ms and `Process.send_after/4` to an absolute
  time, a time already past brought to now, since the VM refuses one from before it
  started, and one later than the VM can time the host's mistake.
  `lib/logex/runner/clock/manual.ex`, `Logex.Runner.Clock.Manual`, a GenServer a test
  moves: `advance/2`, in the caller, delivers each timer due on the way, the earliest
  first and ties in the order set, and calls its receiver through `:sys` from the same
  process, so it goes on only once the receiver has handled its message, by construction,
  one sender to one receiver; a timer set while one is handled comes in the same advance
  where its time falls inside it; `pass/2` is time passing inside a step, delivering
  nothing, the clock never going back; `pending/1` lists the rest. A receiver is an OTP
  process; one that is down, or goes down with whatever reason, `:timeout` among them, is
  passed over, the caller may be one, and one still alive that does not answer within
  `wait:`, 1 to 4294967295 ms, the longest the VM waits, is the host's mistake. Its timers are a gb_tree, so delivering n is n log n. Since M4-4 a receiver may
  advance it while it handles a message an advance delivered, the timers on the way
  delivered to the others, time passing inside a step where `pass/2` delivers none, as a
  runner stuck in a task's run is tested. `Logex.Runtime` reads no clock, and only the
  runner does
- `lib/logex/io.ex` — `Logex.IO` (M4-1, `docs/organisation.md` §4.5 and §4.11), the
  adapter behaviour: `init/3`, a device's name, its points and the options it was bound
  with, run in the device's process, `{:ok, state}` or `{:error, reason}`; `read/1`, some
  or all of its input points; `write/2`, every output point, by address; and two optional
  callbacks, `report/2`, the inputs a message the device's process received says changed
  (decisions 112 and 120), and `close/1`, once, after the last zeros, with a third since
  M4-1's review, `check/3`, given what `init/3` will be, in the host's process, and giving
  the host's mistakes in the options, a line each. A callback fails by giving `{:error,
  reason, state}`, never by raising (decision 114). `points/1` groups a
  configuration's located points by device, each device's in the configuration's order,
  since M5-13 a located array's a point an element named `temps[3]`, and an unbound
  device's message naming an array's elements as their range,
  each a `%Logex.IO.Point{}` (`lib/logex/io/point.ex`: name, direction, address, type),
  the configuration checked as `Logex.Runtime.start/1` checks it, in its words; and
  `bind!/2` checks a host's bindings, `%{device => module | {module, options}}`, against
  them as `Logex.Runner` will at start, giving `{device, module, options, points}` in
  device-name order, or one `ArgumentError` with every mistake, a line each, a key that
  is no device's name first: a device no adapter is bound to, with the points at it; a
  device bound that no point is at, with a did-you-mean; a binding or options that are no
  adapter's; an adapter that lacks `init/3`, `read/1` or `write/2`, or is no module; and
  each line an adapter's `check/3` gives, or a check that gives no list of them; linear
  but for a sort of the names and the did-you-mean, quadratic in the devices and the
  bindings no point is at, as `Logex.Configuration`'s refusals are
- `lib/logex/io/sim.ex` — `Logex.IO.Sim` (M4-1), the one adapter logex ships, a
  simulated device in a GenServer of its own, the fixture of every runner test, bound as
  `{Logex.IO.Sim, sim: sim}`, which its `check/3` and `init/3` hold it to, `sim:` alone
  and a sim that runs and that no other device holds open, a sim being one device's, so
  that another device's process opens it only once the first has closed it or gone down:
  `start_link/1` (`reports:`, `clock:` a manual clock, `wait:`), `set/2` and `set/3` its
  inputs, `outputs/1`, `writes/1`, `reads/1` and `closed?/1`. Where it reports, the inputs
  a set changes go as one report to the device that opened it, from the caller, which
  waits through `:sys` until that device has handled it, by construction, a device that is
  down, or goes down with whatever reason, passed over. `fail/3` acts
  out one failure on the next call of the callback it names, in the order told: an error,
  a raise, a throw, an exit, a hang, a delay on its manual clock or slept without one,
  and, for a read or a report, a value of the test's choosing. Every mistake a test can
  make with it raises a pinned `ArgumentError`; since M5-10 a point's value any number, a
  real point's a float or an integer, the runner checking it against its type; since
  M5-13 `inputs:` and `outputs:`, how many points of each direction it has, nil for any,
  its `check/3` and `init/3` refusing a point past them, the first ten and then a count
- `lib/logex/runner.ex` — `Logex.Runner` (M4-3, `docs/organisation.md` §4.11), the
  wall-clock runner, a GenServer, `restart: :temporary` (decision 115), the one piece of
  logex that reads a clock: it owns one configuration's `%Logex.Runtime{}` and runs it in
  rounds, a round the inputs taken, the cycle's steps run (`cycle_steps/3`, decision 118)
  and the outputs written. `start_link/1` takes `configuration:`, `io:`, `clock:`,
  `poll:` (10 ms), `overhead:` (20%, 10 to 90), `idle:` (500 ms), `forces:` (a path, none
  unless set, M4-5, decision 127) and `name:` (decision 121), each checked in the caller in order, each once, the configuration as
  `Runtime.start/1` and the bindings as `Logex.IO.bind!/2` check them, in their words; it
  then opens every device inside `init/1`, in device-name order, before it handles
  anything sent to it, so that a call or a stop by its name that comes first waits, and
  one that cannot be opened is `init/1`'s `{:error, {:io_init, device, reason}}`, the
  runner exiting normally and every one opened before it closed, reads each once and
  runs the first round at once. The rounds: `anchor` and
  the resource's `now` (`logical`), each round passing the time since the last, one wake
  on the clock at an absolute time with a token that makes an earlier one stale; while
  untimed programs exist, back to back, the next at the millisecond after the one the
  last began in or at once where it took one or more (decision 122); a periodic due time
  a wake of its own; a device's change of an event task's trigger, an input point that is
  a `single`, its own round at once, in address order (decisions 120 and 124); a trigger
  logic writes, changed by a round, the next round at the next millisecond (decision
  123); the share's slots, C ms of the continuous task's rounds, each from its start to
  its end, a millisecond at least, the timed tasks' runs left out, and then, at the end
  of the round that completes them, up to S ms of the host's requests that waited, its
  first whatever the time, each whole, and freely in the rest of a millisecond no round
  wants; a request served at once where no round is owed, and always with no untimed
  program, so on the manual clock one made while a round is owed waits for its slot, in
  the advance that runs the round completing C ms, never later, and a test makes it from
  another process (decision 131); a continuous task that runs no instance timing no
  round; and while it waits a refresh at least once a poll period.
  Every device is refreshed before each step with its task's watchdog and a poll period
  from the step's start, and before its own work, a request served, a slot, a write or a
  wait with `idle:`'s (decisions 125 and 128); a refresh calls no adapter. Its calls go
  through its mailbox, a host's mistake in one relayed and raised in the caller, a
  request still queued at a stop, or left unanswered as the runner goes down, raising
  that the runner is not running, a cast or a message passed over and a call none of its
  functions makes answered as the caller's mistake: `get/2`, `get!/2`,
  `status/1` (running, `now`, rounds, overlaps, each task's longest run against its
  watchdog, the latest wake, the longest wait between refreshes), `subscribe/2` (overlaps
  and faults by default, `:ran` and `{:round, now, outputs}` where named, a subscriber
  monitored) and `unsubscribe/1`; and `stop/2`, every output 0 once and every device
  closed before it returns (decision 116). Since M4-4 it traps exits, and a trip has one
  path (decision 113): scheduling stopped, every output 0 once through each device that
  answers, which latches, `{:trip, reason}`, the requests that waited answered, the
  resource kept for `get/2`, and `restart/2`, cold or warm, releasing every latch, a
  device that does not answer killed, then reading every device once, in device-name
  order, as a start does, opening again each device that went down, those among them
  (decision 142), one that cannot be opened or whose read fails or does not fit leaving
  the runner tripped with its first reason, `{:error, {:io_init, device, cause}}`, and
  every device latched again and written 0 once more (decision 136),
  `Logex.Runtime.restart/2` and the first round at once, on what was read, the
  stopped time not counted, a running runner's restart the host's mistake (decision 133).
  A device's notices that waited are taken together, by the time each was raised, ties in
  device-name order (M4-4's review). Its
  reasons: a timed task's run longer than its watchdog, `{:watchdog, {:task, ...}}`; a
  continuous task's round, from its inputs to its last scan, `{:watchdog, {:round, task,
  took, limit, steps}}`, each step named with its time (decisions 110, 111 and 126); a
  request served whole longer than `idle:`, `{:watchdog, {:idle, ms}}` (decision 128);
  a device latched on its deadline, `{:watchdog, {:device, device, ms}}`, `ms` the
  heartbeat its last refresh gave it (decisions 125 and 137); since M5-9 a major fault,
  `{:fault, task, instance, fault}`, the round's first, at the end of the step whose run
  met it, before any later step of the round and its write, and before a watchdog of the
  same step (provisional) (decisions 153 and 160);
  an I/O fault, `{:io, device, cause}`, an error, a raise, a throw, an exit, a result of
  no shape, a bad value, an unknown address, `:timeout` (no answer within its deadline in
  real time, the device killed; one answered late on the runner's clock, written its 0
  by the trip; or, since M4-4's review, a device not heard back from its adapter within
  `idle:` and a poll period, checked as each round begins and at each wait's refresh,
  killed, decision 134) or `{:down, reason}` (decision 114), the failed device written
  its 0 too where it still takes a write (decision 135); and an
  exception out of the core, `{:internal, message}`, through the core's three calls
  guarded and reached by a test through one hidden option, `steps:`, a module standing in
  for the cycle's steps. Every check comes before the round's write. A clock that goes
  down or fails stops it, `{:shutdown, {:clock, reason}}`, as a stop does. Since M4-5
  it forces input points (decisions 117 and 127): `force/3`, `unforce/2` and
  `unforce_all/1`, each force merged over the devices' changes into every round's inputs,
  after the input latch, across a restart and, kept in the forces file, across a crash
  and a fresh start, `unforce/2` putting back the device's last value, which the runner
  keeps for each input point, a force or an unforce that changes what a trigger reads
  making its round at once, before the call returns, each trigger it changes its own,
  in device-name and then address order, and a device's change of a forced trigger
  none (decision 138); `status/1` lists every force; each force and unforce writes the whole set
  to the file before it returns, `name value` a line in name order, to `<path>.tmp`
  beside it, flushed and renamed over it, a write that fails changing nothing,
  `{:error, {:forces, reason}}`; every start reads it, `start_link/1` in the caller and
  `restart/2` before it releases anything, a file that does not exist no force, one that
  cannot be read, a line that is no force, a point forced twice and a force the
  configuration cannot take the host's mistake, every one named a line each, the runner
  not started or left tripped, the file read exactly as written (decision 140), a real point's force since M5-10 held at its type's nearest value, 16777217
  as 16777216.0, and written as the shortest text that reads back to it, a single's for
  a `real`, `fan_hz 0.1` (decision 156), and since decision 218 its line read as any
  number the lexer reads as one literal, `fan_hz 37.50`, `3.75e1` or `16#25`, held at its
  nearest, the next force writing the file again, and since decision 226 an integer or
  bool point's any integer the lexer reads, `eye_1 01` or `level 16#ff`, held to its type,
  the next force writing plain decimal, and since M5-11's review the value its text
  alone, `n 1//c` or a tab after it no force, and one a float holds nearer 0.0 than an
  lreal's smallest normal, `1.0e-310`, a literal since decision 228, held as 0.0 at a real
  point; a runner without `forces:` takes no force, and an output
  point or a value that does not fit is refused; since M5-13 an element of a located
  array forced, unforced and written in the file by its name, `temps[3] 37.5`, the array
  named whole, an output element and an element the array lacks refused in pinned words. And it steps an online edit
  (§4.11, "Edits"): `accept/2`, `test/1`, `untest/1`, `assemble/1` and `cancel/1`, each a
  call between two rounds, the runner holding the edit, a second accept superseding the
  first; accept's work done in the caller's process against the resource the runner
  hands it with its count of steps, held only where no step came between and otherwise
  done again (decisions 119 and 141); each step `{:ok, report}`, `{:edit, step, report}` sent and
  `status/1`'s `edit` the stage; after each step the rounds reading the configuration
  the resource runs, its watchdogs (decision 129) and untimed programs, a step that
  leaves none serving at once, in order, every request that waited for a slot, and the next
  round planned again from the last, so that a cut interval is next due where decision
  40 moves it, its `now` the step's time on the runner's clock, given to the switch as
  `elapsed_ms` since the last round, 0 while tripped (decision 139).
  `lib/logex/runner/device.ex`, `Logex.Runner.Device`, internal (no moduledoc), one
  GenServer for each bound device, linked to its runner: `open/1` calls the adapter's
  `init/3` and reads it once; it reads every poll period on the runner's clock, on a grid
  from its opening, and gives every other message to the adapter's `report/2`; what
  changed since the runner last took a change of it it passes to the runner by a call, one
  change at a time, answering the runner's own requests while it waits (decision 124), a
  change the runner refuses for a value that does not fit or an address that is no input
  point's not taken, so that the next read passes it on again (fix found by M4-6's walk),
  since M4-6's eighth verification its refused point's reading dropped and the rest kept
  (decision 143),
  the device keeping each point's newest reading the runner has not taken and passing on
  what differs, a restart reading the device whole since decision 142, and each change
  carrying the count of restarts it was read under, so that one read before the runner's
  last restart and taken after it is answered `:stale`, taken by neither, its readings
  given with the restart's read; `write/2`
  writes, answered once written; at each poll, after its read, it writes its last
  outputs again, whether or not a round wrote within the period, a fixed timer as
  Logix's RPI, while its last deadline has not passed, one never written or with no
  output point writing nothing (decision 130, as the maintainer amended it, superseding
  decision 132);
  `refresh/3` carries a deadline and the time it was sent, without a wait, the device
  keeping one wake on the runner's clock at it and latching, every output 0 once and a
  notice to the runner, where it hears nothing by it, in its wait for the runner too,
  one latched already telling it nothing (decision 125, M4-4); `close/1` writes 0 to every output once, a device with none
  written nothing, closes the adapter and stops; since M4-4 every callback is called
  guarded, a fault of its own read, report or write again a notice and a latch, a round's
  write's an `{:error, cause}` answer; each notice carries the time it was raised; after
  every read and report, and at a poll while it waits on the runner, it tells the runner
  it is back from its adapter, `{:back, name, nil}`, a message a poll period (M4-4's
  review); `zero/1` latches it for a trip, `release/1` undoes that for a restart and
  forgets what it last wrote, and `reread/1`, a restart's, reads its adapter once, as its
  opening does, merged over every reading it holds untaken, giving every value or the
  read's fault (decision 142), what it read becoming what it last passed on only once the
  runner, having checked it, casts `taken/2`, or, refusing it, `refused/2` with the cause,
  which drops the refused point's reading and holds the rest, so that a read the runner
  refuses leaves nothing behind to hide the fault, and from its release until then
  passing nothing on, a reading between the release and the reread, or one passed on
  before it and answered stale, superseded by the reread for each point it gives and
  given with its answer for each point it leaves out, so checked as the restart's read
  (M4-6's seventh and eighth), and one after it held and passed on against it once taken
  (M4-6's fourth verification), a report that came before the reread, handled late
  because the device waited on the runner meanwhile, dropped, for each point the reread
  or a poll since gives, by a fence the device sends itself just before the reread
  reads (M4-6's fifth, sixth and eighth), and a zero, a restart refused, passing on what
  it held (M4-6's eighth); each call takes
  the runner's timeout; a close answered
  while it waits on the runner stops it closed; and it traps its runner's exit, writing
  every output 0 once, where it had not, and closing as it goes (decision 115)
- Tests in `test/logex/` mirror compiler stages: `lex_and_parse_test.exs`, `instructionize_test.exs`, `evaluation_test.exs`; `validation_test.exs` holds every diagnostic and warning `instructionize/2` gives, driven from source. `diagnostic_test.exs` pins what each stage stamps on a `%Logex.Diagnostic{}`, beside `format/1`'s doctests, and `lexer_binaries_test.exs` that the lexer cuts each name and number out of the source as a heap binary, which no comparison of tokens can see. `test/logex_test.exs` pins `Logex` (and walks Milestone 1's done sentence and, from files on disk, Milestone 2's and Milestone 3's, the last a bottling line under a `.logex` configuration against an oracle that knows nothing of logex, edited while it runs), `runtime_test.exs` every message the runtime raises and the exact public surface, a program edited by hand whose arithmetic destination has no integer type refused where it is first handed in, traced there and on no scan, a cycle or a switch, one swapped in after its check trusted and a scan that reaches its destination raising, with the check's growth (decisions 182, 190 and 194), and since decision 200 an edit's accept refusing a program running edited by hand, before its candidate, and a configuration edit's refusing a program type the resource runs, an instance that is no map and a timer's `last` that is no integer or later than the instance's `now` refused (decisions 184, 186 and 188), `walk_test.exs` each fact of `Logex.Walk` from source, at depth, with its growth, `counter_test.exs` every rule of a scan of M3-1's counters from source through `call/4`, `timer_test.exs` every rule of a scan of M3-2's `tof`, `tp` and `rto` from source through `call/4`, `arithmetic_test.exs` every rule of a scan of M3-3's arithmetic from source through `call/4`, near the dint's limits and in a block, and since M5-4 every rule at every integer width's two limits against each width's range, Figure 11 and the wrap restated, 127 + 1 in an `sint` and 0 - 1 in a `usint` among them, every source Figure 11 widens computed in its destination's type and every other refused naming its conversion, a three-operand mismatch, `neg` into an unsigned type refused, told a signed type to declare (decision 181), the zero divisor and the minimum by -1 at every width, a member's and a block's destination, a division wrapped in its destination's type whatever its divisor's, each worked example of `docs/naming.md`'s amendments, the comparisons of every pair of widths at their limits by value, a literal compared with a tag at each width's two limits and one past each, refused (decision 183), one at a limit warned where its result never changes, against the result restated at the type's ends (decision 187), a literal `neg` source told the type its negation fits (decision 189), and the arithmetic's growth in reductions, the compile and the scan each apart, `pulse_coil_test.exs` every rule of a scan of M3-4's `osr` and `osf` from source through `call/4`, a frozen block's among them, `jump_test.exs` every rule of a scan of M3-5's `jmp` and `lbl` from source through `call/4`, each frozen kind of state, a jump in a block's body and the block list across a skip among them, a memory on a group's leg too, with its growth tests in reductions, `fault_test.exs` every rule of the minor fault a zero divisor raises, the severity of both kinds since M5-9, the index fault's kind, `read` its subscripts, since decision 233 a tuple that no `inspect/1` shows as a charlist, alone and as a cycle's event since M5-12, a lone instance's, a block's by its path and file, a resource's events, across an edit, its host mistakes and its growth in reductions, `clock_test.exs` every rule of M4-1's clocks, the manual one's on itself and the monotonic one's on the real clock for liveness only, with its growth in reductions, `io_test.exs` every rule of `Logex.IO.Sim`, its reports and failures, and of `Logex.IO.points/1` and `bind!/2`, §4.4's plant from files on disk among them, every mistake a host or a test can make pinned and the bindings' growth in reductions, `runner_test.exs` every rule of M4-3's runner on the manual clock with simulated devices, every host mistake of its start and its calls pinned with the runner alive, what reaches it before its devices are open (a name whose registration puts a call or a stop in its mailbox first), while it stops and from no host, the devices' opening, reads, reports, writes, writes again at every poll, a fixed timer (decision 130), a device a round writes
  every millisecond or every 5, 10 or 20 ms counted exactly, and refreshes, traced, the rounds, the share's slots at 10%, 20%, 50% and 90% and S on a clock whose every reading takes a millisecond, a call answered in the advance whose round completes its slot (decision 131), 100,000 periodic rounds on their grid, stop, status and subscriptions, the review's survivors each a test, with its growth in reductions against the instances and the devices and idle and busy devices' writes a poll period, `trip_test.exs` every rule of M4-4's watchdogs and fault path on the manual clock, since M5-9 the major fault's trip at the end of its step, before the round's write and any later step, a second instance of the faulting task scanned and a later task's instance read as the round before left it, a `cycle/3` host given the event and every step, the untimed programs' step, a minor fault tripping nothing, a restart cold and warm, and a fault and a watchdog on one step tripping for the fault, and since M5-9's review a step that meets two major faults tripping for the first, a hung device's deadline and a device waiting on the runner on the real clock, short: a trip's one path, every output 0 once and nothing after, the resource kept, `restart/2` cold and warm, each trip's reason, a timed task's, a round's naming its steps, the idle watchdog's, a device's deadline with a runner stuck in a step (the clock advanced from inside it) or in its own work (suspended), each kind of I/O fault, a device killed or gone down and opened again at a restart, a device that cannot be opened at start or at a restart, a clock gone down, the runner killed or crashed, and the hidden seam, `steps:`, with the trip's growth in reductions against the devices, and since M4-4's review a restart that writes nothing from before the trip, a device hung inside its read (held with `:sys.suspend/1`) or while the runner is tripped, notices taken in the order raised, a stop or a crash while a device waits on the runner closing it once, a restart taken while a latched device's last deadline passes tripping on no notice from before it, and a restart a trip serves from its queue tripping on no notice raised before its release, taken with the trip's or come in while the trip ran, nor taking a device for hung, each device's notices carrying the count of restarts its release gave it, and each survivor of the review's mutants, and since M4-6 a device that goes on giving a value that does not fit refusing each restart with its fault, and since M4-6's review a restart a device refuses giving the device's own reason, and since decision 142 a restart's read of every device, a card still bad leaving the runner tripped and written only 0, a card put right letting it run on what it gives now, cold and warm, each kind of read fault in the card's words, a card hung in it killed and opened again, and the first in device-name order, and since its third verification a restart's read or a poll's change the runner refuses leaving nothing in the device to hide the same fault later, a change read before a restart and taken after it stale, tripping nothing and overwriting nothing the restart read, and a restart's read the value an unforce puts back, and since its fourth a poll's or a report's change read between a device's release and its reread passed on by neither, on the manual clock and the real one, one read between the reread and its taking passed on against it, several of some points each merged, a restart's read of some points keeping the rest of the device's image, and a device whose restart is refused passing its changes on while tripped, and since its fifth a report waiting in a device's mailbox while it waits on the runner, sent before its release, before its reread or before a refused restart's, overwriting nothing the restart read, and since its sixth a report sent while the restart's read samples passed on after it, and since its seventh a report between a device's release and its reread of a point its read does not give taken by the restart, a bad one refusing it with the device's fault, one passed on before the release still stale, and reports superseded by the reread where it gives their points and taken where it leaves them out, `force_test.exs` every rule of M4-5's forcing on the manual clock, a forced input against its device and across a restart, a forced trigger's round, one for each trigger `unforce_all/1` changes, in device-name and then address order, the device's last value put back, a device opened again at a restart's among them, the forces listed before a first round that trips, the forces file written whole, renamed over, a write that fails changing nothing, read at every start with every refusal as one whole message, a runner killed and started again from it, and every host mistake, with its growth in reductions against the forces, and since decision 226 an integer or bool point's line in five spellings each held to its type and written back in plain decimal by the next force, `runner_edit_test.exs` every rule of an online edit stepped through the runner, each report the one the same step gives over the resource directly, accept's work in the caller's process (traced, and in reductions), an accept another host's step overtakes done again, the rounds after a step reading the watchdogs and untimed programs of the configuration run, decision 40's move with no round lost or added, the share's slots of an untimed program an edit adds, the requests that waited for a slot served in order after a step that leaves no untimed program, each step's event while tripped, and every host mistake, `edit_test.exs` every message, diagnostic and rule of `Logex.Edit`, `configuration_test.exs` every diagnostic, warning and host mistake of `Logex.Configuration`, as whole lists from data and again from source, the loader of `compile_file/1` from files on disk, and the configuration file's round trip, seeded, located arrays among its draws since M5-13, its totality over every argument and its growth, `configuration_text_test.exs` every line a configuration file's reader refuses, as whole lists from source, and what a line can say, `scheduler_test.exs` a test at least per rule of a cycle, one copy of a global shared through `var_external` among them, an event task's edges with decision 39, and the continuous task's instances under its name (M4-2), and the cycle in steps composed as `cycle/3` over seeded configurations (M4-3, decision 118), `function_block_test.exs` every diagnostic, host mistake and rule of M2-5's user function blocks, from source, the loader of `compile_file/1` among them, an online edit of a program that holds them among them, with its growth tests in the block list's bytes (decision 32), `config_edit_test.exs` every host mistake, refusal and rule of `Logex.Configuration.Edit` on §4.4's plant, a watchdog's and the continuous task's since M4-2 (decision 129), the refusals as whole lists from source and from data, with its growth tests in the instances, the types and a program's size (OE-2), and since M4-2's review in the tasks and instances grown together, and `type_table_test.exs` M5-1's table, every message built from it pinned for both types as it was before the table, since M5-3 its nine rows and Figure 11 restated, `integer_width_test.exs` every rule of M5-3's integer widths from source, each width declared everywhere a dint is at its limits and one past them, `move` over every pair by Figure 11, the 56 conversions over their limits against a wrap restated, since decisions 176 and 178 each over every source type that widens into it and warned of a literal, a `cal` formal and a connection widening, a `var_external` binding exactly, an edit of a width, the reserved words, a point of each width through the runner and its forces file, and the conversions' growth in reductions, and greps that `lib/` holds no type list for a guard, no range or article written by hand, and since decision 202 every diagnostic, warning and configuration reader's message that quotes a literal quoting it as written, a quantity a message computes as a value, an edit that only respells a literal changing no rung, and a spelled literal's compile bounded over a plain one's in reductions, `typed_counter_test.exs` every rule of M5-5's typed counters from source, each kind of each width at its two limits, a `ctu_ulint` past 2^63, a preset judged in its type, an edit of a width refused and of an alias accepted with no report, the edge memory on the block list, the event task's warning, each alias compiling to its plain word's program and named by its plain word in every message and warning, the fifteen words reserved, and the counters' growth in reductions, since decision 191 a negative preset on a signed counter, its done lamps, a lone up counter's below one among them since M5-6's review, load and an edit's preset rules and forecast, and since decision 192 the slot's every word, and since M5-5's review a type word's lookup and reservation in tens of reductions and a program of bools compiling in under 20x its own parse, a table built on each lookup making it 40x, `long_timer_test.exs` every rule of M5-6's long timers from source, PLAN's Done-when (a 30-day `ton_ltime` done at exactly 30 days, 1,500,000 ns done at 2 ms and warned of, the one rung `ton t 2000000` at 2,000,000 ms and at 2 ms), each long timer scanned beside its plain timer over seeded scans and restarts, its `.pre` and `.acc` a million times theirs, each kind's own rules in ns, a frozen block's and a skipped rung's catch-up, an edit to or from a plain timer refused, a preset moved and forecast in ns, a resume by its type's `times` member, a `tp_ltime`'s edge on the block list, the presets, messages, warnings and reserved words, the host contract, the event task's warning, a cycle and the runner counting whole milliseconds, and its scan's growth in reductions against a plain timer's, and since M5-6's review a plain timer's energised run bounded over its de-energised one, since decision 197 exactly as before long timers, in a process the collector never visits, each clause that reads a clock seen to pay no look-up in a routine of plain timers, the units each program and body carries, a plain timer beside a long one, every hand edit of them refused where it is handed in and a trusted one's scan raising, and since decision 196 each slot whose literal is a time warned and every other passed over, `bit_string_test.exs` every rule of M5-8's bit strings from source, each declared everywhere an integer is at its limits and one past them, `move` by Figure 11, the arithmetic's refusal, the comparisons, the 76 conversions against a binary transfer restated, a `cal` formal, a connection and a `var_external`, an edit of a type, the reserved words, a word point through the runner, its forces file, a restart and a fresh start, the bitwise instructions and the Done-when's shifts at every width against IEC's rules restated, literal bit access read, written, as a one-shot's storage bit, in a block's body and on a skipped rung, its warnings and an edit's blocking, and the bitwise and bit scans' growth in reductions, a word destination costing within 5% of a uint's, and since M5-8's review a member's bits kept by a coil on one, an edit across bits blocking once and reporting a member's bit unwritten, a zero shift count, decision 187's warning on a bit string, a member's bit beside its whole write warned, a bit quoted as written in every message, and six programs of no bit strings compiling, against their parse, in no more reductions than before M5-8, and since decision 206 a bool as a bitwise operand, three bools computing in a bool, a bool widening into each bit string and refused beside each integer, a bool's shifts and rotates at a width of 1, a bit and a bool member read and written, and a bool destination costing within 5% of a uint's, and since decision 214 IEC's typing of `not` and the shifts, the maintainer's lamp, IEC's own cases, every pair Figure 11 widens over `not` and each shift and rotate at counts about the source's width against the operation restated in the source's bits, `and`, `or` and `xor` of mixed widths the same in either typing, a literal source, a bit and members, and the lookup's cost bounded over a `move`'s, `tag_bit_test.exs` every rule of M5-9's bit number held in a tag from source, every bit of every integer type and bit string read and written through a tag of four widths against bit n restated, a member's bit, the uses and writes it gives, every refusal at its line, each kind of instruction that may hold one on a number out of range (a contact, a coil energised and not, `move`, a bitwise instruction, a shift and a `cal`) doing nothing, passing no power and its major fault in `state.faults` with the number read, a block's by its path and file, the scan running on, a rung a jump skips and a block whose `cal` is false raising nothing, the warnings, an edit's rung, its word's and its number's tag each, since M5-9's review a `cal` operand's number checked, a coil on `w.[n]` beside a whole write of `w` warned either first, and a `cal` whose copy-out is out of range dropping its body's minor faults with its run, and since decision 213 a literal in the brackets read and written as the bit it numbers at every type in four spellings, a member's and a one-shot's, one outside the bits refused quoted as written, a warning keyed by the number and an edit that only respells a bit changing no rung, a configuration's uses and writes, and its growth in reductions, a read within 8 reductions of a literal bit's and 1.5x a bool's, and a program of none scanning rung for rung in exactly what it did at `1ee676b`, a `cal` one reduction more, `element_bit_test.exs` every rule of decision 221's bits of array elements from source, every bit of an element of every integer type and bit string, literal and numbered, read and written in one dimension and two against bit n restated, a move, a bitwise instruction, a `cal` and a block's body, every refusal at its line quoted as written, a one-shot and a pulse coil on one, the major fault of a number out of range and a skipped rung checking none, the warnings keyed by value, the walk's uses and writes, an edit's rung and block list, a configuration's writers element by element, and its cost in reductions against a tag's bit, `tag_subscript_test.exs` every rule of M5-12's subscripts held in tags from source, every element of arrays of one, two and three dimensions read and written through tags of eight widths against the elements' order restated, a literal beside a tag, a bit of such an element, the uses and writes it gives, every refusal at its line, a pulse bit in a bit of such an element among them since M5-12's review, each kind of instruction that may hold one on a subscript out of range (a contact, a coil energised and not, a false `otl` checking nothing, `move`, arithmetic, a comparison, a conversion, a bitwise instruction and a `cal`) doing nothing, passing no power and its major fault in `state.faults` with every subscript read, a block's by its path and file, an index checked before a bit's number, a rung a jump skips and a block whose `cal` is false raising nothing, the warnings, since M5-12's review a write through a tag subscript beside a coil on a bit of an element in either order, since decision 235 beside a coil on an element of a bool array, any instruction's, in either order, with its compile's growth in reductions, an edit's rung and block list, a configuration's writers, since decision 236 by the element two writers may share, and, since M5-12's review, a bit of an element at a far end, and its growth in reductions, a one-dimensional read within 6 reductions of a literal subscript's and a program of none scanning rung for rung in exactly what it did at `e00ae03`, `real_test.exs` every rule of M5-10's reals from source, the literal and its refusals
at their columns, the zero 0.0, `move`, the arithmetic, comparisons, the 34 conversions
against IEC's examples, a tie to even and the wrap after the rounding restated, the 16
truncations, `sqrt` and its negative root's fault alone and as a cycle's event, 3.5e38
saturated before it encodes, −0.0 and subnormals, an integer input stored as its nearest
real, a state's real held to its type's values, since M5-10's review a real literal read
as the real its slot computes in, `eq sp 37.1` true after `move 37.1 sp`, a block's real
formals compared exactly and scanned twice, `scan.reals` and a hand-edited program's
`reals` refused, a block's formals, an edit's `{0, 0.0}`, a configuration's real
globals, constants and print, points and forces through the runner, a seeded walk near
each real's limits from which no exception leaves a scan, and its cost, a program of no
reals scanning as it did at `5eac41f`, and since decisions 216, 218 and 219 a literal a
write would flush refused in every slot and as an initial value, the edge at the smallest
normal single, one below every double but 0.0 a lex error, a forces file's real point read as any
number, a literal its real rounds warned against the rule restated over 1500 seeded
texts, and a program of none paying nothing for the warning, and since decision 227 a
rounded initial value warned at its line, a declaration's, an array list's, a block's and
a configuration global's, none from Elixir, and since decision 228 a subnormal literal
read as its double and refused in every slot naming the instruction and the tag, and
since decision 231 one no double holds but 0.0 read as 0.0 spelled, a well-formed leaf
the printer gives back, refused in every slot in the same words, a zero written any way
0.0, and refused by a configuration file's reader at its column, `array_test.exs` every rule
of M5-11's arrays in a program from source, the syntax and its refusals at their columns,
the declaration and its initial list in the elements' order, restated from Logix's text,
since decision 220 the limit in every shape, since decision 222 a host's element key and
each of its refusals pinned with a program of no array paying nothing,
an element of every elementary type read and written, every refusal at its line, a `cal`
formal and a block's own array, one-shots and pulse coils on elements, an edit of a rung
with `ons edge[2]` blocking it once, a jump's skip, the warnings, the host contract and
the state check, an edit's refusals and its element-by-element reports, the walk, a hand
edit, a seeded walk of `weights[3]` and `grid[1,7]` against an oracle, and the growth in
reductions, an element's read and write within a measured bound of a tag's at one, two
and three dimensions and a program of none scanning rung for rung as before,
`located_array_test.exs` every rule of M5-13's located arrays from source, the line, its
round trip and from Elixir, each element's point and address at one and two dimensions
and a hierarchical address, every overlap and initial list refused, a location naming
the element, an input array driven, a single, the undriven warnings, a cycle's inputs
and outputs by element, more than 16 at once as one by one, every host mistake, the
sim's range, the runner's reads, writes, forces, forces file, restart, crash and fresh
start, a refused element keeping the others (decision 143), an edit's refusals by range
and held elements, and its growth in reductions, a configuration of none cycling a point
at a time as at `a8af419`, and
`array_configuration_test.exs` M5-11 in a configuration, an array global from its line
and from Elixir printed back exactly, its refusals, a
`var_external` array bound exactly, connections whole and by element, widened, refused
and unconnected, `get/2`'s paths and their refusals, a host-built runtime's array global
refused, a restart, and a configuration edit's reports, since decision 223 an element of
a global array at a connection's far end read and driven, widened and refused, its
drivers and writer warnings element by element and held after an edit, since decision
232 each element an edit leaves undriven after a whole driver held by name and an
element of a var_output at a near end a driver where its program writes it, and since M5-11's review each
crash it found a pinned refusal, writers of different elements told nothing, a state's
array checked in about a reduction an element and `instance/1`'s check bounded under one
more walk of the tags, and `api_contract_test.exs` a seeded property over the host contract, which since M1-6 checks every accepted scan against an oracle for `ton` and `ons` and makes every accepted call twice, and since OE-1 walks online edits too, and since M2-1 configurations run as resources, against a model that scans each instance through `call/4` alone, and since M2-5 online edits of programs that hold blocks, two deep, with a one-shot oracle on every scan from the programs' text, and since M2-4 resources whose programs share globals through `var_external`, against a model that runs each program as Elixir over one map of globals, and since M2-6 configurations with event tasks, alone and with an interval, against a model of decision 39 in phase points and oracles that know only each trigger's samples, and since OE-2 staged edits of a running configuration, on a slow task that skips cycles among them, each step's writes rebuilding the resource, against a model of the scheduler seeded from the resource after every step and oracles for timers and one-shots that know nothing of the edit, and since M3-1 counters, alone and in a block, over scans, restarts and edits, against IEC's bodies restated from the programs' text, exact wherever no switch came since a counter last ran, with an oracle that knows nothing of the block list, and since M3-2 the other timers, `tof`, `tp` and `rto`, alone and a pulse in a block, over scans of random intervals, restarts and edits, against each rule restated from the programs' text, exact but where only an edit's block decides a pulse, and since M3-3 arithmetic, alone, in a block and in a resource, near the dint's limits and at zero divisors, against IEC's rules restated in Elixir, every scan's state, outputs and faults and every cycle's events exact, across an online edit whose kept values stay as they were, and since M3-4 the pulse coils, alone and in a block, over scans, restarts and edits that change a coil's rung, kind, presence or block, against IEC's transition-sensing coils restated from the programs' text, exact wherever no switch came since a coil last ran, with an oracle that knows nothing of the block list, and since M3-5 forward jumps over six rungs in a random order, a one-shot, a ctud's two sides, a timer and a `cal` of a block whose body jumps among them, each memory and the `cal` now and then on a leg of a group, over scans, restarts and edits that change a chain, add, remove or retarget a jump, swap two rungs, change a one-shot's kind or a block's body, or put a memory in a group or take it out, against the scan restated rung by rung from the programs' text, with an oracle that knows nothing of the block list, and since M4-2 a configuration's edits whose tasks have watchdogs and a continuous task half the time, a watchdog changed, `with main` added or taken away and a task's kind changed among the draws, against the same model with the untimed instances under the continuous task's name, and since M5-3 programs of every integer width, each width's two limits drawn as a host's input against its range restated, `move` into a wider width and a conversion's wrap restated as a remainder by 2^N, and since M5-6 the timer walk's `tof`, `tp` and `rto` each a long timer half the time, its preset in ns and each millisecond adding 1,000,000 restated, an edit of the `tof`'s unit refused, and since M5-4 the arithmetic walk's every tag of a width drawn from the eight, each source of a width Figure 11 widens into its destination's, the oracle wrapping in the destination's width, its reach a widened source and a wrap in each width, every width drawn from a list, since an atom-keyed map's keys come in an order the atom table sets, and since M5-5 the counter walk's every counter of a word drawn from the six, the alias `_dint` among them, its oracle stopping each at its width's limits restated, its reach a count in each width and in the alias, an unsigned counter stopped at 0, an edit of a width refused and of the alias accepted, and since decision 191 a negative preset drawn for a signed counter, and since M5-8 the host walk's bitwise instructions and bits over every integer width and bit string against an oracle restated in Elixir, its reach a shift past the width, a negative count and a bit written, since decision 206 a bool drawn among them, its two values and a bit inverted into a bool and each bit string, since decision 214 restated in the bool's one bit, and `not` and a shift of the drawn type into a wider one Figure 11 widens it into, in its own width, its reach each type with a wider one, and the configuration walk's word points read, forced and refused by bit, and since M4-6, in a module of its own, `Logex.ApiContractTest.RunnerWalk`, the runner on the manual clock over 30 seeded configurations, about three in four with untimed programs, with devices that report and that are only read, random waits and presses, forces, an online edit's steps, host mistakes, restarts, a crash and a fresh start from the forces file, and injected faults (a slow step, a slow request, the runner stuck, a device killed or hung, and each way a device's read, report or write fails), against a model that calls `cycle/3` with the elapsed times and inputs the runner gave the core, told it through the hidden seam `steps:`, with oracles on those times and inputs, and a model of the watchdogs and the trip, repeating exactly from fresh processes, its reach every event kind and every trip reason but `{:internal, message}`; since M4-6's review its real-time waits given an idle watchdog of 400 or 500 ms, which a device's open made 100 ms late, as on a loaded machine, must not trip, a restart's refusal in the device's own reason, drawn, a device up refusing a restart with its read's fault (decision 142), a start's and a restart's first round reading every device as it is then, and a read device's input allowed only the time passed inside steps while it was read, which a test of the check's own pins by giving the core such a change late; and since M5-10 a walk of real arithmetic, conversions and truncations over values near
each real's limits, at ties, zero divisors and subnormals, alone, across a restart and an
edit, and in a resource, against IEEE 754's rounding and IEC's rules restated through the
BEAM's 32-bit encoding, every state compared exactly, its reach a saturation and a flush
in each real, −0.0, a tie and a wrap, and the configuration round trip's real globals,
and since M5-9 a program whose bit number is the panel's dint, out of range at its -4 while `pb` is pressed, its model tripping a step whose run met a major fault at the step's end, no later step run, its reach `{:fault, ...}` among the trip reasons, and since M5-11 a walk of arrays drawn at one, two and three dimensions of an integer type and of bools, by literal subscripts, `move` and `add` between elements, a host's list whole, a one-shot on an element, over scans, restarts, host mistakes and edits of an initial list, and in a resource connected whole or element by element, against an oracle of each array as a map of its elements by index, the rightmost subscript fastest, its reach each dimension count, a wrap, a one-shot fired, a host's refusal, a restart, an element's report and both kinds of connection, and the configuration round trip's array globals, and since decisions 221 to 223 a bit of an element read by a contact and written by a coil, a host's element key and an element of a global array at a far end among its draws and its reach, and since M5-12 a walk of elements subscripted by tags of four widths beside literal subscripts, at one, two and three dimensions, each subscript drawn now and then outside its dimension, below 0 too, `move`, `add`, coils and contacts, over scans and restarts and in a resource, against an oracle of each array as a map of its elements and each fault restated with its subscripts, its reach a read and a write fault, a contact's, a de-energised `ote`'s and a de-energised latch checking nothing, and the RunnerWalk's program whose subscript is the panel's dint, outside its array at 7 and -4 while `pa` is pressed, its trip reached, its fault's `read` the one subscript in a tuple since decision 233, a fresh start's first round among the rounds that may trip, and since M5-13 every RunnerWalk configuration holding a located array in, `pt int[3]` at `panel.i.3`, and out, `qs bool[2]` at `drive.q.2`, each element pressed, forced and unforced by name and refused at its own address, its reach an element pressed, forced and misfit
- `test/logex/frontend_golden_test.exs` holds `tokenize/1` + `parse/1` to a recorded AST,
  end line or error line for ~1,400 sources (`test/fixtures/frontend_golden.txt`). It
  catches front-end changes the rest of the suite cannot see: B8, making a lone CR end a
  rung, failed it and nothing else until B8's own tests came with it; M3-3's negative
  literals added 24 sources and changed none; M5-7's based literals and `_` added 38,
  recorded by the front end before them, and changed 13 of them on landing; decision 202,
  a rung keeping a literal's spelling, changed 251, each a literal's leaf gaining its
  spelling and nothing else, 235 of them a generated `042`; and M5-9's bit numbers in a
  tag, `status.[n]`, added 23, recorded by the front end before them, and changed 9 on
  landing, the seven that lex and two whose error moved to the parser; and decision 213's
  literal in brackets, `status.[4]`, added 20, recorded by the front end before it, and
  changed 11 on landing, the nine of them that lex and M5-9's `xic s.[3]` and `xic
  s.[-1]`. M5-10's real literals added 30, recorded by the front end before them,
  and changed 15 on landing, the ones that lex, the rest still lex errors; and decision
  216's literals nearer 0.0 than an lreal's smallest normal value added 11, recorded by
  the front end before it, and changed 7 on landing, each now a lex error; and M5-11's
  arrays, `temps[3]`, `int[8]` and their mistakes, added 41, recorded by the front end
  before them, and changed 25 on landing, the 23 that lex and `ote a[3]` and `xic s[n]`,
  the rest still lex errors; and decision 221's bits of elements added 16, recorded by the
  front end before it, which already read them, and changed none; and decision 228
  changed 5 of decision 216's 11, each a subnormal double that now parses; and decision
  231 changed 2, `move 1.0e-400 aa` and `move 1_0.0e-4_00 aa`, each a lex error that now
  parses as a spelled leaf of 0.0. It keeps the AST and error lines, not the tokens or
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
  `Logex.Configuration.Edit`, from text and from files on disk, and M3-1's, a box
  counter, a ctud buffer and a ctd hopper against oracles that know nothing of logex,
  from text and from files on disk, a count stopped at the dint's top, and an edit that
  raises the preset while boxes are counted, and M3-2's, a fan's `tof` on 10 ms and 50 ms
  tasks stopping it at one time, a `tp` horn and an `rto` lubrication timer against
  oracles that know nothing of logex, and the event-task warning naming each, from text
  and from files on disk, and M3-3's, a fill valve's total under a 100 ms task closing
  the valve at its setpoint against an oracle that knows nothing of logex, a total past
  the dint's top, a rate by zero minutes reported as its event and a `mod` of a negative
  offset, every value the resource holds a dint's, from text and from files on disk, and
  M3-4's, `osr` and `osf` giving the pulses `ons` and `xio … ons` give on seeded inputs,
  passing on their power and never firing on a first scan, and an edit that adds or
  changes one blocking it until a scan runs it, as an `ons`, in a frozen block too, from
  text and from files on disk, and M3-5's, a jog section skipped by a forward `jmp` in
  auto against the same section as a block whose `cal` is false, scan for scan over seeded
  scans, with checks that know nothing of logex, a timer catching up the time it was
  skipped, the three diagnostics at their lines, and a program with no `jmp` scanning
  within a measured bound of its cost before, from text and from files on disk, and
  M4-1's, §4.4's plant from files on disk, its points grouped and bound to two simulated
  devices, one reporting its changes, read and written on the manual clock by a device's
  process the test plays, a slow write passing time and delivering nothing, and M4-2's,
  §4.4's plant with a watchdog on every task line and a box counter in its continuous
  task, read, printed back exactly and cycled as before, the counter's runs under `main`
  against an oracle that knows nothing of logex, and an edit adding `with main` moving
  nothing, from text and from files on disk, and M4-3's, §4.4's plant with its box
  counter from files on disk through `Logex.Runner` on the manual clock, the panel
  reporting and the drive only read, over 600 seeded presses and waits, every step's
  events, outputs and `get/2` values those of `cycle/3` called directly by an oracle that
  knows nothing of the runner, repeating exactly from fresh processes, beside the plant
  run on the real clock for 2 s, liveness and an orderly stop only, and M4-5's, the same
  plant edited through `Logex.Runner`'s accept, test, untest, assemble and cancel among
  those presses, against a candidate on disk with `slow` cut to 20 ms and a case of six,
  every step's reply, events, outputs and `get/2` values those of `cycle/3` and
  `Logex.Configuration.Edit` taken over the resource directly, `slow` next due as
  decision 40 says, and the photo-eye forced against its device, across a restart, a
  crash and a fresh start from its forces file, and M5-3's, §4.4's plant from files on
  disk reading its drive's speed as a `uint` point through the sim and moving it into a
  `dint`, a force held to the uint and a reading past it tripping the plant, and M5-5's,
  a plant from files on disk whose `ctud_int` stock stops at 32767 with `ov` on and whose
  `ctd_udint` hopper stops at 0 with `un` on, through `cycle/3` against an oracle that
  knows nothing of logex, a `ctu_dint` the very `ctu`, and M5-6's, a press from files on
  disk whose `ton_ltime` cures for 30 days and whose one rung `ton t 2000000` is done at
  2,000,000 ms on a `ton` and at 2 ms on a `ton_ltime`, through `cycle/3` over seeded
  presses and waits against an oracle that knows nothing of logex, and M5-8's, §4.4's
  plant from files on disk whose lamp program reads bit 3 of the drive's status `word`,
  a point at `drive.i.4`, through `cycle/3` and the runner against an oracle that knows
  nothing of logex, a force held to the word, a restart and a fresh start from the forces
  file, and a reading past the word refused, and M5-9's, §4.4's plant from files on disk
  whose run lamp shows the bit of the drive's fault word the panel's selector names,
  `xic faults.[sel] ote lamp`, through the runner on the manual clock against an oracle
  that knows nothing of logex, the selector at 16 tripping the plant at the fast task's
  step as the slow task falls due, every output 0 once and nothing after, the trip naming
  the instance, the file, the line and the number, the slow task's step never run, and
  M5-10's, §4.4's plant from files on disk reading its fan's frequency as a `real` point,
  `var_global fan_hz real at drive.i.0`, through the runner on the manual clock, its speed
  in a `real` and an `lreal` and an alarm over an `int` limit against an oracle that knows
  nothing of logex, a single restated through the BEAM's 32-bit encoding, the
  configuration file's round trip, an integer reading stored as its nearest real, a force
  of 0.1 written `fan_hz 0.1` and read back across a restart and a fresh start, and 2^128
  tripping the plant, and M5-11's, a checkweigher from files on disk keeping its last
  eight weights in `weights int[8]`, shifted on a pick's edge through `ons edges[1]`, its
  fourth copied into `grid[1,7]` and into a var_output array connected whole to a global
  array, through `cycle/3` over seeded loads and picks against an oracle of eight weights
  that knows nothing of logex, `get/2` reading `line.weights[3]`, `line.grid[1,7]` and
  `history[3]`, and M5-12's, §4.4's plant from files on disk whose box counter weighs each
  box into `weights[slot]`, the slot the panel's, through the runner on the manual clock
  against an oracle of eight weights that knows nothing of logex, the slot at 8 tripping
  the plant at the fast task's step as the slow task falls due, every output 0 once and
  nothing after, the trip naming the instance, the file, the line and the index `[8]`, the
  slow task's step never run, and M5-13's, §4.4's plant from files on disk reading its
  oven card's eight zone temperatures as one located array, `zone_t real[8] at
  card.i.0`, and lighting a lamp a zone through `zone_hot bool[8] at card.q.0`, through
  the runner on the manual clock against an oracle of eight singles that knows nothing of
  logex, printed back exactly, a card of seven inputs refused, `zone_t[3]` forced against
  its device and across a restart, a crash and a fresh start from its forces file;
  `validation_test.exs` and
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
  an edit's rules or report, through "Changing a running program". M3-1's counters are its
  "A counter", and the counter in "Changing a running program"; M3-2's timers its "Three
  more timers"; M3-3's arithmetic, negative literals and the fault a zero divisor raises
  its "Arithmetic"; M3-4's pulse coils its "Two pulse coils", the coil in "Changing a
  running program", and a one-shot's event-task warning in "An event task"; M3-5's jump
  its "A forward jump", the label in the syntax list and the jump in "Changing a running
  program"; M4-2's watchdogs and continuous task its "Watchdogs and the continuous task";
  M4-3's runner its "Running a plant on the clock", whose output is a real run on the
  manual clock, and M4-4's trips and restart the run of `a_trip.exs` there, real too, and
  M4-5's forcing and an edit through the runner the run of `forced_and_edited.exs` there,
  M5-3's integer widths and conversions its "Integer widths", the run of `drive.exs`,
  M5-5's typed counters its "A counter", the run of `stock.exs`, M5-6's long timers its
  "Long timers", the run of `cure.exs`, M5-8's bit strings, bitwise instructions, bit
  access and bit-string conversions its "Bit strings", the run of `status.exs`,
  M5-10's reals its "Reals", the run of `fan.exs`, M5-12's subscripts held in tags its "A
  subscript in a tag", the run of `scales.exs`,
  and since M4-7 the plant on the real clock, `on_the_real_clock.exs`, its keyword list
  the same on every run and its figures that run's; and "What logex is not" says plainly
  what logex does not do, a safety function first, each claim checked against the code,
  so a change that adds an adapter, output forcing, retained values, a backward jump or a
  type stales it. Nothing tests this.
- `CONTRIBUTING.md` — working practices, each one traced to something that broke
- `PLAN.md` — reviewed findings and the ordered plan of work
- `docs/naming.md` — the IEC and vendor name survey, one stanza per mnemonic, declaration
  word, word that heads a file or configuration file's word; append-only
- `docs/organisation.md` — where logex is heading above one program: IEC's configuration,
  tasks, program instances and I/O mapping, in logex's dialect. Decided (PLAN §5; the
  work is PLAN's M1-3, M1-5, M1-6, OE-1, Milestone 2 and OE-2; OE-1, Milestone 2,
  M2-1, M2-5, M2-2, M2-3, M2-4 and M2-6, and OE-2 have landed, Milestone 2 designed on
  2026-10-02, §4.10 and decisions 30–40, and OE-2 on 2026-10-13, §4.9's "OE-2's design"
  and decisions 55–66; Milestone 3, the missing instruction set, decided on 2026-10-14, decisions 67–92, M3-1's
  counters landed, M3-2's timers, with decisions 93–96, M3-3's arithmetic, with
  decisions 97–99, M3-4's pulse coils, with decisions 100–103, 102 confirmed and 103
  answered by the maintainer on 2026-10-15, after M3-4's review, and M3-5's forward jump,
  with decisions 104–107, on 2026-10-15, 106 and 107 confirmed by the maintainer after
  M3-5's review, so Milestone 3 is done; Milestone 4, the wall-clock runner, designed
  and decided on 2026-10-17, §4.11 and decisions 108–121, its first item, M4-1, the
  clocks, the adapter behaviour and the simulated device, landed the same day, and the
  record's answers to M4-1's review, decisions 122–126, on 2026-10-18, with the
  maintainer's answers the same day, forces kept in a file across a crash, decision 127,
  and the runner's own idle watchdog, `idle:`, decision 128; and its second, M4-2, a
  task's watchdog and the continuous task in a configuration, with decision 129, on
  2026-10-18, and its third, M4-3, the runner itself, the same day, and its fourth, M4-4,
  the watchdogs and the fault path, the same day, its review's findings fixed on
  2026-10-19 and its five questions answered by the maintainer the same day, decisions
  133–137, and its fifth, M4-5, forcing and edits through the runner, the same day, its
  four questions answered by the maintainer the same day, decisions 138–141, and its
  sixth, M4-6, the contract walk over the runner, the same day, its question answered
  by the maintainer on 2026-10-20, decision 142, a restart that reads every device first,
  and two calls of the lead's in its verifications confirmed by the maintainer the same
  day, a report-only reading kept across a restart, a fix within decision 142, and a
  refused change's good points kept, decision 143, with the record's claims of Logix
  checked against the manuals the same day, §8, and its seventh and last, M4-7, the
  documents, the same day, §4.5, §4.6, §5 and decision 14 annotated as landed;
  Milestone 5, data types, designed and decided on 2026-10-21, §4.12 and decisions
  144–160, with 161–167 the maintainer's answers the same day to the record's questions
  put back and its open rules, its sixteen items planned in `PLAN.md`, M5-1, one table of
  types, M5-2, the dint's wrap, and M5-3, the integer widths with `move` by Figure 11 and
  the 56 integer conversions, landed, and the maintainer's answers to M5-3's and decision
  171's questions on 2026-10-22, decisions 172–179, landed the same day, and M5-4, the
  arithmetic in every width, and M5-5, the typed counters, with the maintainer's answers
  to their questions, decisions 180–186 and 187–193, the same day, and M5-6, the long
  timers in nanoseconds, the same day, M5-7, based literals, and M5-8, the bit strings
  with the bitwise instructions, literal bit access and the 76 bit-string conversions,
  on 2026-10-23, M5-9, a bit number in a tag, and M5-10, the reals, the same day, with
  the maintainer's answers to their questions, decisions 204–209, 210–214 and 215–219,
  M5-11, arrays, and M5-12, subscripts held in tags, with the answers of 2026-10-23 and
  2026-10-24, decisions 220–228 and 229–236, and M5-13, located arrays, the same day:
  IEC's integer widths,
  signed and unsigned, overflow wrapping in every width, which supersedes decision 77's
  saturation and changes the dint's on purpose (M5-2), the reals, the bit strings and
  the bitwise instructions, a bit number in a tag, arrays of up to three dimensions, of
  instances and located, an index or a bit number out of range a major fault that trips
  the runner, typed counters and long timers in nanoseconds).
  Read it before designing anything that adds a data type (§4.12), names a program, schedules one, binds I/O,
  changes a running controller (§4.9, online edit, decided 2026-10-01), or runs one on
  the clock (§4.11).
- `docs/instruction-sets.md` — reference: IEC's LD elements and standard library by table number,
  Instruction List (withdrawn in Ed 4), and the free-software instruction sets. Read it before
  writing a naming.md stanza; it carries the IEC feature numbers a stanza should cite.

## Conventions

- `evaluate/3` clauses, private in `Logex.Runtime`, take `(instruction, {power_flow_bool, env_map}, %Logex.Scan{})` and return `{new_power_flow_bool, new_env_map}`. The scan is read-only and the same for every instruction of one routine run, a program's rungs or one run of a block's body: a clause that needs the time reads `scan.now`, a timer its unit from `scan.units` (decision 197, a clause for `units: nil` first, which pays no look-up), a write into a real its type from `scan.reals` (M5-10, a clause for `reals: nil` first, which pays none), one that needs the first scan reads `scan.first`, and every other clause ignores it as `_scan` (M1-6). `ons` reads `scan.first` and `scan.ons_blocked`, the storage bits whose `ons` passes no power on this one scan, and since M3-4 `osr` and `osf` read both, a blocked coil setting no pulse, which `call/4` builds from the instance's `ons_blocked` list as a tree of those bits, each to `true` and each instance holding one to a tree of its own, so that each `ons` looks its bit up rather than walking the list, emptying the instance's list after the scan but for the bits inside an instance whose body did not run (OE-1, decision 32) and, since M3-5, those on a rung a jump skipped (decision 106); a host never fills it in. `jmp` (M3-5) records its label in the routine's env under an atom key, `:jump`, which the rung loop takes out once the rung is done, skipping to the rung the label heads (decision 104). `cal` (M2-5) reads `scan.tags`, the routine's tag table, and `scan.blocks`, the program's one table of block types (decision 53), which `call/4` fills from the program, and runs its block's body with the scan narrowed to its instance, `tags` and, since decision 197, `units` the body's and `ons_blocked` the instance's own tree, `now`, `first` and `blocks` unchanged; a clause that looks a tag up in `scan.tags` uses the routine's table. `div` and `mod` (M3-3) record a zero divisor in the routine's env under an atom key, `:faults`, which no tag can be, as `cal` records a body's run under `:ran`: the routine that ran it takes the record out when it is done, `call/4` into the state's `faults`, a `cal` into its own routine's, a level down (decision 99). No state holds one of these keys between scans, so the runtime refuses a host's env that does, and a new key joins `Logex.Runtime`'s `@own_keys`, which a `cal`'s drop and the refusal's message read, and the refusal's guard, which names each. No test calls the evaluator: a test runs a program through `Logex.Runtime.call/4`, on a hand-built `%Logex.Instance{}` when it needs a particular env
- A mistake in the source is a `%Logex.Diagnostic{}`, returned; a mistake by the host is an `ArgumentError`, raised, whose message a test pins. Nothing else may escape the public API (`api_contract_test.exs`)
- An operand in the AST is `{:name, line, tag}` or `{:int_lit, line, value}` — a 3-tuple, not a keyword pair — or, since decision 202, a literal written other than as the plain decimal of its value, `{:int_lit, line, value, spelling}`, which every reader of a literal meets too, by `Logex.Parser.is_int_lit/1` or a clause of its own, its value what every rule judges and its spelling what every message quotes. Since M5-10 a real
  literal is `{:real_lit, line, float}` or `{:real_lit, line, float, spelling}`, which
  `Logex.Parser.is_literal/1` holds with an integer's, its value a float, never −0.0; in
  the IR, since M5-10's review (provisional), a real literal in a slot that computes in a
  `real` holds its nearest single with its spelling, `{:real_lit, line,
  0.10000000149011612, "0.1"}`, which `Logex.Compiler.lowered?/1` reads back from the
  spelling. Destructure the line as `_`; never drop it from the AST, it is what diagnostics will cite. `Logex.Parser.well_formed!/1` states the whole tree `parse/1` can produce, and `instructionize/2` raises `ArgumentError` on any other (OE-1): every line a positive integer, every element of a rung on its one line, each rung on a line after the last, a name that lexes as one name token, a literal an integer, negative too since M3-3 (decision 97), a rung of one element or more and a group of one leg or more. A test that builds a tree by hand builds one of those. The lexer's tokens carry `{line, column}`; the parser keeps only the line, because the suite pins that shape. An instruction in the IR is `{symbol, line, operands}`, carrying its mnemonic's line; a `{:branches, legs}` node carries no line of its own. In the IR, and only there, a member of an instance is `{:member, line, path}`, `t1.acc` becoming `{:member, 3, ["t1", "acc"]}` (M1-6): the runtime's `read/2` and `write/3` take it as they take a tag, and anything that walks IR operands must handle it, as it must a label, `{:label, line, name}` (M3-5), a `jmp`'s or `lbl`'s operand, which is no tag. A walk that reads what an instruction's operands do looks its slots up through `Logex.Compiler.signature/2`, given the program's tag table, never in a table of its own (M2-5), as `Logex.Walk` does, which `Logex.Warnings` and `Logex.Edit` read: a `cal`'s slots are its block's, so the outputs it fills are writes
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
  function block type's name (`{:instance, "ton"}`), or a list of names for one
  that runs several, `{:instance, ["ctu", "ctud"]}` (M3-1), a new built-in type being a row
  of `Logex.FbType.rules/1`, `:preset` for a literal number of
  milliseconds, `:label` for a label, `{:label, nil}` (M3-5), a name no tag table holds;
  type `:bool`, `:dint` or `:any`; a tag may be a member, `t1.acc`, which
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
  any case and owes a `docs/naming.md` stanza, which `naming_test.exs` checks, reading
  `Logex.Declarations.keywords/0`, a list it pins whole, so that a word dropped from it
  is seen and a new word is added to the pinned list with its stanza (M5-5's review). A
  word that
  heads a file of another kind, an entry of `Logex.Declarations.kinds/0` (`function_block`,
  M2-5), owes a stanza too, which the same test checks; `Logex.Compiler` reserves it in
  that kind of file only, in any case (`docs/organisation.md` §4.8), as a tag's name, a
  block's and, since M3-5's review, a label. A word of a
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
