{:ok, drive} = Logex.compile_file("drive.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(drive, state, inputs)
  {outputs, state} = Logex.Runtime.scan(drive, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

state =
  Logex.Runtime.instance(drive)
  |> scan.("a register of 1200, a level of 100", %{"hz" => 1200, "level" => 100})
  |> scan.("the register's top, a level of 129 ", %{"hz" => 65_535, "level" => 129})
  |> scan.("a level of -1                      ", %{"level" => -1})

try do
  Logex.Runtime.put_inputs(drive, state, %{"hz" => 65_536})
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

{:error, diagnostics} =
  Logex.compile(
    "var speed dint\nvar_output hz uint\nvar_output flag bool\n" <>
      "move speed hz\nmove 70000 hz\nmove flag speed\nadd speed 1 hz\nneg speed hz\n" <>
      "lt hz 70000 ote flag",
    name: "back"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))
