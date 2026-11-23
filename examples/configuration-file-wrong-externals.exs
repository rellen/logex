{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
belt = "\nprogram c1 belt\n  c1.start 0\n  c1.stop 0"
boxes = "\nprogram b1 box_count\n  b1.eye 0"

texts = [
  "var_global estap bool" <> belt,
  "var_global estop int" <> belt,
  "var_global estop bool[2]" <> belt,
  "var_global total dint at panel.i.3" <> boxes,
  "var_global total lint" <> boxes
]

report.(112, texts, &Logex.Configuration.compile("line_1", &1, types))
