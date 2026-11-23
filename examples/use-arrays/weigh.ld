var_input eye bool
var_input weight int
var_output good bool
var_output heavy bool
var_output weights int[4]
var limits int[2] 100 500
var edge bool
var box bool

xic eye ons edge ote box
xic box move weights[2] weights[3]
xic box move weights[1] weights[2]
xic box move weights[0] weights[1]
xic box move weight weights[0]
ge weights[0] limits[0] le weights[0] limits[1] ote good
gt weights[0] limits[1] ote heavy
