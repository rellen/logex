{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "var_global eye bool\nvar_global eye bool" <> lamp,
  "var_global eye bool\nvar_global Eye bool" <> lamp,
  "task l1 interval 10 priority 1" <> lamp,
  "var_global Task bool" <> lamp,
  "var_global PROGRAM bool" <> lamp,
  "var_global non_retain bool" <> lamp,
  "var_global pb.start bool" <> lamp,
  "task fast.1 interval 10 priority 1" <> lamp,
  "program lamp lamp\n  lamp.on 0"
]

report.(117, texts, &Logex.Configuration.compile("line_1", &1, types))
