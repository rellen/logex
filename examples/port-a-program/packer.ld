var_input start_pb bool
var_input stop_pb bool
var_input eye bool
var_input reset_pb bool
var_output motor bool
var_output jam_lamp bool
var_output full_lamp bool
var need_reset bool 1
var jam_t ton
var retain boxes ctu

xic reset_pb otu need_reset
( xic start_pb | xic motor ) xio stop_pb xio need_reset ote motor
xic motor xic eye ton jam_t 5000
xic jam_t.dn ote jam_lamp
xic reset_pb ote boxes.r
xic eye ctu boxes 12
xic boxes.q ote full_lamp
