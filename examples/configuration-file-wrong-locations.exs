{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "var_global estop bool at" <> lamp,
  "var_global estop bool at panel" <> lamp,
  "var_global estop bool at panel.x.7" <> lamp,
  "var_global estop bool at panel.I.7" <> lamp,
  "var_global estop bool at panel.i.07" <> lamp,
  "var_global estop bool at 5.i.7" <> lamp,
  "var_global estop bool at task.i.7" <> lamp,
  "var_global estop bool 0 at panel.i.7" <> lamp,
  "var_global motor_k bool 1 at panel.q.0" <> lamp,
  "var_global temps real[2] 20.0 20.0 at card.i.0" <> lamp,
  "var_global estop bool at panel.i.7\nvar_global eye bool at panel.i.7" <> lamp,
  "var_global temps real[2] at card.i.0\nvar_global door bool at card.i.1" <> lamp,
  "var_global temps real[2] at card.i.0\nvar_global spare real[3] at card.i.1" <> lamp,
  "var_global estop bool at panel.i.7\nvar_global eye bool at Panel.i.2" <> lamp
]

report.(53, texts, &Logex.Configuration.compile("line_1", &1, types))
