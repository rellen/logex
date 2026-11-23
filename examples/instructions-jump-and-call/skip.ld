// While `hold` is 1, the jump skips rungs 2 to 6.
var_input  hold   bool
var_input  eye    bool
var_input  rate   dint
var_output lamp   bool
var_output kick   bool
var_output share  dint
var        boxes  ctu
var        dwell  ton
var        seen   bool

xic hold jmp held
xic eye ote lamp
xic eye ctu boxes 100
xic eye ton dwell 300
xic eye osr seen kick
div 100 rate share
lbl held
