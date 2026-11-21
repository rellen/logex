// A gain: `y` is `x` times `k`.
function_block gain
var_input  x  dint
var_input  k  lreal
var_output y  lreal

mul x k y
