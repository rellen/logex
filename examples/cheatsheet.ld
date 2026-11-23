var_input start bool
var_input stop bool
var_input eye bool
var_output motor bool
var_output full bool
var delay ton
var boxes ctu

( xic start | xic motor ) xio stop ote motor
xic motor ton delay 2000
xic delay.dn xic eye ctu boxes 12
ge boxes.cv 10 ote full
