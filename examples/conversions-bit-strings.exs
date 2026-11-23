{cases, _} = Code.eval_file("conversions/cases.exs")

cases.(1, [
  {"word_to_int a_word d_int ote ok", %{"a_word" => 0xFFFF}},
  {"int_to_word a_int d_word ote ok", %{"a_int" => -1}},
  {"int_to_dword a_int d_dword ote ok", %{"a_int" => -1}},
  {"word_to_dint a_word d_dint ote ok", %{"a_word" => 0x8000}},
  {"word_to_uint a_word d_uint ote ok", %{"a_word" => 0xFFFF}},
  {"dword_to_word a_dword d_word ote ok", %{"a_dword" => 0x12345678}},
  {"dint_to_word a_dint d_word ote ok", %{"a_dint" => 70000}},
  {"lword_to_sint a_lword d_sint ote ok", %{"a_lword" => 0x80}},
  {"byte_to_word a_byte d_word ote ok", %{"a_byte" => 0xFF}},
  {"word_to_byte a_word d_byte ote ok", %{"a_word" => 0x01FF}},
  {"int_to_word a_sint d_word ote ok", %{"a_sint" => -1}},
  {"byte_to_word a_bool d_word ote ok", %{"a_bool" => 1}},
  {"byte_to_word a_word.[slot] d_word ote ok", %{"a_word" => 0x0008, "slot" => 3}},
  {"byte_to_word a_word.[slot] d_word ote ok", %{"a_word" => 0x0008, "slot" => 16}},
  {"xic go word_to_int a_word d_int ote ok", %{"a_word" => 0x0005, "go" => 0}},
  {"byte_to_int a_bool d_int ote ok", %{"a_bool" => 1}}
])
