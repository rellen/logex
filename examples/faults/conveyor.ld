// The conveyor runs at the speed of the zone that the operator sets.
var_input  run     bool
var_input  sel     int
var_input  set     bool
var_input  boxes   dint
var_input  minutes dint
var_output motor   bool
var_output speed   int
var_output rate    dint
var retain zone    int
var        speeds  int[4] 100 200 300 400

xic run ote motor
xic set move sel zone
move speeds[zone] speed
xic run div boxes minutes rate
