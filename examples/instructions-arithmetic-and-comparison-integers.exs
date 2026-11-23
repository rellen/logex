{cases, _} = Code.eval_file("instructions-arithmetic-and-comparison/cases.exs")

cases.(1, [
  {"add a_dint b_dint d_dint ote ok", %{"a_dint" => 2, "b_dint" => 3}},
  {"add a_dint b_dint d_dint ote ok", %{"a_dint" => 2_147_483_647, "b_dint" => 1}},
  {"sub a_dint b_dint d_dint ote ok", %{"a_dint" => -2_147_483_648, "b_dint" => 1}},
  {"mul a_dint b_dint d_dint ote ok", %{"a_dint" => 65536, "b_dint" => 65536}},
  {"add a_sint b_sint d_sint ote ok", %{"a_sint" => 127, "b_sint" => 1}},
  {"sub a_usint b_usint d_usint ote ok", %{"a_usint" => 0, "b_usint" => 1}},
  {"add a_ulint b_ulint d_ulint ote ok",
   %{"a_ulint" => 18_446_744_073_709_551_615, "b_ulint" => 1}},
  {"add a_int a_int d_dint ote ok", %{"a_int" => 32767}},
  {"add a_sint a_usint d_int ote ok", %{"a_sint" => -128, "a_usint" => 255}},
  {"div a_dint b_dint d_dint ote ok", %{"a_dint" => -7, "b_dint" => 2}},
  {"mod a_dint b_dint d_dint ote ok", %{"a_dint" => -7, "b_dint" => 3}},
  {"mod a_dint b_dint d_dint ote ok", %{"a_dint" => 7, "b_dint" => -3}},
  {"div a_dint b_dint d_dint ote ok", %{"a_dint" => 7, "b_dint" => 0}},
  {"mod a_dint b_dint d_dint ote ok", %{"a_dint" => 7, "b_dint" => 0}},
  {"div a_dint b_dint d_dint ote ok", %{"a_dint" => -2_147_483_648, "b_dint" => -1}},
  {"mod a_dint b_dint d_dint ote ok", %{"a_dint" => -2_147_483_648, "b_dint" => -1}},
  {"neg a_dint d_dint ote ok", %{"a_dint" => 5}},
  {"neg a_dint d_dint ote ok", %{"a_dint" => -2_147_483_648}},
  {"abs a_dint d_dint ote ok", %{"a_dint" => -5}},
  {"abs a_dint d_dint ote ok", %{"a_dint" => -2_147_483_648}},
  {"neg a_uint d_dint ote ok", %{"a_uint" => 65535}},
  {"abs a_usint d_uint ote ok", %{"a_usint" => 200}},
  {"xic go add a_dint b_dint d_dint ote ok", %{"a_dint" => 2, "b_dint" => 3, "go" => 0}},
  {"add d_array[slot] 1 d_dint ote ok", %{"slot" => 3}}
])
