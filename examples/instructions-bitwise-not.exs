{cases, _} = Code.eval_file("instructions-bitwise/cases.exs")

cases.(1, [
  {"not a_byte d_byte ote ok", %{"a_byte" => 0b0000_1111}},
  {"not a_word d_word ote ok", %{"a_word" => 0x00FF}},
  {"not a_int d_int ote ok", %{"a_int" => 0}},
  {"not a_bool d_bool ote ok", %{"a_bool" => 1}},
  {"not a_bool d_word ote ok", %{"a_bool" => 1}},
  {"not a_bool d_word ote ok", %{"a_bool" => 0}},
  {"not a_byte d_word ote ok", %{"a_byte" => 0b0000_1111}},
  {"not a_usint d_int ote ok", %{"a_usint" => 5}},
  {"not a_sint d_int ote ok", %{"a_sint" => 5}},
  {"not a_sint d_dint ote ok", %{"a_sint" => -1}},
  {"not 0 d_word ote ok", %{}},
  {"xic go not a_byte d_byte ote ok", %{"a_byte" => 0b0000_1111, "go" => 0}}
])
