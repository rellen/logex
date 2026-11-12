# LineDevice: an adapter for a card on a TCP socket that speaks lines, `read` answered by
# its inputs, `0=1 2=0`, and `write 0=1 4=0` answered `ok`.
defmodule LineDevice do
  @behaviour Logex.IO

  @connect [:binary, packet: :line, active: false]

  # In the host's process, as the runner starts: the options' mistakes, a line each.
  @impl true
  def check(_device, _points, opts), do: Enum.flat_map([:host, :port], &given(&1, opts[&1]))

  defp given(key, nil), do: ["LineDevice needs #{key}:, the card's address"]
  defp given(_key, _value), do: []

  # In the device's process, from here on: the connection, made at once.
  @impl true
  def init(_device, _points, opts),
    do: opened(connected(%{host: opts[:host], port: opts[:port], socket: nil}))

  defp opened({:ok, state}), do: {:ok, state}
  defp opened({:error, reason, _state}), do: {:error, reason}

  # Every input, by address; a failure is given back, never raised, and the call after a
  # lost line connects again.
  @impl true
  def read(state), do: asked(connected(state), "read", &values/1)

  # Every output, by address, at each write: a snapshot.
  @impl true
  def write(values, state), do: asked(connected(state), "write " <> line(values), &ok/1)

  @impl true
  def close(%{socket: nil}), do: :ok
  def close(%{socket: socket}), do: :gen_tcp.close(socket)

  defp connected(%{socket: nil} = state),
    do: socket(:gen_tcp.connect(state.host, state.port, @connect, 1000), state)

  defp connected(state), do: {:ok, state}

  defp socket({:ok, socket}, state), do: {:ok, %{state | socket: socket}}
  defp socket({:error, reason}, state), do: {:error, reason, state}

  defp asked({:ok, state}, line, answer),
    do: answered(sent(:gen_tcp.send(state.socket, line <> "\n"), state.socket), answer, state)

  defp asked(error, _line, _answer), do: error

  defp sent(:ok, socket), do: :gen_tcp.recv(socket, 0, 1000)
  defp sent(error, _socket), do: error

  defp answered({:ok, text}, answer, state), do: given_back(answer.(text), state)
  defp answered({:error, reason}, _answer, state), do: lost(reason, state)

  defp given_back({:ok, values}, state), do: {:ok, values, state}
  defp given_back(:ok, state), do: {:ok, state}
  defp given_back({:error, reason}, state), do: {:error, reason, state}

  defp lost(reason, state) do
    :gen_tcp.close(state.socket)
    {:error, reason, %{state | socket: nil}}
  end

  # `0=1 2.1=7` is %{[0] => 1, [2, 1] => 7}: an address is its location's fields.
  defp values(text), do: {:ok, Map.new(String.split(text), &value/1)}

  defp value(pair) do
    [at, value] = String.split(pair, "=")
    {Enum.map(String.split(at, "."), &String.to_integer/1), String.to_integer(value)}
  end

  defp ok("ok\n"), do: :ok
  defp ok(other), do: {:error, {:refused, other}}

  defp line(values),
    do: Enum.map_join(Enum.sort(values), " ", fn {at, v} -> "#{Enum.join(at, ".")}=#{v}" end)
end

# The card, played by the script on the loopback interface: its inputs set, its outputs
# read and its line dropped by calls.
defmodule Card do
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, nil)
  def port(card), do: GenServer.call(card, :port)
  def set(card, at, value), do: GenServer.call(card, {:set, at, value})
  def outputs(card), do: GenServer.call(card, :outputs)
  def drop(card), do: GenServer.call(card, :drop)

  @impl true
  def init(nil) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, packet: :line, active: false, ip: {127, 0, 0, 1}])
    card = self()
    spawn_link(fn -> accepting(listen, card) end)
    {:ok, %{listen: listen, socket: nil, inputs: %{0 => 0, 2 => 0, 7 => 0, 8 => 0}, outputs: %{}}}
  end

  defp accepting(listen, card) do
    {:ok, socket} = :gen_tcp.accept(listen)
    :ok = :gen_tcp.controlling_process(socket, card)
    send(card, {:accepted, socket})
    accepting(listen, card)
  end

  @impl true
  def handle_call(:port, _from, state), do: {:reply, elem(:inet.port(state.listen), 1), state}
  def handle_call({:set, at, value}, _from, state), do: {:reply, :ok, put_in(state.inputs[at], value)}
  def handle_call(:outputs, _from, state), do: {:reply, state.outputs, state}

  def handle_call(:drop, _from, state) do
    :gen_tcp.close(state.socket)
    {:reply, :ok, %{state | socket: nil}}
  end

  @impl true
  def handle_info({:accepted, socket}, state) do
    :ok = :inet.setopts(socket, active: true)
    {:noreply, %{state | socket: socket}}
  end

  def handle_info({:tcp, socket, "read\n"}, state) do
    :gen_tcp.send(socket, Enum.map_join(state.inputs, " ", fn {at, v} -> "#{at}=#{v}" end) <> "\n")
    {:noreply, state}
  end

  def handle_info({:tcp, socket, "write " <> line}, state) do
    :gen_tcp.send(socket, "ok\n")
    {:noreply, %{state | outputs: Map.new(String.split(line), &output/1)}}
  end

  def handle_info({:tcp_closed, _socket}, state), do: {:noreply, state}

  defp output(pair) do
    [at, value] = String.split(pair, "=")
    {String.to_integer(at), String.to_integer(value)}
  end
end

alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, card} = Card.start_link()
{:ok, clock} = Manual.start_link()

opts = fn options ->
  [configuration: plant, io: %{"panel" => {LineDevice, options}}, clock: {Manual, clock}]
end

try do
  Runner.start_link(opts.(port: Card.port(card)))
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

{:ok, runner} = Runner.start_link(opts.(host: {127, 0, 0, 1}, port: Card.port(card)))
Card.set(card, 0, 1)                        # start pressed, read at the next poll, at 10
Manual.advance(clock, 10)
IO.inspect(Card.outputs(card), label: "the card's outputs")
Card.set(card, 0, 0)

Card.drop(card)                             # the line lost: the next read fails
Manual.advance(clock, 10)
IO.inspect(Map.take(Runner.status(runner), [:status, :trip]))
IO.inspect(Card.outputs(card), label: "the card's outputs")

:ok = Runner.restart(runner, :cold)         # the adapter connects again for the restart's read
IO.inspect(Map.take(Runner.status(runner), [:status, :trip]))
:ok = Runner.stop(runner)
IO.inspect(Card.outputs(card), label: "the card's outputs")
