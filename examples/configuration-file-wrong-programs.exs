{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
fast = "task fast interval 10 priority 1\n"

texts = [
  "program l1\n  l1.on 0",
  "program l1 with fast\n  l1.on 0",
  "program l1 lamp fast\n  l1.on 0",
  "program l1 lamb\n  l1.on 0",
  "program l1 Lamp\n  l1.on 0",
  fast <> "program l1 lamp with slow\n  l1.on 0",
  fast <> "program l1 lamp with fast.x\n  l1.on 0",
  "program l1.x lamp\n  l1.on 0",
  "program task lamp\n  task.on 0",
  "program retain lamp\n  retain.on 0",
  "program retain l1 lamp\n  l1.on 0",
  "var_global total dint",
  fast <> "program l1 lamp with fast\n  l1.on 0\nprogram l1 lamp with fast\n  l1.on 0"
]

report.(67, texts, &Logex.Configuration.compile("line_1", &1, types))
