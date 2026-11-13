{:ok, status} = Logex.compile_file("status.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(status, state, inputs)
  {outputs, state} = Logex.Runtime.scan(status, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

state =
  Logex.Runtime.instance(status)
  |> scan.("at speed, shifted by 4    ", %{"status" => 0x0008, "shift" => 4})
  |> scan.("16#fff7, shifted by -1    ", %{"status" => 0xFFF7, "shift" => -1})
  |> scan.("16#8000, shifted by 16    ", %{"status" => 0x8000, "shift" => 16})

try do
  Logex.Runtime.put_inputs(status, state, %{"status" => 65_536})
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

{:error, diagnostics} =
  Logex.compile(
    "var status word\nvar code int\nvar lamp bool\n" <>
      "add status 1 status\nand status 16#00ff code\neq status code ote lamp\n" <>
      "xic status.16 ote lamp\nxic lamp.0 ote lamp\nshl status -1 status\n" <>
        "and lamp code code",
    name: "wrong"
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))
