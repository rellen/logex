# cases.(first, cases) runs 1 scan of each case. A case is a rung and a map with the
# value of some inputs. Each other input is 0. The program of a case is the
# declarations of `tags.txt` and the rung. For each case, the script prints the number
# of the case and its rung. Then it prints the inputs, each output that the rung names
# with `ok` first, and each fault of the scan.
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

value = fn
  list when is_list(list) -> inspect(list)
  number -> "#{number}"
end

pairs = fn
  [] -> "no input"
  list -> Enum.map_join(list, ", ", fn {name, number} -> "#{name} = #{value.(number)}" end)
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
    lines = [head, "      in     " <> pairs.(Enum.sort(inputs)), "      out    " <> pairs.(named)]
    IO.puts(Enum.join(lines ++ Enum.map(state.faults, fault), "\n"))
  end
end
