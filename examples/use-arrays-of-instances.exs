{:ok, conveyors} = Logex.compile_file("use-arrays-of-instances/conveyors.ld")

scan = fn state, number, inputs, ms ->
  state = Logex.Runtime.put_inputs(conveyors, state, inputs)
  {outputs, state} = Logex.Runtime.scan(conveyors, state, ms)

  values =
    Enum.map_join(["motor", "view_ok", "count", "jammed"], "  ", fn name ->
      "#{name} #{inspect(outputs[name])}"
    end)

  IO.puts("#{number}  #{values}  faults #{length(state.faults)}")
  state
end

Logex.Runtime.instance(conveyors)
|> scan.(1, %{"start" => 1, "stop" => 0, "eye" => [0, 0, 0], "view" => 0}, 0)
|> scan.(2, %{"start" => 0, "eye[0]" => 1}, 500)
|> scan.(3, %{"eye[0]" => 0}, 500)
|> scan.(4, %{"eye[0]" => 1}, 500)
|> scan.(5, %{"eye[0]" => 0, "view" => 2}, 500)
|> scan.(6, %{"eye[2]" => 1}, 1000)
|> scan.(7, %{}, 1000)
|> scan.(8, %{}, 1000)
|> scan.(9, %{"view" => 3}, 100)
|> scan.(10, %{"eye[2]" => 0, "view" => 2, "start" => 1}, 100)
