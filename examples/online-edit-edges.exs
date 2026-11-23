{show, _} = Code.eval_file("online-edit/instance.exs")

# The box counter: it counts the boxes that pass the eye, and lights the lamp at the preset.
boxes = fn rungs ->
  "var_input eye bool\nvar_input reset_pb bool\nvar_output full_lamp bool\n" <>
    "var_output count dint\nvar boxes ctu\nvar rejects ctu\n" <> rungs <> "\nmove boxes.cv count"
end

# The jog panel: a one-shot, a pulse coil and a jump.
panel = fn rungs ->
  "var_input start bool\nvar_input jog bool\nvar_input auto bool\n" <>
    "var_output started bool\nvar_output pulse bool\nvar s1 bool\nvar s2 bool\n" <> rungs
end

seal = fn rungs ->
  {"seal",
   "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n" <>
     rungs}
end

belts =
  "var_input start bool\nvar_input stop bool\nvar_output belt_1 bool\n" <>
    "var_output belt_2 bool\nvar s1 seal\nvar s2 seal\n" <>
    "cal s1 start stop belt_1\ncal s2 start stop belt_2"

# A gate counts the scans while `go` is on. `gs` is an array of 2 gates. The lamp `timing`
# is on while `t1` times.
gate = fn count ->
  {"gate", "function_block gate\nvar_input go bool\n#{count}\nxic go add count 1 count"}
end

gates =
  "var_input go bool\nvar_output timing bool\nvar t1 ton\nvar g gate\nvar gs gate[2]\n" <>
    "xic go ton t1 100\nxic t1.tt ote timing\ncal g go\ncal gs[0] go\ncal gs[1] go"

# An up-down counter, its done bit on a lamp.
updown = fn preset ->
  "var_input up bool\nvar_input down bool\nvar_output lamp bool\nvar c ctud\n" <>
    "xic up ctu c #{preset}\nxic down ctd c #{preset}\nxic c.qu ote lamp"
end

show.(1, [
  {"a counter's preset made larger when the counter is done",
   boxes.("xic reset_pb ote boxes.r\nxic eye ctu boxes 3\nxic boxes.q ote full_lamp"),
   boxes.("xic reset_pb ote boxes.r\nxic eye ctu boxes 5\nxic boxes.q ote full_lamp"),
   [
     {:scan, 10, %{}},
     {:scan, 10, %{"eye" => 1}},
     {:scan, 10, %{"eye" => 0}},
     {:scan, 10, %{"eye" => 1}},
     {:scan, 10, %{"eye" => 0}},
     {:scan, 10, %{"eye" => 1}},
     :accept,
     :test,
     {:scan, 10, %{}}
   ]},
  {"a counter added on a true rung", boxes.("xic eye ctu boxes 3"),
   boxes.("xic eye ctu boxes 3\nxic eye ctu rejects 9"), [{:scan, 10, %{"eye" => 1}}, :accept]},
  {"a reset that no rung writes after the edit",
   boxes.("xic reset_pb ote boxes.r\nxic eye ctu boxes 3"), boxes.("xic eye ctu boxes 3"),
   [
     {:scan, 10, %{"reset_pb" => 1}},
     :accept,
     :test,
     {:scan, 10, %{"eye" => 1}},
     {:scan, 10, %{"eye" => 0}},
     {:scan, 10, %{"eye" => 1}}
   ]},
  {"a one-shot on a rung that the edit does not change",
   panel.("xic start ons s1 ote started\nxic jog ote pulse"),
   panel.("xic start ons s1 ote started\nxio jog ote pulse"),
   [{:scan, 10, %{}}, :accept, :test, {:scan, 10, %{"start" => 1}}]},
  {"a one-shot on a rung that the edit changes", panel.("xic start ons s1 ote started"),
   panel.("xic start xio jog ons s1 ote started"),
   [
     {:scan, 10, %{}},
     :accept,
     :test,
     {:scan, 10, %{"start" => 1}},
     {:scan, 10, %{"start" => 0}},
     {:scan, 10, %{"start" => 1}}
   ]},
  {"a label added to the rung of a one-shot", panel.("xic start ons s1 ote started"),
   panel.("lbl here xic start ons s1 ote started"),
   [{:scan, 10, %{}}, :accept, :test, {:scan, 10, %{"start" => 1}}]},
  {"a pulse coil added on a true rung", panel.("xic jog ote pulse"),
   panel.("xic jog ote pulse\nxic start osr s2 started"),
   [{:scan, 10, %{"start" => 1}}, :accept, :test, {:scan, 10, %{}}]},
  {"a pulse coil removed in the scan of its pulse", panel.("xic start osr s2 started"),
   panel.("xic jog ote pulse"),
   [{:scan, 10, %{}}, {:scan, 10, %{"start" => 1}}, :accept, :test, {:scan, 10, %{}}]},
  {"a one-shot changed on a rung that a jump skips",
   panel.("xic auto jmp over\nxic start ons s1 ote started\nlbl over"),
   panel.("xic auto jmp over\nxic start xio jog ons s1 ote started\nlbl over"),
   [
     {:scan, 10, %{"auto" => 1}},
     :accept,
     :test,
     {:scan, 10, %{"start" => 1}},
     {:scan, 10, %{"auto" => 0}},
     {:scan, 10, %{"start" => 0}},
     {:scan, 10, %{"start" => 1}}
   ]},
  {"a one-shot added in a function block",
   {belts, [seal.("( xic start | xic run ) xio stop ote run")]},
   {belts,
    [
      seal.(
        "var edge bool\nvar went bool\n( xic start | xic run ) xio stop ote run\n" <>
          "xic run ons edge ote went"
      )
    ]}, [{:scan, 10, %{"start" => 1}}, :accept]},
  {"retain added to the counter", boxes.("xic eye ctu boxes 3"),
   String.replace(boxes.("xic eye ctu boxes 3"), "var boxes ctu", "var retain boxes ctu"),
   [{:scan, 10, %{}}, {:scan, 10, %{"eye" => 1}}, :accept, :test, :assemble]},
  {"a changed initial value of 1 element of an array",
   "var_input zone int\nvar limits int[3] 10 20 30\nmove zone limits[0]",
   "var_input zone int\nvar limits int[3] 10 25 30\nmove zone limits[0]", [:accept]},
  {"a write through a tag subscript removed",
   "var_input lane dint\nvar_input eye bool\nvar lane_c ctu[2]\nxic eye move 2 lane_c[lane].pv\n" <>
     "xic eye ctu lane_c[0] 5\nxic eye ctu lane_c[1] 5",
   "var_input lane dint\nvar_input eye bool\nvar lane_c ctu[2]\n" <>
     "xic eye ctu lane_c[0] 5\nxic eye ctu lane_c[1] 5", [:accept]},
  {"retain added to a timer and to a member of a function block",
   {gates, [gate.("var count dint")]},
   {String.replace(gates, "var t1 ton", "var retain t1 ton"), [gate.("var retain count dint")]},
   [{:scan, 10, %{"go" => 1}}, {:scan, 10, %{}}, :accept]},
  {"the preset of an up-down counter made larger when the counter is done", updown.(2),
   updown.(5),
   [
     {:scan, 10, %{"up" => 1}},
     {:scan, 10, %{"up" => 0}},
     {:scan, 10, %{"up" => 1}},
     {:scan, 10, %{"up" => 0}},
     {:scan, 10, %{"up" => 1}},
     :accept,
     :test,
     {:scan, 10, %{}}
   ]}
])
