{report, _} = Code.eval_file("warnings/report.exs")
tags = File.read!("warnings/tags.txt")

# Each case is the tags of tags.txt and its rungs. The script keeps only the warnings
# about 2 writes: the warnings that end with "decides it" or with "wrong scans".
two_writes = fn compiled ->
  {:ok, program} = compiled

  kept =
    Enum.filter(program.warnings, &String.ends_with?(&1.message, ["decides it", "wrong scans"]))

  {:ok, %{program | warnings: kept}}
end

cases = [
  {"3 ote instructions on 1 tag", "xic start ote motor\nxic jog ote motor\nxic stop ote motor"},
  {"a pulse coil and an ote on 1 pulse bit, in the 2 orders",
   "xic start osr s1 kick\nxic stop ote kick\nxic jog ote motor\nxic start osf edges[0,0] motor\n" <>
     "xic jog osr edges[0,1] lamps[3]\nxic stop ote lamps[slot]"},
  {"2 ote instructions on 1 member", "xic start ote boxes.r\nxic stop ote boxes.r"},
  {"2 spellings of 1 element", "xic start ote lamps[2]\nxic stop ote lamps[02]"},
  {"an ote on a bit and a write of its word, in the 2 orders",
   "xic start move panel status\nxic stop ote status.3\nxic jog ote faults[1].0\n" <>
     "xic stop move 0 faults[1]\nxic start move 0 flags[2]\nxic stop ote flags[slot].1"},
  {"2 spellings of 1 bit", "xic start ote status.3\nxic stop ote status.03"},
  {"a bit with a tag as its number",
   "xic start ote status.[n]\nxic stop ote status.3\nxic jog ote status.[slot]\n" <>
     "xic start move panel status\nxic stop ote status.[n]"},
  {"an element with a tag as a subscript, and a literal element",
   "xic start ote lamps[slot]\nxic stop ote lamps[2]\nxic jog ote faults[3].1\n" <>
     "xic start ote faults[slot].1"},
  {"2 elements with tags as subscripts", "xic start ote lamps[slot]\nxic stop ote lamps[sel]"},
  {"1 element with the same tag as a subscript",
   "xic start ote lamps[slot]\nxic stop ote lamps[slot]"},
  {"an otl and a move through tags, beside an ote",
   "xic start ote lamps[2]\nxic stop otl lamps[slot]\nxic jog move 0 lamps[sel]"},
  {"a write with a tag as a subscript, then an ote on an element or a bit",
   "xic start move 0 lamps[slot]\nxic stop ote lamps[2]\nxic start move 0 faults[slot]\n" <>
     "xic stop ote faults[2].1"},
  {"elements that can be the same element",
   "xic start ote grid[i,0]\nxic stop ote grid[j,0]\nxic jog ote faults[i].1\n" <>
     "xic start ote faults[j].1\nxic stop ote faults[sel].[n]"},
  {"members of elements of an array of counters",
   "xic start ote lane_c[i].r\nxic stop ote lane_c[1].r\nxic jog otl lane_c[j].r\n" <>
     "xic start ote lane_c[i].pv.3\nxic stop move 5 lane_c[1].pv\n" <>
     "xic jog ote lane_c[j].pv.[n]"},
  {"2 rungs that a jump makes exclusive",
   "xic jog jmp manual\nxic start ote motor\nlbl manual xic jog ote motor"},
  {"writes to the storage bit of a one-shot",
   "xic jog ote s1\nxic start ons s1 ote kick\nxic stop otu s1"},
  {"writes to a storage bit in a word",
   "xic start ons status.3 ote kick\nxic stop move panel status\nxic jog otl status.[n]"},
  {"writes with tags as subscripts to a storage bit in an array",
   "xic start ons edges[1,1] ote kick\nxic stop ote edges[i,1]\nxic start ons flags[1].3 ote motor\n" <>
     "xic stop ote flags[i].3"}
]

report.(11, cases, &two_writes.(Logex.compile(&1, name: "panel")),
  tags: tags,
  none: "no warning about 2 writes"
)
