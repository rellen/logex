{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")
tags = File.read!("instructions-jump-and-call/tags.txt")

rungs = [
  "cal s1",
  "cal s1 eye 0",
  "cal s1 eye ote lamp",
  "cal s1 eye 0 lamp belt",
  "cal s1 eye 0 lamp 5",
  "cal s1 eye slot lamp",
  "cal s1 eye 7 lamp",
  "cal s1 bool 0 lamp",
  "cal s1 delay 0 lamp",
  "cal s1 s2 0 lamp",
  "cal s1 eye 0 1",
  "cal s1 eye 0 skip",
  "cal s1 eye 0 delay.dn",
  "cal s1 eye 0 s2.run",
  "cal g big rate total",
  "cal g 2147483648 rate total",
  "cal g speed rate small",
  "var_input bits bool[4]\ncal s1 bits 0 lamp",
  "var_output bits bool[4]\ncal s1 eye 0 bits"
]

report.(42, rungs, &Logex.compile(tags <> &1, name: "wrong", types: [seal, gain]))
