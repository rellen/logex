defmodule Logex.Instance do
  @moduledoc """
  The state of one instance of a program: the value a host holds between scans. It holds
  no program, so one `%Logex.Program{}` can run as many instances as needed.

  - `type` is the name of the program it is an instance of.
  - `env` is every declared tag, keyed by name, at its current value: an integer, or for
    an instance of a function block such as a `ton`, a map from each member's name to its
    value (M1-6), and for a user block's instance, an instance it holds a map in that map
    (M2-5).
  - `now` is the time of its last scan, in milliseconds (0 before the first).
  - `first` says whether its next scan is the first since it started or restarted.
  - `ons_blocked` lists the storage bits whose `ons` its next scan blocks: each passes no
    power on that scan, as every `ons` passes none on a first scan, and still writes its
    bit. That scan empties it, and so does `Logex.Runtime.restart/3`. It is `[]` except
    between an online edit's switch, which sets it (`Logex.Edit`), and the scan that runs
    each listed `ons` (OE-1, `docs/organisation.md` §4.9). A bit inside a user block's
    instance is named by its path, `s1.edge`, and is blocked at the next scan that runs its
    `ons` (decision 32): a scan in which no `cal` runs the instance's body, its `cal` false
    or none, keeps it in the list, and a switch taken after such a scan keeps it listed
    where the program it starts still has that `ons`. Since M3-1 it also lists counters'
    edge memories, by path, `boxes.cu` or `s1.c.cu`: each is blocked as an `ons` bit is,
    its `ctu` or `ctd` counting no edge at the next scan that runs it (decision 87). Since
    M3-4 it lists a pulse coil's storage bit as it lists an `ons`'s, by name: its `osr` or
    `osf` sets no pulse at the next scan that runs it, and still writes both its bits
    (decision 80). The field keeps its name, the list naming every edge memory an edit
    blocks. Since M3-5 a scan keeps too each listed memory on a rung a jump skipped, in
    the program or in a body that ran, until a scan runs its instruction (decision 106);
    one that no rung of a routine the scan ran holds, which only a plain swap can leave, is
    used up.
  - `switched` says whether an online edit has switched it to another program since its
    last scan (`Logex.Edit`): a switch sets it, and a scan clears it. It is how an edit
    knows whether the program it stops has scanned since the last switch, and so whether
    the state holds what that program last gave the host. `restart/3` leaves it alone,
    since a restart is not a scan.
  - `faults` (M3-3, decision 99) are the minor faults of its last scan, each a
    `%Logex.Fault{}`, in the order they happened: a `div` or a `mod` that met a zero
    divisor. `[]` from `Logex.Runtime.instance/1`; each scan replaces them with its own,
    `[]` for none, so a host reads them after the scan that gave them; `put_inputs/3`,
    `restart/3` and an edit's switch keep them, since none is a scan. A resource reports
    each as an event of its cycle and keeps none: between cycles an instance's state in it
    holds `[]`.

  Make one with `Logex.Runtime.instance/1`. One built or edited by hand is outside the
  contract of `Logex.Runtime`.
  """

  @enforce_keys [:type, :env, :now, :first]
  defstruct [:type, :env, :now, :first, ons_blocked: [], switched: false, faults: []]

  @type t :: %__MODULE__{
          type: String.t() | nil,
          env: %{String.t() => integer | map},
          now: non_neg_integer,
          first: boolean,
          ons_blocked: [String.t()],
          switched: boolean,
          faults: [Logex.Fault.t()]
        }
end
