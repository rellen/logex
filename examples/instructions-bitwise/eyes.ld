var_input  eyes    byte
var_input  step    bool
var_output changed byte
var_output alarms  byte
var_output lamps   byte 2#1000_0001
var        last    byte
var        stepped bool

xor eyes last changed
or alarms changed alarms
move eyes last
xic step ons stepped rol lamps 1 lamps
