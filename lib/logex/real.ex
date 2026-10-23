defmodule Logex.Real do
  @moduledoc false
  # M5-10 (docs/organisation.md §4.12, "Reals", decisions 150, 161 and 166): the one place
  # a real's value is made, read and spelled, so that every write into a `real` or an
  # `lreal`, a scan's, a host's, a device's, a force's and a declaration's, follows one
  # rule. A real is held as the BEAM float that is its value: an `lreal` any float, a
  # `real` one that a single holds exactly. The BEAM's floats are doubles and hold no
  # infinity and no NaN, the operations that would give one raising (verified on Elixir
  # 1.20.4 / OTP 28), so no value logex holds is one; nor is one −0.0 or a subnormal, each
  # written as 0.0 (decision 150).

  import Bitwise

  # The largest finite values, the smallest normal ones, and the least magnitude whose
  # nearest value of the type is infinite: a single's 2^128 − 2^104 rounded to even, half a
  # step past its largest, 2^128 − 2^103, and a double's 2^1024 − 2^970.
  @single_max 3.4028234663852886e38
  @single_min 1.1754943508222875e-38
  @single_past Integer.pow(2, 128) - Integer.pow(2, 103)
  @double_max 1.7976931348623157e308
  @double_min 2.2250738585072014e-308
  @double_past Integer.pow(2, 1024) - Integer.pow(2, 970)

  @doc false
  def max(:real), do: @single_max
  def max(:lreal), do: @double_max

  @doc false
  def min(:real), do: @single_min
  def min(:lreal), do: @double_min

  @doc false
  # Whether a number's nearest value of a real type is finite, decision 166's rule for a
  # value a device, a host or a force gives: 2^128 is past a `real`, and 3.4028235e38 is
  # not. A float is always within an `lreal`.
  def in_range?(:real, value) when is_float(value), do: abs(value) < @single_past * 1.0
  def in_range?(:real, value) when is_integer(value), do: abs(value) < @single_past
  def in_range?(:lreal, value) when is_float(value), do: true
  def in_range?(:lreal, value) when is_integer(value), do: abs(value) < @double_past
  def in_range?(_type, _value), do: false

  @doc false
  # Whether an integer is a value of a real type exactly, decision 147's rule for an
  # integer literal in a real slot: 16777216 is a `real`'s, and 16777217 is not.
  def exact?(type, value) when is_integer(value),
    do: in_range?(type, value) and trunc(nearest(type, value)) == value

  def exact?(_type, _value), do: false

  @doc false
  # The value a number takes in a real type, with whether it is the nearest one, the power
  # an instruction passes: rounded to the nearest, a tie to the even one, a `real` to a
  # single; past the type's largest finite value saturated there, the sign kept, with no
  # power; −0.0, and a value below the normal range once rounded, a subnormal, 0.0, with
  # power, as the conventional controller treats them (1756-RM018A p.882).
  def stored(type, value) do
    stored_in(type, value, in_range?(type, value))
  end

  defp stored_in(type, value, true), do: {true, nearest(type, value)}
  defp stored_in(type, value, false), do: {false, saturated(type, value)}

  defp saturated(type, value) when value > 0, do: max(type)
  defp saturated(type, _value), do: -max(type)

  @doc false
  # The nearest value of a real type to a number within its range, 0.0 for −0.0 and for a
  # subnormal.
  def nearest(:real, value) when is_float(value) do
    <<single::float-32>> = <<value::float-32>>
    normal(single, @single_min)
  end

  def nearest(:real, value) when is_integer(value), do: normal(single_of(value), @single_min)
  def nearest(:lreal, value) when is_float(value), do: normal(value, @double_min)
  def nearest(:lreal, value) when is_integer(value), do: normal(:erlang.float(value), @double_min)

  defp normal(value, min) when value > -min and value < min, do: 0.0
  defp normal(value, _min), do: value

  # An integer's nearest single, rounded once from the integer itself: through a double it
  # would round twice, and 2^60 + 2^36 + 1 come out at 2^60 where its nearest single is
  # 2^60 + 2^37. Up to 2^24 every integer is a single.
  defp single_of(value) when value > -16_777_216 and value < 16_777_216, do: value * 1.0
  defp single_of(value) when value < 0, do: -single_of(-value)

  defp single_of(value) do
    shift = bits(value, 0) - 24
    kept = value >>> shift
    rest = value - (kept <<< shift)
    half = 1 <<< (shift - 1)
    :erlang.float(rounded(kept, rest, half) <<< shift)
  end

  defp bits(0, n), do: n
  defp bits(value, n), do: bits(value >>> 1, n + 1)

  defp rounded(kept, rest, half) when rest > half, do: kept + 1
  defp rounded(kept, rest, half) when rest == half, do: kept + (kept &&& 1)
  defp rounded(kept, _rest, _half), do: kept

  @doc false
  # Whether a term is a value a state of the type may hold: a float the type holds exactly,
  # not −0.0, and no subnormal.
  def value?(:real, value) when is_float(value),
    do: abs(value) <= @single_max and nearest(:real, value) === value

  def value?(:lreal, value) when is_float(value), do: nearest(:lreal, value) === value
  def value?(_type, _value), do: false

  @doc false
  # A real rounded to the nearest integer, a tie to the even one (decision 148, IEC's Table
  # 22 footnote b), on the integer itself, never Elixir's round/1, which takes a tie away
  # from zero.
  def round_even(value) when is_float(value) do
    whole = trunc(value)
    even(whole, value - whole)
  end

  defp even(whole, part) when part > 0.5, do: whole + 1
  defp even(whole, part) when part < -0.5, do: whole - 1
  defp even(whole, part) when part == 0.5, do: whole + (whole &&& 1)
  defp even(whole, part) when part == -0.5, do: whole - (whole &&& 1)
  defp even(whole, _part), do: whole

  @doc false
  # The shortest text that reads back to a real's value, decision 156's spelling for the
  # forces file and a configuration file's `print/1`: an `lreal`'s is `Float.to_string/1`'s,
  # the shortest that reads back to the double; a `real`'s the shortest decimal whose
  # nearest single is the value, which `Float.to_string/1` does not give, since it spells
  # the double that holds the single, 0.1 forced into a `real` giving 0.10000000149011612.
  def spelled(:lreal, value), do: Float.to_string(value)
  def spelled(:real, value), do: shortest(value, 1)

  defp shortest(value, digits) when digits <= 9 do
    {read, ""} = Float.parse(:erlang.float_to_binary(value, [{:scientific, digits - 1}]))
    shorter(nearest(:real, read) === value, read, value, digits)
  end

  defp shortest(value, _digits), do: Float.to_string(value)

  defp shorter(true, read, _value, _digits), do: Float.to_string(read)
  defp shorter(false, _read, value, digits), do: shortest(value, digits + 1)

  @doc false
  # A real's value read from the text `spelled/2` gives, or `:error`: exactly that text, so
  # that a file read back holds what was written, and no other.
  def read(type, text) when is_binary(text), do: read_float(Float.parse(text), type, text)

  defp read_float({value, ""}, type, text) when is_float(value),
    do: written(spelled_as?(type, value, text), type, value)

  defp read_float(_other, _type, _text), do: :error

  defp spelled_as?(type, value, text),
    do: in_range?(type, value) and spelled(type, nearest(type, value)) == text

  defp written(true, type, value), do: {:ok, nearest(type, value)}
  defp written(false, _type, _value), do: :error
end
