# cases.(first, cases) runs 1 scan of each case. A case is a rung and a map with the
# value of some inputs. Each other input is 0. The program of a case is the
# declarations of `tags.txt` and the rung. For each case, the script prints the number
# of the case and its rung. Then it prints the inputs, each output that the rung names
# with `ok` first, and each fault of the scan. It prints the value of a bit string tag
# as a based literal of 16, with a digit for each 4 bits.
tags = File.read!("conversions/tags.txt")
digits = %{byte: 2, word: 4, dword: 8, lword: 16}

value = fn
  list, _type when is_list(list) ->
    inspect(list)

  number, type when is_map_key(digits, type) ->
    text = String.downcase(Integer.to_string(number, 16))
    "16#" <> String.pad_leading(text, digits[type], "0")

  number, _type ->
    "#{number}"
end

pairs = fn
  [], _program ->
    "no input"

  list, program ->
    Enum.map_join(list, ", ", fn {name, number} ->
      "#{name} = #{value.(number, program.tags[name].type)}"
    end)
end

fault = fn fault ->
  "      fault  #{fault.severity}, #{inspect(fault.kind)}, read #{inspect(fault.read)}"
end

fn first, cases ->
  for {{rung, inputs}, number} <- Enum.with_index(cases, first) do
    {:ok, program} = Logex.compile(tags <> rung, name: "case")
    state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), inputs)
    {outputs, state} = Logex.Runtime.scan(program, state)
    named = Map.take(outputs, String.split(rung, [" ", "["]))
    named = Enum.sort_by(named, fn {name, _value} -> {name != "ok", name} end)
    head = String.pad_leading("#{number}", 2) <> "  " <> rung
    inputs = Enum.sort(inputs)

    lines = [
      head,
      "      in     " <> pairs.(inputs, program),
      "      out    " <> pairs.(named, program)
    ]

    IO.puts(Enum.join(lines ++ Enum.map(state.faults, fault), "\n"))
  end
end
