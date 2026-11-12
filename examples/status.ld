var_input  status   word
var_input  shift    sint
var_output at_speed bool
var_output low      word
var_output code     int
var_output moved    word
var_output moved_ok bool
var_output flags    word
var_output slow     bool
var_output slow_w   word

xic status.3 ote at_speed
not at_speed slow
not at_speed slow_w
and status 16#00ff low
word_to_int status code
shl status shift moved ote moved_ok
move status flags
xic at_speed otl flags.15
