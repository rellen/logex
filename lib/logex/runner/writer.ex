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

  use GenServer

  def start_link(path), do: GenServer.start_link(__MODULE__, {path, self()})

  # One image to write, sent only once the last write has been answered.
  def write(pid, at, image), do: GenServer.cast(pid, {:write, at, image})

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_cast({:write, at, image}, {path, runner} = state) do
    result = Logex.Retain.written(path, Logex.Retain.encode(image, at))
    send(runner, {__MODULE__, self(), at, result})
    {:noreply, state}
  end
end
