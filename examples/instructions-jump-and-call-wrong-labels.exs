{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")
tags = File.read!("instructions-jump-and-call/tags.txt")

rungs = [
  "xic eye jmp",
  "xic eye jmp 5",
  "xic eye jmp delay.dn",
  "xic eye jmp lanes[0]",
  "xic eye jmp bool",
  "xic eye jmp ote lamp",
  "xic eye jmp done done\nlbl done ote lamp",
  "lbl ote lamp"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong", types: [seal, gain]))
