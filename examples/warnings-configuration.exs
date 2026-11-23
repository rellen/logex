{report, _} = Code.eval_file("warnings/report.exs")

{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_output run bool\nvar delay ton\n" <>
      "xic start ton delay 500\nxic delay.dn ote run",
    name: "seal"
  )

# The program types of the configurations, compiled from text.
texts = %{
  "lamp" => "var_input on bool\nvar_output lamp bool\nxic on ote lamp",
  "horn" =>
    "var_input on bool\nvar_output lamp bool\nvar_external horn bool\nxic on xic horn ote lamp",
  "totaliser" => "var_input eye bool\nvar_external total dint\nxic eye add total 1 total",
  "box_counter" =>
    "var_input eye bool\nvar_output count dint\nvar boxes ctu\nxic eye ctu boxes 3\n" <>
      "move boxes.cv count",
  "tally" =>
    "var_input eye bool\nvar_output count dint\nvar_external total dint\n" <>
      "xic eye add total 1 total\nmove total count",
  "lamp_2" => "var_input eye bool\nvar_external lamps bool[14]\nxic eye ote lamps[2]",
  "lamp_3" => "var_input eye bool\nvar_external lamps bool[14]\nxic eye ote lamps[3]",
  "slot_lamp" =>
    "var_input eye bool\nvar_input slot dint\nvar_external lamps bool[14]\nxic eye ote lamps[slot]",
  "lamps_12" =>
    "var_input eye bool\nvar_external lamps bool[14]\n" <>
      Enum.map_join(0..11, "\n", &"xic eye ote lamps[#{&1}]"),
  "gate" =>
    "var_input eye bool\nvar_output kick bool\nvar_external edge bool\nxic eye ons edge ote kick",
  "timers" =>
    "var_input go bool\nvar_output motor bool\nvar t1 ton\nvar t2 tof\nvar t3 tp\nvar t4 rto\n" <>
      "xic go ton t1 100\nxic go tof t2 100\nxic go tp t3 100\nxic go rto t4 100\n" <>
      "xic t1.dn xic t2.dn xic t3.dn xic t4.dn ote motor",
  "edges" =>
    "var_input go bool\nvar_output a bool\nvar_output b bool\nvar_output c bool\n" <>
      "var s1 bool\nvar s2 bool\nvar s3 bool\nxic go ons s1 ote a\nxic go osr s2 b\nxic go osf s3 c",
  "belt" => "var_input go bool\nvar_output run bool\nvar s seal\ncal s go run",
  "kept" =>
    "var_input go bool\nvar_output retain run bool\nvar_output count dint\n" <>
      "xic go ote run\nxic go add count 1 count",
  "fan" => "var_input go bool\nvar_input sp real\nvar_output fan bool\nxic go gt sp 1.0 ote fan",
  "pulse" =>
    "var_input eye bool\nvar_output kick bool\nvar_output seen bool\nvar_external edge bool\n" <>
      "xic eye osr edge kick\nxic eye ote seen",
  "q_slot" =>
    "var_input eye bool\nvar_input slot dint\nvar_external q bool[3]\nxic eye ote q[slot]",
  "q_2" => "var_input eye bool\nvar_external q bool[3]\nxic eye ote q[2]",
  "stepper" =>
    "var_input go bool\nvar_input trim lreal\nvar_external steps real[12]\nvar_output f real\n" <>
      "var_output high bool\nxic go move steps[0] f\nxic go gt trim 1.0 ote high"
}

types =
  Map.new(texts, fn {name, text} ->
    {:ok, program} = Logex.compile(text, name: name, types: [seal])
    {name, program}
  end)

