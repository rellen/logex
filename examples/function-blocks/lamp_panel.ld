var_input  test_pb bool
var_output lamp_1  bool
var_output lamp_2  bool
var l1 lamp_relay
var l2 lamp_relay

cal l1 test_pb lamp_1
xic l2.lamp ote lamp_2
