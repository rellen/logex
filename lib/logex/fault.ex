defmodule Logex.Fault do
  @moduledoc """
  A minor fault (M3-3, decisions 78 and 99): what a scan met that IEC calls an error and
  logex runs on through, reported to the host and never raised. The scan goes on, and so
  does the plant. The one kind so far is a zero divisor, which gives 0 and passes no power
  on that scan (decision 78); a host tolerates a kind it does not know.

  - `kind` is what happened: `:divide_by_zero`, a `div` or a `mod` whose divisor was 0.
  - `instruction` is the mnemonic that met it, `:div` or `:mod`.
  - `path` is where it ran inside the program instance: nil for the program's own rungs,
    or the path of the user function block instance whose body holds it, `"s1"`, or
    `"s1.inner"` a level down, as an access path names it (`docs/organisation.md` §4.7).
  - `file` is the file of the routine that holds it, the program's or the block's, as
    `Logex.compile_file/1` read it, or nil for one compiled from text.
  - `line` is the instruction's line in that file.

  A host sees a lone instance's in `state.faults`, every fault of the scan that returned
  the state, in the order they happened, `[]` for none (`Logex.Instance`), after
  `Logex.Runtime.call/4`, `scan/2` and `scan/3`; and a resource's as events of the cycle,
  `{:fault, task, instance, fault}`, each just after its scan's `{:ran, task, instance,
  now}` (`Logex.Runtime`), `instance` the program instance's name, so that a block's is
  at `"\#{instance}.\#{fault.path}"`.
  """

  @enforce_keys [:kind, :instruction, :path, :file, :line]
  defstruct [:kind, :instruction, :path, :file, :line]

  @type t :: %__MODULE__{
          kind: :divide_by_zero,
          instruction: :div | :mod,
          path: String.t() | nil,
          file: String.t() | nil,
          line: pos_integer
        }
end
