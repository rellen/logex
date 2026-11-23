var_input  eye      bool
var_input  weight   int
var_input  product  int
var_external estop  bool
var_output motor    bool
var_output heavy    bool
var_output speed_sp dint 1200
var_output retain cases udint 0
var        tare     int -120
var        net      int
var        limits   int[2,3] 300 500 800 400 600 900
var retain boxes    ctu
var non_retain edge bool

// the conveyor runs if the e-stop is not pressed
xio estop ote motor
xic estop move 0 speed_sp
// a box is heavy if its net weight is more than the middle limit of its product
add weight tare net
gt net limits[product,1] ote heavy
// 12 boxes fill 1 case
xic boxes.q ote boxes.r
xic eye ctu boxes 12
xic boxes.q ons edge add cases 1 cases
