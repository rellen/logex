// A lamp relay. No rung uses `spare`, and logex gives a warning.
function_block lamp_relay
var_input  on    bool
var_output lamp  bool
var        spare bool

xic on ote lamp
