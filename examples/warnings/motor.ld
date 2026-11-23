// 2 rungs write the coil motor. The second rung decides the value of motor.
var_input  start bool
var_input  jog   bool
var_output motor bool

xic start ote motor
xic jog   ote motor
