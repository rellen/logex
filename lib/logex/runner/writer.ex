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
  # the old or the new, never a mix (`Logex.Retain.written/2`).

  use GenServer

  def start_link(path), do: GenServer.start_link(__MODULE__, {path, self()})

  # One image to write, sent only once the last write has been answered.
  def write(pid, at, image), do: GenServer.cast(pid, {:write, at, image})

  # One write, waited on for `ms` of real time.
  def written(path, text, ms), do: within(fn -> Logex.Retain.written(path, text) end, ms)

  # One call of the file system, a write's or the forces file's read at a restart, in a
  # process of its own, waited on for `ms` of real time; its result rides on its process's
  # exit, so that nothing is left in the caller's mailbox, whichever way it ends.
  def within(call, ms) do
    {pid, ref} = spawn_monitor(fn -> exit({__MODULE__, call.()}) end)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> answered(reason)
    after
      ms -> timed_out(pid, ref)
    end
  end

  # A write that answered as it was killed answered; one killed is down at once, its call
  # of the file system, if any, left to run on.
  defp timed_out(pid, ref) do
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^ref, :process, ^pid, :killed} -> {:error, :timeout}
      {:DOWN, ^ref, :process, ^pid, reason} -> answered(reason)
    end
  end

  defp answered({__MODULE__, result}), do: result
  defp answered(reason), do: {:error, {:down, reason}}

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_cast({:write, at, image}, {path, runner} = state) do
    result = Logex.Retain.written(path, Logex.Retain.encode(image, at))
    send(runner, {__MODULE__, self(), at, result})
    {:noreply, state}
  end
end
