defmodule Logex.Tag do
  @moduledoc """
  One declared tag. `type` is `:bool`, `:dint`, or for an instance of a function block a
  `%Logex.FbType{}`, the schema itself, as `Logex.FbType.ton()` (M1-6). `initial` is the
  initial value as declared, or nil when none was, and the tag then starts at 0
  (`Logex.Program.initial_env/1`). An instance is declared with none, and its members
  start where its type says; but a compiled timer carries its preset, the number on the
  `ton` that runs it, as `%{"pre" => 5000}`, and one declared from Elixir may carry the
  same map, its `pre` a preset of 0 to 2147483647 ms. `line` is its declaration's line in
  the source, or nil for a tag declared from Elixir with `new!/4`.
  """

  @enforce_keys [:name, :type, :section]
  defstruct [:name, :type, :section, initial: nil, line: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :bool | :dint | Logex.FbType.t(),
          section: :var | :var_input | :var_output,
          initial: integer | %{String.t() => integer} | nil,
          line: pos_integer | nil
        }

  @doc """
  A tag declared from Elixir, checked by the same rules as a declaration line. Raises
  `ArgumentError` with the message a declaration line would have got. With no initial
  value the tag starts at 0.
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
