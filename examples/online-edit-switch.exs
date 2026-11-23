{show, _} = Code.eval_file("online-edit/instance.exs")

# The conveyor: a seal-in of the motor and a lamp while it runs.
conveyor = """
var_input  start    bool
var_input  stop     bool
var_output motor    bool
var_output run_lamp bool
( xic start | xic motor ) xio stop ote motor
xic motor ote run_lamp
"""

# The new conveyor: no lamp, but `at_speed` after 2000 ms and `started` for 1 scan.
at_speed = """
var_input  start    bool
var_input  stop     bool
var_output motor    bool
var_output at_speed bool
var_output started  bool
var        t1       ton
var        s1       bool
( xic start | xic motor ) xio stop ote motor
xic motor ton t1 2000
xic t1.dn ote at_speed
xic motor ons s1 ote started
"""

# The fan: it runs while `run` is on. A delay timer sets the lamp.
fan = fn rungs ->
  "var_input run bool\nvar_input hold bool\nvar_input set bool\nvar_output lamp bool\n" <>
    "var t1 ton\n" <> rungs
end

show.(1, [
  {"a tag added, an output no longer written, a one-shot added", conveyor, at_speed,
   [
     {:scan, 10, %{"start" => 1}},
     {:scan, 10, %{"start" => 0}},
     :accept,
     :test,
     {:scan, 10, %{}},
     :untest,
     {:scan, 10, %{}},
     :test,
     :assemble
   ]},
  {"the same edit, cancelled after an untest", conveyor, at_speed,
   [{:scan, 10, %{"start" => 1}}, :accept, :test, :untest, :cancel]},
  {"an input made a var, then back", conveyor,
   String.replace(conveyor, "var_input  stop", "var        stop"),
   [{:scan, 10, %{"stop" => 1}}, :accept, :test, :untest]},
  {"a preset made longer while the timer is done",
   fan.("xic run ton t1 3000\nxic t1.dn ote lamp"),
   fan.("xic run ton t1 5000\nxic t1.dn ote lamp"),
   [
     {:scan, 10, %{"run" => 1}},
     {:scan, 3500, %{}},
     :accept,
     :test,
     {:scan, 10, %{}},
     :untest,
     {:scan, 10, %{}}
   ]},
  {"a preset that a rung wrote",
   fan.("xic set move 4000 t1.pre\nxic run ton t1 3000\nxic t1.dn ote lamp"),
   fan.("xic set move 4000 t1.pre\nxic run ton t1 5000\nxic t1.dn ote lamp"),
   [{:scan, 10, %{"set" => 1}}, :accept]},
  {"a timer that only the new program runs", fan.("xic t1.dn ote lamp"),
   fan.("xic run ton t1 3000\nxic t1.dn ote lamp"),
   [
     {:scan, 10, %{"run" => 1}},
     :accept,
     :test,
     {:scan, 100, %{}},
     :untest,
     {:scan, 50, %{}},
     :test,
     :untest
   ]},
  {"a jump added before a timer", fan.("xic run ton t1 300\nxic t1.dn ote lamp"),
   fan.("xic hold jmp skip\nxic run ton t1 300\nlbl skip\nxic t1.dn ote lamp"),
   [
     {:scan, 10, %{"run" => 1}},
     {:scan, 100, %{}},
     :accept,
     :test,
     {:scan, 500, %{"hold" => 1}},
     {:scan, 10, %{"hold" => 0}}
   ]},
  {"a fall delay made shorter during its delay",
   fan.("var f tof\nxic run tof f 3000\nxic f.dn ote lamp"),
   fan.("var f tof\nxic run tof f 1000\nxic f.dn ote lamp"),
   [
     {:scan, 10, %{"run" => 1}},
     {:scan, 10, %{"run" => 0}},
     {:scan, 2000, %{}},
     :accept,
     :test,
     {:scan, 10, %{}}
   ]},
  {"a pulse made shorter during the pulse",
   fan.("var p tp\nxic run tp p 3000\nxic p.tt ote lamp"),
   fan.("var p tp\nxic run tp p 1000\nxic p.tt ote lamp"),
   [
     {:scan, 10, %{}},
     {:scan, 10, %{"run" => 1}},
     {:scan, 2000, %{}},
     :accept,
     :test,
     {:scan, 10, %{}}
   ]},
  {"a pulse timer added on a true rung", fan.("var p tp\nxic run ote lamp"),
   fan.("var p tp\nxic run tp p 500\nxic p.tt ote lamp"),
   [{:scan, 10, %{"run" => 1}}, :accept, :test, {:scan, 10, %{}}]},
  {"a retentive timer's preset made shorter while it times",
   fan.("var r rto\nxic run rto r 3000\nxic r.dn ote lamp"),
   fan.("var r rto\nxic run rto r 1000\nxic r.dn ote lamp"),
   [{:scan, 10, %{"run" => 1}}, {:scan, 2000, %{}}, :accept, :test, {:scan, 10, %{}}]}
])
