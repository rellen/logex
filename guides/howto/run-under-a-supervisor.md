# Run a plant under a supervisor

This guide is for an Elixir developer who can start a
[runner](../reference/glossary.md#runner) on the [clock](../reference/glossary.md#clock)
of the machine. It shows how to put the runner under a supervisor, so that it starts and
stops with your application. It also shows what occurs when the runner crashes.

> #### Warning {: .warning}
>
> Do not use logex for a safety function, for example an emergency stop. If the Erlang
> VM stops, no part of logex sets an output [point](../reference/glossary.md#point) to 0.
> Wire each emergency stop so that it works when logex stops, crashes or does not start.
> [Safety and limits](../explanation/safety-and-limits.md) gives the limits of logex.

## Before you start

- You must know how to start a runner with its
  [devices](../reference/glossary.md#device).
  [Run a plant on the clock](run-on-the-clock.md) gives the steps.
- Get [`conveyor.ld`](../tutorials/first-plant.md#step-1-write-the-conveyor-program) and
  [`packing.logex`](../tutorials/first-plant.md#step-2-write-the-configuration-file) from
  the tutorial Your first plant. Get
  [`boxes.ld`](../tutorials/timers-and-counters.md#step-3-write-the-counter-program) from
  the tutorial A timer and a counter. Put the 3 files in the root directory of your Mix
  project.

## Steps

1. Make the file `run-under-a-supervisor.exs` in the root directory of your project.
   Put these lines at its top. They start the simulated device and get the child spec
   from `Logex.Runner.child_spec/1`. Give it the options of `Logex.Runner.start_link/1`,
   and a `name:`. Your code then finds the runner by its name.

<!-- part of: run-under-a-supervisor.exs -->
```elixir
alias Logex.Runner
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, panel} = Sim.start_link(reports: true)
options = [configuration: plant, io: %{"panel" => {Sim, sim: panel}}, name: Packing]

spec = Runner.child_spec(options)
IO.inspect(Map.take(spec, [:restart, :shutdown]), label: "the child spec")
```

2. Add this line, which puts the child spec in the children of a supervisor. In your
   application, put it in the children of your supervisor.

<!-- part of: run-under-a-supervisor.exs -->
```elixir
{:ok, supervisor} = Supervisor.start_link([spec], strategy: :one_for_one)
```

3. Add these lines, which press the start button. Then they wait for the
   [round](../reference/glossary.md#round) that writes 1 to `k1`, 5 s at most.

<!-- part of: run-under-a-supervisor.exs -->
```elixir
# Press start, then wait for the round that writes 1 to k1.
:ok = Runner.subscribe(Packing, [:round])
Sim.set(panel, "panel.i.0", 1)

receive do
  {Runner, _runner, {:round, _now, %{"k1" => 1}}} -> IO.puts("k1 is 1")
after
  5_000 -> IO.puts("no round wrote 1 to k1 in 5 s")
end

:ok = Runner.unsubscribe(Packing)
```

4. Add these lines, which stop the supervisor. The supervisor stops the runner.

<!-- part of: run-under-a-supervisor.exs -->
```elixir
# Stop the supervisor. It stops the runner as Runner.stop/1 does.
:ok = Supervisor.stop(supervisor)
IO.inspect(List.last(Sim.writes(panel)), label: "the last write")
IO.inspect(Sim.closed?(panel), label: "closed")
```

5. Make sure that the file has this text.

```elixir
alias Logex.Runner
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, panel} = Sim.start_link(reports: true)
options = [configuration: plant, io: %{"panel" => {Sim, sim: panel}}, name: Packing]

spec = Runner.child_spec(options)
IO.inspect(Map.take(spec, [:restart, :shutdown]), label: "the child spec")

{:ok, supervisor} = Supervisor.start_link([spec], strategy: :one_for_one)

# Press start, then wait for the round that writes 1 to k1.
:ok = Runner.subscribe(Packing, [:round])
Sim.set(panel, "panel.i.0", 1)

receive do
  {Runner, _runner, {:round, _now, %{"k1" => 1}}} -> IO.puts("k1 is 1")
after
  5_000 -> IO.puts("no round wrote 1 to k1 in 5 s")
end

:ok = Runner.unsubscribe(Packing)

# Stop the supervisor. It stops the runner as Runner.stop/1 does.
:ok = Supervisor.stop(supervisor)
IO.inspect(List.last(Sim.writes(panel)), label: "the last write")
IO.inspect(Sim.closed?(panel), label: "closed")
```

6. Run the script. The first line shows the values of the child spec. The last 2 lines
   show that the runner wrote 0 to each output point and closed the device.

```console
$ mix run run-under-a-supervisor.exs
the child spec: %{restart: :temporary, shutdown: 10510}
k1 is 1
the last write: %{"panel.q.0" => 0, "panel.q.4" => 0}
closed: true
```

## The result

The runner starts with the supervisor. To stop the [plant](../reference/glossary.md#plant),
stop the supervisor or call `Logex.Runner.stop/1`.

The child spec has 2 values that the runner sets:

| Key | Value |
|---|---|
| `restart:` | `:temporary`. The supervisor does not start the runner again after it stops or crashes. |
| `shutdown:` | The time in ms that the supervisor waits for the runner to stop. It grows with the number of devices and with `idle:`, `poll:` and `write_limit:`. For 1 device and the defaults, it is 10510. [Runner](../reference/runner.md) gives the rule. |

To give a different value, use `Supervisor.child_spec/2`, for example
`Supervisor.child_spec({Logex.Runner, options}, shutdown: 20_000)`.

The runner can end in 2 ways:

- An orderly stop: `Logex.Runner.stop/1`, the shutdown of the supervisor, or
  `GenServer.stop/3` with the reason `:normal`, `:shutdown` or `{:shutdown, term}`. The
  runner writes 0 to each output [point](../reference/glossary.md#point) 1 time and
  closes each device. It writes its [store](../reference/glossary.md#store) if it has
  one. `GenServer.stop/3` returns `:ok` to its caller. If the write of the store fails,
  no caller gets the error. Only a process that subscribed to `:retain` gets
  `{:retain, {:error, reason}}`.
- A crash, or a kill. Each device writes 0 to each output point 1 time and closes. The runner
  writes no store, and the store keeps its last write. The name of the runner is free.

After a crash, the supervisor has no child for the runner. To start a new runner, call
`Supervisor.start_child/2` with the same child spec.

> #### Warning {: .warning}
>
> Do not let a supervisor start the runner again after a crash if an output must not come
> on by itself. If you give `restart: :permanent` or `restart: :transient` with
> `Supervisor.child_spec/2`, the supervisor starts a new runner. A runner with `retain:`
> starts warm from its store. A [program](../reference/glossary.md#program) writes its
> outputs from the retained values in the first round. Thus an output can come on
> immediately after the crash.

For example, in 1 run, `boxes.ld` declared `var retain boxes ctu`, and the runner had a
store. A kill of the runner wrote 0 to the lamp `case_full`. The supervisor started a new
runner. The first write of the new runner set the lamp to 1 again. To start cold, give
`start: :cold`.

## If it does not work

If the runner does not start, the supervisor stops with the reason
`{:shutdown, {:failed_to_start_child, Logex.Runner, reason}}`.
`Supervisor.start_link/2` links your process to the supervisor, so your process stops
with the same reason. If your process traps exits,
`Supervisor.start_link/2` returns `{:error, reason}` with that reason in its place.

| What you see | Cause | What to do |
|---|---|---|
| `no runner is running under the name Packing` | The runner stopped or crashed. | Start a new runner, as [The result](#the-result) shows. |
| `{:io_init, "panel", cause}` in `reason` | The runner cannot open the device `panel`. | [Run a plant on the clock](run-on-the-clock.md) gives each reason. |
| An `ArgumentError` in `reason` | An option is wrong. The message of the `ArgumentError` gives the option. | Correct the option in the child spec. |
| `{:error, :not_found}` from `restart_child/2` | The supervisor removed the child spec after the runner stopped, because the child is `:temporary`. | Start a new runner, as [The result](#the-result) shows. |

## See also

- [Run a plant on the clock](run-on-the-clock.md): the options of the runner and its
  devices.
- [Runner](../reference/runner.md): the child spec, the stop, the shutdown and the crash.
- [Keep retained values on disk](keep-values-on-disk.md): the store, and what a crash loses.
- [Warm and cold restarts](../explanation/warm-and-cold-restarts.md): why a warm start
  can switch on an output.
- [Glossary](../reference/glossary.md): the words of this guide.
