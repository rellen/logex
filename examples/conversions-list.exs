# The script tries each mnemonic `<from>_to_<into>` and `<from>_trunc_<into>` for each
# pair of 2 different type words. It compiles a program with 1 rung of the mnemonic.
# The mnemonic is a conversion if the program compiles. The script prints the
# conversions in 4 groups, and for each type the types that it converts into.
integers = ["sint", "int", "dint", "lint", "usint", "uint", "udint", "ulint"]
bit_strings = ["byte", "word", "dword", "lword"]
reals = ["real", "lreal"]
types = ["bool" | integers ++ bit_strings ++ reals]

kind = fn type -> {type in reals, type in bit_strings} end

group = fn
  "trunc", _from, _into -> "truncations"
  "to", {true, _}, _into -> "real conversions"
  "to", _from, {true, _} -> "real conversions"
  "to", {_, true}, _into -> "bit string conversions"
  "to", _from, {_, true} -> "bit string conversions"
  "to", _from, _into -> "integer conversions"
end

conversion? = fn from, form, into ->
  text = "var_input a #{from}\nvar_output d #{into}\n#{from}_#{form}_#{into} a d\n"
  match?({:ok, _}, Logex.compile(text, name: "list"))
end

found =
  for form <- ["to", "trunc"],
      from <- types,
      into <- types,
      from != into,
      conversion?.(from, form, into),
      do: {group.(form, kind.(from), kind.(into)), from, into}

for name <- ["integer conversions", "bit string conversions", "real conversions", "truncations"] do
  pairs = for {^name, from, into} <- found, do: {from, into}
  IO.puts("#{name}: #{length(pairs)}")

  for from <- types, intos = for({^from, into} <- pairs, do: into), intos != [] do
    IO.puts("  " <> String.pad_trailing(from, 6) <> " into " <> Enum.join(intos, " "))
  end
end

IO.puts("all conversions: #{length(found)}")
