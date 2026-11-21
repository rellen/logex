{cases, _} = Code.eval_file("instructions-bitwise/cases.exs")

cases.(1, [
  {"and a_byte b_byte d_byte ote ok", %{"a_byte" => 0b1100_1010, "b_byte" => 0b0000_1111}},
  {"or a_byte b_byte d_byte ote ok", %{"a_byte" => 0b1100_1010, "b_byte" => 0b0000_1111}},
  {"xor a_byte b_byte d_byte ote ok", %{"a_byte" => 0b1100_1010, "b_byte" => 0b0000_1111}},
  {"and a_sint 16#0f d_sint ote ok", %{"a_sint" => -1}},
  {"and a_int a_usint d_int ote ok", %{"a_int" => -1, "a_usint" => 200}},
  {"or a_byte a_word d_word ote ok", %{"a_byte" => 0xFF, "a_word" => 0x1200}},
  {"or a_bool a_word d_word ote ok", %{"a_bool" => 1, "a_word" => 0x1200}},
  {"and a_bool b_bool d_bool ote ok", %{"a_bool" => 1, "b_bool" => 1}},
  {"xor a_word a_word d_word ote ok", %{"a_word" => 0x1234}},
  {"and a_word.3 a_bool d_word.4 ote ok", %{"a_word" => 0x0008, "a_bool" => 1}},
  {"or a_dint 16#0f00 delay.pre move delay.pre d_dint ote ok", %{"a_dint" => 1}},
  {"xic go and a_byte b_byte d_byte ote ok", %{"a_byte" => 1, "b_byte" => 1, "go" => 0}},
  {"and a_word 16#00ff d_array[slot] ote ok", %{"a_word" => 0x1234, "slot" => 3}}
])
