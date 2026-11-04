defmodule Logex.Runner.Writer do
  @moduledoc false

  # M6-6 (docs/organisation.md §4.13, decision 275): the runner's writer, a process of its
  # own, linked to its runner, so that a period's store write, however slow, delays no
  # round. The runner takes the retained image out between rounds and hands it here with
  # the time of its header; the writer encodes it as the store's text and writes it
  # through `Logex.Retain.written/2`, `<path>.tmp` synced, closed and renamed over the
  # store, and tells the runner how it went, `{Logex.Runner.Writer, pid, at, result}`. It
  # holds one write at a time: the runner sends it the next only once it has answered,
  # keeping the newest it took out meanwhile and dropping the older, latest wins.
  #
  # Decision 353 (RV-4): every other write the runner makes, a force's of the forces file
  # and the store's at a trip, a stop, a shutdown, a cold restart and a fresh start, is
  # `written/3`'s, a process of its own for the one write, waited on for the runner's
  # write limit of real time, as the runner waits on the period's writer at an event, and
  # so is the forces file's read at a restart, the runner's own (`within/2`): one that has
  # not answered by then is killed and is `{:error, :timeout}`, so that a stalled disk
  # leaves the runner answering, and one gone down without an answer is `{:error, {:down,
  # reason}}`. Since decision 400 (RV-11) that limit is the runner's `write_limit:`, 5000
  # ms unless set, apart from the heartbeat, where it was the idle watchdog and a poll
  # period; and a write the runner waits on while it runs, a force's, keeps its devices'
  # heartbeat meanwhile (written/4). A write killed inside a call of the file system runs that
  # call on to its end in the kernel and then does nothing more, so its file may yet be
  # the old or the new, never a mix (`Logex.Retain.written/2`). Since RV-5's review a copy a
  # fresh start owes is made before any write over the store (stored/4), and since decision
  # 418 (RV-13) each copy is a name of its own, `<store>.dropped.<n>`, numbered as it is
  # made, inside the write's own process and its limit (copy/3).
  #
  # Since RV-4's review the one write's process is linked to the runner as the period's
  # writer is, so that a runner killed, or crashed, while it waits on a write takes the
  # write down with it: the write does at most the call of the file system it is in and
  # nothing after, never a rename once the runner is gone and its files are free for the
  # next runner of this VM (decision 356), whose write it would otherwise rename into the
  # store. The runner traps exits, so the write's exit is a message to it, taken here with
  # the write's answer, nothing left in its mailbox.

  use GenServer

  alias Logex.Runner.Paths

  def start_link(path), do: GenServer.start_link(__MODULE__, {path, self()})

  # One image to write, sent only once the last write has been answered, with the copy a
  # fresh start owes, nil for none (stored/4).
  def write(pid, at, image, owed), do: GenServer.cast(pid, {:write, at, image, owed})

  # One write, waited on for `ms` of real time. Decision 414 (RV-13): `text` the store's
  # text, or a function that makes it, an event's or a start's write of the store, so that
  # the retained image's take-out and its text, in proportion to the retained values, are
  # made in the write's own process and within its limit, where the runner made them
  # first, unlimited, so that a supervisor's shutdown deadline, which counts the write
  # limit, waited for the write it was given and killed the runner in a store too big to
  # make in it; a store too big to make and write within the limit is cut off at it, a
  # write past its limit as any (decision 391).
  def written(path, text, ms), do: within(fn -> Logex.Retain.written(path, made(text)) end, ms)

  defp made(text) when is_binary(text), do: text
  defp made(text) when is_function(text, 0), do: text.()

  # Decision 400 (RV-11): one write the runner waits on while it runs, a force's of the
  # forces file, waited on for `ms` of real time as written/3's is, `tick` called on `acc`
  # every `every` ms of real time while it is out, so that the runner renews its devices'
  # heartbeat while it waits on its disk within its limit, a runner that is well, as one
  # waiting on a slow device in time is (decision 348): `{result, acc}`.
  def written(path, text, ms, {every, acc, tick}),
    do:
      ticking(
        :erlang.spawn_opt(fn -> exit({__MODULE__, Logex.Retain.written(path, text)}) end, [
          :link,
          :monitor
        ]),
        System.monotonic_time(:microsecond) + 1000 * ms,
        {every, acc, tick}
      )

  # Decision 360 (RV-5's review): the store's write, an event's, waited on for `ms` of real
  # time as one, and the period's, by the writer, each made where a fresh start's copy of
  # the store it dropped from is owed, its own write having failed, only once that copy
  # is made: the copy first, since decision 418 the next of the store's numbered copies
  # (copy/3), and the store only where the copy was made, `{:copied, n, result}`, the
  # copy's number and the store's result; a copy that fails writes no store, `{:uncopied,
  # reason}`; and with no copy owed the store's write alone, an event's written/3's.
  # Decision 391 (RV-11's review): an event's write killed at its limit is told by the
  # file it was in as the limit passed, which the write tells its caller as it goes, its
  # copy's number once chosen and then the copy made: in the copy's, `{:uncopied,
  # {:unknown, n}}`, the copy `<store>.dropped.<n>` unknown and the store as it was,
  # since the write does nothing after the call it is killed in, or `{:uncopied,
  # :timeout}` where it was killed before it chose the number, so that no copy can land;
  # in the store's, `{:copied, n, {:error, :timeout}}`, the copy made and the store unknown
  # (provisional).
  def stored(path, text, owed, ms) do
    told = {self(), make_ref()}
    in_flight(within(fn -> copied_first(path, text, owed, told) end, ms), told)
  end

  # The copy made is looked for first, its number's note before it in the mailbox.
  defp in_flight({:error, :timeout}, {_caller, tag}) do
    receive do
      {^tag, {:copied, n}} -> flushed(tag, {:copied, n, {:error, :timeout}})
    after
      0 -> uncopied(tag)
    end
  end

  defp in_flight(result, {_caller, tag}), do: flushed(tag, result)

  defp uncopied(tag) do
    receive do
      {^tag, n} -> flushed(tag, {:uncopied, {:unknown, n}})
    after
      0 -> {:uncopied, :timeout}
    end
  end

  # A write's notes to its caller taken, none left in the caller's mailbox: each comes
  # before its process's exit, which the caller has taken.
  defp flushed(tag, result) do
    receive do
      {^tag, _note} -> flushed(tag, result)
    after
      0 -> result
    end
  end

  defp copied_first(path, text, nil, _told), do: Logex.Retain.written(path, made(text))

  defp copied_first(path, text, owed, told),
    do: copy_then(copy(path, owed, told), path, text, told)

  defp copy_then({:ok, n}, path, text, told) do
    tell(told, {:copied, n})
    {:copied, n, Logex.Retain.written(path, made(text))}
  end

  defp copy_then({:error, reason}, _path, _text, _told), do: {:uncopied, reason}

  # Decision 418 (RV-13): a fresh start's copy of its store, waited on for `ms` of real
  # time as one write: `{:ok, n}`, the copy `<store>.dropped.<n>` made; `{:unknown, n}`,
  # killed at its limit once its number was chosen, so that it may yet land there
  # (decision 391); or `{:error, reason}`, `:timeout` among them where it was killed
  # before, so that no copy can land.
  def copied(store, text, ms) do
    told = {self(), make_ref()}
    numbered(within(fn -> copy(store, text, told) end, ms), told)
  end

  defp numbered({:error, :timeout}, {_caller, tag}) do
    receive do
      {^tag, n} -> {:unknown, n}
    after
      0 -> {:error, :timeout}
    end
  end

  defp numbered(result, {_caller, tag}), do: flushed(tag, result)

  # Decision 418 (RV-13): a copy of the store, under a name of its own, the next of its
  # numbered copies, `<store>.dropped.<n>`, n one past the highest number that stands
  # beside the store, 1 where none does, none replaced: every entry of the store's
  # directory named the store's name, `.dropped.` and a whole number in decimal digits
  # counts as standing, by its number's value, whatever it is, a copy, a file or a
  # directory a host made there, so that the copy's name is free as the copy begins; an
  # unnumbered `<store>.dropped` an earlier logex left counts for nothing and is left as it
  # stands (provisional). The directory is read raw, off the VM's file server, as the
  # files are, inside the write's own process and its limit; the copy is written through
  # the one `.tmp` of the store's copies, `<store>.dropped.tmp`, and renamed only where
  # nothing stands at its name (`Logex.Retain.written/2`), so that one a host made there
  # since the directory was read is never replaced: the copy then fails, `:eexist`, and
  # is owed as one that fails is, its next try numbered past it (provisional, decision
  # 416's rule). `told`, `{caller, tag}`, is told `{tag, n}` once the number is chosen,
  # and nil, the period's writer, nothing. `{:ok, n}` or `{:error, reason}`.
  def copy(store, text, told),
    do: copy_numbered(next_copy(store), store, text, told)

  defp copy_numbered({:ok, n}, store, text, told) do
    tell(told, n)
    copy_written(Logex.Retain.written({Paths.copy(store, n), store <> ".dropped.tmp"}, text), n)
  end

  defp copy_numbered(error, _store, _text, _told), do: error

  defp copy_written(:ok, n), do: {:ok, n}
  defp copy_written(error, _n), do: error

  defp next_copy(store),
    do: past_highest(:prim_file.list_dir_all(Path.dirname(store)), Path.basename(store))

  defp past_highest({:ok, names}, base),
    do: {:ok, 1 + Enum.max([0 | for(name <- names, n <- copy_number(name, base), do: n)])}

  defp past_highest(error, _base), do: error

  defp copy_number(name, base), do: same_store(Paths.copy_of(named(name)), base)

  defp named(name) when is_list(name), do: List.to_string(name)
  defp named(name), do: name

  defp same_store({base, n}, base), do: [n]
  defp same_store(_other, _base), do: []

  # The period's writer tells no caller: its write is left to finish, its answer telling
  # both files (decision 401).
  defp tell(nil, _note), do: :ok
  defp tell({caller, tag}, note), do: send(caller, {tag, note})

  # One call of the file system, a write's or the forces file's read at a restart, in a
  # process of its own linked to the caller, a runner, which traps exits, waited on for
  # `ms` of real time; its result rides on its process's exit, so that nothing is left in
  # the caller's mailbox, whichever way it ends, its link's exit taken with its monitor's.
  # Decision 414 (RV-13): the limit counted from before the process is made, so that the
  # copy of what its call holds, a resource's image to take out among it, is within it.
  def within(call, ms) do
    begun = System.monotonic_time(:millisecond)
    write = :erlang.spawn_opt(fn -> exit({__MODULE__, call.()}) end, [:link, :monitor])
    waited(write, max(ms - (System.monotonic_time(:millisecond) - begun), 0))
  end

  # The same for a read made in a start's caller, which need not trap exits, its process
  # unlinked: a read that outlives its caller writes nothing.
  def read(call, ms), do: waited(spawn_monitor(fn -> exit({__MODULE__, call.()}) end), ms)

  defp waited({pid, ref}, ms) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> unlinked(pid, answered(reason))
    after
      ms -> timed_out(pid, ref)
    end
  end

  # The write waited on a tick at a time, the last cut to its limit: each wait that ends
  # before the limit ticks, and the one that ends at it kills the write. The limit's end
  # is kept in microseconds, each wait the whole milliseconds left rounded up, so that the
  # write is given its whole limit, as within/2's single wait gives it.
  defp ticking({pid, ref} = write, until, {every, acc, _tick} = ticks) do
    left = max(div(until - System.monotonic_time(:microsecond) + 999, 1000), 0)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> {unlinked(pid, answered(reason)), acc}
    after
      min(left, every) -> ticked(left <= every, write, until, ticks)
    end
  end

  defp ticked(true, {pid, ref}, _until, {_every, acc, _tick}), do: {timed_out(pid, ref), acc}

  defp ticked(false, write, until, {every, acc, tick}),
    do: ticking(write, until, {every, tick.(acc), tick})

  # A write that answered as it was killed answered; one killed is down at once, its call
  # of the file system, if any, left to run on.
  defp timed_out(pid, ref) do
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^ref, :process, ^pid, :killed} -> unlinked(pid, {:error, :timeout})
      {:DOWN, ^ref, :process, ^pid, reason} -> unlinked(pid, answered(reason))
    end
  end

  # The link's exit, which comes in the caller's mailbox once its process is down, taken:
  # once unlink/1 returns none comes after it, so one that came is there now.
  defp unlinked(pid, result) do
    Process.unlink(pid)

    receive do
      {:EXIT, ^pid, _reason} -> result
    after
      0 -> result
    end
  end

  defp answered({__MODULE__, result}), do: result
  defp answered(reason), do: {:error, {:down, reason}}

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_cast({:write, at, image, owed}, {path, runner} = state) do
    result = copied_first(path, Logex.Retain.encode(image, at), owed, nil)
    send(runner, {__MODULE__, self(), at, result})
    {:noreply, state}
  end
end
