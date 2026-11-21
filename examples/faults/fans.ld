// 2 fans. `f2` runs while `auto` is 1, and `fan` selects its pressure.
var_input  p_1     real
var_input  auto    bool
var_input  fan     int
var_input  ps      real[2]
var_output speed_1 real
var_output ok_1    bool
var_output ran_1   bool
var_output speed_2 real
var_output ok_2    bool
var_output ran_2   bool
var        f1      fan_speed
var        f2      fan_speed

cal f1 p_1 speed_1 ok_1 ote ran_1
xic auto cal f2 ps[fan] speed_2 ok_2 ote ran_2
