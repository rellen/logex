var_input door_shut bool
var_output cured bool
var_output fan bool
var_output cure_ns lint
var cure ton_ltime
var run_on tof_ltime

xic door_shut ton cure 129600000000000
xic cure.dn ote cured
xic door_shut tof run_on 90000000000
xic run_on.dn ote fan
move cure.acc cure_ns
