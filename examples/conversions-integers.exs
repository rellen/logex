{cases, _} = Code.eval_file("conversions/cases.exs")

cases.(1, [
  {"dint_to_sint a_dint d_sint ote ok", %{"a_dint" => 100}},
  {"dint_to_sint a_dint d_sint ote ok", %{"a_dint" => 129}},
  {"dint_to_sint a_dint d_sint ote ok", %{"a_dint" => -129}},
  {"int_to_uint a_int d_uint ote ok", %{"a_int" => -1}},
  {"uint_to_int a_uint d_int ote ok", %{"a_uint" => 40000}},
  {"sint_to_usint a_sint d_usint ote ok", %{"a_sint" => -1}},
  {"lint_to_dint a_lint d_dint ote ok", %{"a_lint" => 4_294_967_297}},
  {"ulint_to_lint a_ulint d_lint ote ok", %{"a_ulint" => 18_446_744_073_709_551_615}},
  {"sint_to_dint a_sint d_dint ote ok", %{"a_sint" => -5}},
  {"dint_to_int a_sint d_int ote ok", %{"a_sint" => -5}},
  {"dint_to_int a_usint d_int ote ok", %{"a_usint" => 200}},
  {"DINT_TO_INT a_dint d_int ote ok", %{"a_dint" => 7}},
  {"xic go dint_to_sint a_dint d_sint ote ok", %{"a_dint" => 5, "go" => 0}},
  {"dint_to_int a_dint d_array[slot] ote ok", %{"a_dint" => 7, "slot" => 2}},
  {"dint_to_int a_dint d_array[slot] ote ok", %{"a_dint" => 7, "slot" => 3}},
  {"dint_to_sint 129 d_sint ote ok", %{}},
  {"dint_to_int a_dint d_int dint_to_sint d_int d_sint ote ok", %{"a_dint" => 300}}
])
