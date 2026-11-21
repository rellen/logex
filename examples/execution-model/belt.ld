var_input  start      bool
var_input  stop       bool
var_input  eye        bool
var_output ready_lamp bool
var_output belt       bool
var_output held       bool
var_output box_seen   bool
var_output box_lamp   bool

xio belt ote ready_lamp
( xic start | xic belt ote held ) xio stop ote belt
( xic eye ote box_seen | xic box_seen ote box_lamp )
