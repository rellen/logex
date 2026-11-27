{report, _} = Code.eval_file("warnings/report.exs")
tags = File.read!("warnings/tags.txt")

# The same tags and the same filter as warnings-writes.exs. logex gives no warning about
# 2 writes for these cases.
two_writes = fn compiled ->
  {:ok, program} = compiled

  kept =
    Enum.filter(program.warnings, &String.ends_with?(&1.message, ["decides it", "wrong scans"]))

  {:ok, %{program | warnings: kept}}
end

cases = [
  {"an ote, an otl and an otu on 1 tag",
   "xic start ote motor\nxic jog otl motor\nxic stop otu motor\nxic stop otl motor"},
  {"2 writes of a bool tag or of a word, with no ote",
   "xic start move 1 motor\nxic stop move 0 motor\nxic start move panel status\n" <>
     "xic stop move 0 status"},
  {"an otl and a move on 1 bool tag", "xic start otl kick\nxic stop move 0 kick"},
  {"an otl on a bit and a write of its word",
   "xic start otl status.3\nxic stop move panel status"},
  {"2 bits with different numbers", "xic start ote status.3\nxic stop ote status.4"},
  {"2 different elements", "xic start ote lamps[1]\nxic stop ote lamps[2]"},
  {"an ote and a latch through the same tag",
   "xic start ote lamps[slot]\nxic stop otl lamps[slot]\nxic start ote status.[n]\n" <>
     "xic stop otu status.[n]\nxic jog ote lane_c[i].r\nxic stop otl lane_c[i].r"},
  {"an otl on a literal bit and an ote on a bit through a tag, in the 2 orders",
   "xic start otl status.3\nxic stop ote status.[n]\nxic jog ote flags[1].[n]\nxic stop otl flags[1].3"},
  {"2 writes with no ote, 1 with a tag as a subscript",
   "xic start move 0 faults[slot]\nxic stop move 1 faults[2]"},
  {"literal subscripts that are different", "xic start ote grid[1,i]\nxic stop ote grid[0,j]"},
  {"a literal element in a different row", "xic start ote grid[0,i]\nxic stop ote grid[1,3]"},
  {"literal bit numbers that are different",
   "xic start ote faults[i].1\nxic stop ote faults[j].2\nxic jog ote lane_c[1].pv.[n]\n" <>
     "xic start ote lane_c[2].pv.3"},
  {"a contact on a storage bit", "xic s1 ote motor\nxic start ons s1 ote kick"},
  {"writes with tags as subscripts that cannot write the storage bit",
   "xic start ons edges[1,1] ote kick\nxic stop ote edges[i,0]\nxic start ons flags[1].3 ote motor\n" <>
     "xic stop ote flags[i].4"},
  {"an otl on a pulse bit", "xic start osr s1 kick\nxic stop otl kick"}
]

report.(29, cases, &two_writes.(Logex.compile(&1, name: "panel")),
  tags: tags,
  none: "no warning about 2 writes"
)
