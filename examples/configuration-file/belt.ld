var_input    start bool
var_input    stop  bool
var_output   motor bool
var_external estop bool

( xic start | xic motor ) xio stop xio estop ote motor
