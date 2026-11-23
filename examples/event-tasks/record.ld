var_input motor bool
var_input stop bool
var_output motor_was bool
var_output stops dint
var presses ctu
var held ton
var s1 bool
var pressed bool

xic motor ote motor_was
xic stop ctu presses 1000
move presses.cv stops
xic stop osr s1 pressed
xic stop ton held 60000
