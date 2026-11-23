var_input  start bool
var_input  stop  bool
var_input  eye   bool[4]
var_output motor bool
var_output lamp  bool[4]

// the motor of the conveyor, with a seal-in
( xic start | xic motor ) xio stop ote motor
// a lamp for each lane that has a box at its photo-eye
xic eye[0] ote lamp[0]
xic eye[1] ote lamp[1]
xic eye[2] ote lamp[2]
xic eye[3] ote lamp[3]
