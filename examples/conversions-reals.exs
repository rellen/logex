{cases, _} = Code.eval_file("conversions/cases.exs")

cases.(1, [
  {"real_to_int a_real d_int ote ok", %{"a_real" => 2.5}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => 3.5}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => -2.5}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => -2.7}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => -1.6}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => 37.9}},
  {"real_to_int a_real d_int ote ok", %{"a_real" => 40000.7}},
  {"real_to_usint a_real d_usint ote ok", %{"a_real" => -0.5}},
  {"real_to_usint a_real d_usint ote ok", %{"a_real" => -1.0}},
  {"lreal_to_dint a_lreal d_dint ote ok", %{"a_lreal" => 2_147_483_647.5}},
  {"dint_to_real a_dint d_real ote ok", %{"a_dint" => 16_777_217}},
  {"lint_to_lreal a_lint d_lreal ote ok", %{"a_lint" => 9_007_199_254_740_993}},
  {"ulint_to_real a_ulint d_real ote ok", %{"a_ulint" => 18_446_744_073_709_551_615}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 1.0e300}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => -1.0e300}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 1.0e-300}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 0.1}},
  {"real_to_lreal a_real d_lreal ote ok", %{"a_real" => 0.1}},
  {"real_to_int a_int d_int ote ok", %{"a_int" => -5}},
  {"lreal_to_int a_real d_int ote ok", %{"a_real" => 2.5}},
  {"xic go real_to_int a_real d_int ote ok", %{"a_real" => 2.5, "go" => 0}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 3.4028235e38}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 1.1754943e-38}},
  {"lreal_to_real a_lreal d_real ote ok", %{"a_lreal" => 1.1754942e-38}}
])
