var_input start_pb bool
var_input eye bool
var_output step bool
var_output held_lamp bool
var_output box_left bool
var_output step_no dint
var s1 bool
var s2 bool

xic start_pb osr s1 step ote held_lamp
xic step add step_no 1 step_no
xic eye osf s2 box_left
