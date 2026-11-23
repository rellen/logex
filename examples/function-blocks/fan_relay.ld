// A fan relay: `fan` runs while `motor` runs, and for 5 s after it stops.
function_block fan_relay
var_input  motor  bool
var_output fan    bool
var        run_on tof

xic motor tof run_on 5000
xic run_on.dn ote fan
