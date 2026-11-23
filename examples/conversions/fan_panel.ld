var_input  hz         real
var_input  status     word
var_input  boxes      dint
var_output rpm        int
var_output rpm_ok     bool
var_output whole      int
var_output code       int
var_output shown      sint
var_output shown_ok   bool
var        speed      real

// the fan's speed in revolutions a minute, in 2 int tags
mul hz 60.0 speed
real_to_int speed rpm ote rpm_ok
real_trunc_int speed whole
// the drive's status word as a number
word_to_int status code
// the box count in 8 bits, for the panel
dint_to_sint boxes shown ote shown_ok
