{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp with fast\n  l1.on 0"

texts = [
  "task fast priority 1 interval 10" <> lamp,
  "task fast interval 10 interval 20 priority 1" <> lamp,
  "task fast interval 10 watchdog 50 priority 1" <> lamp,
  "task fast interval 10 priority 1 continuous" <> lamp,
  "task fast interval 10 priority 1 phase 5" <> lamp,
  "task fast interval 10" <> lamp,
  "task fast priority 1" <> lamp,
  "task fast" <> lamp,
  "task fast interval 0 priority 1" <> lamp,
  "task fast interval 2147483648 priority 1" <> lamp,
  "task fast interval 10 priority 65536" <> lamp,
  "task fast interval 10 priority -1" <> lamp,
  "task fast interval 1.5 priority 1" <> lamp,
  "task fast interval 10 priority 1 watchdog 0" <> lamp,
  "task fast single estop priority 0" <> lamp,
  "task fast single 5 priority 0" <> lamp,
  "var_global estop dint\ntask fast single estop priority 0" <> lamp,
  "var_global estop bool[2]\ntask fast single estop[1] priority 0" <> lamp,
  "task fast single l1.lamp priority 0" <> lamp,
  "var_global estop bool\ntask fast interval 10 single estop priority 0" <> lamp,
  "task fast continuous priority 1" <> lamp,
  "var_global estop bool\ntask fast continuous single estop interval 10" <> lamp,
  "task fast continuous\ntask main continuous" <> lamp,
  "task" <> lamp
]

report.(11, texts, &Logex.Configuration.compile("line_1", &1, types))
