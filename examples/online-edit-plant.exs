{show, _} = Code.eval_file("online-edit/plant.exs")

# The conveyor latches a fault when the e-stop is on. A snapshot keeps the contactor's
# value at the rise of the e-stop.
conveyor = """
var_input    start bool
var_input    stop  bool
var_output   motor bool
var_external estop bool
var          fault bool
xic estop otl fault
( xic start | xic motor ) xio stop xio fault ote motor
"""

snapshot = "var_input a bool\nvar_output a_was bool\nxic a ote a_was\n"

plant = """
task fast interval 10 priority 1
task trip single estop priority 0
var_global estop      bool at panel.i.7
var_global start_pb   bool at panel.i.0
var_global k1         bool at panel.q.0
var_global k1_at_trip bool
program c1 conveyor with fast
  c1.start start_pb
  c1.stop  0
  c1.motor k1
program snap snapshot with trip
  snap.a     k1
  snap.a_was k1_at_trip
"""

programs = %{"conveyor" => conveyor, "snapshot" => snapshot}
before = {plant, programs}
change = fn old, new -> {String.replace(plant, old, new), programs} end

# The new conveyor sounds a horn while it has a fault. The new plant checks it every 5 ms
# and has no snapshot.
horn =
  {plant
   |> String.replace("interval 10", "interval 5")
   |> String.replace(
     "var_global k1_at_trip bool",
     "var_global k1_at_trip bool\nvar_global horn bool"
   )
   |> String.replace(
     "program snap snapshot with trip\n  snap.a     k1\n  snap.a_was k1_at_trip\n",
     ""
   ),
   %{
     programs
     | "conveyor" =>
         String.replace(
           conveyor,
           "var          fault bool",
           "var_external horn  bool\nvar          fault bool"
         ) <>
           "xic fault ote horn\n"
   }}

# The lamp program: a var_output that a rung writes, and 1 that no rung writes.
lamp = %{
  "lamp" => "var_input go bool\nvar_output aux bool\nvar_output aux2 bool\nxic go ote aux\n"
}

lamp_plant = """
task fast interval 10 priority 1
var_global go bool at panel.i.0
var_global k2 bool at panel.q.0
program m1 lamp with fast
  m1.go  go
  m1.aux k2
"""

second_snap = "program snap2 snapshot with trip\n  snap2.a k1\n"

# k2 is a retained global with no location: a warm restart keeps its value.
retained =
  "task fast interval 10 priority 1\nvar_global go bool at panel.i.0\n" <>
    "var_global retain k2 bool\nprogram m1 lamp with fast\n  m1.go  go\n  m1.aux k2\n"

retained_v2 = String.replace(retained, "m1.aux k2", "m1.aux2 k2")

# The connections that a switch cannot hold. `reader` reads its var_output `aux2` on
# line 6. `n` and `n2` are int var_outputs that no rung writes.
wired = %{
  "lamp" =>
    "var_input go bool\nvar_output aux bool\nvar_output aux2 bool\nvar_output n int\n" <>
      "var_output n2 int\nxic go ote aux\n",
  "reader" =>
    "var_input go bool\nvar_output aux bool\nvar_output aux2 bool\nvar_output lamp bool\n" <>
      "xic go ote aux\nxic aux2 ote lamp\n"
}

wired_plant = fn type, connections ->
  "task fast interval 10 priority 1\nvar_global go bool at panel.i.0\n" <>
    "var_global k2 bool at panel.q.0\nvar_global k3 bool at panel.q.1\n" <>
    "var_global kn dint at panel.q.2\nprogram m1 #{type} with fast\n  m1.go go\n" <>
    Enum.map_join(connections, &"  #{&1}\n")
end

# The old `writer` writes `aux2`, which starts at 1. The new `writer` only reads it.
writer = fn rungs ->
  %{
    "writer" =>
      "var_input go bool\nvar_output aux2 bool 1\nvar_output lamp bool\n" <>
        rungs <> "xic aux2 ote lamp\n"
  }
end

