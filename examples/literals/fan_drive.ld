var_input  eye     bool
var_input  status  word
var_input  hz      real
var_output fault   bool
var_output fast    bool
var_output jam     bool
var_output rpm     real
var_output trim    int
var        mask    word 16#00ff
var        code    word
var        blocked ton

// the low byte of the status word is the fault code of the fan drive
and status mask code
eq code 2#0000_0101 ote fault
// the fan turns 60 times in 1 minute for each Hz
mul hz 60.0 rpm
gt rpm 1.5e3 ote fast
xic fast move -120 trim
xio fast move 0 trim
// a box that stays at the eye for 30 s is a jam
xic blocked.dn ote jam
xic eye ton blocked 30_000
