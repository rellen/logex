defmodule Logex.IO.Point do
  @moduledoc """
  A point of a device, as an adapter's `init/3` is given it (`Logex.IO`): a global
  located at the device, or an element of a located array global, `name`, `"eye_1"` or
  `"zone_t[3]"` (decision 156), its `direction`, `:input` for an `i` location and
  `:output` for a `q` one, its `address`, the location's integer fields, leftmost highest,
  `panel.i.1.3` being `[1, 3]`, and its `type`, any elementary type, a row of
  `Logex.Declarations.table/0`: `:bool`, an integer type such as `:dint` or `:uint`, a
  bit string such as `:word`, or a real, `:real` or `:lreal`, an array's element's type
  for an element. Plain data.

  Inside the host contract (decision 523): what `Logex.IO`'s behaviour hands an adapter,
  built by `Logex.IO.points/1` from a configuration `Logex.Configuration.new!/1` checked,
  so an adapter may rely on each field as this moduledoc gives it; a host builds none.
  """

  @enforce_keys [:name, :direction, :address, :type]
  defstruct [:name, :direction, :address, :type]

  @typedoc "A device's point, as the moduledoc gives it."
  @type t :: %__MODULE__{
          name: String.t(),
          direction: :input | :output,
          address: Logex.IO.address(),
          type: Logex.Declarations.elementary()
        }
end
