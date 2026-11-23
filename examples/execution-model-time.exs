{:ok, fan} = Logex.compile_file("execution-model/fan_delay.ld")

# scan/3: the third argument is the time since the last scan, in ms.
show = fn state, label, out ->
  IO.puts("#{label}  now=#{state.now}  t1.acc=#{state.env["t1"]["acc"]}  fan=#{out["fan"]}")
  state
end

step = fn state, ms ->
  {out, state} = Logex.Runtime.scan(fan, state, ms)
  show.(state, "scan/3 #{String.pad_leading("#{ms}", 3)} ms", out)
end

state = Logex.Runtime.put_inputs(fan, Logex.Runtime.instance(fan), %{"belt" => 1})
state = Enum.reduce([0, 200, 200, 200], state, &step.(&2, &1))
{out, state} = Logex.Runtime.scan(fan, state)
state = show.(state, "scan/2       ", out)

# call/4: the scan gives the time of the instance, not the time since the last scan.
{out, state} =
  Logex.Runtime.call(fan, state, %{"belt" => 0}, %Logex.Scan{now: 1000, first: false})

state = show.(state, "call/4 1000  ", out)

# Each of these calls raises an ArgumentError. The script prints its message.
calls = [
  fn -> Logex.Runtime.scan(fan, state, -5) end,
  fn -> Logex.Runtime.scan(fan, state, 2.5) end,
  fn -> Logex.Runtime.call(fan, state, %{}, %Logex.Scan{now: 900, first: false}) end,
  fn -> Logex.Runtime.call(fan, state, %{}, %Logex.Scan{now: -1, first: false}) end,
  fn -> Logex.Runtime.call(fan, state, %{}, %Logex.Scan{now: 1000, first: true}) end,
  fn ->
    fresh = Logex.Runtime.instance(fan)
    Logex.Runtime.call(fan, fresh, %{}, %Logex.Scan{now: 0, first: false})
  end
]

for call <- calls do
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end
