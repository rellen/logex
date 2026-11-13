{:ok, fill} = Logex.compile_file("fill.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(fill, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fill, state, 100)
  IO.puts("#{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.puts("    #{inspect(fault)}")
  state
end

Logex.Runtime.instance(fill)
|> scan.("400 in, no minutes yet", %{"flow" => 400, "setpoint" => 1000})
|> scan.("a minute in           ", %{"minutes" => 1})
|> scan.("past the setpoint     ", %{"minutes" => 2})
|> scan.("a meter gone wild     ", %{"flow" => 2_147_483_000})
|> scan.("still wild            ", %{})
|> scan.("a backflow of 5       ", %{"flow" => -5})

config =
  Logex.Configuration.new!(
    name: "plant",
    programs: [fill],
    tasks: [%Logex.Configuration.Task{name: "fill", interval: 100, priority: 1}],
    globals: [
      %Logex.Configuration.Global{name: "flow", type: :dint, at: "meter.i.0"},
      %Logex.Configuration.Global{name: "valve", type: :bool, at: "panel.q.0"}
    ],
    instances: [%Logex.Configuration.Instance{name: "f1", type: "fill", task: "fill"}],
    connections: [
      %Logex.Configuration.Connection{instance: "f1", member: "flow", to: "flow"},
      %Logex.Configuration.Connection{instance: "f1", member: "setpoint", to: 1000},
      %Logex.Configuration.Connection{instance: "f1", member: "minutes", to: 0},
      %Logex.Configuration.Connection{instance: "f1", member: "valve", to: "valve"}
    ]
  )

{_rt, outputs, events} = Logex.Runtime.cycle(Logex.Runtime.start(config), 0, %{"flow" => 400})
IO.puts("a cycle: #{inspect(outputs)}")
for event <- events, do: IO.puts("    #{inspect(event)}")

{:error, [diagnostic]} =
  Logex.compile("var_input total dint\nvar_output rate dint\ndiv total 0 rate", name: "rate")

IO.puts(Logex.Diagnostic.format(diagnostic))

{:error, [diagnostic]} = Logex.compile("var_output x dint\nmove 5-3 x", name: "minus")
IO.puts(Logex.Diagnostic.format(diagnostic))
