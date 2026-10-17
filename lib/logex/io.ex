defmodule Logex.IO do
  @moduledoc """
  The adapter behaviour (M4-1, `docs/organisation.md` §4.5 and §4.11): how the wall-clock
  runner reads and writes a device. A device is the first part of a location, `panel` in
  `panel.i.0`; the host binds each device to an adapter, a module that implements this
  behaviour, and the runner runs each bound device in a process of its own, which holds
  the adapter's state and calls its callbacks. `Logex.Runtime` never calls one: the core
  takes an input map and gives an output map, and an adapter is what fills the one from
  a device and writes the other to it.

  A device's points are its globals with `at`, each a `%Logex.IO.Point{}`: its name, its
  direction, `:input` for an `i` location and `:output` for a `q` one, its address, the
  location's integer fields, leftmost highest, `panel.i.1.3` being `[1, 3]`, and its type.
  Values go by address, `%{[0] => 1, [1] => 0}`, each an integer.

  - `init/3` opens the device, given its name, its points and the options it was bound
    with, in the device's process, which is where an adapter that reports its changes
    arranges for its device's messages to be sent: a port's, a socket's, a process of its
    own. It gives the adapter's state, or `{:error, reason}`, which is the plant's state,
    a device that cannot be opened, not a mistake.
  - `read/1` gives values for some or all of the device's input points; the runner keeps
    an image of them, so an adapter may give only what changed. The runner reads every
    device every poll period (decision 120).
  - `write/2` is given every output point of the device, by address, a snapshot, so an
    adapter may skip what did not change; it gives back its state, so that a connection
    can be opened again inside it.
  - `report/2`, optional, is called with each message the device's process receives that
    is not the runner's, and gives the inputs that message says changed, `%{}` for one it
    does not know: an adapter that implements it reports its changes as they come, between
    reads (decisions 112 and 120), and one that does not is only read.
  - `close/1`, optional, is called once, after the last write of zeros, when the runner
    stops or dies.

  A callback that fails says so, `{:error, reason, state}`, and does not raise: a device
  that does not answer is the plant's state, not a bug. A raise, a throw or an exit in a
  callback, a value that does not fit its point, an address that is no point of the
  device, or no answer in time, is an I/O fault all the same, which trips the runner
  (decision 114).

  `points/1` groups a configuration's points by device, what each adapter's `init/3` is
  given, and `bind!/2` checks a host's bindings against them, as `Logex.Runner` checks
  them at start: every device a point is at bound, every device bound with a point at it.

  `Logex.IO.Sim` is the one adapter logex ships, an in-memory device for tests and demos;
  an adapter for real hardware needs libraries, and lives in the host's application or a
  package of its own.
  """

  @typedoc "A point's address, the integer fields of its location, leftmost highest: `panel.i.1.3` is `[1, 3]`."
  @type address :: [non_neg_integer, ...]

  @typedoc "Values by address."
  @type values :: %{address => integer}

  @typedoc "An adapter's own state, which the device's process holds between callbacks."
  @type state :: term

  @doc "Opens the device `device`, whose points are `points`, with the options it was bound with."
  @callback init(device :: String.t(), points :: [Logex.IO.Point.t()], opts :: keyword) ::
              {:ok, state} | {:error, reason :: term}

  @doc "Reads some or all of the device's input points."
  @callback read(state) :: {:ok, values, state} | {:error, reason :: term, state}

  @doc "Writes every output point of the device."
  @callback write(values, state) :: {:ok, state} | {:error, reason :: term, state}

  @doc "The inputs a message the device's process received says changed, `%{}` for one it does not know."
  @callback report(message :: term, state) ::
              {:ok, values, state} | {:error, reason :: term, state}

  @doc "Closes the device, after the last write of zeros."
  @callback close(state) :: :ok

  @optional_callbacks report: 2, close: 1

  alias Logex.{Configuration, Declarations, Diagnostic}
  alias Logex.Configuration.Global
  alias Logex.IO.Point

  # The callbacks an adapter cannot do without.
  @required [init: 3, read: 1, write: 2]

  @doc """
  The located points of a configuration, grouped by device, `%{device =>
  [%Logex.IO.Point{}]}`, each device's points in the order the configuration declares
  them: what each device's adapter is opened with. A global with `at` is a point, its
  device the location's first part and its address its integer fields
  (`Logex.Configuration.location/1`). A configuration with no located global has no
  device.

  The configuration is checked as `Logex.Runtime.start/1` checks it, and one it refuses
  raises `ArgumentError` in the same words.
  """
  def points(configuration) do
    configured!(configuration)

    configuration.globals
    |> Enum.flat_map(&point/1)
    |> Enum.group_by(fn {device, _point} -> device end, fn {_device, point} -> point end)
  end

  defp point(%Global{at: nil}), do: []

  defp point(%Global{name: name, at: at, type: type}) do
    {:ok, {device, io, address}} = Configuration.location(at)
    [{device, %Point{name: name, direction: direction(io), address: address, type: type}}]
  end

  defp direction("i"), do: :input
  defp direction("q"), do: :output

  defp configured!(configuration), do: refused!(Configuration.check(configuration))

  defp refused!([]), do: :ok

  defp refused!(diagnostics),
    do: raise(ArgumentError, Enum.map_join(diagnostics, "\n", &Diagnostic.format/1))

  @doc """
  A host's bindings, checked against a configuration's devices, as `Logex.Runner` checks
  them at start: `io` maps each device's name to its adapter, a module that implements
  this behaviour, or `{module, options}`, its options a keyword list. Gives each device
  with its adapter, its options and its points, `{device, module, options, points}`, in
  device-name order, so that the devices are opened in one order.

  Every device the points name is bound, and every device bound has a point at it
  (`docs/organisation.md` §4.5). A mistake is the host's, and every mistake comes in one
  `ArgumentError`, a line each, in device-name order, a key that is not a device's name
  first: a device no adapter is bound to, naming the points at it; a device bound that no
  point is at, with a did-you-mean among the devices; a binding that is no adapter; an
  adapter's options that are no keyword list; and an adapter that does not implement this
  behaviour, naming the callbacks it lacks. The configuration is checked first, as
  `points/1` checks it.
  """
  def bind!(configuration, io) do
    devices = points(configuration)
    io = io!(io)

    problems =
      Enum.flat_map(unnamed(io), &unnamed_key(&1, devices)) ++
        Enum.flat_map(
          names(devices, io),
          &device(&1, Map.fetch(devices, &1), Map.fetch(io, &1), devices)
        )

    bound!(problems, devices, io)
  end

  defp io!(io) when is_map(io) and not is_struct(io), do: io

  defp io!(other),
    do:
      raise(
        ArgumentError,
        "io binds each device by its name to its adapter, a map such as " <>
          "%{\"panel\" => MyApp.PanelIO}, got: #{inspect(other)}"
      )

  defp unnamed(io), do: Enum.sort(for key <- Map.keys(io), not is_binary(key), do: key)

  defp names(devices, io),
    do:
      Enum.sort(Enum.uniq(Map.keys(devices) ++ for(key <- Map.keys(io), is_binary(key), do: key)))

  defp unnamed_key(key, devices),
    do: ["io names each device by a string, got: #{inspect(key)}" <> named(key, devices)]

  # An atom that spells a device's name is told the string.
  defp named(key, devices) when is_atom(key),
    do: spelled(Map.has_key?(devices, Atom.to_string(key)), Atom.to_string(key))

  defp named(_key, _devices), do: ""

  defp spelled(true, name), do: " — did you mean #{inspect(name)}?"
  defp spelled(false, _name), do: ""

  # A device's problems: its points and its binding, each found or not.
  defp device(name, {:ok, points}, :error, _devices),
    do: ["no adapter is bound to the device `#{name}`, which " <> at(name, points)]

  defp device(name, :error, {:ok, _binding}, devices),
    do: [
      "the device `#{name}` is bound, but no point is at it" <>
        Declarations.suggest(name, Enum.sort(Map.keys(devices)), & &1, "devices")
    ]

  defp device(name, {:ok, _points}, {:ok, binding}, _devices), do: adapter(name, binding)

  # Each point named with its location, as the configuration spells it.
  defp at(device, [%Point{} = point]), do: "#{shown(device, point)} is at"
  defp at(device, points), do: listed(Enum.map(points, &shown(device, &1))) <> " are at"

  defp shown(device, %Point{name: name, direction: direction, address: address}),
    do:
      "`#{name}` (#{Enum.join([device, letter(direction) | Enum.map(address, &Integer.to_string/1)], ".")})"

  defp letter(:input), do: "i"
  defp letter(:output), do: "q"

  defp listed([one, two]), do: "#{one} and #{two}"
  defp listed([one | rest]), do: one <> ", " <> listed(rest)

  defp adapter(name, {module, opts}) when is_atom(module) and is_list(opts),
    do: options(name, Keyword.keyword?(opts), opts) ++ implemented(name, module)

  defp adapter(name, {module, opts}) when is_atom(module),
    do: options(name, false, opts) ++ implemented(name, module)

  defp adapter(name, module) when is_atom(module), do: implemented(name, module)

  defp adapter(name, other),
    do: [
      "the device `#{name}` is bound to #{inspect(other)}: an adapter is a module that " <>
        "implements Logex.IO, or {module, options}"
    ]

  defp options(_name, true, _opts), do: []

  defp options(name, false, opts),
    do: ["the device `#{name}`'s adapter options are a keyword list, got: #{inspect(opts)}"]

  defp implemented(name, module), do: lacking(name, module, Code.ensure_loaded?(module))

  defp lacking(name, module, false),
    do: ["the device `#{name}` is bound to `#{inspect(module)}`, which is no module"]

  defp lacking(name, module, true),
    do:
      missing(
        name,
        module,
        for({f, a} <- @required, not function_exported?(module, f, a), do: "#{f}/#{a}")
      )

  defp missing(_name, _module, []), do: []

  defp missing(name, module, callbacks),
    do: [
      "the device `#{name}` is bound to `#{inspect(module)}`, which does not implement " <>
        "Logex.IO: it has no " <> either(callbacks)
    ]

  defp either([one]), do: one
  defp either([one, two]), do: "#{one} or #{two}"
  defp either([one | rest]), do: one <> ", " <> either(rest)

  defp bound!([], devices, io),
    do:
      for(
        name <- Enum.sort(Map.keys(devices)),
        do: entry(name, Map.fetch!(io, name), Map.fetch!(devices, name))
      )

  defp bound!(problems, _devices, _io), do: raise(ArgumentError, Enum.join(problems, "\n"))

  defp entry(name, {module, opts}, points), do: {name, module, opts, points}
  defp entry(name, module, points), do: {name, module, [], points}
end
