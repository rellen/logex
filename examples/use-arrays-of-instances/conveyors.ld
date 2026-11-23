var_input  start   bool
var_input  stop    bool
var_input  eye     bool[3]
var_input  view    int
var_output motor   bool[3]
var_output view_ok bool
var_output count   dint
var_output jammed  bool
var jam   ton[3]
var boxes ctu[3]
var belts belt[3]

xic eye[0] ton jam[0] 2000
xic eye[1] ton jam[1] 2000
xic eye[2] ton jam[2] 2000
xic eye[0] ctu boxes[0] 1000
xic eye[1] ctu boxes[1] 1000
xic eye[2] ctu boxes[2] 1000
cal belts[0] start stop jam[0].dn motor[0]
cal belts[1] start stop jam[1].dn motor[1]
cal belts[2] start stop jam[2].dn motor[2]
ge view 0 lt view 3 ote view_ok
xic view_ok move boxes[view].cv count
xic view_ok xic jam[view].dn ote jammed
