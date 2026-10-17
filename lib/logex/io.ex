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
end
