defmodule Logex.IO.Point do
  @moduledoc """
  A point of a device, as an adapter's `init/3` is given it (M4-1, `Logex.IO`): a global
  located at the device, `name`, its `direction`, `:input` for an `i` location and
  `:output` for a `q` one, its `address`, the location's integer fields, leftmost
  highest, `panel.i.1.3` being `[1, 3]`, and its `type`, `:bool` or `:dint`. Plain data.
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
