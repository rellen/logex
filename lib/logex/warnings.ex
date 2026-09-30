defmodule Logex.Warnings do
  @moduledoc """
  What compiles but is probably a mistake (M1-5), as `%Logex.Diagnostic{severity:
  :warning}` in line order. A program that does not compile gets none.

  - a tag declared but used by no rung;
  - a `var_output` a rung reads but none writes: it stays at its initial value;
  - a second `ote` on one tag: only the last one in the scan decides it;
  - an `ons` storage bit that another instruction writes (M1-6): the one-shot then fires
    on the wrong scans. A second `ons` on it is an error (`Logex.Compiler`).

  A tag declared from Elixir (`Logex.Tag.new!/4`) has no line and is never warned about.
  """

  alias Logex.{Compiler, Diagnostic, Tag}

  @doc "The warnings for lowered `rungs` checked against the tag table `tags`."
  def of(rungs, tags) do
    signatures = Map.new(Compiler.instructions(), fn {_word, {symbol, sig}} -> {symbol, sig} end)
    uses = Enum.flat_map(rungs, fn {:rung, elements} -> uses(elements, signatures) end)
    # Grouped once, so the pass stays linear in the program's size.
    accesses =
      Enum.group_by(uses, fn {_, name, _, _} -> name end, fn {access, _, _, _} -> access end)

    # M1-6: each `ons` storage bit, to the line of the one `ons` that writes it. The
    # compiler refuses a second `ons` on one bit, so a program that compiles has one.
    owners = Map.new(for {:write, name, line, :ons} <- uses, do: {name, line})

    tags
    |> Map.values()
    |> Enum.filter(& &1.line)
    |> Enum.flat_map(&about(&1, Map.get(accesses, &1.name, [])))
    |> Kernel.++(second_otes(uses, tags, owners))
    |> Kernel.++(storage_writes(uses, tags, owners))
    |> Enum.sort_by(& &1.line)
  end

  # Every tag operand, in rung order, as {access, name, line, symbol}.
  defp uses(elements, signatures), do: Enum.flat_map(elements, &element(&1, signatures))

  defp element({:branches, legs}, signatures), do: Enum.flat_map(legs, &uses(&1, signatures))

  defp element({symbol, line, operands}, signatures),
    do:
      for(
        {{access, _type}, {:name, _, name}} <- Enum.zip(Map.fetch!(signatures, symbol), operands),
        do: {access, name, line, symbol}
      )

  defp about(%Tag{} = tag, []),
    do: [warning(tag.line, "`#{tag.name}` is declared but no rung uses it")]

  defp about(%Tag{section: :var_output} = tag, accesses), do: unwritten(:write in accesses, tag)
  defp about(_tag, _accesses), do: []

  defp unwritten(true, _tag), do: []

  defp unwritten(false, tag),
    do: [
      warning(
        tag.line,
        "`#{tag.name}` is a var_output, but no rung writes it: it stays at #{start(tag.initial)}"
      )
    ]

  defp start(nil), do: 0
  defp start(initial), do: initial

  # Each `ote` after the first on a tag declared in source cites the first. An `ons`
  # storage bit is left to storage_writes/3, which warns about every `ote` on it: the `ons`
  # writes it too, so the last `ote` need not be what decides it, and one instruction gets
  # one warning.
  defp second_otes(uses, tags, owners) do
    uses
    |> Enum.filter(fn {_access, name, _line, symbol} ->
      symbol == :ote and from_source?(tags, name) and not Map.has_key?(owners, name)
    end)
    |> Enum.group_by(fn {_access, name, _line, _symbol} -> name end, fn {_, _, line, _} ->
      line
    end)
    |> Enum.flat_map(fn {name, [first | later]} ->
      Enum.map(later, &second_ote(name, first, &1))
    end)
  end

  # M1-6: every other write to an `ons` storage bit declared in source, before or after
  # the `ons` in the scan, is warned about at its own line, citing the `ons`. The uses are
  # walked in rung order, not grouped into a map, whose order stops being sorted past 32
  # keys.
  defp storage_writes(uses, tags, owners) do
    for {:write, name, line, symbol} <- uses,
        symbol != :ons,
        {:ok, first} <- [Map.fetch(owners, name)],
        from_source?(tags, name),
        do: storage_write(symbol, name, first, line)
  end

  defp storage_write(symbol, name, first, line),
    do:
      warning(
        line,
        "`#{symbol}` writes `#{name}`, the storage bit of the `ons` #{where(first, line)}: " <>
          "the one-shot then fires on the wrong scans"
      )

  defp where(line, line), do: "in this rung"
  defp where(first, _line), do: "on line #{first}"

  defp from_source?(tags, name),
    do: match?(%Tag{line: line} when line != nil, Map.get(tags, name))

  defp second_ote(name, line, line),
    do: warning(line, "`#{name}` already has an `ote` in this rung: #{last()}")

  defp second_ote(name, first, line),
    do: warning(line, "`#{name}` already has an `ote` on line #{first}: #{last()}")

  defp last, do: "the last one in the scan decides it"

  defp warning(line, message),
    do: %Diagnostic{stage: :validate, severity: :warning, line: line, message: message}
end
