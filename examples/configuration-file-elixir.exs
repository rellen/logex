# The script builds the configuration of line_1.logex from Elixir data. It compares each
# list of items with the list that the file gives, with no line numbers. Then it
# prints the text of the configuration.
alias Logex.Configuration
alias Logex.Configuration.{Connection, Global, Instance, Task, Text}

programs =
  for name <- ~w(belt box_count fan_control stop_record) do
    {:ok, program} = Logex.compile_file("configuration-file/#{name}.ld")
    program
  end

wire = fn instance, pairs ->
  for {member, to} <- pairs, do: %Connection{instance: instance, member: member, to: to}
end

plant =
  Configuration.new!(
    name: "line_1",
    programs: programs,
    tasks: [
      %Task{name: "fast", interval: 10, priority: 1, watchdog: 50},
      %Task{name: "on_stop", single: "estop", priority: 0},
      %Task{name: "main", continuous: true, watchdog: 200}
    ],
    globals: [
      Global.new!("estop", :bool, at: "panel.i.7"),
      Global.new!("pb_start", :bool, at: "panel.i.0"),
      Global.new!("eye", :bool, at: "panel.i.2"),
      Global.new!("motor_k", :bool, at: "panel.q.0"),
      Global.new!("fan_k", {:array, :bool, [2]}, at: "panel.q.1"),
      Global.new!("temps", {:array, :real, [2]}, at: "card.i.0"),
      Global.new!("limits", {:array, :real, [2]}, initial: [40.0, 45.0]),
      Global.new!("total", :dint, initial: 0, retain: true),
      Global.new!("total_at_stop", :dint)
    ],
    instances: [
      %Instance{name: "c1", type: "belt", task: "fast"},
      %Instance{name: "b1", type: "box_count", task: "fast"},
      %Instance{name: "f1", type: "fan_control"},
      %Instance{name: "f2", type: "fan_control"},
      %Instance{name: "r1", type: "stop_record", task: "on_stop"}
    ],
    connections:
      wire.("c1", [{"start", "pb_start"}, {"stop", 0}, {"motor", "motor_k"}]) ++
        wire.("b1", [{"eye", "eye"}]) ++
        wire.("f1", [{"temp", "temps[0]"}, {"limit", "limits[0]"}, {"fan", "fan_k[0]"}]) ++
        wire.("f2", [{"temp", "temps[1]"}, {"limit", "limits[1]"}, {"fan", "fan_k[1]"}]) ++
        wire.("r1", [{"count", "total"}, {"count_at_stop", "total_at_stop"}])
  )

{:ok, file} = Configuration.compile_file("configuration-file/line_1.logex")
no_lines = fn elements -> Enum.map(elements, &%{&1 | line: nil}) end

for part <- [:tasks, :globals, :instances, :connections] do
  same = no_lines.(Map.fetch!(file, part)) == Map.fetch!(plant, part)
  IO.puts("#{part}: the same as the file: #{same}")
end

IO.puts("file: #{inspect(plant.file)}, warnings: #{length(plant.warnings)}")
IO.write(Text.print(plant))
