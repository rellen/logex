# TraceIO is an adapter that tells the script each call of a callback, and the process
# that makes the call. The script runs packing.logex on it 2 times: first with a read
# that gives a map, then with a read that gives a struct.
defmodule TraceIO do
  @behaviour Logex.IO

  @impl true
  def check(_device, _points, options), do: tell(options[:to], "check/3", [])

  @impl true
  def init(device, points, options) do
    state = %{to: options[:to], inputs: options[:inputs]}
    tell(state.to, "init/3 #{inspect(device)}, #{length(points)} points", {:ok, state})
  end

  @impl true
  def read(state), do: tell(state.to, "read/1", {:ok, state.inputs, state})

  @impl true
  def write(values, state),
    do: tell(state.to, "write/2 #{inspect(values, charlists: :as_lists)}", {:ok, state})

  @impl true
  def report(message, state),
    do: tell(state.to, "report/2 #{inspect(message)}", {:ok, %{}, state})

  @impl true
  def close(state), do: tell(state.to, "close/1", :ok)

  defp tell(to, call, result) do
    send(to, {:call, self(), call})
    result
  end
end

alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
host = self()

calls = fn ->
  {:messages, messages} = Process.info(host, :messages)
  for {:call, _pid, _call} = message <- messages, do: receive(do: (^message -> message))
end

show = fn list ->
  for {:call, pid, call} <- list,
      do: IO.puts("  " <> Map.get(%{host => "host  "}, pid, "device") <> "  " <> call)
end

start = fn inputs ->
  options = [to: host, inputs: inputs]

  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {TraceIO, options}},
    clock: {Manual, clock}
  )
end

IO.puts("A read that gives %{[0] => 1}:")
{:ok, runner} = start.(%{[0] => 1})
started = calls.()
show.(started)
[device] = Enum.uniq(for {:call, pid, _call} <- started, pid != host, do: pid)
send(device, :hello)
Manual.advance(clock, 10)
:ok = Runner.stop(runner)
show.(calls.())

IO.puts("A read that gives a struct:")
# The message holds the state of the adapter, with a pid that is different at each run.
answer = inspect(start.(MapSet.new([[0]])))
IO.puts("  start: " <> Regex.replace(~r/#PID<[0-9.]+>/, answer, "#PID<...>"))
show.(calls.())
