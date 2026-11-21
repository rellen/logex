var_input belt_1 int
var_input belt_2 int
var_input slot int
var_output total dint
var_output total_ok bool
var_output total_int int
var_output total_int_ok bool
var_output weight int
var_output checked int
var weights int[8] 410 380 520 0 0 0 0 0

add belt_1 belt_2 total ote total_ok
add belt_1 belt_2 total_int ote total_int_ok
move weights[slot] weight
ge slot 0 lt slot 8 move weights[slot] checked
