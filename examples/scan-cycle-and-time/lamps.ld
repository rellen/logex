var_input start bool
var_input stop bool
var_output ready_lamp bool
var_output start_lamp bool
var_output motor bool
var_output run_lamp bool

xio motor ote ready_lamp
( xic motor | xic start ote start_lamp ) xio stop ote motor
xic motor ote run_lamp
