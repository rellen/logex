defmodule Logex.Tag do
  @moduledoc """
  One declared tag. `initial` is the initial value as declared, or nil when none was, and
  the tag then starts at 0 (`Logex.Program.initial_env/1`). `line` is its declaration's
  line in the source, or nil for a tag declared from Elixir with `new!/4`.
  """

  @enforce_keys [:name, :type, :section]
  defstruct [:name, :type, :section, initial: nil, line: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :bool | :dint,
          section: :var | :var_input | :var_output,
          initial: integer | nil,
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

defmodule Logex.Program do
  @moduledoc """
  A lowered routine and the tag table it was checked against. Declaration lines are rungs
  in the parse AST but never in `rungs`.
  """

  @enforce_keys [:rungs, :tags]
  defstruct [:rungs, :tags]

  @type t :: %__MODULE__{rungs: [{:rung, list}], tags: %{String.t() => Logex.Tag.t()}}

  @doc "The first env: every declared tag at its initial value, 0 when none was declared."
  def initial_env(%__MODULE__{tags: tags}),
    do: Map.new(tags, fn {name, %Logex.Tag{initial: initial}} -> {name, start(initial)} end)

  defp start(nil), do: 0
  defp start(initial), do: initial
end
