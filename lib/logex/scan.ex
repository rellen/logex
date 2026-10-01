defmodule Logex.Scan do
  @moduledoc """
  What one scan knows, read-only: `now`, the time of this scan in milliseconds, and
  `first`, whether it is the instance's first scan since it started or restarted.

  `Logex.Runtime.call/4` checks it against the instance: time never goes backwards, and
  `first` must agree. The evaluator threads it, unchanged, to every instruction of every
  rung (`evaluate/3`); M1-6's timers read `now`, and `ons` reads `first` (PLAN.md M1-6)
  and `ons_blocked`.

  `ons_blocked` is the runtime's, not the host's (OE-1): the storage bits whose `ons` this
  scan blocks, as a first scan blocks every `ons`. `call/4` takes it from the instance's
  `ons_blocked`, a list, and gives the evaluator a map of those bits, each to `true`, so
  each `ons` looks its bit up rather than walking the list; a host builds a scan with
  `now` and `first` only, leaving the field `[]`, and one that fills it in is refused.
  """

  @enforce_keys [:now, :first]
  defstruct [:now, :first, ons_blocked: []]

  @type t :: %__MODULE__{
          now: non_neg_integer,
          first: boolean,
          ons_blocked: [] | %{optional(String.t()) => true}
        }
end
