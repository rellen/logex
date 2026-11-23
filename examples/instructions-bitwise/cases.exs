# cases.(first, cases) runs 1 scan of each case. A case is a rung and a map with the
# value of some inputs. Each other input is 0. The program of a case is the
# declarations of `tags.txt` and the rung. For each case, the script prints the number
# of the case and its rung. Then it prints the inputs, each output that the rung names
# with `ok` first, and each fault of the scan. `show.exs` gives the text of each value.
tags = File.read!("instructions-bitwise/tags.txt")
{show, _} = Code.eval_file("instructions-bitwise/show.exs")

value = fn
  {:array, type, _sizes}, list -> "[" <> Enum.map_join(list, ", ", &show.(type, &1)) <> "]"
  type, number -> show.(type, number)
end

pairs = fn
  [], _program ->
    "no input"

  list, program ->
    Enum.map_join(list, ", ", fn {name, number} ->
      "#{name} = #{value.(program.tags[name].type, number)}"
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
    named = Map.take(outputs, String.split(rung, [" ", "[", "."]))
    named = Enum.sort_by(named, fn {name, _value} -> {name != "ok", name} end)
    head = String.pad_leading("#{number}", 2) <> "  " <> rung
    ins = "      in     " <> pairs.(Enum.sort(inputs), program)
    outs = "      out    " <> pairs.(named, program)
    IO.puts(Enum.join([head, ins, outs | Enum.map(state.faults, fault)], "\n"))
  end
end
