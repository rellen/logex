defmodule Logex.Program do
  @moduledoc """
  A compiled program: a program *type* in IEC's terms, named and stateless. Every instance
  of it keeps its own state (`Logex.Runtime`), so one program can run as many instances.

  - `name` is set by `Logex.compile/2` and `Logex.compile_file/1`; it is nil only for a
    program built by `Logex.Compiler.instructionize/2` directly, or by hand.
  - `source` is the text it was compiled from, when it came through `Logex.compile*`.
  - `rungs` are the lowered rungs. Declaration lines are rungs in the parse AST, but never
    here.
  - `tags` is the tag table, keyed by tag name.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`, in line order.
  """

  @enforce_keys [:rungs, :tags]
  defstruct [:rungs, :tags, name: nil, source: nil, warnings: []]

  @type t :: %__MODULE__{
          rungs: [{:rung, list}],
          tags: %{String.t() => Logex.Tag.t()},
          name: String.t() | nil,
          source: String.t() | nil,
          warnings: [Logex.Diagnostic.t()]
        }

  @doc """
  The first env: every declared tag at its initial value, 0 when none was declared, and
  every instance of a function block a map of its members at theirs (M1-6).
  """
  def initial_env(%__MODULE__{tags: tags}),
    do: Map.new(tags, fn {name, tag} -> {name, start(tag)} end)

  defp start(%Logex.Tag{type: %Logex.FbType{} = type, initial: nil}),
    do: Logex.FbType.initial(type)

  # A timer's preset, from the `ton` that runs it (Logex.Compiler), is its `pre` to start.
  defp start(%Logex.Tag{type: %Logex.FbType{} = type, initial: inputs}),
    do: Logex.FbType.initial(type, inputs)

  defp start(%Logex.Tag{initial: nil}), do: 0
  defp start(%Logex.Tag{initial: initial}), do: initial
end
