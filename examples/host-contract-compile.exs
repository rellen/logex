# Wrong calls to Logex, Logex.Tag and Logex.Configuration. The script prints each message.
alias Logex.Configuration
alias Logex.Configuration.{Global, Instance, Task}

refused = fn label, call ->
  try do
    call.()
    IO.puts("#{label}: no error")
  rescue
    error in ArgumentError ->
      IO.puts("#{label}:\n  " <> String.replace(error.message, "\n", "\n  "))
  end
end

source = File.read!("motor.ld")

IO.puts("Logex:")
refused.("compile/2 with no name", fn -> Logex.compile(source, []) end)
refused.("compile/2 with an atom name", fn -> Logex.compile(source, name: :motor) end)
refused.("compile/2 with the name 2motor", fn -> Logex.compile(source, name: "2motor") end)
refused.("compile/2 with a charlist", fn -> Logex.compile(~c"xic a", name: "m") end)
refused.("compile/2 with the option file", fn -> Logex.compile(source, name: "m", file: "x") end)
refused.("compile/2 with types: [1]", fn -> Logex.compile(source, name: "m", types: [1]) end)
refused.("compile/2 with declared: [:x]", fn -> Logex.compile(source, name: "m", declared: [:x]) end)
refused.("compile_file/1 with a charlist", fn -> Logex.compile_file(~c"motor.ld") end)
refused.("compile_files/1 with a path", fn -> Logex.compile_files("motor.ld") end)
{:error, [diagnostic]} = Logex.compile_file("motor.txt")
IO.puts("compile_file/1 of motor.txt:\n  " <> Logex.Diagnostic.format(diagnostic))

IO.puts("\nLogex.Tag:")
IO.inspect(Logex.Tag.new!("count", :dint, :var_output))
refused.("new!/5 with the name 2x", fn -> Logex.Tag.new!("2x", :bool) end)
refused.("new!/5 with the name xic", fn -> Logex.Tag.new!("xic", :bool) end)
refused.("new!/5 with a bool at 5", fn -> Logex.Tag.new!("b", :bool, :var, 5) end)
refused.("new!/5 with a preset", fn -> Logex.Tag.new!("t1", Logex.FbType.ton(), :var, 5) end)
refused.("new!/5 with retain: 1", fn -> Logex.Tag.new!("c", :dint, :var, nil, retain: 1) end)

IO.puts("\nLogex.Configuration:")
{:ok, motor} = Logex.compile(source, name: "motor")
refused.("new!/1 with a map", fn -> Configuration.new!(%{name: "p"}) end)
refused.("Global.new!/3 with a bool at 5", fn -> Global.new!("estop", :bool, initial: 5) end)
refused.("Global.new!/3 with the option start", fn -> Global.new!("estop", :bool, start: 5) end)

refused.("new!/1 with 5 problems", fn ->
  Configuration.new!(
    name: "p",
    programs: [motor],
    tasks: [
      %Task{name: "fast", priority: 1.5, interval: 10},
      %Task{name: "slow", priority: -1, interval: 10}
    ],
    globals: [%Global{name: "estop", type: :bool, initial: 5}],
    instances: [%Instance{name: "m1", type: "motor", task: "fsat"}]
  )
end)

wrong = %Configuration{
  name: "p",
  programs: %{"motor" => motor},
  tasks: [%Task{name: "fast", priority: -1, interval: 10}],
  globals: [],
  instances: [],
  connections: []
}

refused.("check/1 with a map", fn -> Configuration.check(%{name: "p"}) end)
IO.puts("check/1 of a priority of -1:")
for d <- Configuration.check(wrong), do: IO.puts("  " <> Logex.Diagnostic.format(d))

refused.("check/1 of a priority of 1.5", fn ->
  Configuration.check(%{wrong | tasks: [%Task{name: "fast", priority: 1.5, interval: 10}]})
end)
