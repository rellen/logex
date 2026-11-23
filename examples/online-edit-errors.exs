alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

# Each call is a wrong argument. The script prints the message of each ArgumentError.
raised = fn label, call ->
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts(String.pad_trailing(label, 22) <> error.message)
  end
end

lamp = "var_input go bool\nvar_output lamp bool\nxic go ote lamp"
{:ok, line} = Logex.compile(lamp, name: "line")
{:ok, other} = Logex.compile(lamp, name: "other")

{:ok, seal} =
  Logex.compile("function_block seal\nvar_input go bool\nvar_output run bool\nxic go ote run",
    name: "seal"
  )

state = Logex.Runtime.instance(line)

raised.("a program renamed", fn -> Logex.Edit.accept(line, other, state) end)
raised.("not a program", fn -> Logex.Edit.accept(line, :line, state) end)
raised.("a block type", fn -> Logex.Edit.accept(line, seal, state) end)
raised.("no edit", fn -> Logex.Edit.test(:edit, state) end)
{:ok, edit, []} = Logex.Edit.accept(line, line, state)
raised.("a step at its stage", fn -> Logex.Edit.untest(edit, state) end)
raised.("the state of another", fn -> Logex.Edit.test(edit, Logex.Runtime.instance(other)) end)

# Under test, the new program has no var_input `go`.
{:ok, new} = Logex.compile(String.replace(lamp, "var_input go", "var go"), name: "line")
{:ok, edit, _forecast} = Logex.Edit.accept(line, new, state)
{edit, state, _report} = Logex.Edit.test(edit, state)

raised.("an input of the old", fn ->
  Logex.Runtime.put_inputs(Logex.Edit.running(edit), state, %{"go" => 1})
end)

raised.("an input of no one", fn ->
  Logex.Runtime.put_inputs(Logex.Edit.running(edit), state, %{"nope" => 1})
end)

raised.("a cancel under test", fn -> Logex.Edit.cancel(edit, state) end)

# A configuration: wrong arguments, and a step on an edit that has ended.
plant =
  "task fast interval 10 priority 1\nvar_global go bool at panel.i.0\nprogram m1 line with fast\n  m1.go go\n"

{:ok, configuration} = Logex.Configuration.compile("plant", plant, %{"line" => line})
{:ok, renamed} = Logex.Configuration.compile("other", plant, %{"line" => line})

{:ok, larger} =
  Logex.Configuration.compile("plant", plant <> "var_global spare bool\n", %{"line" => line})

runtime = Logex.Runtime.start(configuration)
alias Logex.Configuration.Edit
raised.("a plant renamed", fn -> Edit.accept(runtime, renamed) end)
raised.("a time below 0", fn -> Edit.accept(runtime, configuration, -1) end)
raised.("not an edit", fn -> Edit.test(:edit, runtime) end)
{:ok, edit, []} = Edit.accept(runtime, configuration)
raised.("another resource", fn -> Edit.test(edit, Logex.Runtime.start(larger)) end)
{_configuration, runtime, []} = Edit.cancel(edit, runtime)
raised.("an edit that ended", fn -> Edit.test(edit, runtime) end)

# A runner: a step with no edit held, an accept of no configuration, and a step at its
# stage.
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: configuration,
    clock: {Manual, clock},
    io: %{"panel" => {Sim, sim: panel}}
  )

raised.("the runner, no edit", fn -> Runner.test(runner) end)
raised.("the runner, no plant", fn -> Runner.accept(runner, :plant) end)
{:ok, []} = Runner.accept(runner, configuration)
raised.("the runner, its stage", fn -> Runner.assemble(runner) end)
:ok = Runner.stop(runner)
