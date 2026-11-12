var_input flow dint
var_input setpoint dint
var_input minutes dint
var_output valve bool
var_output total dint
var_output total_ok bool
var_output per_minute dint
var_output overflow bool
var full bool

add total flow total ote total_ok
xio total_ok otl overflow
ge total setpoint ote full
xio full ote valve
div total minutes per_minute
