{cases, _} = Code.eval_file("instructions-arithmetic-and-comparison/cases.exs")

cases.(1, [
  {"add a_real b_real d_real ote ok", %{"a_real" => 16_777_216.0, "b_real" => 1.0}},
  {"add a_lreal b_lreal d_lreal ote ok", %{"a_lreal" => 16_777_216.0, "b_lreal" => 1.0}},
  {"mul a_real b_real d_real ote ok", %{"a_real" => 3.0e38, "b_real" => 10.0}},
  {"mul a_real b_real d_real ote ok", %{"a_real" => -3.0e38, "b_real" => 10.0}},
  {"add a_lreal b_lreal d_lreal ote ok", %{"a_lreal" => 1.0e308, "b_lreal" => 1.0e308}},
  {"mul a_real b_real d_real ote ok", %{"a_real" => 1.0e-30, "b_real" => 1.0e-30}},
  {"mul a_real b_real d_real ote ok", %{"a_real" => -1.0, "b_real" => 0.0}},
  {"div a_real b_real d_real ote ok", %{"a_real" => 1.0, "b_real" => 3.0}},
  {"div a_lreal b_lreal d_lreal ote ok", %{"a_lreal" => 1.0, "b_lreal" => 3.0}},
  {"div a_real b_real d_real ote ok", %{"a_real" => 7.0, "b_real" => 0.0}},
  {"div a_dint b_dint d_lreal ote ok", %{"a_dint" => 7, "b_dint" => 2}},
  {"add a_uint a_real d_real ote ok", %{"a_uint" => 65535, "a_real" => 0.5}},
  {"neg a_real d_real ote ok", %{"a_real" => -2.5}},
  {"abs a_real d_real ote ok", %{"a_real" => -2.5}},
  {"sqrt a_real d_real ote ok", %{"a_real" => 2.0}},
  {"sqrt a_lreal d_lreal ote ok", %{"a_lreal" => 2.0}},
  {"sqrt a_int d_real ote ok", %{"a_int" => 16}},
  {"sqrt a_real d_real ote ok", %{"a_real" => 0.0}},
  {"sqrt a_real d_real ote ok", %{"a_real" => -0.25}},
  {"xic go sqrt a_real d_real ote ok", %{"a_real" => 4.0, "go" => 0}}
])
