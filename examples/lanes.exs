{:ok, lanes} = Logex.compile_file("lanes.ld")

scan = fn state, label, inputs, ms ->
  state = Logex.Runtime.put_inputs(lanes, state, inputs)
  {outputs, state} = Logex.Runtime.scan(lanes, state, ms)
  counts = for c <- Tuple.to_list(state.env["lane_c"]), do: c["cv"]
  IO.puts("#{label}  #{inspect(outputs)}  counts #{inspect(counts)}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

box = fn state, lane ->
  eye = List.replace_at([0, 0, 0, 0], lane, 1)

  state
  |> scan.("box in lane #{lane}", %{"eye" => eye, "lane" => lane}, 10)
  |> scan.("40 ms later  ", %{}, 40)
  |> scan.("gone         ", %{"eye" => [0, 0, 0, 0]}, 10)
end

state =
  Logex.Runtime.instance(lanes)
  |> box.(2)
  |> box.(2)
  |> box.(1)
  |> box.(2)
  |> scan.("lane 4       ", %{"lane" => 4}, 10)

{:ok, slower} =
  "lanes.ld"
  |> File.read!()
  |> String.replace("xic eye[2] ton lane_t[2] 30", "xic eye[2] ton lane_t[2] 50")
  |> Logex.compile(name: "lanes", types: [elem(Logex.compile_file("gate.ld"), 1)])

{:ok, edit, _forecast} = Logex.Edit.accept(lanes, slower, state)
{_edit, _state, report} = Logex.Edit.test(edit, state)
IO.puts("edit: #{inspect(report)}")

{:ok, plant} =
  Logex.Configuration.compile(
    "plant",
    "task fast interval 10 priority 1\nprogram m1 lanes with fast\n  m1.eye[0] 0\n  m1.eye[1] 0\n  m1.eye[2] 1\n  m1.eye[3] 0\n  m1.lane 2",
    %{"lanes" => lanes}
  )

runtime =
  Enum.reduce([0, 10, 10, 10], Logex.Runtime.start(plant), fn ms, runtime ->
    {runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, ms, %{})
    runtime
  end)

IO.puts("m1.lane_t[2].acc #{Logex.Runtime.get!(runtime, "m1.lane_t[2].acc")}, " <>
  "m1.lane_c[2].cv #{Logex.Runtime.get!(runtime, "m1.lane_c[2].cv")}")

{:error, diagnostics} =
  Logex.compile(
    "var lane_t ton[4]\nvar lane_c ctu[4]\nvar i int\nvar on bool\n" <>
      "xic on ton lane_t[i] 30\nxic on ctu lane_c[1] 3\nxic on ctu lane_c[1] 5\n" <>
      "xic lane_t.dn ote on",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))
