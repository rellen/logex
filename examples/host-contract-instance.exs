# Each call gives a wrong argument to Logex.Runtime. The script prints the message.
alias Logex.Runtime
alias Logex.Scan

refused = fn label, call ->
  try do
    call.()
    IO.puts("#{label}: no error")
  rescue
    error in ArgumentError ->
      IO.puts("#{label}:\n  " <> String.replace(error.message, "\n", "\n  "))
  end
end

{:ok, motor} = Logex.compile_file("motor.ld")
state = Runtime.instance(motor)

{:ok, seal} =
  Logex.compile("function_block seal\nvar_input go bool\nvar_output run bool\nxic go ote run",
    name: "seal"
  )

refused.("instance/1 with an atom", fn -> Runtime.instance(:motor) end)
refused.("instance/1 with a block type", fn -> Runtime.instance(seal) end)

refused.("put_inputs/3 with a map that is wrong", fn ->
  Runtime.put_inputs(motor, state, %{"motor" => 1, "strat" => 1})
end)

refused.("put_inputs/3 with 3 wrong inputs", fn ->
  Runtime.put_inputs(motor, state, %{"stop" => 3, "start" => true, "fault" => 1})
end)

refused.("put_inputs/3 with an atom key", fn -> Runtime.put_inputs(motor, state, %{start: 1}) end)
refused.("put_inputs/3 with a list", fn -> Runtime.put_inputs(motor, state, [{"start", 1}]) end)
refused.("put_inputs/3 with no state", fn -> Runtime.put_inputs(motor, %{}, %{}) end)
refused.("scan/3 with -1 ms", fn -> Runtime.scan(motor, state, -1) end)
refused.("scan/3 with 1.5 ms", fn -> Runtime.scan(motor, state, 1.5) end)
refused.("restart/3 with :hot", fn -> Runtime.restart(motor, state, :hot) end)

{_outputs, later} = Runtime.call(motor, state, %{}, %Scan{now: 10, first: true})

refused.("call/4 at 9 ms after 10 ms", fn ->
  Runtime.call(motor, later, %{}, %Scan{now: 9, first: false})
end)

refused.("call/4 with first: true again", fn ->
  Runtime.call(motor, later, %{}, %Scan{now: 10, first: true})
end)

refused.("call/4 with a map", fn -> Runtime.call(motor, state, %{}, %{now: 0, first: true}) end)

refused.("call/4 with scan.tags", fn ->
  Runtime.call(motor, state, %{}, %Scan{now: 0, first: true, tags: %{}})
end)

bad = %{state | env: %{state.env | "start" => 5, "speed_sp" => 5_000_000_000, "fault" => 37.5}}
refused.("scan/2 with 3 values outside their types", fn -> Runtime.scan(motor, bad) end)

refused.("scan/2 with an atom key in env", fn ->
  Runtime.scan(motor, %{state | env: Map.put(state.env, :faults, [])})
end)

refused.("scan/2 with state.now -1 and state.first :x", fn ->
  Runtime.scan(motor, %{state | now: -1, first: :x})
end)

edited = %{motor | tags: Map.update!(motor.tags, "speed_sp", &%{&1 | type: :real})}
refused.("instance/1 with a program edited by hand", fn -> Runtime.instance(edited) end)

{:ok, pump} = Logex.compile(File.read!("motor.ld"), name: "pump")
refused.("scan/2 with the state of motor", fn -> Runtime.scan(pump, state) end)
