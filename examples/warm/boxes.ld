var_input eye bool
var_input reset_pb bool
var_output full_lamp bool
var_output count dint
var retain boxes ctu

xic reset_pb ote boxes.r
xic eye ctu boxes 3
xic boxes.q ote full_lamp
move boxes.cv count
