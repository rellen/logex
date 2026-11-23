var_input run bool
var_input status word
var_input temps real[4]
var_input slot int
var_output fan bool
var_output alarm bool
var_output speed real
var t1 ton

xic run ton t1 3000
xic t1.dn ote fan
xic status.3 ote alarm
gt temps[slot] 40.0 move 75.5 speed
xic fan gt temps[2] 16#3c otl alarm
