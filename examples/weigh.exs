{:ok, weigh} = Logex.compile_file("weigh.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(weigh, state, inputs)
  {outputs, state} = Logex.Runtime.scan(weigh, state)
  IO.puts("#{label}  #{inspect(outputs)}  weights #{inspect(Tuple.to_list(state.env["weights"]))}")
  state
end

state =
  Enum.reduce([620, 410, 730, 550, 90], Logex.Runtime.instance(weigh), fn load, state ->
    state
    |> scan.("pick #{load}", %{"load" => load, "pick" => 1})
    |> scan.("release ", %{"pick" => 0})
  end)

IO.inspect(state.env["grid"], label: "grid")

{:error, diagnostics} =
  Logex.compile(
    "var weights int[8]\nvar grid int[4,8]\nvar slot bool\nvar x int\n" <>
      "var cells int[2,2,2,2]\nvar short int[3] 1 2\n" <>
      "move weights[8] x\nmove grid[1] x\nmove weights[slot] x\nmove weights x",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))

{:ok, buffer} = Logex.compile("var_input w int[3]\nvar_output s int\nmove w[1] s", name: "buffer")

try do
  Logex.Runtime.put_inputs(buffer, Logex.Runtime.instance(buffer), %{"w" => [1, 2]})
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

state = Logex.Runtime.put_inputs(buffer, Logex.Runtime.instance(buffer), %{"w" => [1, 2, 3]})
state = Logex.Runtime.put_inputs(buffer, state, %{"w[1]" => 20})
IO.inspect(state.env["w"], label: "w[1] set alone")

for inputs <- [%{"w[3]" => 1}, %{"w" => [1, 2, 3], "w[1]" => 5}] do
  try do
    Logex.Runtime.put_inputs(buffer, state, inputs)
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end

{:ok, lamp} =
  Logex.compile(
    "var_input faults word[4]\nvar_input n int\nvar_output lamp bool\nvar_output any bool\n" <>
      "xic faults[2].3 ote lamp\nxic faults[2].[n] ote any",
    name: "lamp"
  )

{outputs, _} =
  Logex.Runtime.call(
    lamp,
    Logex.Runtime.instance(lamp),
    %{"faults" => [0, 0, 0b1000, 0], "n" => 3},
    %Logex.Scan{now: 0, first: true}
  )

IO.inspect(outputs, label: "faults[2].3 and faults[2].[n]")

