defmodule Logex.Scan do
  @moduledoc """
  What one scan knows, read-only: `now`, the time of this scan in milliseconds, and
  `first`, whether it is the instance's first scan since it started or restarted.

  `Logex.Runtime.call/4` checks it against the instance: time never goes backwards, and
  `first` must agree. The evaluator threads it, unchanged, to every instruction of every
  rung (`evaluate/3`); M1-6's timers read `now`, and `ons` reads `first` (PLAN.md M1-6)
  and `ons_blocked`, as M3-1's counters and M3-4's pulse coils, `osr` and `osf`, do.

  `ons_blocked`, `tags`, `blocks`, `units` and `reals` are the runtime's, not the host's: a host builds a
  scan with `now` and `first` only, leaving them out, and one that fills any in is refused.

  - `ons_blocked` (OE-1) holds the storage bits whose `ons` this scan blocks, as a first
    scan blocks every `ons`. `call/4` takes them from the instance's `ons_blocked`, a list
    of names, a bit inside a function block instance named by its path, `s1.edge` (M2-5),
    and gives the evaluator a tree of them: each bit of the routine running to `true`, and
    each instance holding a blocked bit to a tree of its own, so each `ons` looks its bit
    up rather than walking the list. After the scan the instance keeps the bits of the
    instances whose bodies did not run, and since M3-5 those on rungs a jump skipped
    (`Logex.Instance`, decision 106). A counter's edge memory, since
    M3-1, is under the counter's name, `boxes` to `%{"cu" => true}`, which its `ctu` or
    `ctd` looks up (decision 87). A pulse coil's storage bit, since M3-4, is under its own
    name, as an `ons`'s is (decision 80).
  - `tags` (M2-5) is the tag table of the routine running, so that `cal` finds the type of
    the instance it runs, and the body of that type.
  - `blocks` (M2-5) is the program's one table of block types, by name, where a `cal`
    finds the type an instance names, `{:block, name}`, at any depth (`Logex.Program`'s
    `blocks`, decision 53).

  - `units` (decision 197) is the routine's own `units` (`Logex.Program`), each timer's
    unit where it is not the millisecond, so that a timer's run reads its unit with the
    routine and a plain timer's, in no table, costs no look-up.
  - `reals` (M5-10) is the routine's own `reals` (`Logex.Program`), the type of each tag
    that is a real, so that a `move` or a `cal`'s copy-out into one writes its nearest
    value, and a routine of no real, `reals` nil, pays no look-up.

  A `cal` runs its block's body with this scan narrowed to its instance: `tags` and
  `units` and `reals` the body's own and `ons_blocked` the instance's own tree, `now`, `first` and `blocks` unchanged. So
  every instruction of one routine, a program's rungs or one run of a body, sees one scan.
  """

  @enforce_keys [:now, :first]
  defstruct [:now, :first, ons_blocked: [], tags: nil, blocks: nil, units: nil, reals: nil]

  @type blocked :: %{optional(String.t()) => true | blocked}

  @type t :: %__MODULE__{
          now: non_neg_integer,
          first: boolean,
          ons_blocked: [] | blocked,
          tags: nil | %{String.t() => Logex.Tag.t()},
          blocks: nil | %{String.t() => Logex.FbType.t()},
          units: nil | %{String.t() => pos_integer},
          reals: nil | %{String.t() => :real | :lreal}
        }
end
