{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

plant_text = """
var_input  eye        bool
var        delay      ton
var        run_on     tof
var        horn_pulse tp
var        lube       rto
var        boxes      ctu
var        hopper     ctd
xic eye ton delay 100
xic eye tof run_on 100
xic eye tp horn_pulse 100
xic eye rto lube 100
xic eye ctu boxes 3
xic eye ctd hopper 3
"""

{:ok, plant} = Logex.compile(plant_text, name: "plant")

configurations = [
  "task pick single eye_1 priority 0\nvar_global eye_1 bool\n" <>
    "program p1 plant with pick\n  p1.eye eye_1"
]

report.(14, configurations, &Logex.Configuration.compile("line", &1, %{"plant" => plant}))
