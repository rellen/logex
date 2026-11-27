# Runs and tables of the records: file work

This page is for a contributor who reads the decision record about the file work of the
runner. It holds the run, the measurements and the long tables of record 0018, so that
the record stays short. The record links to this section.

The suite runs each example of this page, as it runs the examples of each other page.
The script and its files are under `examples/`.

## 0018. File work with a limit

These tables and this run support
[0018. File work with a limit](../adr/0018-file-work-with-a-limit.md).

### The words of the record

| Word | Meaning on this page |
|---|---|
| File call | A read, a write, a copy or a check of a file by the runner |
| Write limit | The time in ms of real time that 1 file call can take: the option `write_limit:` |
| Cut write | A write that did not end within its write limit. The call of the file system that it was in can still end later |
| End write | A write of the store at a [trip](../../guides/reference/glossary.md#trip), a stop, a shutdown or a [cold restart](../../guides/reference/glossary.md#cold-restart) |
| Writer | The process that writes the store each period, `retain_period:` |
| File server | The process of the VM, `:file_server_2`, that does each file call that is not raw. A rename and a delete go through it |
| Raw call | A file call that does not go through the file server |
| Holder | A process of logex that holds the files of a runner that stopped, until its cut writes end |
| Own work | Work of the runner between rounds: a request of the [host](../../guides/reference/glossary.md#host), a step of an [online edit](../../guides/reference/glossary.md#online-edit), or the hand-off to the writer |
| Refresh | A message from the runner to each [device](../../guides/reference/glossary.md#device) with a deadline. A device that gets no refresh by its deadline writes 0 to each output ([0014](../adr/0014-devices-are-processes.md)) |

### The 4 problems of the review after Milestone 6

Before decision 353, the runner made its file calls in its own process, with no limit.
The review after Milestone 6 found these problems:

| Problem | What occurred | Decision |
|---|---|---|
| A stalled disk | A network drive or a failing disk stops answering. The runner then waits in the file call and answers no one. | 353 |
| A busy computer | When each core is busy, a disk that works correctly can take longer to sync than the [idle watchdog](../../guides/reference/glossary.md#idle-watchdog) and 1 [poll period](../../guides/reference/glossary.md#poll-period). Such a short limit cuts a good write. | 400 |
| The runner's own long work | A large [array](../../guides/reference/glossary.md#array) of [instances](../../guides/reference/glossary.md#instance), retained, made the runner work past the idle watchdog. Each device then wrote 0 at its deadline, and the [plant](../../guides/reference/glossary.md#plant) tripped at its first period. | 352 |
| 2 runners on 1 file | Nothing refused a second runner on the same store or forces file. Each runner wrote over the file of the other. | 356 |

### The measurement behind the write limit

Decision 353 first gave each file call the idle watchdog and 1 poll period as its limit,
510 ms by default. Decision 400 made the limit a separate option. On a computer whose
cores were all busy, the review measured 231 ms for 1 write of the store. A sleep of
10 ms came 668 ms late. The default of 5000 ms is about 20 times the first figure.

Decision 352 made the own work of the runner cheaper. The moduledoc of `Logex.Runner`
gives the size of plant that the default idle watchdog carries: about 32,768 elements.

### The requests while a write of the forces file runs

| Request | What the runner does |
|---|---|
| A round | Runs with the forces of the last write that ended with `:ok` (437) |
| A forcing request with a wrong argument | Raises an `ArgumentError` in its caller immediately (473) |
| More forcing requests | Joins them into the next write, in the sequence asked. Each caller gets the answer of that write. 10 requests take 2 writes (465) |
| A trip, or a step of an online edit | Leaves the write as it is (437, 518) |
| `restart/2` on a tripped runner | Waits for the write, outside the process of the runner. Then it restarts on the file that the write left (468, 500) |
| `status/1` during that wait | Gives the runner as tripped, and the set that the runner writes as `forcing`. It does not show the restart (510) |
| A second `restart/2` during that wait | The runner takes it after the first restart. If the runner then runs, it raises `the runner is running`. If the first restart tripped again, the trip refuses it. If the runner refused the first restart, it makes the second (508) |
| A force during that wait | Joins the next write, after the restart (509) |
| A step of an online edit during that wait | The runner does it immediately. The restart then runs what the resource holds (518) |
| `stop/2` | Writes each 0 and closes each device immediately. Then it waits for the write, to its limit, and gives its result to the caller of `force/3`. A request that waits behind the write raises `the runner #PID<...> is not running` (467) |

### A file that the runner cannot read

A stalled disk at a start or a restart gives these results:

| File and time | Result | Decision |
|---|---|---|
| The forces file, at a restart | The restart keeps the forces that the runner holds, and goes on. `forces_unread` names the file | 390 |
| The forces file, at a fresh start | The start goes on with no force. `forces_unread` names the file | 390 |
| The store, at a fresh start | The runner refuses the start with an `ArgumentError`. A start with `start: :cold` gives `{:error, {:retain, :timeout}}` | 415 |
| A relative path, when the working directory does not answer | The runner refuses the start: the file cannot be located | 446 |

A start with a FIFO in place of the store and `write_limit: 300` gave this refusal:

<!-- unchecked: the message of a run, the store a FIFO that no process writes, write_limit: 300 -->
```text
tally.retain: the store cannot be read: the disk did not answer within the write limit, 300 ms (write_limit:)
```

### The cases that keep a file held

| Case | What happens | Decision |
|---|---|---|
| The runner ends with a cut write | A holder keeps the file. It gives the file up when the file server answers a call made after the cut. The runner refuses a start meanwhile | 475 |
| The disk never answers again | The holder keeps the file with no limit, until a person kills the holder or the VM stops | 495 |
| A person kills the runner | The claim stays with the dead process. A start sends a call to the file server and waits, for up to its write limit. When the answer comes, the file server did each call queued before it, a cut rename also. Then the start takes the file. Past the limit the runner refuses the start | 499 |

### The rules in a run

The script `examples/0018-file-work-with-a-limit.exs` shows the rules of this record as
numbered results. It runs the box-counting program of
[0017. The store on disk](../adr/0017-the-store-on-disk.md): [`tally.ld`](record-runs-store.md)
and [`tally.logex`](record-runs-store.md). Both files are in `examples/`.

The script makes the disk stop with `:sys.suspend/1` on the file server of the VM. Each
rename and delete then waits, as on a disk that stalls. A host does not do this. The
runner runs on the manual clock, with a write limit of 300 ms. The script removes the
directory of the run and the numbers of the processes from each message.

> #### Caution {: .error}
>
> Run the script in a separate VM, from `examples/`. It deletes each file
> `tally.retain*` and `tally.forces*` in the directory. It stops each file call of the VM
> through the file server for some seconds.

```elixir
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

Enum.each(Path.wildcard("tally.{retain,forces}*"), &File.rm!/1)
{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
{:ok, clock} = Manual.start_link()
here = File.cwd!() <> "/"

# Each runner gets a new simulated panel. The paths are absolute, so that a start does
# not read the working directory through the file server. A limit of 300 ms keeps the
# run short.
opts = fn ->
  {:ok, panel} = Sim.start_link(clock: clock)

  {panel,
   [
     configuration: plant,
     io: %{"panel" => {Sim, sim: panel}},
     clock: {Manual, clock},
     retain: here <> "tally.retain",
     forces: here <> "tally.forces",
     write_limit: 300
   ]}
end

# A message without the directory of the run and without the numbers of the processes,
# in lines of 80 characters or fewer.
plain = fn message ->
  message |> String.replace(here, "") |> String.replace(~r/#PID<[0-9.]+>/, "#PID<...>")
end

wrap = fn text -> IO.write(Regex.replace(~r/(.{1,78})( |$)/, text, "  \\1\n")) end

refused = fn opts ->
  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> wrap.("refused: " <> plain.(error.message))
  end
end

eye = fn panel, values ->
  for value <- values do
    Sim.set(panel, "panel.i.0", value)
    Manual.advance(clock, 10)
  end
end

# The 3 keys of the forces, in a fixed sequence.
forcing = fn runner ->
  status = Runner.status(runner)
  [forces: status.forces, forcing: status.forcing, forces_unknown: status.forces_unknown]
end

# The disk stops: each call through the VM's file server waits. A real disk that stalls
# does the same to each file call.
server = Process.whereis(:file_server_2)
hold = fn -> :sys.suspend(server) end

let_go = fn ->
  :sys.resume(server)
  :sys.get_state(server)
end

{panel, first} = opts.()
{:ok, runner} = Runner.start_link(first)
:ok = Runner.subscribe(runner)
eye.(panel, [1, 0])

IO.puts("1. A second runner on the same files")
{_panel, second} = opts.()
refused.(second)

IO.puts("2. A force while the disk does not answer")
hold.()
force = Task.async(fn -> Runner.force(runner, "eye_1", 1) end)

wait = fn
  [forces: _, forcing: nil, forces_unknown: _], again -> again.(forcing.(runner), again)
  status, _again -> status
end

IO.puts("  while it is written: #{inspect(wait.(forcing.(runner), wait))}")
eye.(panel, [1, 0, 1, 0])
IO.puts("  total_boxes after 2 more boxes: #{Runner.get!(runner, "total_boxes")}")

try do
  Runner.force(runner, "nope", 1)
rescue
  error in ArgumentError -> wrap.("a wrong point, raised at once: " <> error.message)
end

IO.puts("  the answer at the limit: #{inspect(Task.await(force))}")
IO.puts("  then: #{inspect(forcing.(runner))}")

IO.puts("3. The disk answers again")
let_go.()
IO.puts("  tally.forces holds #{inspect(File.read!("tally.forces"))}")
IO.puts("  the runner: #{inspect(forcing.(runner))}")
IO.puts("  unforce: #{inspect(Runner.unforce(runner, "eye_1"))}")
IO.puts("  the runner: #{inspect(forcing.(runner))}")
IO.puts("  tally.forces holds #{inspect(File.read!("tally.forces"))}")

IO.puts("4. A trip while the disk does not answer")
hold.()
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
%{status: status, trip: trip, retain: retain} = Runner.status(runner)
IO.puts("  status: #{inspect(status)}, trip: #{inspect(trip)}")
IO.puts("  retain: unknown #{inspect(plain.(retain.unknown))}, failed #{inspect(retain.failed)}")

receive do
  {Runner, ^runner, {:retain, answer}} -> IO.puts("  event: #{inspect({:retain, answer})}")
end

IO.puts("5. A stop and a start while the disk does not answer")
IO.puts("  stop: #{inspect(Runner.stop(runner))}")
{_panel, third} = opts.()
refused.(third)

IO.puts("6. The disk answers again")
let_go.()
{_panel, fourth} = opts.()

attempt = fn ->
  try do
    Runner.start_link(fourth)
  rescue
    ArgumentError -> :held
  end
end

# The holder gives the files up when the cut write ends. Until then a start is refused.
free = fn
  {:ok, runner}, _again ->
    runner

  :held, again ->
    Process.sleep(10)
    again.(attempt.(), again)
end

runner = free.(attempt.(), free)
total = Runner.get!(runner, "total_boxes")
IO.puts("  started: total_boxes #{total}, forces #{inspect(Runner.status(runner).forces)}")
:ok = Runner.stop(runner)
```

Run it from the directory `examples/`. The first run also builds logex, and prints the
lines of the build first. The run takes some seconds:

```console
$ mix run 0018-file-work-with-a-limit.exs
1. A second runner on the same files
  refused: the runner's retain: "tally.retain" names the store of another runner
  of this VM, #PID<...>, which holds it until it stops: two runners on one file
  write each over the other's
2. A force while the disk does not answer
  while it is written: [forces: %{}, forcing: %{"eye_1" => 1}, forces_unknown: []]
  total_boxes after 2 more boxes: 3
  a wrong point, raised at once: `nope` is no input point of `tally`
  the answer at the limit: {:error, {:forces, :timeout}}
  then: [forces: %{}, forcing: nil, forces_unknown: [%{"eye_1" => 1}]]
3. The disk answers again
  tally.forces holds "eye_1 1\n"
  the runner: [forces: %{}, forcing: nil, forces_unknown: [%{"eye_1" => 1}]]
  unforce: :ok
  the runner: [forces: %{}, forcing: nil, forces_unknown: []]
  tally.forces holds ""
4. A trip while the disk does not answer
  status: :tripped, trip: {:io, "panel", {:error, :eio}}
  retain: unknown "tally.retain", failed nil
  event: {:retain, {:error, :timeout}}
5. A stop and a start while the disk does not answer
  stop: {:error, {:retain, :timeout}}
  refused: the runner's retain: "tally.retain" names the store of a runner of
  this VM that has stopped, #PID<...>, held by #PID<...> until a write of it
  that runner cut at its write limit has ended, which may yet land: two runners
  on one file write each over the other's
6. The disk answers again
  started: total_boxes 3, forces %{}
```

Each result shows these rules:

1. The runner refuses a second runner of the VM on the same store. The message names the
   first runner (decision 356).
2. While its write runs, the force is in `forcing` and not in `forces`. The rounds run
   on: the [counter](../../guides/reference/glossary.md#counter) counts 2 more boxes. A
   wrong [point](../../guides/reference/glossary.md#point) raises immediately. At 300 ms
   the force is a cut write, and `forces_unknown` names its set (decisions 437, 473 and
   391).
3. The cut write reaches the disk when the disk answers. The file then holds the force
   that the runner reported as failed. The runner did not put it in effect.
   `forces_unknown` stays until a later write of the file ends (decisions 391 and 502).
4. The runner cuts the end write of the trip. Then `status/1` answers, and names the
   store `unknown` (decisions 353 and 391).
5. The stop answers `{:error, {:retain, :timeout}}`. The holder keeps the store, and the
   runner refuses a start (decision 475).
6. When the disk answers, the holder gives the files up and a start runs. The store
   holds the count of 3, from a cut write that reached the disk.

### Each option not taken

| Decision | Not taken | Why not |
|---|---|---|
| 353 | File calls in the runner with no limit | A stalled disk stops the runner and each request of the host |
| 390 | A restart that fails on a forces file that it cannot read | The plant stays tripped on a stalled disk |
| 391 | Report a cut write as failed | A stop that answers `{:error, {:retain, :timeout}}` can leave that same write as the store |
| 400 | The idle watchdog and 1 poll period as the limit | A busy computer cuts a good write |
| 401 | Kill the write of the period at its limit | The newest image must wait for the write and then win (decision 275) |
| 414 | Make the text of the store outside the limit of its write | The supervisor kills the runner in a long write, and the store stays the one before |
| 437 | The runner waits for the write of a force | No round runs meanwhile, and each missed period of a [task](../../guides/reference/glossary.md#task) is an [overlap](../../guides/reference/glossary.md#overlap) |
| 455 | Only the shutdown makes the text of the store in its write | A trip of a large plant held the runner for 11.3 s |
| 465 | 1 write for each forcing request | 10 forces on a disk of 3 s a write take 30 s |
| 468 | A restart that reads the file while the write runs | The operator's screen shows a force that then goes away |
| 473 | Judge a wrong argument in its turn | The caller learns of the error only after the write ahead of it |
| 475 | Free the files when the runner ends | The next runner reads the old file, and a cut write then changes it |
| 488 | Send the whole resource to the writer | 36 ms of the runner each period for a program of 65,536 [rungs](../../guides/reference/glossary.md#rung) that retains 1 `bool` |
| 493 | Give only the failure of the store | The next start brings back a force that the operator removed, with no warning |
| 499 | Take the file of a killed runner immediately | A queued rename of the killed runner reaches the disk after the start reads the file |
| 500 | Wait for the write in the process of the runner | `status/1` blocked for up to the write limit, 1,503 ms in a probe |
| 502 | Clear `forces_unknown` at the read of a restart | The cut write can still bring the force back at the next restart |
| 508 | Make the second restart also | A second press clears a trip that came after the press |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
