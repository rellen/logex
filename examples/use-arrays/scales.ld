var_input eye bool
var_input weight int
var_input slot int
var_input clear bool
var_output slot_ok bool
var_output last int
var_output full bool[8]
var weights int[8]
var edge bool
var box bool

xic eye ons edge ote box
ge slot 0 lt slot 8 ote slot_ok
xic slot_ok xic box move weight weights[slot]
xic slot_ok xic box otl full[slot]
xic slot_ok xic clear otu full[slot]
xic slot_ok move weights[slot] last
