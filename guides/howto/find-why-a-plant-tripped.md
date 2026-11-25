# Find why a plant tripped

This guide is for a reader whose [plant](../reference/glossary.md#plant)
[tripped](../reference/glossary.md#trip) on a [runner](../reference/glossary.md#runner).
It shows how to find the reason of the trip, the
[devices](../reference/glossary.md#device) whose outputs can still be on, and the values
of the last [round](../reference/glossary.md#round).

> #### Warning {: .warning}
>
> Do not use logex for a safety function, for example an emergency stop. A trip writes 0
> only to the devices that answer. Make each safety function with hardwired circuits or
> with a safety-rated controller.
> [Safety and limits](../explanation/safety-and-limits.md) gives the limits of logex.

## Before you start

You must have:

- a plant that runs on `Logex.Runner`
  ([Run a plant on the clock](run-on-the-clock.md) shows how to start one)
- the pid or the name of the runner, in your Elixir code

## What a trip does

- The runner stops the rounds. Only `Logex.Runner.restart/2` starts them again.
- Each device that answers writes 0 to its output
  [points](../reference/glossary.md#point) 1 time. Then it writes nothing until a
  restart. If the write of the 0 fails, the device writes the 0 again 1 time in each
  [poll period](../reference/glossary.md#poll-period), until the write succeeds.
- The [resource](../reference/glossary.md#resource) keeps the values of the last round.
  Its time does not change until the restart.

## Steps

The blocks are parts of the script `restart-after-a-trip.exs`.
[An example](restart-after-a-trip.md#an-example) in
[Restart after a trip](restart-after-a-trip.md) gives the whole script and its output.

1. **Get the reason of the trip.** Call `Logex.Runner.status/1` and read the field
   `trip`.

<!-- part of: restart-after-a-trip.exs -->
```elixir
IO.inspect(Runner.status(runner).trip, label: "trip")
```

The script prints `trip: {:io, "panel", {:error, :eio}}`. The read of the device
`panel` failed.

> #### Note {: .info}
>
> A subscriber gets only the events that come after its call of
> `Logex.Runner.subscribe/2`. To get the next trip as the event `{:trip, reason}`,
> subscribe when the runner starts.

2. **Find the reason in these tables.** First the reasons of a
   [watchdog](../reference/glossary.md#watchdog):

| `trip` | What occurred | Where to look |
|---|---|---|
| `{:watchdog, {:task, ...}}` | `{:watchdog, {:task, task, took_ms, limit_ms}}`. The run of the [task](../reference/glossary.md#task) took `took_ms`, more than its watchdog `limit_ms`. | The programs of the task, and the load of the computer. |
| `{:watchdog, {:round, ...}}` | `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`. A round of the [continuous task](../reference/glossary.md#continuous-task) took more than its watchdog. `steps` gives each step of the round with its time. | The step with the largest time. |
| `{:watchdog, {:idle, ...}}` | `{:watchdog, {:idle, ms, work}}`. Work of the runner between rounds took more than the idle watchdog. `work` names it, for example `:status`, `{:edit, :test}` or `:period`. | The call, the edit step or the write of the store that `work` names. |
| `{:watchdog, {:device, ...}}` | `{:watchdog, {:device, device, ms}}`. The device got no message from the runner for `ms`. The device wrote 0 to its outputs by itself. | The computer. The runner did not run in time. |
| `{:watchdog, {:late, ms}}` | The runner was late. `ms` is the time since its last check of the devices. | The computer, not a device. |

If a watchdog is too short for the work, [Set watchdogs](set-watchdogs.md) shows how to
change it. Then the other reasons:

| `trip` | What occurred | Where to look |
|---|---|---|
| `{:io, ...}` | `{:io, device, detail}`. The device or its [adapter](../reference/glossary.md#adapter) failed. | The device. [Check a device adapter](test-a-device-adapter.md#when-the-plant-runs) gives each `detail`. |
| `{:fault, ...}` | `{:fault, task, instance, fault}`. A [major fault](../reference/glossary.md#major-fault): a bit number or a [subscript](../reference/glossary.md#subscript) that a [tag](../reference/glossary.md#tag) holds is out of range. `fault` gives the file, the line and the value. | That line of the program, and the tag that holds the value. |
| `{:clock, ...}` | `{:clock, {:now_ms, answer}}` or `{:clock, {:wall_ms, answer}}`. The [clock](../reference/glossary.md#clock) of the [host](../reference/glossary.md#host) gave a time that the runner cannot use. | The clock module of the host. |
| `{:internal, ...}` | `{:internal, message}`. An exception in logex. The host cannot cause it. | A defect of logex. Keep the message and the values of the resource. Report it in the [issues of logex](https://github.com/rellen/logex/issues). |

3. **Read the field `unzeroed` of the status.** It names each device whose outputs can
   still be on.

> #### Warning {: .warning}
>
> Before you go near a device that `unzeroed` names, make its outputs safe at the
> machine. If a device does not answer in time, logex stops the process of the device.
> The outputs then do what the device does when it loses contact with the runner.

<!-- part of: restart-after-a-trip.exs -->
```elixir
IO.inspect(Runner.status(runner).unzeroed, label: "unzeroed")
```

The script prints `unzeroed: ["panel"]`, because the write of the 0 failed. After 1
poll period, the next write of the 0 succeeds, and `unzeroed` is `[]`. A device whose
process stopped stays in the list until a restart.

4. **Read the values of the resource** with `Logex.Runner.get!/2`. They are the values of
   the last round.

<!-- part of: restart-after-a-trip.exs -->
```elixir
IO.inspect(Runner.get!(runner, "k1"), label: "k1 in the resource")
```

The script prints `k1 in the resource: 1`. At the device, `k1` is 0, from the trip. A
round that trips before its write does not write its outputs. Thus the resource can hold
outputs that the devices did not get.

## The result

You know the reason of the trip, the devices whose outputs can still be on, and the
values of the last round. To start the plant again, follow
[Restart after a trip](restart-after-a-trip.md).

## If it does not work

| What you see | Cause | What to do |
|---|---|---|
| `trip` is `nil` | The status is `:running`. The plant did not trip. | Read the field `status`. A restart is not necessary. |
| `the runner #PID<0.102.0> is not running` | The runner stopped, or it crashed. | Start a new runner with `Logex.Runner.start_link/1`. |
| `` `k9` is neither a global nor a program instance `` | The resource holds no value at this path. | Give the name of a global, or a path such as `b1.boxes.cv`. |

The 2 messages come in an `ArgumentError`.

## See also

- [Restart after a trip](restart-after-a-trip.md): the next task.
- [Runner](../reference/runner.md): the reasons of a trip and the fields of the status.
- [Trips and watchdogs](../explanation/trips-and-watchdogs.md): why the runner trips.
- [Set watchdogs](set-watchdogs.md): the watchdogs of a task and of the runner.
- [Glossary](../reference/glossary.md): the technical words.
