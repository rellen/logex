var_input sel int
var_input go bool
var_output lamps word

ge sel 0 lt sel 16 xic go otl lamps.[sel]
ge sel 0 lt sel 16 xio go otu lamps.[sel]
