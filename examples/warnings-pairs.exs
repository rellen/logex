{report, _} = Code.eval_file("warnings/report.exs")
tags = File.read!("warnings/tags.txt")

{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_output run bool\nxic start ote run",
    name: "seal"
  )

# The same tags and the same filter as warnings-writes.exs. Each case is 1 pair of writes
# in the 2 orders: an ote first, then the other write first.
two_writes = fn compiled ->
  {:ok, program} = compiled

  kept =
    Enum.filter(program.warnings, &String.ends_with?(&1.message, ["decides it", "wrong scans"]))

  {:ok, %{program | warnings: kept}}
end

orders = fn ote, other ->
  ["xic start #{ote}\nxic stop #{other}", "xic stop #{other}\nxic start #{ote}"]
end

cases = [
  {"an ote and a move on 1 literal element", orders.("ote lamps[2]", "move 0 lamps[2]")},
  {"an ote on a literal element and an otl through a tag",
   orders.("ote lamps[2]", "otl lamps[slot]")},
  {"an ote through a tag and an otl on a literal element or member",
   orders.("ote lamps[slot]", "otl lamps[2]") ++ orders.("ote lane_c[i].r", "otu lane_c[1].r")},
  {"an ote and an otl through different tags", orders.("ote lamps[slot]", "otl lamps[sel]")},
  {"an ote and an otl on 1 literal bit", orders.("ote status.3", "otl status.3")},
  {"an ote on a bit and an otl on a bit with a tag as its number",
   orders.("ote status.3", "otl status.[n]")},
  {"an ote on a bit through a tag and an otl on a literal bit of a literal element",
   orders.("ote flags[i].3", "otl flags[1].3")},
  {"an ote on a bit and a move of its element through the same tag",
   orders.("ote flags[i].3", "move 0 flags[i]")},
  {"a member of an element: an ote through a tag and an otl on a literal bit",
   orders.("ote lane_c[i].pv.3", "otl lane_c[1].pv.3")},
  {"a member of an element: an ote and a move through the same tag",
   orders.("ote lane_c[i].pv.3", "move 5 lane_c[i].pv") ++
     orders.("ote lane_c[i].pv.[n]", "move 5 lane_c[i].pv")},
  {"an ote and the output operand of a cal on 1 bool tag",
   Enum.map(orders.("ote motor", "cal belt jog motor"), &("var belt seal\n" <> &1))},
  {"2 writes in 1 rung", "xic start ote motor ote motor\nxic jog ons s1 ote s1"},
  {"an ote and a move on 1 bool tag", orders.("ote kick", "move 0 kick")},
  {"an ote and a move on 1 literal bit", orders.("ote status.3", "move 1 status.3")},
  {"an ote and a move on 1 element through the same tag",
   orders.("ote lamps[slot]", "move 0 lamps[slot]")},
  {"the output operands of 2 cals on 1 bool tag",
   "var belt seal\nvar roll seal\nxic start cal belt jog motor\nxic stop cal roll jog motor"},
  {"a move and the output operand of a cal on 1 bool tag",
   Enum.map(orders.("cal belt jog motor", "move 0 motor"), &("var belt seal\n" <> &1))},
  {"an ote and an otl on 1 literal element", orders.("ote lamps[2]", "otl lamps[2]")},
  {"the output operand of a cal on 1 bit and a move of its word",
   Enum.map(orders.("cal belt jog status.3", "move 0 status"), &("var belt seal\n" <> &1))},
  {"the output operand of a cal and a move through different tags",
   Enum.map(orders.("cal belt jog lamps[slot]", "move 0 lamps[sel]"), &("var belt seal\n" <> &1))}
]

report.(63, cases, &two_writes.(Logex.compile(&1, name: "panel", types: [seal])),
  tags: tags,
  none: "no warning about 2 writes"
)
