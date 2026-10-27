defmodule Logex.Tag do
  @moduledoc """
  One declared tag. `type` is an elementary type, a row of
  `Logex.Declarations.table/0`: `:bool`, since M5-3 IEC's eight integer widths, `:sint`
  to `:ulint`, since M5-8 the four bit strings, `:byte` to `:lword`, and since M5-10 the
  two reals, `:real` and `:lreal`; or for an instance of a function block a
  `%Logex.FbType{}`, the schema itself, as `Logex.FbType.ton()` (M1-6) or a user block's
  type as `Logex.compile/2` gives it for the block's file (M2-5); or an array of either
  (below). `initial` is the initial value as declared, or nil when none was, and the tag
  then starts at its type's zero, 0 or, for a real, 0.0 (`Logex.Program.initial_env/1`).
  An instance is declared with none, and its members start where its type says; but a
  compiled timer carries its preset, the number on the `ton` that runs it, as
  `%{"pre" => 5000}`. Only the compiler gives that map: since OE-1 a tag from Elixir
  carries none (`new!/4`). `line` is its declaration's line in the
  source, or nil for a tag declared from Elixir with `new!/4`.

  In a compiled program, and in a user function block's compiled body (M2-5), an instance
  of a user block names its type, `{:block, name}`, which the program's or the outermost
  type's one table holds, once, in its `blocks` (decision 53;
  `Logex.Program.typed_tags/1` gives the tag table with each type itself); a tag from
  Elixir holds the type itself, as `Logex.compile/2` gives it.

  Since M5-11 (decision 151) a type may be an array, `{:array, type, dims}`, of an
  elementary type and one to three sizes, `{:array, :int, [4, 8]}` for `int[4,8]`, its
  `initial` nil or a list of one value for every element, in the elements' order, the
  rightmost subscript fastest; and since M5-14 (decision 154) an array of instances,
  `{:array, %Logex.FbType{}, dims}` for `ton[4]` or `gate[4]`, declared in `var` alone
  with no initial list, an array of a user block's instances in a compiled program naming
  its type, `{:array, {:block, name}, dims}`.

  Since M6-1 (`docs/organisation.md` §4.13, decisions 267 to 270) `retain` is the
  declaration's qualifier: `:retain` for `var retain count dint`, `:non_retain` for `var
  non_retain jog bool`, and nil, the default, for a line with none, which is not retained
  unless an instance holding it is (`Logex.Program`'s `retained`, decision 270). A program's
  `var_input` and a `var_external` take none.
  """

  @enforce_keys [:name, :type, :section]
  defstruct [:name, :type, :section, initial: nil, line: nil, retain: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          type:
            Logex.Declarations.elementary()
            | Logex.FbType.t()
            | {:block, String.t()}
            | {:array, Logex.Declarations.elementary() | Logex.FbType.t() | {:block, String.t()},
               [pos_integer]},
          section: :var | :var_input | :var_output | :var_external,
          initial: integer | float | [integer | float] | %{String.t() => integer} | nil,
          line: pos_integer | nil,
          retain: :retain | :non_retain | nil
        }

  @doc """
  A tag declared from Elixir, checked by the same rules as a declaration line
  (`Logex.Declarations.check/1`). Raises `ArgumentError` with the message a declaration
  line would have got. With no initial value a tag starts at its type's zero, a bool, an
  integer of any width or a bit string at 0 and a real at 0.0, an array each element so,
  and an instance of a function block where its type says (`Logex.FbType.initial/2`), an
  array of instances each element so.

  What no declaration line can say is refused here too, so every tag declared from Elixir
  could have been written as text (OE-1; `docs/organisation.md` §4.9, decisions 24 and
  28):
  - any initial value on an instance, with the message `var t1 ton 5` gets. A timer's
    preset is the number on the `ton` that runs it; the `%{"pre" => ms}` this took until
    OE-1 is withdrawn, since a `ton` silently replaced it and, with none, no text could
    give that `.pre`;
  - a user block's type that is not the one its source text compiles to
    (`Logex.FbType.user?/1`, decision 54), such as one whose body was edited by hand
    (M2-5);
  - a qualifier, `retain`, a declaration line could not give (M6-1): one on a
    `var_external`, whose global carries it. One on a program's `var_input` is refused
    where the program compiles (`Logex.Compiler`), which knows a program from a function
    block's body.

  Since decision 296 (2026-10-27) the qualifier is an option, the line's own word as its
  key: `new!("c", :dint, :var, nil, retain: true)` for `var retain c dint` and
  `non_retain: true` for `var non_retain c dint`, `false` or no option for a line with
  none; `new!/4` is as it was. Refused, each a line of one `ArgumentError`, before the
  declaration is checked: options that are no keyword list, the fifth argument of M6-1's
  `new!/5`, `:retain`, among them; an option of another name; a value that is neither
  `true` nor `false`; an option given twice; and both `true`, as a line takes `retain` or
  `non_retain`, not both. The struct's `retain` keeps the atom, `:retain`, `:non_retain`
  or nil, and a `%Logex.Tag{}` built by hand with any other is refused where it is
  checked (`Logex.Declarations.check/1`).
  """
  def new!(name, type, section \\ :var, initial \\ nil, options \\ []),
    do:
      Logex.Declarations.validate!(%__MODULE__{
        name: name,
        type: type,
        section: section,
        initial: initial,
        retain: qualifier!(options, name)
      })

  # Decision 296: the qualifier's options, read in clauses, every problem a line.
  @options [:retain, :non_retain]

  defp qualifier!(options, name) when is_list(options),
    do: options(options, options, name, %{}, [])

  defp qualifier!(options, name), do: raise(ArgumentError, shape(options, name))

  defp options([], _all, name, seen, []), do: chosen(seen, name)

  defp options([], _all, _name, _seen, problems),
    do: raise(ArgumentError, Enum.join(Enum.reverse(problems), "\n"))

  defp options([{key, _value} | rest], all, name, seen, problems) when is_map_key(seen, key),
    do: options(rest, all, name, seen, ["`#{key}:` is given twice for #{label(name)}" | problems])

  defp options([{key, value} | rest], all, name, seen, problems)
       when key in @options and is_boolean(value),
       do: options(rest, all, name, Map.put(seen, key, value), problems)

  defp options([{key, value} | rest], all, name, seen, problems) when key in @options,
    do:
      options(rest, all, name, Map.put(seen, key, value), [
        "`#{key}:` for #{label(name)} takes true or false, found #{inspect(value)}" | problems
      ])

  defp options([{key, value} | rest], all, name, seen, problems) when is_atom(key),
    do:
      options(rest, all, name, Map.put(seen, key, value), [
        "unknown option #{inspect(key)} for #{label(name)}: Logex.Tag.new!/5 takes " <>
          "`retain:` and `non_retain:`"
        | problems
      ])

  defp options(_improper, all, name, _seen, _problems), do: raise(ArgumentError, shape(all, name))

  defp chosen(%{retain: true, non_retain: true}, name),
    do:
      raise(
        ArgumentError,
        "#{label(name)} takes `retain: true` or `non_retain: true`, not both, as a " <>
          "declaration takes `retain` or `non_retain`, not both"
      )

  defp chosen(%{retain: true}, _name), do: :retain
  defp chosen(%{non_retain: true}, _name), do: :non_retain
  defp chosen(_seen, _name), do: nil

  defp shape(options, name),
    do:
      "the options of #{label(name)} are a keyword list, `retain: true` or " <>
        "`non_retain: true`, found #{inspect(options)}"

  defp label(name) when is_binary(name), do: "`#{name}`"
  defp label(name), do: inspect(name)
end
