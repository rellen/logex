{cases, _} = Code.eval_file("instructions-bitwise/cases.exs")

cases.(1, [
  {"shl a_byte 3 d_byte ote ok", %{"a_byte" => 0b0001_1001}},
  {"shr a_byte 3 d_byte ote ok", %{"a_byte" => 0b0001_1001}},
  {"rol a_byte 3 d_byte ote ok", %{"a_byte" => 0b0001_1001}},
  {"ror a_byte 3 d_byte ote ok", %{"a_byte" => 0b0001_1001}},
  {"shr a_int 1 d_int ote ok", %{"a_int" => -2}},
  {"shl a_dint 31 d_dint ote ok", %{"a_dint" => 1}},
  {"shr a_sint 1 d_int ote ok", %{"a_sint" => -2}},
  {"shl a_byte 1 d_word ote ok", %{"a_byte" => 0b1001_0001}},
  {"rol a_byte 1 d_word ote ok", %{"a_byte" => 0b1001_0001}},
  {"shl a_byte 0 d_byte ote ok", %{"a_byte" => 0b1001_0001}},
  {"shl a_byte 8 d_byte ote ok", %{"a_byte" => 0b1111_1111}},
  {"rol a_byte 9 d_byte ote ok", %{"a_byte" => 0b1001_0001}},
  {"rol a_word n_int d_word ote ok", %{"a_word" => 0x8001, "n_int" => 17}},
  {"shl a_byte n_ulint d_byte ote ok", %{"a_byte" => 1, "n_ulint" => 18_446_744_073_709_551_615}},
  {"rol a_byte n_ulint d_byte ote ok", %{"a_byte" => 1, "n_ulint" => 18_446_744_073_709_551_615}},
  {"shl a_word n_int d_word ote ok", %{"a_word" => 0x00FF, "n_int" => -1}},
  {"ror a_word n_int d_word ote ok", %{"a_word" => 0x0019, "n_int" => -3}},
  {"shl a_bool 1 d_bool ote ok", %{"a_bool" => 1}},
  {"rol a_bool 5 d_bool ote ok", %{"a_bool" => 1}},
  {"shl a_bool 3 d_word ote ok", %{"a_bool" => 1}},
  {"shl 1 15 d_int ote ok", %{}},
  {"shr -4 1 d_int ote ok", %{}},
  {"xic go shl a_byte 1 d_byte ote ok", %{"a_byte" => 1, "go" => 0}},
  {"shl a_word.[slot] 0 d_bool ote ok", %{"a_word" => 0x0008, "slot" => -1}}
])
