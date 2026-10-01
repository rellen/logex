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
  - `ons_blocked` lists the storage bits whose `ons` its next scan blocks: each passes no
    power on that scan, as every `ons` passes none on a first scan, and still writes its
    bit. That scan empties it, and so does `Logex.Runtime.restart/3`. It is `[]` except
    between an online edit's switch and the next scan (OE-1, `docs/organisation.md`
    §4.9), and nothing sets it yet.
  - `switched` says whether an online edit has switched it to another program since its
    last scan (`Logex.Edit`): a switch sets it, and a scan clears it. It is how an edit
    knows whether the program it stops has scanned since the last switch, and so whether
    the state holds what that program last gave the host. `restart/3` leaves it alone,
    since a restart is not a scan.

  Make one with `Logex.Runtime.instance/1`. One built or edited by hand is outside the
  contract of `Logex.Runtime`.
  """

  @enforce_keys [:type, :env, :now, :first]
  defstruct [:type, :env, :now, :first, ons_blocked: [], switched: false]

  @type t :: %__MODULE__{
          type: String.t() | nil,
          env: %{String.t() => integer | %{String.t() => integer}},
          now: non_neg_integer,
          first: boolean,
          ons_blocked: [String.t()],
          switched: boolean
        }
end
