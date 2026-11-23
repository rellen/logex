// line.ld -- the conveyor, its fan, the box counter, the lamp and the lube timer
var_input start bool
var_input stop bool
var_input eye bool
var_output motor bool
var_output fan bool
var_output retain full bool
var retain boxes ctu
var retain lube rto
var retain run_on tof

( xic start | xic motor ) xio stop ote motor
xic motor tof run_on 5000
xic run_on.dn ote fan
xic eye ctu boxes 2
xic boxes.q otl full
xic motor rto lube 360000000
