{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt") <> "var        horn   alarm\n"
{:ok, alarm} = Logex.compile_file("instructions-contacts-and-coils/alarm.ld")

rungs = [
  "xic eye ote horn.go",
  "xic eye otl horn.on",
  "xic horn.held ote lamp",
  "xic eye ons horn.on ote lamp",
  "xic eye osr s1 horn.on"
]

report.(21, rungs, &Logex.compile(tags <> &1, name: "wrong", types: [alarm]))
