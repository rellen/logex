var_input  hz       uint
var_input  level    dint
var_output speed    dint
var_output twice    uint
var_output twice_ok bool
var_output trim     sint
var_output trim_ok  bool

move hz speed
add hz hz twice ote twice_ok
dint_to_sint level trim ote trim_ok
