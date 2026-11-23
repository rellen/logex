alias Logex.Runtime
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, delay} = Logex.compile_file("delay.ld")
{:ok, jog} = Logex.compile_file("jog.ld")

# Give each step's inputs and milliseconds to scan/3. Keep the time and the outputs.
run = fn program, steps ->
  {rows, _state} =
    Enum.map_reduce(steps, Runtime.instance(program), fn {ms, inputs}, state ->
      state = Runtime.put_inputs(program, state, inputs)
      {outputs, state} = Runtime.scan(program, state, ms)
      {{state.now, outputs, state.env}, state}
    end)

  rows
end

IO.puts("1. delay.ld: the same steps, 2 runs")

steps = [
  {0, %{}},
  {500, %{"go" => 1}},
  {1250, %{}},
  {2000, %{"go" => 0}},
  {100, %{"go" => 1}},
  {3000, %{}}
]

first = run.(delay, steps)
Enum.each(first, fn {now, outputs, _env} -> IO.puts("  #{now} ms  #{inspect(outputs)}") end)
IO.puts("  same outputs in the second run: #{run.(delay, steps) == first}")

IO.puts("2. A time that goes back")
state = Runtime.instance(delay)
{_outputs, state} = Runtime.scan(delay, state, 3000)

refused = fn call ->
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts("  ArgumentError: " <> Exception.message(error))
  end
end

refused.(fn -> Runtime.scan(delay, state, -5) end)
refused.(fn -> Runtime.call(delay, state, %{}, %Logex.Scan{now: 10, first: false}) end)

IO.puts("3. jog.ld: jog_t in the rungs that the jump skips")

jogged =
  run.(jog, [
    {0, %{"manual" => 1, "jog_pb" => 1}},
    {1000, %{}},
    {0, %{"manual" => 0}},
    {10_000, %{}},
    {0, %{"manual" => 1}}
  ])

Enum.each(jogged, fn {now, outputs, env} ->
  IO.puts("  #{now} ms  jog_t.acc #{env["jog_t"]["acc"]}  jog_long #{outputs["jog_long"]}")
end)

IO.puts("4. A timer in a block whose cal is false")

{:ok, run_on} =
  Logex.compile(
    """
    function_block run_on
    var_input go bool
    var_output done bool
    var t ton

    xic go ton t 3000
    xic t.dn ote done
    """,
    name: "run_on"
  )

{:ok, fan} =
  Logex.compile(
    """
    var_input enable bool
    var_input hot bool
    var_output fan bool
    var r1 run_on

    xic enable cal r1 hot fan
    """,
    name: "fan",
    types: [run_on]
  )

fan
|> run.([
  {0, %{"enable" => 1, "hot" => 1}},
  {1000, %{}},
  {0, %{"enable" => 0}},
  {10_000, %{}},
  {0, %{"enable" => 1}}
])
|> Enum.each(fn {now, outputs, env} ->
  IO.puts("  #{now} ms  r1.t.acc #{env["r1"]["t"]["acc"]}  fan #{outputs["fan"]}")
end)

IO.puts("5. delay.ld at 3 rates: go rises at 1000 ms")

# Scan until the lamp comes on. go is 1 from 1000 ms.
go = fn
  now when now >= 1000 -> 1
  _now -> 0
end

until_lamp = fn
  until_lamp, state, [ms | more], %{"lamp" => 0} ->
    state = Runtime.put_inputs(delay, state, %{"go" => go.(state.now + ms)})
    {outputs, state} = Runtime.scan(delay, state, ms)
    until_lamp.(until_lamp, state, more ++ [ms], outputs)

  _until_lamp, state, _steps, %{"lamp" => 1} ->
    state.now
end

Enum.each([[10], [50], [10, 25, 40, 70]], fn steps ->
  lamp = until_lamp.(until_lamp, Runtime.instance(delay), steps, %{"lamp" => 0})
  IO.puts("  steps of #{Enum.join(steps, ", ")} ms: lamp on at #{lamp} ms")
end)

IO.puts("6. An online edit gives back a timer")

