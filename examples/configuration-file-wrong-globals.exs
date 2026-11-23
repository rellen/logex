{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"
# In cases 49 to 52, the instance l1 reads the global: no diagnostic says that the global
# is not there.
reads = fn global -> "\nprogram l1 lamp\n  l1.on #{global}" end

texts = [
  "var_global total" <> lamp,
  "var_global total dint 1 2" <> lamp,
  "var_global total ton" <> lamp,
  "var_global total time" <> lamp,
  "var_global total dint 2147483648" <> lamp,
  "var_global total word -1" <> lamp,
  "var_global total dint 1.5" <> lamp,
  "var_global estop bool 2" <> lamp,
  "var_global temp real 1.0e40" <> lamp,
  "var_global temp real 1.0e-40" <> lamp,
  "var_global limits real[2] 40.0" <> lamp,
  "var_global limits real[0]" <> lamp,
  "var_global limits real[100000]" <> lamp,
  "var_global limits real [2]" <> lamp,
  "var_global retain retain done bool" <> reads.("done"),
  "var_global retain non_retain done bool" <> reads.("done"),
  "var_global done bool 0 retain" <> reads.("done"),
  "var_global retain estop bool at panel.i.7" <> reads.("estop")
]

report.(35, texts, &Logex.Configuration.compile("line_1", &1, types))
