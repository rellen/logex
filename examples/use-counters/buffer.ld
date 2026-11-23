var_input infeed bool
var_input outfeed bool
var_input new_order bool
var_output buffer_full bool
var_output order_done bool
var buffer ctud
var order ctd

xic infeed ctu buffer 3
xic outfeed ctd buffer 3
xic buffer.qu ote buffer_full
xic new_order ote order.ld
xic outfeed ctd order 2
xic order.q ote order_done
