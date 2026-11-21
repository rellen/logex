var_input x real
var_output up int
var_output down int

real_trunc_int x up
lt up x add up 1 up
real_trunc_int x down
gt down x sub down 1 down
