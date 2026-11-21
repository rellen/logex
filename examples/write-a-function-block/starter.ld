// A conveyor starter: `run` holds itself in from `start` until `stop`,
// or until the photo-eye `eye` stays blocked for 2 s.
function_block starter
var_input  start  bool
var_input  stop   bool
var_input  eye    bool
var_output run    bool
var_output jammed bool
var        jam_t  ton

xic eye ton jam_t 2000
xic jam_t.dn ote jammed
( xic start | xic run ) xio stop xio jammed ote run
