{cases, _} = Code.eval_file("instructions-bitwise/cases.exs")

cases.(1, [
  {"xic a_word.3 ote d_bool", %{"a_word" => 0x0008}},
  {"xic a_word.[16#3] ote d_bool", %{"a_word" => 0x0008}},
  {"xic a_int.15 ote d_bool", %{"a_int" => -1}},
  {"xic go otl d_int.15", %{"go" => 1}},
  {"move a_word d_word xic go otu d_word.3", %{"a_word" => 0xFFFF, "go" => 1}},
  {"move a_dint boxes.pv xic boxes.pv.3 ote d_bool", %{"a_dint" => 8}},
  {"xic go ote d_array[1].[slot]", %{"go" => 1, "slot" => 2}},
  {"xic a_word.[slot] ote d_bool", %{"a_word" => 0x0010, "slot" => 4}},
  {"xic a_word.[slot] ote d_bool", %{"a_word" => 0xFFFF, "slot" => 16}},
  {"xio a_word.[slot] ote d_bool", %{"a_word" => 0xFFFF, "slot" => 16}},
  {"xic go xic a_word.[slot] ote d_bool", %{"go" => 0, "slot" => 16}},
  {"xic go ote d_word.[slot]", %{"go" => 0, "slot" => 16}},
  {"xic go otl d_word.[slot]", %{"go" => 0, "slot" => 16}}
])
