{show, _} = Code.eval_file("online-edit/instance.exs")

# The conveyor: a seal-in of the motor, a lamp, a speed and a delay timer.
tags = """
var_input  start    bool
var_input  stop     bool
var_output motor    bool
var_output run_lamp bool
var_output speed_sp dint 1200
var        t1       ton
"""

rungs = """
( xic start | xic motor ) xio stop ote motor
xic motor ote run_lamp
xic motor ton t1 2000
"""

conveyor = tags <> rungs

# A function block with a seal-in, and 3 belts that each run 1 instance of it.
seal = fn kind ->
  {"seal",
   "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n" <>
     "var memo #{kind}\n( xic start | xic run ) xio stop ote run"}
end

latch = {"latch", String.replace(elem(seal.("bool"), 1), "block seal", "block latch")}

belts =
  "var_input start bool\nvar_input stop bool\nvar_output belt_1 bool\n" <>
    "var_output belt_2 bool\nvar_output belt_3 bool\nvar s1 seal\nvar s2 seal\nvar s3 seal\n" <>
    "cal s1 start stop belt_1\ncal s2 start stop belt_2\ncal s3 start stop belt_3"

lanes =
  "var_input start bool\nvar_input stop bool\nvar_output belt bool\nvar ws seal[3]\n" <>
    "cal ws[0] start stop belt\ncal ws[1] start stop belt\ncal ws[2] start stop belt"

show.(1, [
  {"3 tags change type", conveyor,
   conveyor
   |> String.replace("run_lamp bool", "run_lamp dint")
   |> String.replace("speed_sp dint 1200", "speed_sp int 1200")
   |> String.replace("t1       ton", "t1       tof")
   |> String.replace("xic motor ote run_lamp", "xic motor move 1 run_lamp")
   |> String.replace("ton t1 2000", "tof t1 2000"), [:accept]},
  {"a timer made a long timer", conveyor,
   conveyor
   |> String.replace("t1       ton", "t1       ton_ltime")
   |> String.replace("ton t1 2000", "ton t1 2000000000"), [:accept]},
  {"a counter of 32 bits made a counter of 16 bits",
   "var_input eye bool\nvar boxes ctu\nxic eye ctu boxes 3",
   "var_input eye bool\nvar boxes ctu_int\nxic eye ctu boxes 3", [:accept]},
  {"a counter word made its alias", "var_input eye bool\nvar boxes ctu\nxic eye ctu boxes 3",
   "var_input eye bool\nvar boxes ctu_dint\nxic eye ctu boxes 3", [:accept]},
  {"3 arrays change size, element type and kind",
   "var_input zone int\nvar temps int[8]\nvar limits int[8]\nvar levels int[8]\n" <>
     "move zone temps[1]\nmove zone limits[1]\nmove zone levels[1]",
   "var_input zone int\nvar temps int[10]\nvar limits dint[8]\nvar levels int\n" <>
     "move zone temps[1]\nmove zone limits[1]\nmove zone levels", [:accept]},
  {"a member of a function block changes type", {belts, [seal.("bool")]},
   {belts, [seal.("dint")]}, [:accept]},
  {"a function block of another name", {belts, [seal.("bool")]},
   {String.replace(belts, " seal", " latch"), [latch]}, [:accept]},
  {"a member changes type in each element of an array of instances", {lanes, [seal.("bool")]},
   {lanes, [seal.("dint")]}, [:accept]},
  {"2 sections and 2 initial values change",
   tags <> "var level real 0\n" <> rungs <> "xic motor move 1.5 level",
   String.replace(tags, "var_input  stop", "var        stop")
   |> String.replace("var_output run_lamp", "var        run_lamp")
   |> String.replace("speed_sp dint 1200", "speed_sp dint 1500")
   |> Kernel.<>("var level real 0.0\n" <> rungs <> "xic motor move 1.5 level"),
   [{:scan, 10, %{"stop" => 1}}, :accept]},
  {"a literal written in another base", conveyor,
   String.replace(conveyor, "ton t1 2000", "ton t1 16#7d0"), [:accept]},
  {"a tag made an array, and an array of 2 dimensions made an array of 1",
   "var_input zone int\nvar temp int\nvar grid int[2,4]\nmove zone temp\nmove zone grid[0,0]",
   "var_input zone int\nvar temp int[4]\nvar grid int[8]\nmove zone temp[0]\nmove zone grid[0]",
   [:accept]}
])
