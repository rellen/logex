{cases, _} = Code.eval_file("instructions-arithmetic-and-comparison/cases.exs")

cases.(1, [
  {"eq a_dint b_dint ote ok", %{"a_dint" => 3, "b_dint" => 3}},
  {"ne a_dint b_dint ote ok", %{"a_dint" => 3, "b_dint" => 3}},
  {"lt a_dint b_dint ote ok", %{"a_dint" => 2, "b_dint" => 3}},
  {"gt a_dint b_dint ote ok", %{"a_dint" => 2, "b_dint" => 3}},
  {"le a_dint b_dint ote ok", %{"a_dint" => 3, "b_dint" => 3}},
  {"ge a_dint b_dint ote ok", %{"a_dint" => 2, "b_dint" => 3}},
  {"lt a_sint a_udint ote ok", %{"a_sint" => -1, "a_udint" => 0}},
  {"gt a_ulint a_lint ote ok",
   %{"a_ulint" => 18_446_744_073_709_551_615, "a_lint" => 9_223_372_036_854_775_807}},
  {"eq a_real a_int ote ok", %{"a_real" => 1.0, "a_int" => 1}},
  {"eq a_real a_lreal ote ok", %{"a_real" => 0.1, "a_lreal" => 0.1}},
  {"eq a_real 0.1 ote ok", %{"a_real" => 0.1}},
  {"gt a_word a_byte ote ok", %{"a_word" => 65535, "a_byte" => 255}},
  {"eq a_word 16#00ff ote ok", %{"a_word" => 255}},
  {"xic go eq a_dint b_dint ote ok", %{"a_dint" => 3, "b_dint" => 3, "go" => 0}},
  {"eq d_array[slot] 0 ote ok", %{"slot" => -1}},
  {"eq 9007199254740993 9007199254740992 ote ok", %{}}
])
