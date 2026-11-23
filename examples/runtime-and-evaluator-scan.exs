{:ok, scales} = Logex.compile_file("scales.ld")

# A new instance: each tag at its initial value. The array is a tuple.
state = Logex.Runtime.instance(scales)
IO.inspect(state, label: "instance", width: 70)

# call/4 is 1 scan. The host gives the inputs and a %Logex.Scan{}.
scan = fn state, inputs, now ->
  at = %Logex.Scan{now: now, first: state.first}
  {outputs, state} = Logex.Runtime.call(scales, state, inputs, at)
  IO.inspect(outputs, label: "t=#{now} outputs")
  state
end

state = scan.(state, %{"eye" => 0}, 0)
state = scan.(state, %{"eye" => 1, "weight" => 620, "slot" => 2}, 10)
IO.inspect(state.env["weights"], label: "weights")

# A subscript outside int[8]: 2 faults. The scan runs on.
state = scan.(state, %{"eye" => 0, "slot" => 8}, 20)
IO.inspect(state.faults, label: "faults", width: 70)

# Each of these calls raises an ArgumentError. The script prints its message.
refused = fn call ->
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end

refused.(fn -> Logex.Runtime.call(scales, state, %{}, %Logex.Scan{now: 10, first: false}) end)
refused.(fn -> Logex.Runtime.call(scales, state, %{}, %Logex.Scan{now: 30, first: true}) end)
held = %{state | env: Map.put(state.env, :faults, [])}
refused.(fn -> Logex.Runtime.call(scales, held, %{}, %Logex.Scan{now: 30, first: false}) end)
