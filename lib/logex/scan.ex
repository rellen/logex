defmodule Logex.Scan do
  @moduledoc """
  What one scan knows, read-only: `now`, the time of this scan in milliseconds, and
  `first`, whether it is the instance's first scan since it started or restarted.

  `Logex.Runtime.call/4` checks it against the instance: time never goes backwards, and
  `first` must agree. Nothing reads it yet; M1-6's timers read `now` and `ons` reads
  `first` (PLAN.md M1-6).
  """

  @enforce_keys [:now, :first]
  defstruct [:now, :first]

  @type t :: %__MODULE__{now: non_neg_integer, first: boolean}
end
