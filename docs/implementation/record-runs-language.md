# Runs and tables of the records: the language

This page is for a contributor who reads a decision record about the lexer, the parser, the declarations and the types. It holds the
runs, the measurements and the long tables of records 0001, 0002, 0003, 0005 and 0006, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0001. A program is data

These measurements and this run support
[0001. A program is data](../adr/0001-a-program-is-data.md).

### The time of a compile

On 2026-10-01, a measurement on Elixir 1.20.4 compared a module with plain data for 2 programs, of 4
and 200 [tags](../../guides/reference/glossary.md#tag). It compiled a Spark module again with `Code.compile_string/2`.
It compiled the same program with `Logex.compile/2`. 2 runs on 2026-11-21 measured
`Logex.compile/2` again, against a plain module, because Spark is not in the repository.

| The compile, and its date | 4 tags | 200 tags |
|---|---|---|
| `Logex.compile/2`, 2026-10-01 | 22 µs | 1.7 ms |
| A Spark module, `Code.compile_string/2`, 2026-10-01 | 74 to 95 ms | 0.5 to 0.7 s |
| `Logex.compile/2`, 2026-11-21 | 79 to 82 µs | 1.8 to 2.9 ms |
| A plain module of 1 function a tag, `Code.compile_string/2`, 2026-11-21 | 5.3 ms | 52 to 66 ms |

Each run was on 1 machine. Compare the times of 1 run with each other, not with the
times of the other run. In each run, `Logex.compile/2` took less than 0.06 of the time of
the module.

### A new version of a module that runs

A run on Elixir 1.20.4 on 2026-11-21 compiled a new version of a plain module that runs, in 5 cases.

- The new version raises an exception in its body. The BEAM unloads the old version, and
  a call raises `UndefinedFunctionError`.
- The new version calls a local function that the module does not define. The compile
  raises `CompileError`, and the BEAM unloads the old version.
- The new version calls a function of a module that does not exist. The compile prints a
  message and goes on. The new version replaces the old one, and a call raises
  `UndefinedFunctionError`.
- The new version has a syntax error. The compile raises `SyntaxError`, and the old
  version stays.
- The body of the new version writes a file. The compile writes the file.

Thus 3 of 4 failed edits leave the controller with no program that works.

### No call into a compiler

This script counts the calls into a compiler. Run it beside
[`motor.ld`](../../guides/tutorials/first-program.md). It compiles `motor.ld`, changes 1
value in rung 5, and makes an online edit of an instance.

```elixir
# The modules of the Elixir compiler and of the Erlang compiler.
compilers = [:elixir, :elixir_compiler, :elixir_module, :elixir_expand, :elixir_erl, :compile]
Enum.each(compilers, &Code.ensure_loaded!/1)
Enum.each(compilers, &:erlang.trace_pattern({&1, :_, :_}, true, [:global]))

# An online edit of motor.ld: compile, scan, accept, test, assemble.
edit = fn ->
  text = File.read!("motor.ld")
  {:ok, motor} = Logex.compile(text, name: "motor")
  changed = String.replace(text, "move 0 speed_sp", "move 600 speed_sp")
  {:ok, candidate} = Logex.compile(changed, name: "motor")
  state = Logex.Runtime.instance(motor)
  {_outputs, state} = Logex.Runtime.scan(motor, state, 10)
  {:ok, change, _report} = Logex.Edit.accept(motor, candidate, state)
  {change, state, _report} = Logex.Edit.test(change, state)
  {_program, _state, _report} = Logex.Edit.assemble(change, state)
end

# Count the calls into a compiler that a function makes, in each process it starts.
calls = fn function ->
  counter =
    spawn(fn ->
      count = fn count, n ->
        receive do
          {:trace, _pid, :call, _mfa} -> count.(count, n + 1)
          {:total, from} -> send(from, {:total, n})
        end
      end

      count.(count, 0)
    end)

  :erlang.trace(:new_processes, true, [:call, {:tracer, counter}])
  :erlang.trace(self(), true, [:call, {:tracer, counter}])
  function.()
  :erlang.trace(:all, false, [:call])
  ref = :erlang.trace_delivered(:all)

  receive do
    {:trace_delivered, :all, ^ref} -> send(counter, {:total, self()})
  end

  receive do
    {:total, n} -> n
  end
end

# The first edit loads the modules of logex.
edit.()

modules = length(:code.all_loaded())
atoms = :erlang.system_info(:atom_count)
edit_calls = calls.(edit)
new_modules = length(:code.all_loaded()) - modules
new_atoms = :erlang.system_info(:atom_count) - atoms

IO.puts("calls into a compiler: #{edit_calls}")
IO.puts("new modules: #{new_modules}")
IO.puts("new atoms: #{new_atoms}")

# The same count for 1 small Elixir module.
module = fn -> Code.compile_string("defmodule Lamp do def on, do: 1 end") end
IO.puts("1 Elixir module calls a compiler: #{calls.(module) > 0}")
```

```console
$ mix run 0001-a-program-is-data.exs
calls into a compiler: 0
new modules: 0
new atoms: 0
1 Elixir module calls a compiler: true
```

The last line is a control. 1 small Elixir module makes calls into the compiler, so the
count can see a call.

## 0002. A dialect for logex, and a survey for each word

This run supports
[0002. A dialect for logex, and a survey for each word](../adr/0002-own-dialect-and-names.md).

This script [compiles](../../guides/reference/glossary.md#compile) 9 texts of a motor and of a counter of boxes. Each text has a word
or a form that this record decides. The last line compares a program in lowercase with
the same program in uppercase. The script is `examples/0002-own-dialect-and-names.exs`.
Run it from `examples/`.

```elixir
# Print "compiles", or each diagnostic of the compile.
report = fn
  {:ok, _program} -> IO.puts("  compiles")
  {:error, diagnostics} -> Enum.each(diagnostics, &IO.puts("  " <> Logex.Diagnostic.format(&1)))
end

# The declarations of the motor, and of the box counter.
motor = "var_input start bool\nvar_input stop bool\nvar_output motor bool\n"
boxes = "var_input eye bool\n"

texts = [
  {"1. A mnemonic in uppercase", motor <> "XIC start XIO stop OTE motor\n"},
  {"2. A mnemonic as the name of a tag", motor <> "var Ote bool\nxic start ote motor\n"},
  {"3. A tag in the wrong case", motor <> "xic Start xio stop ote motor\n"},
  {"4. The old name of move", motor <> "var speed dint\nmov 600 speed\n"},
  {"5. A new word for ton", motor <> "var t1 ton\nxic start on_delay t1 3000\n"},
  {"6. A master control zone", motor <> "xic start mcr\n"},
  {"7. A branch in words", motor <> "bst xic start nxb xic motor bnd xio stop ote motor\n"},
  {"8. A rung on 2 lines", motor <> "xic start xio stop\note motor\n"},
  {"9. ctu_dint, and a ctd on it", boxes <> "var boxes ctu_dint\nxic eye ctd boxes 3\n"}
]

Enum.each(texts, fn {title, text} ->
  IO.puts(title)
  report.(Logex.compile(text, name: "dialect"))
end)

# The case of a mnemonic, a section and a type word changes nothing in the program.
{:ok, lower} = Logex.compile(motor <> "xic start xio stop ote motor\n", name: "motor")
declarations = "VAR_INPUT start BOOL\nVAR_INPUT stop BOOL\nVAR_OUTPUT motor BOOL\n"
{:ok, upper} = Logex.compile(declarations <> "XIC start XIO stop OTE motor\n", name: "motor")
same = {lower.rungs, lower.tags} == {upper.rungs, upper.tags}
IO.puts("The same rungs and tags in uppercase: #{same}")
```

```console
$ mix run 0002-own-dialect-and-names.exs
1. A mnemonic in uppercase
  compiles
2. A mnemonic as the name of a tag
  line 4: `Ote` is an instruction and cannot name a tag
3. A tag in the wrong case
  line 4: `Start` is not declared — did you mean `start`? (tags are case-sensitive)
4. The old name of move
  line 5: unknown instruction `mov` — did you mean `move`? (renamed to its IEC name)
5. A new word for ton
  line 5: unknown instruction `on_delay`
6. A master control zone
  line 4: unknown instruction `mcr`
7. A branch in words
  line 4: `bst` is no longer a keyword — branches are written `( … | … )`
  line 4: `nxb` is no longer a keyword — branches are written `( … | … )`
  line 4: `bnd` is no longer a keyword — branches are written `( … | … )`
8. A rung on 2 lines
  line 4: this rung writes nothing and jumps nowhere: none of its instructions writes a tag, a member or a bit, runs an instance or keeps a one-shot's storage bit. A newline ends a rung, so a rung's conditions and its outputs go on one line, as in `xic start xio stop ote motor`
9. ctu_dint, and a ctd on it
  line 3: `ctd` runs a ctd, ctud, ctd_int, ctud_int, ctd_lint, ctud_lint, ctd_udint, ctud_udint, ctd_ulint or ctud_ulint, but `boxes` is a ctu (declared on line 2): a ctu only counts up; declare it `var boxes ctud` to count both ways
The same rungs and tags in uppercase: true
```

The message of result 8 ends with the rule: "A newline ends a rung". Result 9 names
`ctu` for `boxes`, which `ctu_dint` declares: "`boxes` is a ctu".

## 0003. No dependencies and no generated code

This run and this measurement support
[0003. No dependencies and no generated code](../adr/0003-no-dependencies-no-generated-code.md).

### Only Erlang/OTP and Elixir, and a tree that reads back

This script shows 2 good results: logex needs only Erlang/OTP and Elixir, and a tree that
the printer prints reads back as the same tree. Run it from `examples/`, a Mix project that
has logex as its dependency. The first run also prints the compile lines of logex.

```elixir
# Load the description of logex if no Mix project loaded it.
_ = Application.load(:logex)
IO.puts("logex needs: #{inspect(Application.spec(:logex, :applications))}")

# The file that each module of logex comes from.
modules = Application.spec(:logex, :modules)
files = Enum.map(modules, &to_string(&1.module_info(:compile)[:source]))

from_lib =
  Enum.all?(files, &(String.contains?(&1, "/lib/logex") and String.ends_with?(&1, ".ex")))

IO.puts("each module comes from a .ex file under lib/: #{from_lib}")

# Text to tokens, tokens to a tree, the tree to text, and that text to a tree again.
text = """
( xic start | xic motor ) xio stop ote motor
xic motor ( xio overtemp | ) ote run_lamp
"""

{:ok, tokens, _end_line} = Logex.Lexer.tokenize(text)
{:ok, tree} = Logex.Parser.parse(tokens)
{:routine, {:rungs, [_rung_1, {:rung, [_xic, _motor, group | _]}]}} = tree
IO.puts("the branch of rung 2: #{inspect(group)}")

printed = Logex.Printer.print(tree)
IO.puts(printed)
{:ok, tokens, _end_line} = Logex.Lexer.tokenize(printed)
same = Logex.Parser.parse(tokens) == {:ok, tree}
IO.puts("the printed text reads back as the same tree: #{same}")
```

```console
$ mix run 0003-no-dependencies-no-generated-code.exs
logex needs: [:kernel, :stdlib, :elixir]
each module comes from a .ex file under lib/: true
the branch of rung 2: {:branches, [[{:name, 2, "xio"}, {:name, 2, "overtemp"}], []]}
( xic start | xic motor ) xio stop ote motor
xic motor ( xio overtemp | ) ote run_lamp
the printed text reads back as the same tree: true
```

The branch of rung 2 has 2 [legs](../../guides/reference/glossary.md#leg). The second leg
is the empty list `[]`. An empty leg passes the power that it receives.

### An overlap that no ExUnit test reads

A run on 2026-11-21 shows this cost. The diff adds 1 clause to `legs/3` in
`lib/logex/parser.ex`. `acc` holds the legs that the parser read before. The new clause
drops an empty leg when 3 legs or more come before it and another leg follows it:

```diff
     case branch(tokens, []) do
+      {:ok, [], [{:nxb, _} | rest]} when length(acc) >= 3 -> legs(rest, open, acc)
       {:ok, leg, [{:nxb, _} | rest]} -> legs(rest, open, [leg | acc])
```

The full suite passed with this overlap. But it changes a rung. Declare `aa`, `bb`, `cc`
and `ee` as `var_input`, each at 0. Then the rung
`( xic aa | xic bb | xic cc | | xic ee ) ote lamp` sets `lamp` to 1 with the correct
parser, because the empty leg passes power. With the overlap, the parser drops the empty
leg, and `lamp` is 0. The overlap does not change rung 2 of the script, because its empty
leg has only 1 leg before it.

## 0005. Every tag is declared

These runs support [0005. Every tag is declared](../adr/0005-every-tag-is-declared.md).

### 2 defects on older commits

Until 2026-09-28, logex checked no name against a declaration. Each name in a
[rung](../../guides/reference/glossary.md#rung) was a tag, and a name with no value read
as 0. Thus a typing error in a name gave a rung that did nothing, with no message. Commit
`5b63a9f` shows this. It reads declaration lines into a table, but it does not use the
table to check a rung. The [contact](../../guides/reference/glossary.md#contact)
`xic strat` is the error:

<!-- unchecked: a program that logex at commit 5b63a9f compiled with no diagnostic -->
```text
var_input start bool
var_input stop bool
var_output motor bool

( xic strat | xic motor ) xio stop ote motor
```

A run on a copy of that commit [compiles](../../guides/reference/glossary.md#compile) the program and
does 1 [scan](../../guides/reference/glossary.md#scan) with `start` at 1. The motor
stays off:

<!-- unchecked: the output of a run on a copy of commit 5b63a9f, 2026-11-21 -->
```text
instructionize: :ok
after a scan with start = 1: %{"motor" => 0, "start" => 1, "stop" => 0}
```

A second defect came from the operand list. Before M1-2, logex knew only the number of
[operands](../../guides/reference/glossary.md#operand) of each mnemonic. It took that
number of words after the mnemonic, also when a word was a mnemonic. On a copy of commit
`5360eb9`, the rung `xic aa mov src ote` writes 9 to a tag with the name `ote`, with no
error. `mov` was the name of `move` at that commit:

<!-- unchecked: the output of a run on a copy of commit 5360eb9, 2026-11-21 -->
```text
ir: {:routine,
 {:rungs,
  [rung: [xic: [{:name, 1, "aa"}], mov: [{:name, 1, "src"}, {:name, 1, "ote"}]]]}}
env: %{"aa" => 1, "ote" => 9, "src" => 9}
```

The mnemonic of a [coil](../../guides/reference/glossary.md#coil), `ote`, became the name
of a tag. A table of operand
signatures alone cannot find this error, because `ote` is a legal name.

### The rules of the record

This script compiles 14 programs of the motor, 2 files with `function_block`, 4
configuration files of the fan and 4 tags from Elixir. The script is
`examples/0005-every-tag-is-declared.exs`. Run it from `examples/`.

```elixir
# Print "compiles", or each diagnostic of the compile.
report = fn
  {:ok, _program_or_type} -> IO.puts("  compiles")
  {:error, diagnostics} -> Enum.each(diagnostics, &IO.puts("  " <> Logex.Diagnostic.format(&1)))
end

# The declarations of the motor: lines 1 to 4 of each program.
motor = """
var_input start bool
var_input stop bool
var_output motor bool
var_output speed_sp dint 1200
"""

programs = [
  {"1. A typing error in a name", motor <> "( xic strat | xic motor ) xio stop ote motor\n"},
  {"2. A program that declares nothing", "xic start ote motor\n"},
  {"3. A dint read as a bool", motor <> "xic speed_sp ote motor\n"},
  {"4. A rung that writes a var_input", motor <> "xic stop ote start\n"},
  {"5. A move with 1 operand", motor <> "var src dint\nmove src ote motor\n"},
  {"6. A mnemonic as the name of a tag", motor <> "var Ote bool\nxic start ote motor\n"},
  {"7. A timer that is not declared", motor <> "xic start ton t1 3000\n"},
  {"8. A preset on the declaration of a timer",
   motor <> "var t1 ton 3000\nxic start ton t1 3000\n"},
  {"9. An initial value that does not fit", motor <> "var r int 40000\nxic r ote motor\n"},
  {"10. A qualifier after the name", motor <> "var count retain dint\nxic start move 1 count\n"},
  {"11. A declaration after the first rung",
   motor <> "xic start ote motor\nvar late dint\nxic late ote motor\n"},
  {"12. A word after the initial value", motor <> "var r int 5 7\nxic r ote motor\n"},
  {"13. A configuration word as a tag", motor <> "var task bool\nxic start xio task ote motor\n"},
  {"14. A configuration word as a var_external",
   motor <> "var_external task bool\nxic start xio task ote motor\n"}
]

Enum.each(programs, fn {title, text} ->
  IO.puts(title)
  report.(Logex.compile(text, name: "motor"))
end)

# The same word in a program and in the file of a function block.
seal = "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n"
IO.puts("15. function_block as a tag, in a program, then in a block")

report.(
  Logex.compile(motor <> "var function_block bool\nxic start xio function_block ote motor\n",
    name: "motor"
  )
)

report.(
  Logex.compile(seal <> "var function_block bool\n( xic start | xic run ) xio stop ote run\n",
    name: "seal"
  )
)

# The words in a configuration file: a global, a device and an instance.
{:ok, fan} =
  Logex.compile("var_input hot bool\nvar_output fan bool\nxic hot ote fan\n", name: "fan")

plant = fn global, device, instance ->
  """
  task fast interval 10 priority 1
  var_global #{global} bool at #{device}.i.0
  var_global fan_q bool at panel.q.0
  program #{instance} fan with fast
  #{instance}.hot #{global}
  #{instance}.fan fan_q
  """
end

IO.puts("16. A mnemonic, then 3 configuration words, in a configuration file")
report.(Logex.Configuration.compile("plant", plant.("xic", "panel", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("task", "panel", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("hot_i", "program", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("hot_i", "panel", "retain"), %{"fan" => fan}))

# A tag declared from Elixir gets the checks of a declaration line.
declare = fn call ->
  try do
    tag = call.()
    IO.puts("  `#{tag.name}` is declared, qualifier: #{inspect(tag.retain)}")
  rescue
    error in ArgumentError -> IO.puts("  ArgumentError: " <> Exception.message(error))
  end
end

IO.puts("17. Tags declared from Elixir")
declare.(fn -> Logex.Tag.new!("count", :dint, :var, nil, retain: true) end)
declare.(fn -> Logex.Tag.new!("count", :dint, :var, nil, :retain) end)
declare.(fn -> Logex.Tag.new!("t1", Logex.FbType.ton(), :var, %{"pre" => 3000}) end)
declare.(fn -> Logex.Tag.new!("Ote", :bool) end)
```

```console
$ mix run 0005-every-tag-is-declared.exs
1. A typing error in a name
  line 5: `strat` is not declared — did you mean `start`?
2. A program that declares nothing
  line 1: `start` is not declared (this program declares no tags: each is now declared before the first rung, as in `var start bool` or `var start dint`)
  line 1: `motor` is not declared
3. A dint read as a bool
  line 5: `xic` reads a bool, but `speed_sp` is a dint (declared on line 4)
4. A rung that writes a var_input
  line 5: `ote` writes `start`, a var_input (declared on line 1): logic must not write an input
5. A move with 1 operand
  line 6: `move` expects 2 operands (a value, then a tag), found 1 before the instruction `ote`
6. A mnemonic as the name of a tag
  line 5: `Ote` is an instruction and cannot name a tag
7. A timer that is not declared
  line 5: `t1` is not declared
8. A preset on the declaration of a timer
  line 5: `t1` is a ton: its preset is the number on its `ton` instruction, as in `ton t1 5000`, not an initial value on its declaration
9. An initial value that does not fit
  line 5: `r` is an int: `40000` is outside -32768 to 32767
  line 6: `xic` reads a bool, but `r` is an int (declared on line 5)
10. A qualifier after the name
  line 5: `retain` comes straight after the section word, as in `var retain count dint`
11. A declaration after the first rung
  line 6: `var` after the first rung (line 5): declarations come first
  line 7: `xic` reads a bool, but `late` is a dint (declared on line 6)
12. A word after the initial value
  line 5: unexpected `7` after the declaration of `r`
  line 6: `r` is not declared
13. A configuration word as a tag
  compiles
14. A configuration word as a var_external
  line 5: `task` is a keyword of a configuration file, where a var_external's global is declared, so it cannot name a var_external
  line 6: `task` is not declared
15. function_block as a tag, in a program, then in a block
  compiles
  line 5: `function_block` heads a function block's file and cannot name a tag in one
16. A mnemonic, then 3 configuration words, in a configuration file
  compiles
  line 2: `task` is a keyword and cannot name a global
  line 2: `program` is a keyword and cannot name a device
  line 4: `retain` is a keyword and cannot name an instance
17. Tags declared from Elixir
  `count` is declared, qualifier: :retain
  ArgumentError: the options of `count` are a keyword list, `retain: true` or `non_retain: true`, found :retain
  ArgumentError: `t1` is a ton: its preset is the number on its `ton` instruction, as in `ton t1 5000`, not an initial value on its declaration
  ArgumentError: `Ote` is an instruction and cannot name a tag
```

Result 1 is the program of the first defect, with its typing error. Result 5 is the defect of
`5360eb9`: `move` stops at `ote`, and `ote motor` is a correct instruction. In results 9, 10
and 11, the line declares its tag. Thus the second diagnostic of results 9 and 11 is
about the type of the tag, and `move 1 count` in result 10 gets no diagnostic. In results
12 and 14, the line declares nothing.

## 0006. The types of IEC 61131-3 and overflow

### IEC 61131-3, Logix and Siemens

This table supports the Context of
[0006. The types of IEC 61131-3 and overflow](../adr/0006-iec-types-and-overflow.md).
Each new type asked the questions of the first column. IEC 61131-3
Edition 3 (2013) and the controllers answer them differently. The table gives their
answers from the sources of §4.12 of
[`docs/organisation.md`](../organisation.md#412-data-types-milestone-5):

| Question | IEC 61131-3 Edition 3 | Logix | Siemens |
|---|---|---|---|
| Names of the integer types | `SINT` to `LINT`, `USINT` to `ULINT` | The IEC names. The unsigned types only on CompactLogix 5380 and 5480 and ControlLogix 5580 and 5590 | The IEC names. The S7-1200 has no `LINT` and no `ULINT`, and the S7-1500 has both |
| An integer result outside its type | "an error", and the implementer decides what occurs | Wraps, and sets the status bit `S:V` | The S7-1200 wraps: "the least significant part of the result that fits" |
| The power out after a wrap | Not specified | The power in. A minor fault only if Report Overflow Faults is on | ENO of the S7-1200 is 0 |
| Types in 1 instruction | Only an implicit conversion that keeps each value (Figure 11). `INT + INT` computes in `INT`, also into a `DINT` | Converts any number type into any number type | The IEC check of TIA Portal, on by default, refuses signed and unsigned together |
| A real to an integer | To the nearest, a tie to the even integer. A value outside the target is the implementer's | To the nearest in the same way, then the low bits | `docs/organisation.md` gives no source |
| Arrays | Bounds, such as `[1..8]` or `[-2..5]` | A count from 0, such as `[8]`, up to 3 dimensions | Up to 6 dimensions |

The sources of the Logix column are these pages of the manuals, as §4.12 gives them:

- The names, and the unsigned types on the 5x80 controllers: 1756-RM018A pp.873 and 874,
  and the release notes 33.01.
- The wrap and `S:V`: 1756-RM018A p.868 and p.308. The power and the minor fault:
  1756-PM015Q p.57 and 1756-PM014O p.25.
- The conversions between number types: 1756-RM018A, Data type conversions, pp.871 to 874.
- The arrays: 1756-PM004L p.34 and 1756-RM094N p.85.

### The rules in a run

This run supports
[0006. The types of IEC 61131-3 and overflow](../adr/0006-iec-types-and-overflow.md). A
result number of the record, such as result 3, names a line that this run prints.

This script runs small programs of the box counter, the fan and the drive. It does 1
[scan](../../guides/reference/glossary.md#scan) of each program, except for results 20
and 21. It prints the [outputs](../../guides/reference/glossary.md#output), the faults or
the diagnostics. The script is `examples/0006-iec-types-and-overflow.exs`. Run it from
`examples/`.

```elixir
# Do 1 scan of a program and print its outputs and faults, or print its diagnostics.
# Each line that it prints starts with the text of label.
show = fn
  label, {:ok, program}, inputs ->
    state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), inputs)
    {outputs, state} = Logex.Runtime.scan(program, state, 10)
    faults = Enum.map(state.faults, & &1.kind)
    IO.puts("#{label}#{inspect(outputs)} faults: #{inspect(faults)}")

  label, {:error, diagnostics}, _inputs ->
    Enum.each(diagnostics, &IO.puts(label <> Logex.Diagnostic.format(&1)))
end

run = fn title, text, inputs ->
  IO.puts(title)
  show.("  ", Logex.compile(text, name: "box_line"), inputs)
end

# The box counter adds 1 to the top of each integer type. ok is the power out of the add.
IO.puts("1. The top of each integer type, plus 1")

tops = [
  sint: 127,
  int: 32767,
  dint: 2_147_483_647,
  lint: 9_223_372_036_854_775_807,
  usint: 255,
  uint: 65535,
  udint: 4_294_967_295,
  ulint: 18_446_744_073_709_551_615
]

for {type, top} <- tops do
  text = """
  var_input box bool
  var_output boxes #{type} #{top}
  var_output ok bool
  xic box add boxes 1 boxes ote ok
  """

  show.("  #{type} #{top} + 1: ", Logex.compile(text, name: "box_line"), %{"box" => 1})
end

run.(
  "2. 0 - 1 in a usint",
  """
  var_input box bool
  var_output boxes usint
  var_output ok bool
  xic box sub boxes 1 boxes ote ok
  """,
  %{"box" => 1}
)

run.(
  "3. 2 ints added into a dint",
  """
  var_input a int
  var_input b int
  var_output total dint
  var_output ok bool
  add a b total ote ok
  """,
  %{"a" => 32767, "b" => 1}
)

run.(
  "4. 1000 * 1000 in an int",
  """
  var_input a int
  var_output area int
  var_output ok bool
  mul a a area ote ok
  """,
  %{"a" => 1000}
)

run.(
  "5. A uint moved into a dint",
  """
  var_input hz uint
  var_output speed dint
  move hz speed
  """,
  %{"hz" => 65535}
)

run.(
  "6. A dint moved into an int",
  """
  var_input level dint
  var_output trim int
  move level trim
  """,
  %{}
)

run.(
  "7. A bool moved into an int",
  """
  var_input run bool
  var_output trim int
  move run trim
  """,
  %{}
)

run.(
  "8. A word added to a uint",
  """
  var_input status word
  var_output hz uint
  add status 1 hz
  """,
  %{}
)

# Each literal is moved into a tag of the type that the line names.
IO.puts("9. A literal that its type cannot hold")

for {type, literal} <- [int: "16#ffff", real: "16777217", dint: "1.5"] do
  text = """
  var_output trim #{type}
  move #{literal} trim
  """

  show.("  #{literal} into #{type}: ", Logex.compile(text, name: "box_line"), %{})
end

# The fan speed is a real. Each conversion writes into an int, and ok is its power out.
IO.puts("10. real_to_int and real_trunc_int of the fan speed")

speeds = [
  real_to_int: 2.5,
  real_to_int: 3.5,
  real_to_int: -2.5,
  real_to_int: 32767.6,
  real_to_int: 40000.7,
  real_trunc_int: 40000.7,
  real_trunc_int: -1.6
]

for {conversion, speed} <- speeds do
  text = """
  var_input speed real
  var_output hz int
  var_output ok bool
  #{conversion} speed hz ote ok
  """

  show.("  #{conversion} #{speed}: ", Logex.compile(text, name: "fan"), %{"speed" => speed})
end

run.(
  "11. dint_to_sint of 129, and word_to_byte of 16#1234",
  """
  var_input n dint
  var_input status word
  var_output trim sint
  var_output low byte
  var_output ok1 bool
  var_output ok2 bool
  dint_to_sint n trim ote ok1
  word_to_byte status low ote ok2
  """,
  %{"n" => 129, "status" => 0x1234}
)

run.(
  "12. dint_to_int with an sint source",
  """
  var_input small sint
  var_output trim int
  dint_to_int small trim
  """,
  %{"small" => -5}
)

run.(
  "13. not of a usint 5 into an int, and not of a bool into a word",
  """
  var_input n usint
  var_input left bool
  var_output wide int
  var_output mask word
  not n wide
  not left mask
  """,
  %{"n" => 5, "left" => 1}
)

# Each line runs 1 instruction on 2 reals, a and b, into the real r. ok is its power out.
IO.puts("14. A real result out of range, too near 0.0, and a divisor of 0.0")

reals = [
  {"mul", 2.0e38, 2.0},
  {"mul", -2.0e38, 2.0},
  {"mul", 1.2e-38, 0.001},
  {"div", 2.0e38, 0.0}
]

for {op, a, b} <- reals do
  text = """
  var_input a real
  var_input b real
  var_output r real
  var_output ok bool
  #{op} a b r ote ok
  """

  show.("  #{op} #{a} #{b}: ", Logex.compile(text, name: "fan"), %{"a" => a, "b" => b})
end

run.(
  "15. A real literal too near 0.0",
  """
  var_output speed real
  move 1.0e-40 speed
  """,
  %{}
)

run.(
  "16. Subscripts from 0, and a bit of an element",
  """
  var_input faults word[4]
  var_output lamp bool
  var_output first word
  xic faults[2].3 ote lamp
  move faults[0] first
  """,
  %{"faults" => [7, 0, 8, 0]}
)

run.(
  "17. The subscript 4 of an array of 4",
  """
  var temps real[4]
  var_output t real
  move temps[4] t
  """,
  %{}
)

run.(
  "18. An array of 65537",
  """
  var weights int[65537]
  var_output w int
  move weights[0] w
  """,
  %{}
)

run.(
  "19. A timer and a one-shot of an array, each through a tag subscript",
  """
  var_input slot dint
  var_input jam bool
  var lane_t ton[4]
  var edge bool[4]
  var_output reject bool
  xic jam ton lane_t[slot] 500
  xic jam ons edge[slot] ote reject
  """,
  %{}
)

# A counter does not wrap. The count starts at 32766, and 2 boxes go past the eye.
IO.puts("20. A ctu_int at the top of its type")

{:ok, counter} =
  Logex.compile(
    """
    var_input eye bool
    var boxes ctu_int
    var_output cv int
    var_output ov bool
    xic eye ctu boxes 32767
    move boxes.cv cv
    xic boxes.ov ote ov
    """,
    name: "boxes"
  )

start = Logex.Runtime.instance(counter)

Enum.reduce([0, 1, 0, 1], put_in(start.env["boxes"]["cv"], 32766), fn eye, state ->
  state = Logex.Runtime.put_inputs(counter, state, %{"eye" => eye})
  {outputs, state} = Logex.Runtime.scan(counter, state, 10)
  IO.puts("  eye #{eye}: #{inspect(outputs)}")
  state
end)

# The preset 5000 of a long timer is in nanoseconds. The 2 scans are 7 ms apart.
IO.puts("21. ton with the preset 5000 on a ton_ltime")

{:ok, jam} =
  Logex.compile(
    """
    var_input jam bool
    var jam_t ton_ltime
    var_output acc lint
    var_output done bool
    xic jam ton jam_t 5000
    move jam_t.acc acc
    xic jam_t.dn ote done
    """,
    name: "jam"
  )

state = Logex.Runtime.put_inputs(jam, Logex.Runtime.instance(jam), %{"jam" => 1})

Enum.reduce([0, 7], state, fn now, state ->
  {outputs, state} = Logex.Runtime.scan(jam, state, now)
  IO.puts("  at #{now} ms: #{inspect(outputs)}")
  state
end)
```

```console
$ mix run 0006-iec-types-and-overflow.exs
1. The top of each integer type, plus 1
  sint 127 + 1: %{"boxes" => -128, "ok" => 0} faults: []
  int 32767 + 1: %{"boxes" => -32768, "ok" => 0} faults: []
  dint 2147483647 + 1: %{"boxes" => -2147483648, "ok" => 0} faults: []
  lint 9223372036854775807 + 1: %{"boxes" => -9223372036854775808, "ok" => 0} faults: []
  usint 255 + 1: %{"boxes" => 0, "ok" => 0} faults: []
  uint 65535 + 1: %{"boxes" => 0, "ok" => 0} faults: []
  udint 4294967295 + 1: %{"boxes" => 0, "ok" => 0} faults: []
  ulint 18446744073709551615 + 1: %{"boxes" => 0, "ok" => 0} faults: []
2. 0 - 1 in a usint
  %{"boxes" => 255, "ok" => 0} faults: []
3. 2 ints added into a dint
  %{"ok" => 1, "total" => 32768} faults: []
4. 1000 * 1000 in an int
  %{"area" => 16960, "ok" => 0} faults: []
5. A uint moved into a dint
  %{"speed" => 65535} faults: []
6. A dint moved into an int
  line 3: `move` writes `level`, a dint, into `trim`, an int: a dint does not widen into an int, so convert it with `dint_to_int`
7. A bool moved into an int
  line 3: `move` writes `run`, a bool, into `trim`, an int: a bool does not widen into an int, and logex has no conversion between them
8. A word added to a uint
  line 3: `add` reads a number, but `status` is a word (declared on line 1): a word is a bit string, not a number: convert it first, with `word_to_uint`
9. A literal that its type cannot hold
  16#ffff into int: line 2: `move` writes `16#ffff` into `trim`, an int: it is outside -32768 to 32767
  16777217 into real: line 2: `move` writes `16777217` into `trim`, a real: it is no value of a real, which holds integers exactly only to 2^24: the nearest it holds is 16777216.0
  1.5 into dint: line 2: `move` writes `1.5` into `trim`, a dint: it is a real, and a dint holds only integers
10. real_to_int and real_trunc_int of the fan speed
  real_to_int 2.5: %{"hz" => 2, "ok" => 1} faults: []
  real_to_int 3.5: %{"hz" => 4, "ok" => 1} faults: []
  real_to_int -2.5: %{"hz" => -2, "ok" => 1} faults: []
  real_to_int 32767.6: %{"hz" => -32768, "ok" => 0} faults: []
  real_to_int 40000.7: %{"hz" => -25535, "ok" => 0} faults: []
  real_trunc_int 40000.7: %{"hz" => -25536, "ok" => 0} faults: []
  real_trunc_int -1.6: %{"hz" => -1, "ok" => 1} faults: []
11. dint_to_sint of 129, and word_to_byte of 16#1234
  %{"low" => 52, "ok1" => 0, "ok2" => 1, "trim" => -127} faults: []
12. dint_to_int with an sint source
  %{"trim" => -5} faults: []
13. not of a usint 5 into an int, and not of a bool into a word
  %{"mask" => 0, "wide" => 250} faults: []
14. A real result out of range, too near 0.0, and a divisor of 0.0
  mul 2.0e38 2.0: %{"ok" => 0, "r" => 3.4028234663852886e38} faults: []
  mul -2.0e38 2.0: %{"ok" => 0, "r" => -3.4028234663852886e38} faults: []
  mul 1.2e-38 0.001: %{"ok" => 1, "r" => 0.0} faults: []
  div 2.0e38 0.0: %{"ok" => 0, "r" => 0.0} faults: [:divide_by_zero]
15. A real literal too near 0.0
  line 2: `move` writes `1.0e-40` into `speed`, a real: it is too near 0.0 for a real, whose smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0
16. Subscripts from 0, and a bit of an element
  %{"first" => 7, "lamp" => 1} faults: []
17. The subscript 4 of an array of 4
  line 3: `temps[4]`'s subscript `4` is outside the elements of `temps`, 0 to 3: `temps` is an array of 4 reals (declared on line 1)
18. An array of 65537
  line 1: `weights` would hold 65537 elements, `[65537]`: an array holds 65536 at most
19. A timer and a one-shot of an array, each through a tag subscript
  line 6: `ton` runs `lane_t[slot]`, whose subscript `slot` holds: an instruction that runs an instance takes an element of an array of instances by literal subscripts, as in `ton lane_t[0]`, so that each element is one instance, run by one instruction whatever the program does
  line 7: `ons` keeps its storage bit in `edge[slot]`, whose subscript `slot` holds: a one-shot's storage bit is a bool, a bit with a literal number or an element with literal subscripts, as in `edge[0]`, so that it is one bit whatever the program does
20. A ctu_int at the top of its type
  eye 0: %{"cv" => 32766, "ov" => 0}
  eye 1: %{"cv" => 32767, "ov" => 0}
  eye 0: %{"cv" => 32767, "ov" => 0}
  eye 1: %{"cv" => 32767, "ov" => 1}
21. ton with the preset 5000 on a ton_ltime
  at 0 ms: %{"acc" => 0, "done" => 0}
  at 7 ms: %{"acc" => 5000, "done" => 1}
```

Result 1 shows the wrap in all 8 integer widths, and results 2 and 4 show it in a `sub`
and a `mul`. Result 4 shows that a wrapped value can look like a correct value:
1000 * 1000 in an `int` gives 16960. In result 10, 32767.6 goes to the nearest integer,
32768, which wraps to -32768.

Result 11 shows the 2 rules of power for a conversion. In result 13, `not` of a `bool` 1
into a `word` is 0, because `not` computes in the type of the `bool`. Result 14 shows a
real at the largest value of each sign, and a result too near 0.0 that writes 0.0 with
power. Result 20 shows that the counter stops at 32767 and sets `ov`, but an `add` wraps
(result 1). Result 21 shows that the [preset](../../guides/reference/glossary.md#preset)
of a long timer is in nanoseconds.

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
