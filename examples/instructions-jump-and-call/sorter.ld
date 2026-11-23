// The kicker runs while `auto` is 1. The tag `lane` selects the eye that it reads.
var_input  auto  bool
var_input  lane  dint
var_input  eyes  bool[2]
var_output kick  bool
var_output ran   bool
var        k     kicker

xic auto cal k eyes[lane] kick ote ran
