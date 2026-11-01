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
  """

  @enforce_keys [:name, :direction, :address, :type]
  defstruct [:name, :direction, :address, :type]

  @type t :: %__MODULE__{
          name: String.t(),
          direction: :input | :output,
          address: Logex.IO.address(),
          type: Logex.Declarations.elementary()
        }
end
