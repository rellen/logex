{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")
tags = File.read!("instructions-jump-and-call/tags.txt")

rungs = [
  "cal",
  "cal 5 eye 0 lamp",
  "cal bool eye 0 lamp",
  "cal s9 eye 0 lamp",
  "cal lamp eye 0 lamp",
  "cal delay eye 0 lamp",
  "cal s1.run eye 0 lamp",
  "cal lanes eye 0 lamp",
  "cal lanes[slot] eye 0 lamp",
  "cal lanes[3] eye 0 lamp",
  "cal lanes[1].run eye 0 lamp",
  "cal s1 eye 0 lamp\ncal s1 skip 0 belt",
  "xic skip cal lanes[1] eye 0 lamp\nxic eye cal lanes[1] skip 0 belt",
  "xic eye ton s1 100"
]

report.(28, rungs, &Logex.compile(tags <> &1, name: "wrong", types: [seal, gain]))
