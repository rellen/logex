defmodule Logex.Runner.Writer do
  @moduledoc false

  # M6-6 (docs/organisation.md §4.13, decision 275): the runner's writer, a process of its
  # own, linked to its runner, so that a period's store write, however slow, delays no
  # round. The runner hands it the resource between rounds with the time of its header,
  # and since decision 455 (RV-6) the writer takes the retained image out of it, where the
  # runner took it out itself, encodes it as the store's text and writes it
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
  # period; and since decision 437 (RV-16) a force's write of the forces file is made
  # off the runner's path, so that its rounds run on while it is out: begun/2 makes it, a
  # process of its own linked and monitored as within/2's, and the runner takes its
  # answer as a message, ended/2, or cuts it at its limit, cut/1, or waits for it as it
  # stops, awaited/2. A write killed inside a call of the file system runs that
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
  # fresh start owes, nil for none (stored/4). Since decision 455 (RV-6) the resource the
  # image is taken out of, `{:runtime, runtime}`, the take-out and the text made here, in
  # the writer, within the limit the runner gives the write from the hand-off; an image a
  # test's seam took out in the runner, `{:image, image}`, its text alone.
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

  # Decision 437 (RV-16): a force's write of the forces file, made while the runner goes
  # on, the rounds running meanwhile: its process, linked to the runner and monitored, as
  # within/2's, `{pid, ref}`, whose answer rides on its exit, the runner taking it as its
  # monitor's message, ended/2, and cutting it at its limit, cut/1, or, as it stops,
  # waiting for it to that limit, awaited/2. The write lets go of its link once its call of
  # the file system has answered, the last it does, so that its exit never reaches the
  # runner as a message of its own, while a runner killed during the call still takes it
  # down; one cut keeps its link, its exit taken with its answer.
  def begun(path, text) do
    runner = self()

    :erlang.spawn_opt(
      fn ->
        answer = Logex.Retain.written(path, text)
        Process.unlink(runner)
        exit({__MODULE__, answer})
      end,
      [:link, :monitor]
    )
  end

  # The write's answer, its monitor's message taken by the runner: `:ok` or `{:error,
  # reason}`, `{:error, {:down, reason}}` for one gone down without an answer.
  def ended({pid, _ref}, reason), do: unlinked(pid, answered(reason))

  # The write at its limit: killed, `{:error, :timeout}`, or its answer where it gave one
  # as it was killed.
  def cut({pid, ref}), do: timed_out(pid, ref)

  # The write waited for until `until`, a time of the VM's monotonic clock in ms, and cut
  # there: a runner that stops while its force's write is out.
  def awaited({pid, ref} = write, until) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> ended(write, reason)
    after
      max(until - System.monotonic_time(:millisecond), 0) -> cut(write)
    end
  end

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
  # (decision 447).
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
  # stands (decision 450). The store's name is read whole, so that a store whose own name
  # ends in `.dropped` counts its own copies (`Logex.Runner.Paths.copy_of/2`). The
  # directory is read raw, off the VM's file server, as the files are, inside the write's
  # own process and its limit; the copy is written through the one `.tmp` of the store's
  # copies, `<store>.dropped.tmp`, and renamed only where nothing stands at its name as it
  # looks, raw, just before the rename (`Logex.Retain.written/2`), so that one a host
  # made there since the directory was read and before that look is not replaced: the
  # copy then fails, `:eexist`, and is owed as one that fails is, its next try numbered
  # past it (decision 448, decision 416's rule); one made between the look and the rename,
  # which goes through the VM's file server and on a stalled disk waits in its queue, is
  # replaced (decision 449).
  #
  # Decision 456 (RV-6): before it copies, the copy compares the store's text with the
  # highest-numbered copy that stands, and where they hold the same bytes it makes no new
  # copy and is that one, `{:ok, n}` its number, so that a start that fails after its copy
  # and is started again, a supervisor's restarts among them, leaves one copy where it
  # left one a start, and so does an owed copy made by a later write over one that landed
  # late (decision 391), the copy a start owes compared as the start's own is
  # (provisional). The comparison is a read, raw and inside the copy's own process and
  # its limit, `write_limit:`: of the highest number's entry only where it is a regular
  # file, so that a FIFO or a device a host put there is never read; and an entry that is
  # none, or that cannot be read, a directory among them, is no match, the new copy made
  # one past it, as before. Nothing is told before the copy is chosen to be made, so that
  # a comparison cut off at its limit is a copy killed before it took a number, which can
  # land nowhere, `:timeout` (decision 452). `told`, `{caller, tag}`, is told `{tag, n}`
  # once the number is chosen, and nil, the period's writer, nothing. `{:ok, n}` or
  # `{:error, reason}`.
  def copy(store, text, told),
    do: copy_numbered(highest_copy(store), store, text, told)

  defp copy_numbered({:ok, highest}, store, text, told),
    do: copy_matched(same_copy?(highest, store, text), highest, store, text, told)

  defp copy_numbered(error, _store, _text, _told), do: error

  defp copy_matched(true, highest, _store, _text, _told), do: {:ok, highest}

  defp copy_matched(false, highest, store, text, told) do
    n = highest + 1
    tell(told, n)
    copy_written(Logex.Retain.written({Paths.copy(store, n), store <> ".dropped.tmp"}, text), n)
  end

  defp copy_written(:ok, n), do: {:ok, n}
  defp copy_written(error, _n), do: error

  # Decision 456 (RV-6): the highest copy holds the store's text byte for byte; none
  # standing, 0, is no match.
  defp same_copy?(0, _store, _text), do: false

  defp same_copy?(highest, store, text),
    do:
      same_bytes?(:file.read_link_info(Paths.copy(store, highest), [:raw]), store, highest, text)

  defp same_bytes?({:ok, info}, store, n, text)
       when elem(info, 2) == :regular and elem(info, 1) == byte_size(text),
       do: :prim_file.read_file(Paths.copy(store, n)) == {:ok, text}

  defp same_bytes?(_other, _store, _n, _text), do: false

  defp highest_copy(store),
    do: highest(:prim_file.list_dir_all(Path.dirname(store)), Path.basename(store))

  defp highest({:ok, names}, base),
    do: {:ok, Enum.max([0 | for(name <- names, n <- copy_number(name, base), do: n)])}

  defp highest(error, _base), do: error

  defp copy_number(name, base), do: listed(Paths.copy_of(named(name), base))

  defp named(name) when is_list(name), do: List.to_string(name)
  defp named(name), do: name

  defp listed(nil), do: []
  defp listed(n), do: [n]

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
  def handle_cast({:write, at, taken, owed}, {path, runner} = state) do
    result = copied_first(path, fn -> Logex.Retain.encode(image(taken), at) end, owed, nil)
    send(runner, {__MODULE__, self(), at, result})
    {:noreply, state}
  end

  defp image({:runtime, runtime}), do: Logex.Runtime.retained(runtime)
  defp image({:image, image}), do: image
end
