{:ok, line} = Logex.Configuration.compile_file("line.logex")
rt = Logex.Runtime.start(line)

# cycle/3 in its steps, as the runner calls them. These 3 functions are
# internal: a host calls cycle/3.
{rt, steps} = Logex.Runtime.cycle_steps(rt, 0, %{"pb_start_1" => 1})
IO.inspect(steps, label: "steps")

rt =
  Enum.reduce(steps, rt, fn step, rt ->
    {rt, events} = Logex.Runtime.cycle_step(rt, step)
    IO.inspect(events, label: "events")
    rt
  end)

IO.inspect(Logex.Runtime.cycle_outputs(rt), label: "outputs")

# 120 ms later, with the e-stop pressed: each task runs 1 time.
{rt, outputs, events} = Logex.Runtime.cycle(rt, 120, %{"estop" => 1})
IO.inspect(events, label: "events")
IO.inspect(outputs, label: "outputs")
IO.inspect(Logex.Runtime.next_due_in(rt), label: "next_due_in")

# The resource holds 1 copy of the global. Between cycles, the state of
# c2 holds no estop. get!/2 reads c2.estop as the global.
IO.inspect(Map.has_key?(rt.instances["c2"].env, "estop"), label: "c2 holds estop")
IO.inspect(Logex.Runtime.get!(rt, "c2.estop"), label: "c2.estop")