# d2 runs on a task of 50 ms. The candidate has no rung that runs t1.
text = File.read!("delay.ld")
{:ok, no_timer} = Logex.compile(String.replace(text, "xic go ton t1 3000\n", ""), name: "delay")

slow = fn program ->
  {:ok, configuration} =
    Logex.Configuration.compile(
      "plant",
      """
      task fast interval 10 priority 1
      task slow interval 50 priority 2
      var_global go_i bool at panel.i.0
      var_global lamp_q bool at panel.q.0
      program d2 delay with slow
      d2.go go_i
      d2.lamp lamp_q
      """,
      %{"delay" => program}
    )

  configuration
end

cycles = fn runtime, n ->
  Enum.reduce(1..n, runtime, fn _cycle, runtime ->
    {runtime, _outputs, _events} = Runtime.cycle(runtime, 10, %{})
    runtime
  end)
end

{runtime, _outputs, _events} = Runtime.cycle(Runtime.start(slow.(delay)), 0, %{"go_i" => 1})
runtime = cycles.(runtime, 7)
IO.puts("  70 ms, d2 last scanned at 50 ms: d2.t1.acc #{Runtime.get!(runtime, "d2.t1.acc")}")
{:ok, edit, _forecast} = Logex.Configuration.Edit.accept(runtime, slow.(no_timer))
{edit, runtime, _report} = Logex.Configuration.Edit.test(edit, runtime)
runtime = cycles.(runtime, 6)
{_edit, runtime, report} = Logex.Configuration.Edit.untest(edit, runtime)
IO.puts("  untest at 130 ms: #{inspect(report)}, d2.t1.acc #{Runtime.get!(runtime, "d2.t1.acc")}")
runtime = cycles.(runtime, 2)
IO.puts("  150 ms, after the next scan: d2.t1.acc #{Runtime.get!(runtime, "d2.t1.acc")}")

IO.puts("7. The runner on the manual clock, 2 runs")

{:ok, plant} =
  Logex.Configuration.compile(
    "plant",
    """
    var_global go_i bool at panel.i.0
    var_global lamp_q bool at panel.q.0
    program d1 delay
    d1.go go_i
    d1.lamp lamp_q
    """,
    %{"delay" => delay}
  )

on_the_clock = fn say ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock}
    )

  # This process moves the clock and calls the runner. That is safe here, because no
  # device in this run moves the clock with pass/2.
  status = fn label ->
    %{now: now, rounds: rounds} = Runner.status(runner)
    say.("  #{label}: now #{now}, rounds #{rounds}, lamp #{Sim.outputs(panel)["panel.q.0"]}")
  end

  status.("start")
  Manual.advance(clock, 10)
  status.("10 ms later")
  Sim.set(panel, "panel.i.0", 1)
  Manual.advance(clock, 3000)
  status.("go, then 3000 ms later")
  Manual.advance(clock, 1)
  status.("1 ms later")
  :ok = Runner.stop(runner)
  Sim.writes(panel)
end

writes = on_the_clock.(&IO.puts/1)
IO.puts("  the second run makes the same writes: #{on_the_clock.(fn _line -> :ok end) == writes}")

IO.puts("8. A clock with no wall_ms/1, and a store")

defmodule NoWall do
  @behaviour Logex.Runner.Clock
  defdelegate now_ms(clock), to: Manual
  defdelegate wake_at(clock, pid, message, at_ms), to: Manual
  defdelegate cancel(clock, timer), to: Manual
end

{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(clock: clock)
io = %{"panel" => {Sim, sim: panel}}

refused.(fn ->
  Runner.start_link(configuration: plant, io: io, clock: {NoWall, clock}, retain: "plant.retain")
end)

{:ok, runner} = Runner.start_link(configuration: plant, io: io, clock: {NoWall, clock})
IO.puts("  with no retain: the runner starts, rounds #{Runner.status(runner).rounds}")
:ok = Runner.stop(runner)

IO.puts("9. A limit of real time on the manual clock")
{:ok, slow} = Sim.start_link()
Sim.fail(slow, :init, {:delay, 300})

started =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: slow}},
    clock: {Manual, clock},
    open: 100
  )

IO.puts("  #{inspect(started)} at #{Manual.now_ms(clock)} ms on the manual clock")
