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
  # `written/3`'s, a process of its own for the one write, waited on for the idle watchdog
  # and a poll period of real time, as the runner waits on the period's writer at an event,
  # and so is the forces file's read at a restart, the runner's own (`within/2`):
  # one that has not answered by then is killed and is `{:error, :timeout}`, so that a
  # stalled disk leaves the runner answering, and one gone down without an answer is
  # `{:error, {:down, reason}}`. A write killed inside a call of the file system runs that
  # call on to its end in the kernel and then does nothing more, so its file may yet be
  # the old or the new, never a mix (`Logex.Retain.written/2`). Since RV-5's review a copy a
  # fresh start owes is made before any write over the store (stored/4).
  #
  # Since RV-4's review the one write's process is linked to the runner as the period's
  # writer is, so that a runner killed, or crashed, while it waits on a write takes the
  # write down with it: the write does at most the call of the file system it is in and
  # nothing after, never a rename once the runner is gone and its files are free for the
  # next runner of this VM (decision 356), whose write it would otherwise rename into the
  # store. The runner traps exits, so the write's exit is a message to it, taken here with
  # the write's answer, nothing left in its mailbox.

  use GenServer

  def start_link(path), do: GenServer.start_link(__MODULE__, {path, self()})

  # One image to write, sent only once the last write has been answered, with the copy a
  # fresh start owes, nil for none (stored/4).
  def write(pid, at, image, owed), do: GenServer.cast(pid, {:write, at, image, owed})

  # One write, waited on for `ms` of real time.
  def written(path, text, ms), do: within(fn -> Logex.Retain.written(path, text) end, ms)

  # Decision 360 (RV-5's review): the store's write, an event's, waited on for `ms` of real
  # time as one, and the period's, by the writer, each made where a fresh start's copy of
  # the store it dropped from is owed, its own write having failed, only once that copy
  # is made: the copy first, `<store>.dropped`, and the store only where the copy was
  # made, `{:copied, result}`, the store's result; a copy that fails writes no store,
  # `{:uncopied, reason}`; and with no copy owed the store's write alone, an event's
  # written/3's.
  def stored(path, text, owed, ms), do: within(fn -> copied_first(path, text, owed) end, ms)

  defp copied_first(path, text, nil), do: Logex.Retain.written(path, text)

  defp copied_first(path, text, owed),
    do: copy_then(Logex.Retain.written(path <> ".dropped", owed), path, text)

  defp copy_then(:ok, path, text), do: {:copied, Logex.Retain.written(path, text)}
  defp copy_then({:error, reason}, _path, _text), do: {:uncopied, reason}

  # One call of the file system, a write's or the forces file's read at a restart, in a
  # process of its own linked to the caller, a runner, which traps exits, waited on for
  # `ms` of real time; its result rides on its process's exit, so that nothing is left in
  # the caller's mailbox, whichever way it ends, its link's exit taken with its monitor's.
  def within(call, ms),
    do: waited(:erlang.spawn_opt(fn -> exit({__MODULE__, call.()}) end, [:link, :monitor]), ms)

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
  def handle_cast({:write, at, image, owed}, {path, runner} = state) do
    result = copied_first(path, Logex.Retain.encode(image, at), owed)
    send(runner, {__MODULE__, self(), at, result})
    {:noreply, state}
  end
end
