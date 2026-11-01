defmodule Logex.Printer do
  @moduledoc """
  The other direction: a parse AST back to source text.

  Without this the pipeline is one-way — `tokenize/1`, `parse/1`, `instructionize/2`
  and `evaluate/3` all consume toward an environment — so logex could read a rung
  written as text but never write one. That makes it a textual *input format* rather
  than a textual *representation*, which is the thing a per-rung editing box needs:
  the vendor's own guide for the software logex borrows its mnemonics from describes
  the box as showing you the rung you already have, not only as somewhere to type a
  new one — *"For a rung that already contains logic, the existing ASCII instructions
  appear in the box so you can edit them."*

  Prints the **parse** AST, not the instruction IR. The parse AST is one lossless
  step from the source, while `instructionize/2` has already resolved mnemonics
  through `@instructions` and would need the reverse map; and a text area has to
  render text that is mid-edit and not yet a valid instruction stream, which the IR
  cannot represent at all.

  The output is canonical rather than faithful — see `print/1`.
  """

  @doc """
  Renders a parse AST as source text.

  The result is **canonical** in its layout, not a copy of whatever was parsed: one rung
  per line and single spaces between elements, so `"  xic   aa  "` prints as `"xic aa"`.
  That is a decision, not an accident, and `test/logex/printer_test.exs` pins each loss
  so that none can change silently. A literal prints exactly as it was written, since
  decision 202 keeps its spelling in the AST wherever it is not the plain decimal of its
  value: `"move 16#00ff hh"` prints as written, and so do `"move 1_000 hh"`, `"mov 007
  hh"` and `"eq -0 x"`, where until then each printed as its value's decimal, `255`,
  `1000`, `7` and `0`. Mnemonic case is kept too: it carries no meaning since M1-2, but
  the parse AST does not know which names are mnemonics, so `XIC` prints as written.
  Anything that must survive a round trip unchanged has to reach the AST as structure.
  `//` comments do not: `Logex.Lexer` skips them, so printing drops them, until
  `PLAN.md` §5's comment above a rung gives one somewhere to live.

  A real literal prints as written too, `37.50` and `1.0e-400`, and one written as its
  float's plain text as that text, `Float.to_string/1`'s.

  Raises on two AST shapes that `parse/1` cannot produce, rather than emitting text
  that would read back as something else:

    * `{:rung, []}` — an empty rung, which `parse/1` drops, so it would print as a
      blank line that reads back as no rung at all.
    * `{:branches, []}` — a group with no legs at all, which differs in meaning from
      `{:branches, [[]]}`, a group with one empty leg. The first is false
      (`Enum.any?` over zero legs), the second passes power.

  Both are reachable only by building an AST by hand, which is what the test
  generator does. Neither compiles: `Logex.Compiler.instructionize/2` refuses both on
  entry, as it refuses every tree `Logex.Parser.well_formed!/1` does not take (OE-1).
  Since RV-2 (the review after Milestone 6) anything else that is no such tree, a leaf of
  another shape among it, is an `ArgumentError` naming it, and the text is built in one
  pass, linear in the rung's depth of nesting, where each group copied every token
  inside it.
  """
  def print({:routine, {:rungs, rungs}}) when is_list(rungs),
    do: Enum.map_join(rungs, "\n", &print/1)

  def print({:rung, []}) do
    raise ArgumentError,
          "cannot print an empty rung: Logex.Parser drops these, " <>
            "so one here was built by hand"
  end

  def print({:rung, elements}) when is_list(elements),
    do: elements |> series([]) |> Enum.reverse() |> Enum.join(" ")

  def print(tree), do: unprintable!(tree)

  # The tokens newest first, each group's opened, its legs split and closed on the way.
  defp series([element | rest], acc), do: series(rest, token(element, acc))
  defp series([], acc), do: acc
  defp series(tail, _acc), do: unprintable!(tail)

  defp token({:name, _, name}, acc) when is_binary(name), do: [name | acc]

  defp token({:int_lit, _, value}, acc) when is_integer(value),
    do: [Integer.to_string(value) | acc]

  defp token({:int_lit, _, _value, spelling}, acc) when is_binary(spelling), do: [spelling | acc]

  # M5-10: a real literal as written too, a plain one as its float's plain text.
  defp token({:real_lit, _, value}, acc) when is_float(value), do: [Float.to_string(value) | acc]
  defp token({:real_lit, _, _value, spelling}, acc) when is_binary(spelling), do: [spelling | acc]

  defp token({:branches, []}, _acc) do
    raise ArgumentError,
          "cannot print a branch group with no legs: it would print as `( )`, " <>
            "which parses back as one empty leg and passes power"
  end

  defp token({:branches, [leg | legs]}, acc), do: legs(legs, series(leg, ["(" | acc]))
  defp token(element, _acc), do: unprintable!(element)

  defp legs([leg | legs], acc), do: legs(legs, series(leg, ["|" | acc]))
  defp legs([], acc), do: [")" | acc]
  defp legs(tail, _acc), do: unprintable!(tail)

  defp unprintable!(node),
    do:
      raise(
        ArgumentError,
        "cannot print #{inspect(node)}: not a tree Logex.Parser.parse/1 can produce"
      )
end
