{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "taks fast interval 10 priority 1" <> lamp,
  "resource line_1" <> lamp,
  "at fast" <> lamp,
  "interval 10" <> lamp,
  "retain total dint" <> lamp,
  "task fast interval 10 priority 1 |" <> lamp,
  "program l1 lamp\n  l1.on 0\n( l1.lamp )",
  "task fast interval 10ms priority 1" <> lamp,
  "taks fast interval 10 priority 1\nvar_global x bool @ panel.i.0" <> lamp,
  "program l1 lamp\n  l1.on -> 0"
]

report.(1, texts, &Logex.Configuration.compile("line_1", &1, types))