cases = [
  {"a global that nothing uses", "var_global spare bool\nprogram l1 lamp\n  l1.on 0"},
  {"an output point that a program reads and nothing drives",
   "var_global horn bool at panel.q.0\nprogram h1 horn\n  h1.on 0"},
  {"arrays of output points that nothing drives, or drives in part",
   "var_global lamps bool[3] at panel.q.0\nvar_global beacons bool[14] at card.q.0\n" <>
     "program l1 lamp\n  l1.on lamps[0]\n  l1.lamp beacons[1]"},
  {"tasks that run no instance",
   "task fast interval 10 priority 1\ntask slow interval 50 priority 2\ntask main continuous\n" <>
     "program l1 lamp with fast\n  l1.on 0"},
  {"2 instances that write 1 global through var_external",
   "var_global total dint\nprogram t1 totaliser\n  t1.eye 0\nprogram t2 totaliser\n  t2.eye 0"},
  {"2 instances that can write 1 element of a global array",
   "var_global lamps bool[14]\nprogram s1 slot_lamp\n  s1.eye 0\n  s1.slot 0\n" <>
     "program s2 lamp_2\n  s2.eye 0"},
  {"2 instances that write different elements of a global array",
   "var_global lamps bool[14]\nprogram s2 lamp_2\n  s2.eye 0\nprogram s3 lamp_3\n  s3.eye 0"},
  {"2 instances that write 12 elements of a global array",
   "var_global lamps bool[14]\nprogram a1 lamps_12\n  a1.eye 0\nprogram a2 lamps_12\n  a2.eye 0"},
  {"a write through var_external and a connection that drive 1 global",
   "var_global total dint\nprogram t1 totaliser\n  t1.eye 0\nprogram b1 box_counter\n" <>
     "  b1.eye 0\n  b1.count total"},
  {"1 instance that drives 1 global in the 2 ways",
   "var_global total dint\nprogram k1 tally\n  k1.eye 0\n  k1.count total"},
  {"2 instances that keep the storage bit of a one-shot in 1 global",
   "var_global edge bool\nprogram g1 gate\n  g1.eye 0\nprogram g2 gate\n  g2.eye 0"},
  {"timers under an event task",
   "var_global trip bool\ntask on_trip single trip priority 0\nprogram m1 timers with on_trip\n" <>
     "  m1.go trip\nprogram b1 belt with on_trip\n  b1.go trip"},
  {"a counter and one-shots under an event task",
   "var_global trip bool\ntask on_trip single trip priority 0\n" <>
     "program c1 box_counter with on_trip\n  c1.eye trip\nprogram e1 edges with on_trip\n  e1.go trip"},
  {"retained values and the connections that drive them",
   "var_global run_lamp bool at panel.q.0\nvar_global retain count dint\nprogram k1 kept\n" <>
     "  k1.go 0\n  k1.run run_lamp\n  k1.count count"},
  {"real values with more digits than a real keeps",
   "var_global sp real 16777217.0\nprogram f1 fan\n  f1.go 0\n  f1.sp sp\nprogram f2 fan\n" <>
     "  f2.go 0\n  f2.sp 16777217.0"},
  {"storage bits in a global, with a connection, and for an osr",
   [
     "var_global edge bool\nprogram g1 gate\n  g1.eye 0\nprogram l1 lamp\n  l1.on 0\n  l1.lamp edge",
     "var_global edge bool\nprogram p1 pulse\n  p1.eye 0\n  p1.seen edge"
   ]},
  {"a write through a tag subscript and a connection that drives 1 element",
   "var_global lamps bool[14]\nprogram s1 slot_lamp\n  s1.eye 0\n  s1.slot 0\nprogram l1 lamp\n" <>
     "  l1.on 0\n  l1.lamp lamps[3]"},
  {"arrays of output points that writes through var_external drive",
   [
     "var_global q bool[3] at panel.q.0\nprogram w1 q_slot\n  w1.eye 0\n  w1.slot 0",
     "var_global q bool[3] at panel.q.0\nprogram w2 q_2\n  w2.eye 0"
   ]},
  {"a list of 12 real initial values, and an lreal",
   "var_global steps real[12] " <>
     Enum.map_join(1..12, " ", &"#{16_777_215 + 2 * &1}.0") <>
     "\nvar_global fine lreal 0.12345678901234567890\nprogram s1 stepper\n  s1.go 0\n" <>
     "  s1.trim fine"}
]

report.(44, cases, &Logex.Configuration.compile("plant", &1, types), [])
