# Runs and tables of the records: typespecs

This page is for a contributor who reads the decision record about typespecs and
Dialyzer. It holds the run, the measurements and the long tables of record 0022, so that
the record stays short. The record links to this section.

The suite runs each example of this page, as it runs the examples of each other page.
The script is under `examples/`.

## 0022. Typespecs and Dialyzer

These runs and tables support
[0022. Typespecs and Dialyzer](../adr/0022-typespecs-and-dialyzer.md). A warning on this
page is a warning of Dialyzer, and a test is an ExUnit test.

### The problems before the decision

1. **No line between the host and the rest** (decision 514). A review called 40
   documented functions with wrong arguments, in 118 cases. Each of these functions
   takes only values that logex makes. For example, `Logex.Program.initial_env(:x)` and
   `Logex.Walk.writes(nil)` raised `FunctionClauseError`. The rule of logex is different.
   A wrong argument of the host gets an `ArgumentError`, and a test compares its message.
2. **The examples call more modules** (decision 523). The examples of the pages call
   `Logex.Diagnostic.format/1`, `Logex.IO.Sim`, the clocks of the runner, the parts of a
   configuration and `Logex.FbType.ctu/0`. Decision 514 did not say if these modules are
   in the contract.
3. **No types and no static analysis** (decision 515). No function had a spec, and no
   tool compared the code with a type.
4. **Warnings that are not defects** (decision 551). The first run of Dialyzer gave 12
   warnings, and none was a defect. 10 of them had the same cause. A function called a
   second function only to raise its refusal. An example is the refusal of a wrong
   `steps:` option of the runner. Dialyzer read that call as a call that never returns.
5. **logex read the fields of the opaque resource** (decision 553). The specs made
   `Logex.Runtime.t()` opaque. `Logex.Configuration.Edit` reads the fields of the
   resource at each step, and it broke the opacity in 28 places.
