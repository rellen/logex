// The fan: it runs while its switch is on and the motor is hot.
var_input fan_on bool
var_input hot bool
var_output fan bool
var_output speed int 900

xic fan_on xic hot ote fan
