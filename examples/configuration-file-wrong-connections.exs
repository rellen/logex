{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

# fans: a program type with 2 arrays, for texts 105 to 109.
fans_text = """
var_input  temps real[2]
var_output fans  bool[2]

gt temps[0] 40.0 ote fans[0]
gt temps[1] 40.0 ote fans[1]
"""

{:ok, fans} = Logex.compile(fans_text, name: "fans")
fan = "program f1 fan_control\n  f1.temp 20.0\n"

texts = [
  "program l1 lamp",
  "program c1 belt\n  c1.start 0\nvar_global estop bool",
  "program l1 lamp\n  l1.of 0",
  "program l1 lamp\n  l1.on 0\n  l2.on 0",
  "program l1 lamp\n  l1.on",
  "program l1 lamp\n  l1 0",
  "program l1 lamp\n  l1.on 0 1",
  "program l1 lamp\n  l1.on 0\n  l1.on 1",
  "program l1 lamp\n  l1.on 2",
  "program l1 lamp\n  l1.on 1.0",
  "program l1 lamp\n  l1.on pb_start",
  "var_global total dint\nprogram l1 lamp\n  l1.on total",
  "var_global level int\nprogram b1 box_count\n  b1.eye 0\nprogram r1 stop_record\n  r1.count 0\n  r1.count_at_stop level\nvar_global total dint",
  "var_global level real\nprogram r1 stop_record\n  r1.count level\nvar_global total dint",
  fan <> "  f1.limit 1.0e40",
  "program l1 lamp\n  l1.on 0\n  l1.lamp 1",
  "var_global pb_start bool at panel.i.0\nprogram l1 lamp\n  l1.on 0\n  l1.lamp pb_start",
  "var_global lamp_k bool at panel.q.3\nprogram l1 lamp\nprogram l2 lamp\n  l1.on 0\n  l2.on 0\n  l1.lamp lamp_k\n  l2.lamp lamp_k",
  "var_global estop bool\nprogram c1 belt\n  c1.start 0\n  c1.stop 0\n  c1.estop estop",
  "program b1 box_count\n  b1.eye 0\n  b1.seen 0\nvar_global total dint",
  "program l1 lamp\n  l1.on l2.lamp",
  "program l1 lamp\n  l1.on panel.i.0",
  "program l1 lamp\n  l1[1].on 0",
  "program r1 stop_record\n  r1.count 0\n  r1.x.y 0",
  "var_global temps real[2]\n" <> fan <> "  f1.limit temps",
  "var_global temps real[2]\n" <> fan <> "  f1.limit temps[2]",
  "var_global temps real[2]\nvar_global i dint\n" <> fan <> "  f1.limit temps[i]",
  "program f1 fans\n  f1.temps 20.0",
  "program f1 fans\n  f1.temps[0] 20.0",
  "program f1 fans\n  f1.temps[0] 20.0\n  f1.temps[1] 20.0\n  f1.temps[2] 20.0",
  "var_global temps real[3]\nprogram f1 fans\n  f1.temps temps",
  "var_global temps int[2]\nvar_global fan_k bool[2]\nprogram f1 fans\n  f1.temps temps\n  f1.fans fan_k"
]

report.(80, texts, &Logex.Configuration.compile("line_1", &1, Map.put(types, "fans", fans)))
