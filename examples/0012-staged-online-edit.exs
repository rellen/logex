alias Logex.Configuration.Edit, as: PlantEdit
alias Logex.Edit
alias Logex.Runtime

{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the name of the program. compile_file/1 names this program `motor_v2`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

# Prints each entry of a report on a line of its own.
show = fn report -> Enum.each(report, &IO.puts("     #{inspect(&1)}")) end

# Gives the inputs to the program, runs 1 scan and prints the outputs.
scan = fn state, program, elapsed, inputs ->
  state = Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Runtime.scan(program, state, elapsed)
  IO.puts("     scan at #{state.now} ms: #{inspect(outputs)}")
  state
end

IO.puts("1. The original runs:")

state =
  Runtime.instance(motor)
  |> scan.(motor, 10, %{"start" => 1})
  |> scan.(motor, 10, %{"start" => 0})

IO.puts("2. accept/3 gives the forecast:")
{:ok, edit, forecast} = Edit.accept(motor, v2, state)
show.(forecast)

IO.puts("3. test/2 gives the same report. The candidate runs:")
{edit, state, report} = Edit.test(edit, state)
IO.puts("     the report is the forecast: #{report == forecast}")
state = state |> scan.(v2, 10, %{}) |> scan.(v2, 2000, %{})

IO.puts("4. untest/2. The original runs again:")
{edit, state, report} = Edit.untest(edit, state)
show.(report)
state = scan.(state, motor, 10, %{})

IO.puts("5. cancel/2 after the untest:")
{_motor, _state, report} = Edit.cancel(edit, state)
show.(report)

IO.puts("6. A change of type is refused:")
text = String.replace(File.read!("motor.ld"), "speed_sp dint", "speed_sp int")
{:ok, retyped} = Logex.compile(text, name: "motor")
{:error, [diagnostic]} = Edit.accept(motor, retyped, Runtime.instance(motor))
IO.puts("     " <> Logex.Diagnostic.format(diagnostic))

plant = """
task fast interval 10 priority 1
task slow interval 50 priority 2
var_global start_1 bool at panel.i.0
var_global stop_1  bool at panel.i.1
var_global start_2 bool at panel.i.2
var_global stop_2  bool at panel.i.3
var_global k1      bool at panel.q.0
var_global k2      bool at panel.q.1
program m1 motor with fast
  m1.start    start_1
  m1.stop     stop_1
  m1.overtemp 0
  m1.reset    0
  m1.motor    k1
program m2 motor with slow
  m2.start    start_2
  m2.stop     stop_2
  m2.overtemp 0
  m2.reset    0
  m2.motor    k2
"""

# Compiles the text of a configuration that runs motor.ld.
configuration = fn text ->
  {:ok, configuration} = Logex.Configuration.compile("plant", text, %{"motor" => motor})
  configuration
end

{runtime, _outputs, _events} = Runtime.start(configuration.(plant)) |> Runtime.cycle(0, %{})
{runtime, _outputs, _events} = Runtime.cycle(runtime, 10, %{})

IO.puts("7. A plant: an instance cannot move to a different task:")
moved = String.replace(plant, "m2 motor with slow", "m2 motor with fast")
{:error, [diagnostic]} = PlantEdit.accept(runtime, configuration.(moved))
IO.puts("     " <> Logex.Diagnostic.format(diagnostic))

IO.puts("8. An interval can change. The forecast:")
faster = String.replace(plant, "slow interval 50", "slow interval 20")
{:ok, edit, forecast} = PlantEdit.accept(runtime, configuration.(faster))
show.(forecast)

IO.puts("9. A step on an edit that has ended is refused:")
{_plant, runtime, []} = PlantEdit.cancel(edit, runtime)

try do
  PlantEdit.test(edit, runtime)
rescue
  error in ArgumentError -> IO.puts("     " <> error.message)
end
