// a buffer table between 2 conveyors: stock is the number of boxes on the table
var_input  infeed       bool
var_input  outfeed      bool
var_input  clear_pb     bool
var_output buffer_full  bool
var_output buffer_empty bool
var        stock        ctud

xic clear_pb ote stock.r
xic infeed ctu stock 3
xic outfeed ctd stock 3
xic stock.qu ote buffer_full
xic stock.qd ote buffer_empty
