var_input eye bool
var_input motor bool
var_output full_lamp bool
var retain boxes ctu
var seen ctu
var retain lube rto

xic eye ctu boxes 3
xic eye ctu seen 1000
xic boxes.q ote full_lamp
xic motor rto lube 60000
