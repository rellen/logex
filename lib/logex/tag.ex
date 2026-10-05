defmodule Logex.Tag do
  @moduledoc """
  One declared tag. `type` is `:bool`, `:dint`, or for an instance of a function block a
  `%Logex.FbType{}`, the schema itself, as `Logex.FbType.ton()` (M1-6) or a user block's
  type as `Logex.compile/2` gives it for the block's file (M2-5). `initial` is the
  initial value as declared, or nil when none was, and the tag then starts at 0
  (`Logex.Program.initial_env/1`). An instance is declared with none, and its members
  start where its type says; but a compiled timer carries its preset, the number on the
  `ton` that runs it, as `%{"pre" => 5000}`. Only the compiler gives that map: since OE-1
  a tag from Elixir carries none (`new!/4`). `line` is its declaration's line in the
  source, or nil for a tag declared from Elixir with `new!/4`.

  In a compiled program, and in a user function block's compiled body (M2-5), an instance
  of a user block names its type, `{:block, name}`, which the program's or the outermost
  type's one table holds, once, in its `blocks` (decision 53;
  `Logex.Program.typed_tags/1` gives the tag table with each type itself); a tag from
  Elixir holds the type itself, as `Logex.compile/2` gives it.
  """

  @enforce_keys [:name, :type, :section]
  defstruct [:name, :type, :section, initial: nil, line: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :bool | :dint | Logex.FbType.t() | {:block, String.t()},
          section: :var | :var_input | :var_output,
          initial: integer | %{String.t() => integer} | nil,
          line: pos_integer | nil
        }

  @doc """
  A tag declared from Elixir, checked by the same rules as a declaration line
  (`Logex.Declarations.check/1`). Raises `ArgumentError` with the message a declaration
  line would have got. With no initial value a bool or a dint starts at 0, and an
  instance of a function block where its type says (`Logex.FbType.initial/2`).

  What no declaration line can say is refused here too, so every tag declared from Elixir
  could have been written as text (OE-1; `docs/organisation.md` §4.9, decisions 24 and
  28):
  - any initial value on an instance, with the message `var t1 ton 5` gets. A timer's
    preset is the number on the `ton` that runs it; the `%{"pre" => ms}` this took until
    OE-1 is withdrawn, since a `ton` silently replaced it and, with none, no text could
    give that `.pre`;
  - a negative initial value, until a negative literal lexes (`PLAN.md` §5);
  - a user block's type that no compile could give (`Logex.FbType.user?/1`), such as one
    whose body was edited by hand (M2-5).
  """
  def new!(name, type, section \\ :var, initial \\ nil),
    do:
      Logex.Declarations.validate!(%__MODULE__{
        name: name,
        type: type,
        section: section,
        initial: initial
      })
end
