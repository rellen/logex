defmodule Logex.Array do
  @moduledoc false
  # M5-11 (decision 151; docs/organisation.md §4.12, "Arrays"): an array of an elementary
  # type, of one to three dimensions, each a count of elements from 0, Logix's form
  # (1756-PM004L pp.34-36), the one place its shape and its values are read and made.
  # Internal: its callers have checked their arguments.
  #
  # Its type is `{:array, type, dims}`, `type` an elementary type of
  # `Logex.Declarations.table/0` and `dims` a list of one to three counts, each 1 or more,
  # `[8]`, `[4, 8]` or `[2, 3, 4]`, with no more than `max_elements/0` elements in all. Its
  # elements have one order, the rightmost subscript varying fastest (PM004L p.35), which an
  # initial list follows. Its value in a state is a tuple, and for more dimensions a tuple
  # of tuples, `{{0, 0}, {0, 0}}` for an `int[2,2]` (§4.12's routine choice, the spike's
  # measure): read in constant time and copied on a write, a write copying the tuple of
  # each dimension it passes through. A host gives and is given lists, a list of lists for
  # more dimensions, in the same shape.

  alias Logex.Declarations

  # §4.12: "a proposal: 1 to 65,536 elements in all", measured by M5-11's spike: a read is
  # one `elem/2` a dimension whatever the size, and a write copies the tuple of each
  # dimension it passes through, about 1 ns an element on the machine measured, so a write
  # into an `int[65536]` costs some 0.2 ms and into an `int[256,256]` some 3 µs
  # (provisional).
  @max_elements 65_536
  @max_dimensions 3

  @doc false
  @shown_lines 10

  def max_elements, do: @max_elements

  @doc false
  def max_dimensions, do: @max_dimensions

  @doc false
  defguard is_array(type)
           when is_tuple(type) and tuple_size(type) == 3 and elem(type, 0) == :array

  @doc false
  # The number of elements of an array of `dims`.
  def size(dims), do: Enum.reduce(dims, 1, &(&1 * &2))

  @doc false
  # An array's type as a message names it: `an array of 8 ints`, `an array of 4 by 8 reals`.
  def a_type({:array, type, dims}),
    do: "an array of #{Enum.join(dims, " by ")} #{Declarations.word(type)}#{plural(size(dims))}"

  # An array of one element holds one, `an array of 1 int` (M5-11's review).
  defp plural(1), do: ""
  defp plural(_size), do: "s"

  @doc false
  # An array's first value, the one rule for it (`Logex.Program.initial_env/1`'s, a block's
  # member's and an edit's): each element at its type's zero, or at its initial list's
  # value in the elements' order, a real's held at its nearest (decision 150).
  def started({:array, type, dims}, nil), do: filled(Declarations.zero(type), dims)

  def started({:array, type, dims}, values) when is_list(values),
    do: from_flat(Enum.map(values, &element(type, &1)), dims)

  # Read when called, not when this module compiles, since `Logex.Declarations` imports
  # `is_array/1` from here.
  defp element(type, value), do: element(type in Declarations.reals(), type, value)

  defp element(true, type, value), do: Logex.Real.nearest(type, value)
  defp element(false, _type, value), do: value

  @doc false
  # An array's declared values in the elements' order, its type's zero for each where it
  # declares none, as an edit compares two (decision 157).
  def declared({:array, type, dims}, nil), do: List.duplicate(Declarations.zero(type), size(dims))
  def declared({:array, _type, _dims}, values), do: values

  @doc false
  # The value of an array whose every element is `value`.
  def filled(value, [count]), do: :erlang.make_tuple(count, value)
  def filled(value, [count | dims]), do: :erlang.make_tuple(count, filled(value, dims))

  @doc false
  # An array's value from its elements in the elements' order, a flat list of `size(dims)`.
  def from_flat(values, dims) do
    {value, []} = flat(values, dims)
    value
  end

  defp flat(values, [count]) do
    {row, rest} = Enum.split(values, count)
    {List.to_tuple(row), rest}
  end

  defp flat(values, [count | dims]) do
    {rows, rest} =
      Enum.map_reduce(1..count//1, values, fn _row, values -> flat(values, dims) end)

    {List.to_tuple(rows), rest}
  end

  @doc false
  # An array's elements in the elements' order, a flat list.
  def to_flat(value, [_count]), do: Tuple.to_list(value)

  def to_flat(value, [_count | dims]),
    do: Enum.flat_map(Tuple.to_list(value), &to_flat(&1, dims))

  @doc false
  # An array's value as a host is given it, a list, a list of lists for more dimensions.
  def to_list(value, [_count]), do: Tuple.to_list(value)
  def to_list(value, [_count | dims]), do: Enum.map(Tuple.to_list(value), &to_list(&1, dims))

  @doc false
  # An array's value from a host's list of `dims`, each element taken by `each`.
  def from_list(list, [_count], each), do: List.to_tuple(Enum.map(list, each))

  def from_list(list, [_count | dims], each),
    do: List.to_tuple(Enum.map(list, &from_list(&1, dims, each)))

  @doc false
  # The element at `index`, a list of subscripts, one a dimension.
  def fetch(value, [i]), do: elem(value, i)
  def fetch(value, [i | index]), do: fetch(elem(value, i), index)

  @doc false
  # The array with the element at `index` replaced by `element`.
  def put(value, [i], element), do: put_elem(value, i, element)

  def put(value, [i | index], element),
    do: put_elem(value, i, put(elem(value, i), index, element))

  @doc false
  # Every index of an array of `dims`, in the elements' order.
  def indexes([count]), do: for(i <- 0..(count - 1)//1, do: [i])

  def indexes([count | dims]),
    do: for(i <- 0..(count - 1)//1, rest <- indexes(dims), do: [i | rest])

  @doc false
  # The lines a message gives for an array's elements, at most the first 10, then one line
  # that counts the rest, `more.(count)` (provisional): an array of 65,536 elements every one
  # outside its type would otherwise give a message of megabytes.
  def capped(lines, more), do: capped_at(Enum.split(lines, @shown_lines), more)

  defp capped_at({shown, []}, _more), do: shown
  defp capped_at({shown, rest}, more), do: shown ++ [more.(length(rest))]

  @doc false
  # An element's name, by its subscripts' values, `grid[1,7]`: how the walks, the warnings,
  # an edit and a block list name it (decision 213's rule for a bit, by value).
  def name(array, index), do: "#{array}[#{Enum.join(index, ",")}]"

  @doc false
  # A name with subscripts split into its array's name and each subscript as written,
  # `{"grid", ["1", "7"]}` for `grid[1,7]`, or nil for a name with none. The lexer took
  # the name only where its brackets close one to many subscripts with no space.
  def split(name), do: split_at(:binary.split(name, "["))

  defp split_at([array, bracketed]),
    do:
      {array, :binary.split(binary_part(bracketed, 0, byte_size(bracketed) - 1), ",", [:global])}

  defp split_at([_name]), do: nil

  @doc false
  # A subscript as written: `{:literal, n}`, the number a literal spells, `16#a` 10, or
  # `{:tag, name}`, a tag's name, whose value a scan reads (M5-12, decision 152).
  def subscript(<<d, _::binary>> = text) when d in ?0..?9 or d == ?-,
    do: {:literal, literal(Logex.Lexer.tokenize(text))}

  def subscript(text), do: {:tag, text}

  defp literal({:ok, [literal], _line}), do: elem(literal, 2)

  @doc false
  # Whether `value` is an array of `dims` as a state holds one, a tuple of tuples of the
  # right sizes, its every element passing `each`.
  def held?(value, [count], each) when is_tuple(value) and tuple_size(value) == count,
    do: all?(value, count, each)

  def held?(value, [count | dims], each) when is_tuple(value) and tuple_size(value) == count,
    do: all?(value, count, &held?(&1, dims, each))

  def held?(_value, _dims, _each), do: false

  defp all?(_value, 0, _each), do: true
  defp all?(value, i, each), do: each.(elem(value, i - 1)) and all?(value, i - 1, each)

  @doc false
  # Whether `list` is a host's list of `dims`, its every element passing `each`.
  def listed?(list, [count], each) when is_list(list),
    do: proper_length(list, 0) == count and Enum.all?(list, each)

  def listed?(list, [count | dims], each) when is_list(list),
    do: proper_length(list, 0) == count and Enum.all?(list, &listed?(&1, dims, each))

  def listed?(_list, _dims, _each), do: false

  defp proper_length([], n), do: n
  defp proper_length([_ | rest], n), do: proper_length(rest, n + 1)
  defp proper_length(_improper, _n), do: -1
end
