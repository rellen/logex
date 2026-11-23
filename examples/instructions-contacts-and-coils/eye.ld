// the photoelectric sensor of a conveyor: eye is 1 while a box is at the sensor
var_input  eye        bool
var_input  reset_pb   bool
var_output box_lamp   bool
var_output clear_lamp bool
var_output box_seen   bool

xic eye ote box_lamp
xio eye ote clear_lamp
xic eye otl box_seen
xic reset_pb otu box_seen
