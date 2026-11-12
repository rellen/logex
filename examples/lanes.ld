var_input  eye    bool[4]
var_input  lane   int
var_output kick   bool[4]
var_output count  int
var_output held   bool
var lane_t ton[4]
var lane_c ctu_int[4]
var gates  gate[4]

xic eye[0] ton lane_t[0] 30
xic eye[1] ton lane_t[1] 30
xic eye[2] ton lane_t[2] 30
xic eye[3] ton lane_t[3] 30
xic lane_t[0].dn ctu lane_c[0] 3
xic lane_t[1].dn ctu lane_c[1] 3
xic lane_t[2].dn ctu lane_c[2] 3
xic lane_t[3].dn ctu lane_c[3] 3
cal gates[0] lane_c[0].q kick[0]
cal gates[1] lane_c[1].q kick[1]
cal gates[2] lane_c[2].q kick[2]
cal gates[3] lane_c[3].q kick[3]
move lane_c[lane].cv count
xic lane_t[lane].dn ote held
