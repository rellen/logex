defmodule Logex.Fault do
  @moduledoc """
  A fault a scan met (M3-3, decisions 78 and 99; since M5-9, decisions 153 and 160): what
  IEC calls an error, found only as the program runs, reported to the host and never
  raised. The scan goes on either way. A host tolerates a kind it does not know.

  - `severity` is what the fault does to the plant: `:minor`, which the plant runs on
    through, or `:major`, on which `Logex.Runner` trips (decision 113's one path), at the
    end of the step whose run met the round's first one (decision 153's note).
  - `kind` is what happened: `:divide_by_zero`, minor, a `div` or a `mod` whose divisor
    was 0, which gives 0 and passes no power on that scan (decision 78); and since M5-9
    `:bit_out_of_range`, major, a bit whose number a tag holds, `status.[n]`, outside its
    word's bits when its instruction read or wrote it, which did nothing and passed no
    power (decision 160); and since M5-10 `:negative_sqrt`, minor, a `sqrt` whose source
    was negative, which gives 0.0 and passes no power on that scan (decision 164). A
    zero divisor of a real destination gives 0.0.
  - `instruction` is the mnemonic that met it, `:div` or `:mod` for a zero divisor, `:sqrt`
    for a negative root, and
    for a bit out of range the instruction whose operand the bit is, `:xic`, `:ote`,
    `:move`, `:and`, `:cal` and the rest.
  - `path` is where it ran inside the program instance: nil for the program's own rungs,
    or the path of the user function block instance whose body holds it, `"s1"`, or
    `"s1.inner"` a level down, as an access path names it (`docs/organisation.md` §4.7).
  - `file` is the file of the routine that holds it, the program's or the block's, as
    `Logex.compile_file/1` read it, or nil for one compiled from text.
  - `line` is the instruction's line in that file.
  - `read` is what the scan read that was out of range: the bit number, 16 for
    `drive_faults.[sel]` with `sel` at 16 in a `word`; the source of a negative root,
    −0.25 for `sqrt fan_var fan_dev` with `fan_var` at −0.25; nil for a zero divisor.

  A host sees a lone instance's in `state.faults`, every fault of the scan that returned
  the state, in the order they happened, `[]` for none (`Logex.Instance`), after
  `Logex.Runtime.call/4`, `scan/2` and `scan/3`; and a resource's as events of the cycle,
  `{:fault, task, instance, fault}`, each just after its scan's `{:ran, task, instance,
  now}` (`Logex.Runtime`), `instance` the program instance's name, so that a block's is
  at `"\#{instance}.\#{fault.path}"`.
  """

  @enforce_keys [:severity, :kind, :instruction, :path, :file, :line]
  defstruct [:severity, :kind, :instruction, :path, :file, :line, read: nil]

  @type t :: %__MODULE__{
          severity: :minor | :major,
          kind: :divide_by_zero | :bit_out_of_range | :negative_sqrt,
          instruction: atom,
          path: String.t() | nil,
          file: String.t() | nil,
          line: pos_integer,
          read: number | nil
        }
end
