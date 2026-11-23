var_input  eye       bool
var_output count     dint
var_output pulse     bool
var_output first_out bool
var retain boxes ctu
var edge  bool
var first bool 1

xic eye ctu boxes 100
xic eye ons edge ote pulse
move boxes.cv count
xic first ote first_out
otu first
