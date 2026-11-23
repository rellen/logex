{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

# More program types. kept_lamp retains its var_output lamp. flash keeps the storage bit
# of its ons in a global, and rise and fall have an osr and an osf. lamp_0, lamp_2 and
# lamp_3 write 1 element of the global array lamps, lamp_z writes the element that its
# input z gives, and lamps_12 writes 12 elements. bit_0 and bit_1 write 1 bit of the
# global w.
more = %{
  "kept_lamp" =>
    "var_input on bool\nvar_output retain lamp bool\nvar_output count dint\n" <>
      "xic on ote lamp\nxic on add count 1 count",
  "flash" =>
    "var_input on bool\nvar_output lamp bool\nvar_external memory bool\n" <>
      "xic on ons memory ote lamp",
  "rise" => "var_input on bool\nvar_output q bool\nvar s bool\nxic on osr s q",
  "fall" => "var_input on bool\nvar_output q bool\nvar s bool\nxic on osf s q",
  "lamp_0" => "var_input on bool\nvar_external lamps bool[13]\nxic on ote lamps[0]",
  "lamp_2" => "var_input on bool\nvar_external lamps bool[4]\nxic on ote lamps[2]",
  "lamp_3" => "var_input on bool\nvar_external lamps bool[4]\nxic on ote lamps[3]",
  "lamp_z" =>
    "var_input on bool\nvar_input z dint\nvar_external lamps bool[4]\nxic on ote lamps[z]",
  "lamps_12" =>
    "var_input on bool\nvar_external lamps bool[13]\n" <>
      Enum.map_join(0..11, "\n", &"xic on ote lamps[#{&1}]"),
  "bit_0" => "var_input on bool\nvar_external w word\nxic on ote w.0",
  "bit_1" => "var_input on bool\nvar_external w word\nxic on ote w.1"
}

types =
  Enum.reduce(more, types, fn {name, text}, types ->
    {:ok, program} = Logex.compile(text, name: name)
    Map.put(types, name, program)
  end)

lamp = "\nprogram l1 lamp\n  l1.on 0"
boxes = "\nvar_global total dint\nprogram b1 box_count with fast\n  b1.eye 0"
fast = "task fast interval 10 priority 1\n"
two = fn a, b -> "\nprogram a1 #{a}\nprogram a2 #{b}\n  a1.on 0\n  a2.on 0" end

texts = [
  # 154 to 158: a global that nothing uses, and output points that nothing writes
  "var_global spare bool" <> lamp,
  "var_global estop bool at panel.q.7" <> "\nprogram c1 belt\n  c1.start 0\n  c1.stop 0",
  "var_global fan_k bool[2] at panel.q.1\nprogram f1 fan_control\n  f1.temp 20.0\n  f1.limit 40.0\n  f1.fan fan_k[0]",
  "var_global lamps bool[3] at panel.q.0\nprogram l1 lamp\n  l1.on lamps[0]",
  "var_global lamps bool[13] at card.q.0\nprogram a1 lamp_0\n  a1.on 0",
  # 159 and 160: tasks
  fast <> "task slow interval 50 priority 2" <> lamp,
  fast <> "task main continuous\nprogram l1 lamp with fast\n  l1.on 0",
  # 161 to 164: 2 writers of 1 global
  fast <> "program b2 box_count with fast\n  b2.eye 0" <> boxes,
  fast <> "program r1 stop_record with fast\n  r1.count 0\n  r1.count_at_stop total" <> boxes,
  "var_global w word" <> two.("bit_0", "bit_1"),
  "var_global memory bool\nprogram f1 flash\n  f1.on 0\nprogram f2 flash\n  f2.on 0",
  # 165 and 166: one-shots under an event task
  "var_global eye bool\ntask on_eye single eye priority 0\nprogram b1 box_count with on_eye\n  b1.eye eye\nvar_global total dint",
  "var_global eye bool\ntask on_eye single eye priority 0\nprogram p1 rise with on_eye\n  p1.on eye\nprogram p2 fall with on_eye\n  p2.on eye",
  # 167 and 168: reals
  "var_global limit real 16777217.0\nprogram f1 fan_control\n  f1.temp 20.0\n  f1.limit limit",
  "program f1 fan_control\n  f1.temp 20.0\n  f1.limit 16777217.0",
  # 169 and 170: retained values
  "var_global lamp_k bool at panel.q.3\nprogram k1 kept_lamp\n  k1.on 0\n  k1.lamp lamp_k",
  "var_global retain count dint\nprogram k1 kept_lamp\n  k1.on 0\n  k1.count count",
  # 171 to 176: elements of a global array
  "var_global lamps bool[4] at card.q.0\nprogram a1 lamp_2\n  a1.on 0",
  "var_global lamps bool[4] at card.q.0\nprogram a1 lamp_z\n  a1.on 0\n  a1.z 0",
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_3"),
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_2"),
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_z") <> "\n  a2.z 0",
  "var_global lamps bool[13]" <> two.("lamps_12", "lamps_12")
]

report.(154, texts, &Logex.Configuration.compile("line_1", &1, types))
