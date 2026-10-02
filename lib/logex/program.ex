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

  The one rule for a new piece of state (`docs/organisation.md` §4.9):
  `Logex.Runtime.instance/1` and `restart/3` start every tag by it, an online edit's
  switch (`Logex.Edit`) starts each tag it adds by it, and `Logex.Runtime.start/1` and
  `restart/2` start every program instance of a configuration by it, through `instance/1`
  and `restart/3`. The edit's exceptions, for state an instance already holds around the
  new piece: `first` stays false; an `ons` the edit adds or changes is blocked for one
  scan by the instance's `ons_blocked`, where a new instance relies on `first`; a
  var_input a switch starts or makes live is reported, since its value is the host's; at
  the first test, a tag the candidate adds, or one whose value does not fit its type,
  starts here over what a plain swap left; and a kept bool or dint whose initial value
  changed keeps its value until a restart, and is reported as `:initial_changed`, except
  one the switch starts here, at its new initial value, and a var_input of the program
  started, whose value a restart keeps: neither is so reported. M2-6 will add an event
  task's trigger.
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
