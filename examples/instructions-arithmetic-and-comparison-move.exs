{cases, _} = Code.eval_file("instructions-arithmetic-and-comparison/cases.exs")

cases.(1, [
  {"move a_dint d_dint ote ok", %{"a_dint" => -5}},
  {"move a_uint d_dint ote ok", %{"a_uint" => 65535}},
  {"move a_int d_real ote ok", %{"a_int" => -32768}},
  {"move a_real d_lreal ote ok", %{"a_real" => 0.1}},
  {"move a_bool d_word ote ok", %{"a_bool" => 1}},
  {"move 16#ffff d_dint ote ok", %{}},
  {"move 0.1 d_real ote ok", %{}},
  {"move 1 d_bool ote ok", %{}},
  {"xic go move a_dint d_dint ote ok", %{"a_dint" => 7, "go" => 0}},
  {"move a_word.3 d_bool ote ok", %{"a_word" => 8}},
  {"move a_dint d_array[slot] ote ok", %{"a_dint" => 7, "slot" => 3}},
  {"move a_word.[slot] d_bool ote ok", %{"a_word" => 8, "slot" => 16}}
])