6. **Specs that Dialyzer cannot check** (decision 554). Dialyzer finds no type for the
   value of a call to a process, or for the field of a struct. On 2026-11-23,
   `dialyzer -Wspecdiffs` gave `any()` as the type of the value for 33 of the 101 specs.
   Among them are 15 functions of the runner, 6 of `Logex.IO.Sim` and 3 of the manual
   [clock](../../guides/reference/glossary.md#clock). `Logex.compile/2`,
   `Logex.compile_file/1` and `Logex.compile_files/1` are also among them. For these 33
   specs, Dialyzer finds no error in a wrong return type.

### A script that counts the specs

The script `examples/0022-typespecs-and-dialyzer.exs` reads the specs and the opaque
types of each module of the contract from its compiled file. It counts the modules whose
moduledoc says that they are outside. Then it gives the same wrong value to a function
inside the contract and to a function outside it. Run it from `examples/`.

```elixir
# The modules of the host contract: the way in (decision 514), then the tools of the host
# and the parts of a configuration (decision 523).
contract = [
  Logex,
  Logex.Runtime,
  Logex.Edit,
  Logex.Configuration,
  Logex.Configuration.Edit,
  Logex.Runner,
  Logex.IO,
  Logex.Tag,
  Logex.Configuration.Task,
  Logex.Configuration.Global,
  Logex.Configuration.Instance,
  Logex.Configuration.Connection,
  Logex.IO.Point,
  Logex.IO.Sim,
  Logex.Runner.Clock,
  Logex.Runner.Clock.Manual,
  Logex.Runner.Clock.Monotonic
]

# Reads the specs and the opaque types of a module from its compiled file.
specs = fn module ->
  {:ok, specs} = Code.Typespec.fetch_specs(module)
  length(specs)
end

opaque = fn module ->
  {:ok, types} = Code.Typespec.fetch_types(module)
  for {:opaque, {name, _type, _parameters}} <- types, do: "#{name}()"
end

# Gives "" for no opaque type, and the list after a comma for each other list.
shown = fn
  [] -> ""
  names -> ", opaque " <> Enum.join(names, " and ")
end

IO.puts("1. The host contract")

for module <- contract do
  IO.puts("   #{inspect(module)}: #{specs.(module)} specs" <> shown.(opaque.(module)))
end

IO.puts("   #{length(contract)} modules, #{Enum.sum(Enum.map(contract, specs))} specs")

# Gives the moduledoc of a module on 1 line, or "" for a hidden module.
moduledoc = fn
  {:docs_v1, _, :elixir, _, %{"en" => text}, _, _} -> String.replace(text, ~r/\s+/, " ")
  _hidden -> ""
end

# A module outside the contract ends its moduledoc with 1 sentence that says so. The
# script loads the application of logex to read its list of modules.
_ = Application.load(:logex)
sentence = "Outside the host contract, this module takes logex's own data unguarded"
outside? = &String.contains?(moduledoc.(Code.fetch_docs(&1)), sentence)
outside = Enum.filter(Application.spec(:logex, :modules), outside?)
IO.puts("2. Outside the contract")
IO.puts("   #{length(outside)} modules, #{Enum.sum(Enum.map(outside, specs))} specs")

# Runs a call and prints the exception that it raises.
raised = fn call ->
  try do
    IO.puts("   returned " <> inspect(call.()))
  rescue
    error -> IO.puts("   #{inspect(error.__struct__)}: " <> Exception.message(error))
  end
end

IO.puts(~s(3. The name "motor" in place of the program motor))
raised.(fn -> Logex.Runtime.instance("motor") end)
raised.(fn -> Logex.Program.initial_env("motor") end)
```

```console
$ mix run 0022-typespecs-and-dialyzer.exs
1. The host contract
   Logex: 3 specs
   Logex.Runtime: 25 specs, opaque t()
   Logex.Edit: 7 specs, opaque t()
   Logex.Configuration: 7 specs
   Logex.Configuration.Edit: 10 specs, opaque t()
   Logex.Runner: 19 specs
   Logex.IO: 2 specs
   Logex.Tag: 4 specs
   Logex.Configuration.Task: 0 specs
   Logex.Configuration.Global: 2 specs
   Logex.Configuration.Instance: 0 specs
   Logex.Configuration.Connection: 0 specs
   Logex.IO.Point: 0 specs
   Logex.IO.Sim: 13 specs
   Logex.Runner.Clock: 3 specs
   Logex.Runner.Clock.Manual: 6 specs
   Logex.Runner.Clock.Monotonic: 0 specs
   17 modules, 101 specs
2. Outside the contract
   15 modules, 0 specs
3. The name "motor" in place of the program motor
   ArgumentError: expected a %Logex.Program{} from Logex.compile/2, got: "motor"
   FunctionClauseError: no function clause matching in Logex.Program.initial_env/1
```

The 5 modules with 0 specs have no public function that needs a spec. 4 of them are
structs, and `Logex.Runner.Clock.Monotonic` has only the callbacks of
`Logex.Runner.Clock`. Result 3 shows where the contract ends. A function of the contract
gives 1 `ArgumentError` with a message. A function outside it gives what Elixir raises.

### The modules of the host contract

| Group | Modules |
|---|---|
| The way in (decision 514) | `Logex`, `Logex.Runtime`, `Logex.Edit`, `Logex.Configuration`, `Logex.Configuration.Edit`, `Logex.Runner`, `Logex.IO` and `Logex.Tag` |
| The tools of the host and the parts of a configuration (decision 523) | `Logex.Configuration.Task`, `Logex.Configuration.Global`, `Logex.Configuration.Instance`, `Logex.Configuration.Connection`, `Logex.IO.Point`, `Logex.IO.Sim`, `Logex.Runner.Clock`, `Logex.Runner.Clock.Manual` and `Logex.Runner.Clock.Monotonic` |

### The flags of Dialyzer

`scripts/dialyzer.sh` turns on these 6 flags beside the default warnings:

| Flag | The warning |
|---|---|
| `-Wextra_return` | A spec gives a value that its function never returns |
| `-Wmissing_return` | A spec omits a value that its function returns |
| `-Wunderspecs` | A spec lets in more values than its function takes or gives |
| `-Woverlapping_contract` | 2 specs of 1 function take the same arguments |
| `-Wopaque_union` | A function returns an opaque value or another value |
| `-Wunmatched_returns` | A call whose structured value the code drops (decision 550) |

### The time of a run of Dialyzer

The first run of the script on a computer builds the PLT. On 2026-11-23, on a computer of
4 cores, that took 44 s to 61 s. With the PLT kept, a run of the script took 17 s to
27 s. The analysis of Dialyzer took 8 s to 19 s of that time.

### A red run of Dialyzer

This is the end of a red run. On 2026-11-23 a copy of the code had a false spec: the spec
of `Logex.Runtime.overlaps/1` gave a list where the function gives a map. Dialyzer gave
7 warnings and exited with 2. The last one was this:

<!-- unchecked: the last warning of scripts/dialyzer.sh on a copy of the code with a false spec of overlaps/1, a run of 2026-11-23 -->
```text
lib/logex/runtime.ex:1593: Invalid type specification for function 'Elixir.Logex.Runtime':overlaps/1.
 The success typing is 'Elixir.Logex.Runtime':overlaps
          (#{'__struct__' := 'Elixir.Logex.Runtime', _ => _}) -> map()
 But the spec is 'Elixir.Logex.Runtime':overlaps
          (t()) -> [non_neg_integer()]
 The return types do not overlap
```

Dialyzer also gave 6 warnings in `Logex.Configuration.Edit`, which calls `overlaps/1`.
Correct the spec or the code until they agree.
[The toolchain and the gates](../contributing/toolchain.md) gives the steps.

### A red run of the test of the specs

On 2026-11-23, a copy of the code had a false spec of `Logex.Runner.status/1`. The false
spec gave `:ok` as the only value. Dialyzer exited with 0. The test failed with this
line:

<!-- unchecked: a line of a failure of typespec_test.exs on a copy of the code with a false spec of Logex.Runner.status/1, a run of 2026-11-23, the map cut -->
```text
Logex.Runner.status/1 gave what its spec does not: %{status: :running, now: 12, edit: nil, ...}
```

Correct the spec or the code until they agree.

### 5 changes to a spec

On 2026-11-23 a copy of the code had 5 changes to a spec, 1 at a time. The "Tests" column
is `runtime_test.exs` and `typespec_test.exs` together, and the "Dialyzer" column is
`scripts/dialyzer.sh`:

| Change to a spec | Tests | Dialyzer |
|---|---|---|
| `Logex.Edit.stage/1`: spec removed | 3 fail | exit 0 |
| `Logex.Runtime.overlaps/1`: a list | 1 fails | exit 2 |
| `Logex.Runtime.overlaps/1`: also `:none` | each passes | exit 2 |
| `Logex.Runner.status/1`: `:ok` | 1 fails | exit 0 |
| `Logex.Edit.stage/1`: any `atom` | each passes | exit 0 |

The third change is wider, and Dialyzer refuses it because it types the value of
`overlaps/1` as a map. The last change passes both checks because `atom` holds each of
the 3 values of `Logex.Edit.stage/1`, and Dialyzer types its value as `any()`. Only
`edit_test.exs` finds a wrong value of `stage/1`, because it compares each stage with its
value.

### A wrong initial value of a global

`Global.new!("fan_on", :bool, initial: true)` raises an `ArgumentError` when it gets the
value (decision 555). Its message has the words of `check/1` (decision 575):

<!-- unchecked: the message of Logex.Configuration.Global.new!/3 for initial: true, a run of 2026-11-23 on main 263fc95 -->
```text
the initial value of global `fan_on` must be an integer, found true
```

### Each option not taken

| Alternative | Why logex does not use it |
|---|---|
| Check each argument of each documented function (decision 514) | The maintainer chose the way in. This option adds a check, and a message that a test compares, to 40 functions that take only what logex makes |
| Make the helpers of the contract `@doc false`, so that the documented functions are the contract (decision 514) | The maintainer chose the way in. The modules of the compiler and the walks stay documented |
| Put `Logex.Diagnostic.format/1` in the contract (decision 523) | It takes only a diagnostic that logex returns. The maintainer kept it outside, with `Logex.FbType` and `Logex.Scan` |
| The 8 modules of decision 514 alone as the contract (decision 523) | The examples call the simulated device, the clocks and the parts of a configuration with arguments that a host makes |
| Specs on the modules of decision 514 alone (decision 552) | `Logex.IO.Sim`, the clocks and the parts of a configuration then have no spec |
| Specs on the documented functions alone (decision 552) | The internal functions then have no spec, and Dialyzer does not check them. The runner and a configuration edit call such functions |
| Dialyzer by hand and in CI only (decision 549) | A contributor learns of a broken spec from CI, minutes after the push |
| Dialyzer as a test of the suite (decision 549) | Each run of `mix test` takes 20 s to 35 s longer, with the PLT kept |
| Silence a warning with `@dialyzer {:nowarn_function, ...}` (decision 551) | The mark stays when the code changes, and it hides the next defect |
| Turn a class of warnings off (decision 551) | A class off hides each defect of that class |
| `-Wunmatched_returns` off (decision 550) | A change that drops an `{:error, _}`, for example of a write of the store, passes |
| `-Werror_handling` on (decision 550) | Only a `no_return()` spec passes its 18 warnings, and that spec silences a warning |
| `-Wno_opaque`, with the rule of opacity in the documents only (decision 553) | Dialyzer then gives no warning when a module reads an opaque value |
| A plain type for the resource (decision 553) | The same: no check of the opacity |
| A test that reaches each value of the return type of each spec (decision 554) | The tests must then cause each error value in a run. The file gets much longer. The maintainer kept the limit |
| No `typespec_test.exs` (decision 554) | 33 specs then have no check |
| Keep the wrong initial value of a global until `new!/1` (decision 555) | The struct is outside `Global.t()`, and the refusal comes far from its cause |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The toolchain and the gates](../contributing/toolchain.md): the steps to run Dialyzer.
