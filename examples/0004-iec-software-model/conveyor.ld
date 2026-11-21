// A conveyor: its motor runs from start until stop or the shared e-stop.
var_input start bool
var_input stop bool
var_output motor bool
var_external estop bool
var halt bool
var s1 seal

( xic stop | xic estop ) ote halt
cal s1 start halt motor
