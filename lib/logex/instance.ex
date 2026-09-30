defmodule Logex.Instance do
  @moduledoc """
  The state of one instance of a program: the value a host holds between scans. It holds
  no program, so one `%Logex.Program{}` can run as many instances as needed.

  - `type` is the name of the program it is an instance of.
  - `env` is every declared tag, keyed by name, at its current value: an integer, or for
    an instance of a function block such as a `ton`, a map from each member's name to its
    value (M1-6).
  - `now` is the time of its last scan, in milliseconds (0 before the first).
  - `first` says whether its next scan is the first since it started or restarted.

  Make one with `Logex.Runtime.instance/1`. One built or edited by hand is outside the
  contract of `Logex.Runtime`.
  """

  @enforce_keys [:type, :env, :now, :first]
  defstruct [:type, :env, :now, :first]

  @type t :: %__MODULE__{
          type: String.t() | nil,
          env: %{String.t() => integer | %{String.t() => integer}},
          now: non_neg_integer,
          first: boolean
        }
end