show.(1, [
  {"an instance removed, a global added, an interval made shorter", before, horn,
   [
     {:cycle, 10, %{"start_pb" => 1}},
     {:cycle, 10, %{"start_pb" => 0}},
     :accept,
     :test,
     {:cycle, 5, %{"estop" => 1}},
     {:get, ["horn"]},
     :untest,
     {:cycle, 10, %{"estop" => 0}},
     :test,
     :assemble
   ]},
  {"an instance added", before, {plant <> second_snap, programs},
   [{:cycle, 10, %{}}, :accept, :test, :untest, :test, :assemble]},
  {"a priority, a watchdog and the order of 2 instances", {plant <> second_snap, programs},
   {String.replace(plant, "priority 1", "priority 3 watchdog 50")
    |> String.replace("program snap snapshot", second_snap <> "program snap snapshot"), programs},
   [:accept]},
  {"a var_external made a var, then back", before,
   {plant,
    %{
      programs
      | "conveyor" => String.replace(conveyor, "var_external estop", "var          estop")
    }}, [{:cycle, 10, %{"estop" => 1}}, :accept, :test, :untest]},
  {"an initial value and retain added to a global", before,
   change.("var_global k1_at_trip bool", "var_global retain k1_at_trip bool 1"), [:accept]},
  {"a second edit accepted while the first is under test", before, horn,
   [{:cycle, 10, %{}}, :accept, :test, :accept_old, :test]},
  {"a cold restart during an edit", before, horn,
   [
     {:cycle, 10, %{}},
     :accept,
     :test,
     {:restart, :cold},
     :untest,
     {:restart, :cold},
     :test,
     :assemble
   ]},
  {"an output point wired to a var_output that no rung writes", {lamp_plant, lamp},
   {String.replace(lamp_plant, "m1.aux k2", "m1.aux2 k2"), lamp},
   [
     {:cycle, 10, %{"go" => 1}},
     :accept,
     :test,
     {:cycle, 10, %{"go" => 0}},
     :untest,
     :test,
     :assemble
   ]},
  {"an instance given another program type and another task", before,
   {String.replace(plant, "program snap snapshot with trip", "program snap recorder with fast"),
    Map.put(programs, "recorder", snapshot)}, [{:cycle, 10, %{}}, :accept]},
  {"a warm restart before the assemble", {retained, lamp}, {retained_v2, lamp},
   [
     {:cycle, 10, %{"go" => 1}},
     :accept,
     :test,
     {:restart, :warm},
     {:get, ["k2", "m1.aux2"]},
     :assemble
   ]}
])

# Each of these changes needs a restart.
show.(11, [
  {"a task added", before,
   change.("task trip single", "task slow interval 100 priority 2\ntask trip single"), [:accept]},
  {"a task removed", before,
   {plant
    |> String.replace("task trip single estop priority 0\n", "")
    |> String.replace("snapshot with trip", "snapshot with fast"), programs}, [:accept]},
  {"the single of an event task changed", before, change.("single estop", "single start_pb"),
   [:accept]},
  {"a single added to a periodic task", before,
   change.("task fast interval 10", "task fast single start_pb interval 10"), [:accept]},
  {"an interval added to an event task", before,
   change.("single estop priority 0", "single estop interval 50 priority 0"), [:accept]},
  {"the interval of an event task removed",
   change.("single estop priority 0", "single estop interval 50 priority 0"), before, [:accept]},
  {"an instance moved to another task with the same program type", before,
   change.("program c1 conveyor with fast", "program c1 conveyor with trip"), [:accept]},
  {"the type of a global", before,
   {plant
    |> String.replace("var_global k1_at_trip bool", "var_global k1_at_trip int")
    |> String.replace("  snap.a_was k1_at_trip\n", ""), programs}, [:accept]},
  {"a location moved, a location removed and a location added", before,
   {plant
    |> String.replace("start_pb   bool at panel.i.0", "start_pb   bool at panel.i.3")
    |> String.replace("k1         bool at panel.q.0", "k1         bool")
    |> String.replace("k1_at_trip bool", "k1_at_trip bool at panel.q.5"), programs}, [:accept]},
  {"a timed task made continuous", before,
   change.("task fast interval 10 priority 1", "task fast continuous"), [:accept]},
  {"the type of a tag of a program type", before,
   {plant,
    %{
      programs
      | "conveyor" =>
          String.replace(conveyor, "fault bool", "fault dint")
          |> String.replace("xic estop otl fault", "xic estop move 1 fault")
          |> String.replace("xio fault ", "")
    }}, [:accept]},
  {"a located array made longer, and an array made longer",
   {plant <> "var_global zone_t int[4] at panel.i.10\nvar_global spare int[4]\n", programs},
   {plant <> "var_global zone_t int[6] at panel.i.10\nvar_global spare int[6]\n", programs},
   [:accept]},
  {"an output point held through a var_output of another type",
   {wired_plant.("lamp", ["m1.aux k2", "m1.n kn"]), wired},
   {wired_plant.("lamp", ["m1.aux k2", "m1.n2 kn"]), wired},
   [{:cycle, 10, %{"go" => 1}}, :accept]},
  {"an output point held through a var_output that a rung reads",
   {wired_plant.("reader", ["m1.aux k2", "m1.lamp k3"]), wired},
   {wired_plant.("reader", ["m1.aux2 k2", "m1.lamp k3"]), wired},
   [{:cycle, 10, %{"go" => 1}}, :accept]},
  {"an output point held through a var_output that drives another point",
   {wired_plant.("lamp", ["m1.aux k3"]), wired},
   {wired_plant.("lamp", ["m1.aux2 k3", "m1.aux2 k2"]), wired},
   [{:cycle, 10, %{"go" => 1}}, :accept]},
  {"a var_output that a rung reads, before its first run after a restart",
   {wired_plant.("writer", ["m1.aux2 k3", "m1.lamp k2"]), writer.("xic go ote aux2\n")},
   {wired_plant.("writer", ["m1.aux2 k3", "m1.lamp k2"]), writer.("")},
   [{:cycle, 10, %{"go" => 1}}, {:restart, :cold}, :accept, {:cycle, 10, %{}}, :accept]}
])
