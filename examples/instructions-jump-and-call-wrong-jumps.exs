{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")
tags = File.read!("instructions-jump-and-call/tags.txt")

rungs = [
  "lbl top xic eye ote lamp\nxic eye jmp top",
  "lbl top xic eye jmp top ote lamp",
  "xic eye jmp done",
  "xic eye jmp dne\nlbl done ote lamp",
  "xic eye jmp Done\nlbl done ote lamp",
  "xic eye jmp done\nxic skip lbl done ote lamp",
  "xic eye jmp done\n( lbl done | xic skip ) ote lamp",
  "xic eye jmp done\nlbl done ote lamp\nlbl done ote belt",
  "xic eye jmp done\nlbl Done ote lamp\nlbl done ote belt",
  "xic eye jmp done jmp done\nlbl done ote lamp",
  "( xic eye jmp done | xic skip jmp done ) ote lamp\nlbl done",
  "xic eye ton delay 100 jmp done\nlbl done",
  "xic eye ote lamp\nlbl done",
  "xic eye jmp done\nlbl done xic skip"
]

report.(9, rungs, &Logex.compile(tags <> &1, name: "wrong", types: [seal, gain]))
