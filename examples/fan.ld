var_input  hz      real
var_output speed   real
var_output precise lreal
var_output rpm     int
var_output whole   int
var_output root    real
var_output root_ok bool

// the fan's speed in revolutions a minute, in a real and in an lreal
mul hz 60.0 speed
mul hz 60.0 precise
real_to_int speed rpm
real_trunc_int speed whole
sqrt hz root ote root_ok
