defmodule Logex.Printer do
  @moduledoc """
  The other direction: a parse AST back to source text.

  Without this the pipeline is one-way — `tokenize/1`, `parse/1`, `instructionize/1`
  and `evaluate/2` all consume toward an environment — so logex could read a rung
  written as text but never write one. That makes it a textual *input format* rather
  than a textual *representation*, which is the thing a per-rung editing box needs:
  the vendor's own guide for the software logex borrows its mnemonics from describes
  the box as showing you the rung you already have, not only as somewhere to type a
  new one — *"For a rung that already contains logic, the existing ASCII instructions
  appear in the box so you can edit them."*

  Prints the **parse** AST, not the instruction IR. The parse AST is one lossless
  step from the source, while `instructionize/1` has already resolved mnemonics
  through `@instructions` and would need the reverse map; and a text area has to
  render text that is mid-edit and not yet a valid instruction stream, which the IR
  cannot represent at all.

  The output is canonical rather than faithful — see `print/1`.
  """

  @doc """
  Renders a parse AST as source text.

  The result is **canonical**, not a copy of whatever was parsed: one rung per line,
  single spaces between elements, and integers in their shortest form. So
  `"  xic   aa  "` prints as `"xic aa"` and `"mov 007 hh"` as `"mov 7 hh"`. That is a
  decision, not an accident — `print/1` emits the one spelling logex considers
  correct, and `test/logex/printer_test.exs` pins both losses so that neither can
  change silently. Anything that must survive a round trip unchanged has to reach the
  AST as structure; comments are the open case (`PLAN.md` §5), and landing `//` as
  `skip_token` would make this printer destructive.

  Raises on two AST shapes that `parse/1` cannot produce, rather than emitting text
  that would read back as something else:

    * `{:branches, []}` — a group with no legs at all, which differs in meaning from
      `{:branches, [[]]}`, a group with one empty leg. The first is false
      (`Enum.any?` over zero legs), the second passes power.

  Both are reachable only by building an AST by hand, which is what the test
  generator does.
  """
  def print({:routine, {:rungs, rungs}}), do: Enum.map_join(rungs, "\n", &print/1)

  def print({:rung, []}) do
    raise ArgumentError,
          "cannot print an empty rung: the `routine` rule in src/ladder_parser.yrl " <>
            "filters these out, so one here was built by hand"
  end

  def print({:rung, elements}), do: elements |> tokens() |> Enum.join(" ")

  defp tokens(elements) when is_list(elements), do: Enum.flat_map(elements, &tokens/1)

  defp tokens({:name, _, name}), do: [name]

  defp tokens({:int_lit, _, value}), do: [Integer.to_string(value)]

  defp tokens({:branches, []}) do
    raise ArgumentError,
          "cannot print a branch group with no legs: it would print as `( )`, " <>
            "which parses back as one empty leg and passes power"
  end

  defp tokens({:branches, legs}) do
    ["("] ++
      (legs |> Enum.map(&tokens/1) |> Enum.intersperse(["|"]) |> Enum.concat()) ++
      [")"]
  end
end
