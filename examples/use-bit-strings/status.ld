var_input status word
var_input run bool
var_input sel int
var_output at_speed bool
var_output flags word
var_output error word
var_output code uint
var_output command word
var_output lamp bool

xic status.3 ote at_speed
and status 16#00ff flags
shr status 8 error
word_to_uint error code
xic run ote command.0
ge sel 0 lt sel 16 xic status.[sel] ote lamp
