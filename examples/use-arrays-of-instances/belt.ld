function_block belt
var_input  start bool
var_input  stop  bool
var_input  jam   bool
var_output run   bool

( xic start | xic run ) xio stop xio jam ote run
