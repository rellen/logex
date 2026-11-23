var_input  start_1  bool
var_input  start_2  bool
var_input  stop     bool
var_input  eye_1    bool
var_input  eye_2    bool
var_output belt_1   bool
var_output belt_2   bool
var_output jam_1    bool
var_output jam_2    bool
var_output jam_lamp bool
var        c1       starter
var        c2       starter

cal c1 start_1 stop eye_1 belt_1 jam_1
cal c2 start_2 stop eye_2 belt_2 jam_2
( xic c1.jammed | xic c2.jammed ) ote jam_lamp
