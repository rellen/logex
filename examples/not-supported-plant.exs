alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# A fan that runs while the motor is hot, and counts its hours.
fan_text = """
var_input  hot   bool
var_output fan   bool
var        hours dint
var        temps int[4]

xic hot ote fan
xic fan add hours 1 hours
xic hot move 40 temps[0]
"""

{:ok, fan} = Logex.compile(fan_text, name: "fan")

# The configuration: 1 task, 3 globals on a panel and 1 instance of the fan.
head = """
task fast interval 10 priority 1
var_global hot     bool at panel.i.0
var_global fan_out bool at panel.q.0
var_global lamp    bool at panel.q.1
program f1 fan with fast
f1.hot hot
f1.fan fan_out
"""

texts = [
  "resource r1 on cpu",
  "configuration line_1",
  "program retain f2 fan with fast\nf2.hot hot\nf2.fan lamp",
  "var_global retain eye bool at panel.i.1",
  "var_global persistent level dint"
]

report.(45, texts, &Logex.Configuration.compile("line_1", head <> &1, %{"fan" => fan}))

# An online edit keeps the type of each tag and the size of each array.
state = Logex.Runtime.instance(fan)
candidates = [{"var hours int", "hours dint"}, {"var temps int[8]", "temps int[4]"}]

accept = fn "var " <> to = text ->
  {_, from} = List.keyfind(candidates, text, 0)
  {:ok, candidate} = Logex.compile(String.replace(fan_text, from, to), name: "fan")
  Logex.Edit.accept(fan, candidate, state)
end

report.(50, Enum.map(candidates, &elem(&1, 0)), accept)

# A restart is cold or warm.
for mode <- [:hot, {:warm, cold: ["hours"]}] do
  try do
    Logex.Runtime.restart(fan, state, mode)
  rescue
    error in ArgumentError -> IO.puts("restart #{inspect(mode)}\n  #{error.message}")
  end
end

# The runner forces an input point only.
{:ok, plant} = Logex.Configuration.compile("line_1", head, %{"fan" => fan})
File.rm("not-supported.forces")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock},
    forces: "not-supported.forces"
  )

IO.puts("force hot\n  #{inspect(Runner.force(runner, "hot", 1))}")

try do
  Runner.force(runner, "fan_out", 1)
rescue
  error in ArgumentError -> IO.puts("force fan_out\n  #{error.message}")
end
