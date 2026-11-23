var_input  run       bool
var_input  error     dint
var_output fan       bool
var_output deviation dint

// on a false rung, ote writes 0 and abs writes nothing
xic run ote fan
xic run abs error deviation
