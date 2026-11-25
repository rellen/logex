# For each type word, the script declares 1 instance `x` and makes a state of the program
# with Logex.Runtime.instance/1. It prints each member that the state holds for `x`, with
# its first value. The members of a member that is an instance have its name before them.
{:ok, fan_relay} = Logex.compile_file("function-blocks/fan_relay.ld")
words = ~w(ton rto ton_ltime ctu ctd ctud ctu_int fan_relay)

flat = fn
  members, prefix, flat when is_map(members) ->
    Enum.flat_map(members, fn {name, value} -> flat.(value, prefix <> name <> ".", flat) end)

  value, prefix, _flat ->
    [String.trim_trailing(prefix, ".") <> "=#{value}"]
end

for word <- words do
  {:ok, program} = Logex.compile("var x #{word}", name: "members", types: [fan_relay])
  members = Logex.Runtime.instance(program).env["x"]
  IO.puts(String.pad_trailing(word, 10) <> Enum.join(flat.(members, "", flat), " "))
end
