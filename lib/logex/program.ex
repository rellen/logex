defmodule Logex.Program do
  @moduledoc """
  A compiled program: a program *type* in IEC's terms, named and stateless. Every instance
  of it keeps its own state (`Logex.Runtime`), so one program can run as many instances.

  - `name` is set by `Logex.compile/2` and `Logex.compile_file/1`; it is nil only for a
    program built by `Logex.Compiler.instructionize/2` directly, or by hand.
  - `source` is the text it was compiled from, when it came through `Logex.compile*`.
  - `file` is the path `Logex.compile_file/1` read it from, and nil for a program from
    text (fix F15): a diagnostic about it that cites a line, such as an online edit's
    (`Logex.Edit`), cites that file too.
  - `rungs` are the lowered rungs. Declaration lines are rungs in the parse AST, but never
    here.
  - `tags` is the tag table, keyed by tag name.
  - `blocks` is empty except in a user function block's compiled body (M2-5): there it
    holds each user block type the body declares instances of, once, by name, and each
    such instance's tag names its type, `{:block, name}` (`docs/organisation.md` §4.10,
    "Held types"). So a type holds each type it nests once, however many instances of it
    its body declares. A program's own tags hold each type itself, as `Logex.Tag.new!/4`
    gives it, and `typed_tags/1` gives a body's table so.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`, in line order. From
    `Logex.compile_file/1` the warnings of each block it loaded beside the file follow,
    each with its block's file (decision 34); a block's body holds only its own.
  """

  @enforce_keys [:rungs, :tags]
  defstruct [:rungs, :tags, name: nil, source: nil, file: nil, warnings: [], blocks: %{}]

  @type t :: %__MODULE__{
          rungs: [{:rung, list}],
          tags: %{String.t() => Logex.Tag.t()},
          blocks: %{String.t() => Logex.FbType.t()},
          name: String.t() | nil,
          source: String.t() | nil,
          file: String.t() | nil,
          warnings: [Logex.Diagnostic.t()]
        }

  @doc """
  The first env: every declared tag at its initial value, 0 when none was declared, and
  every instance of a function block a map of its members at theirs (M1-6).

  An instance of a user function block (M2-5) starts as its type says, every member at its
  initial value and every instance it holds at its own, at any depth (`Logex.FbType`).

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

  @doc """
  The tag table with each instance's type itself: in a block's compiled body, every tag
  that names a type its `blocks` holds, `{:block, name}`, given that type, and every other
  tag as it is (M2-5). It is the table a compile works over, which the walks that read an
  instruction's slots in a body (`Logex.Compiler.signature/2`, `Logex.Warnings.of/2`) take.
  Its tags share each type, so it costs one entry per tag, and no copy of a type. A name
  `blocks` lacks, which only a body built by hand can give, is left as it is.
  """
  def typed_tags(%__MODULE__{tags: tags, blocks: blocks}),
    do: Map.new(tags, fn {name, tag} -> {name, typed(tag, blocks)} end)

  defp typed(%Logex.Tag{type: {:block, name}} = tag, blocks),
    do: held(Map.fetch(blocks, name), tag)

  defp typed(tag, _blocks), do: tag

  defp held({:ok, type}, tag), do: %{tag | type: type}
  defp held(:error, tag), do: tag
end
