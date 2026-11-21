// A fan speed: `speed` is the square root of `pressure`.
function_block fan_speed
var_input  pressure real
var_output speed    real
var_output ok       bool

sqrt pressure speed ote ok
