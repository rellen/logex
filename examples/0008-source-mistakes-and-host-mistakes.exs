# Print each diagnostic of a compile, or "compiles".
report = fn
  {:ok, _program_or_type} -> IO.puts("  compiles")
  {:error, diagnostics} -> Enum.each(diagnostics, &IO.puts("  " <> Logex.Diagnostic.format(&1)))
end

# Run a call, and print what it returns or the exception it raises, 1 line of its
# message on each line of output.
refused = fn call ->
  try do
    IO.puts("  returned " <> inspect(call.()))
  rescue
    error ->
      message = String.replace(Exception.message(error), "\n", "\n    ")
      IO.puts("  #{inspect(error.__struct__)}: " <> message)
  end
end

motor = """
var_input start bool
var_input stop bool
var_output motor bool
var_output speed_sp dint 1200
"""

IO.puts("1. A program with 2 errors in its text")
report.(Logex.compile(motor <> "xic strat ote motor\nxic speed_sp ote motor\n", name: "motor"))

IO.puts("2. A lex error stops the compile")
report.(Logex.compile(motor <> "xic st@rt ote motor\nxic strat ote motor\n", name: "motor"))

IO.puts("3. A number of 10001 digits")

report.(
  Logex.compile(motor <> "xic start move #{String.duplicate("1", 10_001)} speed_sp\n",
    name: "motor"
  )
)

IO.puts("4. An array of 65537 elements")
report.(Logex.compile(motor <> "var log int[65537]\nxic start move 1 log[0]\n", name: "motor"))

IO.puts("5. 102 names that are not declared")
eyes = for i <- 1..102, into: "var_output full_lamp bool\n", do: "var_input eye_#{i} bool\n"
rungs = for i <- 1..102, into: "", do: "xic eey_#{i} ote full_lamp\n"
{:error, diagnostics} = Logex.compile(eyes <> rungs, name: "boxes")
IO.puts("  #{length(diagnostics)} diagnostics, of which the 100th and the 101st are:")
diagnostics |> Enum.slice(99..100) |> Enum.each(&IO.puts("  " <> Logex.Diagnostic.format(&1)))

IO.puts("6. A program name that no file can give")
refused.(fn -> Logex.compile(motor <> "xic start ote motor\n", name: "1motor") end)

{:ok, program} = Logex.compile(motor <> "xic start ote motor\n", name: "motor")
state = Logex.Runtime.instance(program)

IO.puts("7. 2 wrong inputs in 1 call")
refused.(fn -> Logex.Runtime.put_inputs(program, state, %{"motor" => 1, "strat" => 1}) end)

IO.puts("8. A state with a value outside the type of its tag")
refused.(fn -> Logex.Runtime.scan(program, put_in(state.env["speed_sp"], 5_000_000_000)) end)
refused.(fn -> Logex.Runtime.scan(program, put_in(state.env["speed_sp"], 37.5)) end)

IO.puts("9. A program edited by hand after it compiled")

{:ok, boxes} =
  Logex.compile("var_input eye bool\nvar_output count dint\nxic eye add count 1 count\n",
    name: "boxes"
  )

edited = put_in(boxes.tags["count"].type, :bool)
refused.(fn -> Logex.Runtime.instance(edited) end)
checked = Logex.Runtime.instance(boxes)
refused.(fn -> Logex.Runtime.scan(edited, checked) |> elem(0) end)

refused.(fn ->
  Logex.Runtime.scan(edited, Logex.Runtime.put_inputs(boxes, checked, %{"eye" => 1}))
end)

IO.puts("10. A block type edited by hand, given in types:")

{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n( xic start | xic run ) xio stop ote run\n",
    name: "seal"
  )

uses_seal = motor <> "var s1 seal\ncal s1 start stop motor\n"
report.(Logex.compile(uses_seal, name: "motor", types: [seal]))
edited_seal = put_in(seal.body.tags["run"].initial, 1)

try do
  Logex.compile(uses_seal, name: "motor", types: [edited_seal])
rescue
  # Print the message up to the type that it quotes, which is long.
  error in ArgumentError ->
    [start | _] = String.split(Exception.message(error), ", got: ")
    IO.puts("  ArgumentError: " <> start <> ", got: %Logex.FbType{...}")
end

IO.puts("11. A path that names nothing, to get/2 and to get!/2")

{:ok, fan} =
  Logex.compile("var_input hot bool\nvar_output fan bool\nxic hot ote fan\n", name: "fan")

plant =
  "task fast interval 10 priority 1\nvar_global hot_i bool\nprogram f1 fan with fast\nf1.hot hot_i\n"

{:ok, config} = Logex.Configuration.compile("plant", plant, %{"fan" => fan})
resource = Logex.Runtime.start(config)
IO.puts("  " <> inspect(Logex.Runtime.get(resource, "f1.fna")))
refused.(fn -> Logex.Runtime.get!(resource, "f1.fna") end)

IO.puts("12. A wrong initial value of a global, from text and from Elixir")

report.(
  Logex.Configuration.compile("plant", String.replace(plant, "hot_i bool", "hot_i bool 2"), %{
    "fan" => fan
  })
)

refused.(fn ->
  Logex.Configuration.new!(
    name: "plant",
    programs: [fan],
    tasks: [%Logex.Configuration.Task{name: "fast", interval: 10, priority: 1}],
    globals: [Logex.Configuration.Global.new!("hot_i", :bool, initial: 2)],
    instances: [%Logex.Configuration.Instance{name: "f1", type: "fan", task: "fast"}],
    connections: [%Logex.Configuration.Connection{instance: "f1", member: "hot", to: "hot_i"}]
  )
end)

IO.puts("13. A module outside the host contract")
refused.(fn -> Logex.Diagnostic.format(:motor) end)
