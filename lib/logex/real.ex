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
  # Whether a number within a real type's range is flushed to 0.0 when it is written there,
  # nonzero and nearer 0.0 than the type's smallest normal value once rounded, `1.0e-40` in
  # a `real`: decision 216's rule for a literal, which is refused, where a device's, a
  # host's and a force's value is written as 0.0 (decision 166).
  def flushed?(type, value), do: value != 0 and nearest(type, value) == 0.0

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
  # subnormal. A float past a single's range has no single, the BEAM's 32-bit encoding
  # giving infinity's bits, which no pattern reads back, so every caller holds a `real`'s
  # value to in_range?/2 first.
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
    shorter(in_range?(:real, read) and nearest(:real, read) === value, read, value, digits)
  end

  defp shortest(value, _digits), do: Float.to_string(value)

  defp shorter(true, read, _value, _digits), do: Float.to_string(read)
  defp shorter(false, _read, value, digits), do: shortest(value, digits + 1)

  @doc false
  # Decision 219: what a real literal written `text`, of value `value`, is held as in a real
  # type, where its digits are more than the type keeps: `{:rounded, held}`, the shortest
  # text that reads back to the value it is held as, or `:kept`. It is warned where the
  # number the text writes is neither the value held nor the number that text writes, so
  # `16777217.0` in a `real` is held as 16777216.0 and warned, and `0.1` and `37.1` are
  # not, each the shortest text of the single nearest it; nor is a text that writes the
  # value held exactly, `0.100000001490116119384765625` in a `real`, which loses nothing.
  def held_as(type, value, text) do
    rounded_in(in_range?(type, value), type, value, text)
  end

  defp rounded_in(false, _type, _value, _text), do: :kept

  defp rounded_in(true, type, value, text),
    do: spelled_so(spelled(type, nearest(type, value)) == text, type, value, text)

  # A literal written as the shortest text of the value it is held as keeps every digit,
  # `0.1` in a `real`, with no fraction computed.
  defp spelled_so(true, _type, _value, _text), do: :kept

  defp spelled_so(false, type, value, text),
    do: written(Logex.Lexer.tokenize(text), type, value, text)

  # Only a text that lexes as one real literal is read, so a hand-edited body's spelling,
  # which `Logex.Compiler.lowered?/1` refuses, is passed over rather than raising.
  defp written({:ok, [{:real_lit, _at, _value}], _end_line}, type, value, text),
    do: held_in(type, value, text)

  defp written({:ok, [{:real_lit, _at, _value, _spelling}], _end_line}, type, value, text),
    do: held_in(type, value, text)

  defp written(_other, _type, _value, _text), do: :kept

  defp held_in(type, value, text) do
    held = nearest(type, value)
    held_text = spelled(type, held)
    written = decimal(text)
    lost(written != binary_value(held) and written != decimal(held_text), held_text)
  end

  defp lost(true, held_text), do: {:rounded, held_text}
  defp lost(false, _held_text), do: :kept

  # The number a real literal's text writes, exactly, as a fraction of two integers in
  # lowest terms, `16777217.0` 16777217/1 and `0.1` 1/10: its digits with the `_`s left
  # out, the sign and the exponent applied.
  defp decimal(text) do
    plain = IO.iodata_to_binary(:binary.split(text, "_", [:global]))
    {sign, unsigned} = signed(plain)
    [mantissa | power] = :binary.split(unsigned, ["e", "E"])
    [whole, fraction] = :binary.split(mantissa, ".")
    digits = String.to_integer(whole <> fraction)
    scaled(sign * digits, exponent(power) - byte_size(fraction))
  end

  defp signed(<<?-, rest::binary>>), do: {-1, rest}
  defp signed(text), do: {1, text}

  defp exponent([]), do: 0
  defp exponent([power]), do: String.to_integer(power)

  defp scaled(digits, power) when power >= 0, do: lowest(digits * Integer.pow(10, power), 1)
  defp scaled(digits, power), do: lowest(digits, Integer.pow(10, -power))

  # A float's value, exactly, as the same fraction: its 53-bit significand over a power of
  # two, a subnormal's and 0.0's too.
  defp binary_value(value) do
    <<sign::1, biased::11, fraction::52>> = <<value::float>>
    significand(1 - 2 * sign, biased, fraction)
  end

  defp significand(sign, 0, fraction), do: power_of_two(sign * fraction, -1074)

  defp significand(sign, biased, fraction),
    do: power_of_two(sign * ((1 <<< 52) + fraction), biased - 1075)

  defp power_of_two(n, power) when power >= 0, do: lowest(n <<< power, 1)
  defp power_of_two(n, power), do: lowest(n, 1 <<< -power)

  defp lowest(0, _denominator), do: {0, 1}

  defp lowest(numerator, denominator) do
    common = Integer.gcd(numerator, denominator)
    {div(numerator, common), div(denominator, common)}
  end
end
