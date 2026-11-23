// A fan with an input of each kind: a bool, 2 integers, a real and an array.
var_input  run    bool
var_input  level  usint
var_input  trim   int
var_input  hz     real
var_input  limits int[3]
var_output fan    bool
var_output fan_hz real
var_output steps  int[3]
var t1 ton

xic run ton t1 500
xic t1.dn ote fan
mul hz 2.0 fan_hz
move limits[0] steps[0]
add limits[1] trim steps[1]
move level steps[2]
