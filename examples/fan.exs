{:ok, fan} = Logex.compile_file("fan.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(fan, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fan, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

state =
  Logex.Runtime.instance(fan)
  |> scan.("0.1 Hz      ", %{"hz" => 0.1})
  |> scan.("12.5 Hz     ", %{"hz" => 12.5})
  |> scan.("-0.25 Hz    ", %{"hz" => -0.25})
  |> scan.("600 Hz      ", %{"hz" => 600})
  |> scan.("16777217 Hz ", %{"hz" => 16_777_217})

try do
  Logex.Runtime.put_inputs(fan, state, %{"hz" => Integer.pow(2, 128)})
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

{:error, [lexed]} = Logex.compile("var x real\nmove 1.5e+3 x", name: "lexed")
IO.puts(Logex.Diagnostic.format(lexed))

{:error, diagnostics} =
  Logex.compile(
    "var speed real\nvar count dint\nvar rpm int\nvar on bool\nvar big lreal\n" <>
      "move 16777217 speed\nmove speed rpm\ngt speed count ote on\ndiv speed 0.0 speed\n" <>
      "mod speed 2 rpm\nsqrt -4.0 speed\nsqrt speed rpm\nxic speed.3 ote on\nmove 1.0e-40 speed\n" <>
      "move 1.0e-310 big\nmove 1.0e-400 big\ngt 1.0e-310 0.0 ote on",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))

{:ok, rounded} =
  Logex.compile(
    "var_output speed real\nvar_output set_point real 16777217.0\nmove 16777217.0 speed\n" <>
      "move 37.1 speed\nmove 37.1 set_point",
    name: "rounded"
  )

for warning <- rounded.warnings, do: IO.puts(Logex.Diagnostic.format(warning))
