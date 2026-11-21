{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-bitwise/tags.txt")

rungs = [
  "xic a_word.16 ote ok",
  "xic a_sint.8 ote ok",
  "xic a_word.[16#10] ote ok",
  "xic a_word.[-1] ote ok",
  "xic a_bool.0 ote ok",
  "xic a_real.0 ote ok",
  "xic d_array.3 ote ok",
  "xic d_array[0].16 ote ok",
  "xic delay.dn.0 ote ok",
  "xic delay.acc.32 ote ok",
  "xic d_word.3.1 ote ok",
  "xic a_word.[n_word] ote ok",
  "xic a_word.[a_bool] ote ok",
  "xic a_word.[a_real] ote ok",
  "xic a_word.[boxes] ote ok",
  "xic go ote a_word.3",
  "xic go ote boxes.cv.0",
  "move a_word.[slot] d_dint",
  "eq a_word.1 1 ote ok",
  "add a_word.3 1 d_dint",
  "xic go ons d_word.[slot] ote ok",
  "xic go osr d_word.3 d_word.[slot]",
  "xic go ons delay.pre.2 ote ok"
]

report.(37, rungs, &Logex.compile(tags <> &1, name: "wrong"))
