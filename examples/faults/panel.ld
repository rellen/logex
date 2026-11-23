// The panel of the line. Each rung can find 1 of the 4 faults.
var_input  boxes      dint
var_input  minutes    dint
var_input  pressure   real
var_input  drive      word
var_input  sel        int
var_input  zone       int
var_output per_minute dint
var_output rate_ok    bool
var_output fan_speed  real
var_output fan_ok     bool
var_output lamp       bool
var_output belt_sp    int
var_output belt_ok    bool
var        speeds     int[4] 100 200 300 400

// the box counter: the boxes in each minute
div boxes minutes per_minute ote rate_ok
// the fan: its speed is the square root of the pressure
sqrt pressure fan_speed ote fan_ok
// the lamp: the bit of the status word of the drive that sel selects
xic drive.[sel] ote lamp
// the conveyor: the speed of its zone
move speeds[zone] belt_sp ote belt_ok
