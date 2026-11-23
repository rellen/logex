{cases, _} = Code.eval_file("conversions/cases.exs")

cases.(1, [
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => 2.5}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => 3.5}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => -2.5}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => -2.7}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => -1.6}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => 37.9}},
  {"real_trunc_int a_real d_int ote ok", %{"a_real" => 40000.7}},
  {"real_trunc_usint a_real d_usint ote ok", %{"a_real" => -0.9}},
  {"real_trunc_usint a_real d_usint ote ok", %{"a_real" => -1.5}},
  {"lreal_trunc_dint a_lreal d_dint ote ok", %{"a_lreal" => 2_147_483_647.9}},
  {"lreal_trunc_int a_real d_int ote ok", %{"a_real" => 7.75}},
  {"real_trunc_int a_int d_int ote ok", %{"a_int" => 7}},
  {"xic go real_trunc_int a_real d_int ote ok", %{"a_real" => 5.0, "go" => 0}}
])
