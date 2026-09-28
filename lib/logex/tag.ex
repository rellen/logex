defmodule Logex.Tag do
  @moduledoc """
  One declared tag. `line` is its declaration's line in the source, or nil for a tag
  declared from Elixir with `new!/4`.
  """

  @enforce_keys [:name, :type, :section]
  defstruct [:name, :type, :section, initial: 0, line: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          type: :bool | :dint,
          section: :var | :var_input | :var_output,
          initial: integer,
          line: pos_integer | nil
        }

  @doc """
  A tag declared from Elixir, checked by the same rules as a declaration line. Raises
  `ArgumentError` with the message a declaration line would have got. With no initial
  value the tag starts at 0.
  """
  def new!(name, type, section \\ :var, initial \\ nil) do
    tag = %__MODULE__{name: name, type: type, section: section, initial: initial}
    checked(Logex.Declarations.check(tag), tag)
  end

  defp checked([], %__MODULE__{initial: initial} = tag), do: %{tag | initial: initial || 0}
  defp checked([message | _], _tag), do: raise(ArgumentError, message)
end

defmodule Logex.Program do
  @moduledoc """
  A lowered routine and the tag table it was checked against. Declaration lines are rungs
  in the parse AST but never in `rungs`.
  """

  @enforce_keys [:rungs, :tags]
  defstruct [:rungs, :tags]

  @type t :: %__MODULE__{rungs: [{:rung, list}], tags: %{String.t() => Logex.Tag.t()}}

  @doc "The first env: every declared tag at its initial value."
  def initial_env(%__MODULE__{tags: tags}),
    do: Map.new(tags, fn {name, %Logex.Tag{initial: initial}} -> {name, initial} end)
end
