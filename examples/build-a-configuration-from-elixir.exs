# Part 1: compile the program type. Its name is the name of its file: "motor".
{:ok, motor} = Logex.compile_file("motor.ld")

alias Logex.Configuration
alias Logex.Configuration.{Connection, Global, Instance}

# Part 2: the tasks.
tasks = [
  %Configuration.Task{name: "fast", interval: 10, priority: 1},
  %Configuration.Task{name: "slow", interval: 50, priority: 2}
]

# Part 3: the globals. Each global is at a point of a device.
point = fn name, type, at -> %Global{name: name, type: type, at: at} end

globals = [
  point.("pb_start_1", :bool, "panel.i.0"),
  point.("pb_stop_1", :bool, "panel.i.1"),
  point.("tt_1", :bool, "panel.i.2"),
  point.("pb_start_2", :bool, "panel.i.3"),
  point.("pb_stop_2", :bool, "panel.i.4"),
  point.("pb_reset", :bool, "panel.i.5"),
  point.("k1", :bool, "panel.q.0"),
  point.("k2", :bool, "panel.q.1"),
  point.("sp_1", :dint, "drive.q.0"),
  point.("sp_2", :dint, "drive.q.1")
]

# Part 4: the instances. The instances of 1 task run in the sequence of this list.
instances = [
  %Instance{name: "m1", type: "motor", task: "fast"},
  %Instance{name: "m2", type: "motor", task: "slow"}
]

# Part 5: the connections. Each pair is a tag of the instance, then a global or a number.
wire = fn instance, pairs ->
  for {tag, to} <- pairs, do: %Connection{instance: instance, member: tag, to: to}
end

connections =
  wire.("m1", [{"start", "pb_start_1"}, {"stop", "pb_stop_1"}, {"overtemp", "tt_1"}]) ++
    wire.("m1", [{"reset", "pb_reset"}, {"motor", "k1"}, {"speed_sp", "sp_1"}]) ++
    wire.("m2", [{"start", "pb_start_2"}, {"stop", "pb_stop_2"}, {"overtemp", 0}]) ++
    wire.("m2", [{"reset", 0}, {"motor", "k2"}, {"speed_sp", "sp_2"}])

# Part 6: build the configuration. new!/1 checks it, and raises an ArgumentError if the
# data has an error. Print each warning.
plant =
  Configuration.new!(
    name: "plant",
    programs: [motor],
    tasks: tasks,
    globals: globals,
    instances: instances,
    connections: connections
  )

Enum.each(plant.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

# Part 7: run 7 cycles. Each line gives the ms since the last cycle, and the input
# points that change before the cycle. An input point keeps its value until it changes.
steps = [
  {0, %{}},
  {10, %{"pb_start_1" => 1, "pb_start_2" => 1}},
  {10, %{"pb_start_1" => 0, "pb_start_2" => 0}},
  {10, %{"tt_1" => 1}},
  {10, %{}},
  {10, %{"pb_start_2" => 1}},
  {10, %{"pb_start_2" => 0}}
]

row = fn cells, ran ->
  IO.puts(Enum.map_join(cells, &String.pad_leading("#{&1}", 6)) <> "  " <> ran)
end

row.(["time", "k1", "k2", "sp_1", "sp_2"], "ran")

Enum.reduce(steps, {Logex.Runtime.start(plant), 0}, fn {ms, changes}, {resource, time} ->
  {resource, out, events} = Logex.Runtime.cycle(resource, ms, changes)
  ran = for {:ran, _task, instance, _time} <- events, do: instance
  row.([time + ms, out["k1"], out["k2"], out["sp_1"], out["sp_2"]], Enum.join(ran, " "))
  {resource, time + ms}
end)
