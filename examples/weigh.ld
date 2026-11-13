var_input  load    int
var_input  pick    bool
var_output heavy   bool
var_output fourth  int
var weights int[4]
var grid    int[2,8]
var edges   bool[1]
var shift   bool

// the last four weights, newest first, shifted along on each pick
xic pick ons edges[0] ote shift
xic shift move weights[2] weights[3]
xic shift move weights[1] weights[2]
xic shift move weights[0] weights[1]
xic shift move load weights[0]
xic shift move weights[3] grid[1,7]
gt weights[3] 500 ote heavy
move grid[1,7] fourth
