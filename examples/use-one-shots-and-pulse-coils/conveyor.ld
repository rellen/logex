var_input index_pb bool
var_input eye bool
var_output held_lamp bool
var_output index bool
var_output position dint
var_output boxes dint
var_output box_left bool
var s1 bool
var s2 bool
var s3 bool

xic index_pb osr s1 index ote held_lamp
xic index add position 1 position
xic eye ons s2 add boxes 1 boxes
xic eye osf s3 box_left
