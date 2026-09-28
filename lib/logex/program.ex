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
