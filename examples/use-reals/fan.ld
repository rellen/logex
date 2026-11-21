var_input hz real
var_output speed real
var_output precise lreal
var_output root real
var_output root_ok bool
var_output rpm int
var_output rpm_ok bool
var_output whole int
var_output whole_ok bool

mul hz 60.0 speed
mul hz 60.0 precise
sqrt hz root ote root_ok
real_to_int speed rpm ote rpm_ok
real_trunc_int speed whole ote whole_ok
