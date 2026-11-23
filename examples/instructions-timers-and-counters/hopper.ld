// a hopper that holds 3 portions: each portion subtracts 1 from the count
var_input  portion    bool
var_input  refill_pb  bool
var_output empty_lamp bool
var_output left       dint
var        hopper     ctd

xic refill_pb ote hopper.ld
xic portion ctd hopper 3
xic hopper.q ote empty_lamp
move hopper.cv left
