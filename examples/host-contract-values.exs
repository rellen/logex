# The values that the host gives to the inputs of fan.ld, and the state that it gets.
alias Logex.Runtime

refused = fn label, call ->
  try do
    call.()
    IO.puts("#{label}: no error")
  rescue
    error in ArgumentError ->
      IO.puts("#{label}:\n  " <> String.replace(error.message, "\n", "\n  "))
  end
end

{:ok, fan} = Logex.compile_file("host-contract/fan.ld")
state = Runtime.instance(fan)
IO.puts("The state of a new instance:")
IO.inspect(state.env)

inputs = %{
  "run" => 1,
  "level" => 255,
  "trim" => -32768,
  "hz" => 16_777_217,
  "limits" => [1, 2, 3]
}

state = Runtime.put_inputs(fan, state, inputs)
{_outputs, state} = Runtime.scan(fan, state, 0)
{outputs, state} = Runtime.scan(fan, state, 600)
IO.puts("\nThe outputs and the state after 2 scans:")
IO.inspect(outputs)
IO.inspect(state.env)
IO.puts("now: #{state.now}, first: #{state.first}, faults: #{inspect(state.faults)}")

IO.puts("\nAn element by its name:")
IO.inspect(Runtime.put_inputs(fan, state, %{"limits[2]" => 9}).env["limits"])
IO.puts("A real input of 0.1:")
IO.inspect(Runtime.put_inputs(fan, state, %{"hz" => 0.1}).env["hz"])

IO.puts("\nInputs that logex refuses:")
refused.("usint 256", fn -> Runtime.put_inputs(fan, state, %{"level" => 256}) end)
refused.("usint -1", fn -> Runtime.put_inputs(fan, state, %{"level" => -1}) end)
refused.("int 1.0", fn -> Runtime.put_inputs(fan, state, %{"trim" => 1.0}) end)
refused.("real 1.0e39", fn -> Runtime.put_inputs(fan, state, %{"hz" => 1.0e39}) end)
refused.("real :nan", fn -> Runtime.put_inputs(fan, state, %{"hz" => :nan}) end)
refused.("array of 2", fn -> Runtime.put_inputs(fan, state, %{"limits" => [1, 2]}) end)
refused.("array as a tuple", fn -> Runtime.put_inputs(fan, state, %{"limits" => {1, 2, 3}}) end)
refused.("element 40000", fn -> Runtime.put_inputs(fan, state, %{"limits" => [1, 2, 40000]}) end)
refused.("element 3", fn -> Runtime.put_inputs(fan, state, %{"limits[3]" => 1}) end)

refused.("element by 2 subscripts", fn ->
  Runtime.put_inputs(fan, state, %{"limits[1,1]" => 1})
end)

refused.("whole and element", fn ->
  Runtime.put_inputs(fan, state, %{"limits" => [1, 2, 3], "limits[2]" => 9})
end)

refused.("1 element 2 times", fn ->
  Runtime.put_inputs(fan, state, %{"limits[1]" => 1, "limits[01]" => 2})
end)

IO.puts("\nStates that logex refuses:")
refused.("t1 not a map", fn -> Runtime.scan(fan, %{state | env: Map.put(state.env, "t1", 5)}) end)

refused.("t1.last after now", fn ->
  Runtime.scan(fan, %{state | env: put_in(state.env, ["t1", "last"], 9999)})
end)

refused.("hz 0.1", fn -> Runtime.scan(fan, %{state | env: Map.put(state.env, "hz", 0.1)}) end)

refused.("steps as a list", fn ->
  Runtime.scan(fan, %{state | env: Map.put(state.env, "steps", [1, 2, 3])})
end)

refused.("no steps", fn -> Runtime.scan(fan, %{state | env: Map.delete(state.env, "steps")}) end)
