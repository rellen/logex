var_input flow dint
var_input setpoint dint
var_input minutes dint
var_input reset bool
var_output valve bool
var_output total dint
var_output total_ok bool
var_output per_minute dint
var_output overflow bool
var full bool

add total flow total ote total_ok
xio total_ok otl overflow
xic reset otu overflow
xic reset move 0 total
ge total setpoint ote full
xio full xio overflow ote valve
div total minutes per_minute
