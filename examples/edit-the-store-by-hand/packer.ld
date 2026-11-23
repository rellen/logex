// packer.ld -- the weight of each box in its place in a case, places 0 to 7
var_input  weight  int
var_input  eye     bool
var retain place   dint
var retain weights int[8]
var e bool

// the scale is under the place: its weight goes to that place
move weight weights[place]
// the eye sees the box leave: the next box goes to the next place
xic eye ons e add place 1 place
