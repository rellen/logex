// the photoelectric sensor of a conveyor: eye is 1 while a box is at the sensor
var_input  eye      bool
var_output new_box  bool
var_output box_in   bool
var_output eye_lamp bool
var_output box_out  bool
var        s1       bool
var        s2       bool
var        s3       bool

xic eye ons s1 ote new_box
xic eye osr s2 box_in ote eye_lamp
xic eye osf s3 box_out
