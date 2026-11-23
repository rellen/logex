{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gate} = Logex.compile_file("gate.ld")
{:ok, fan_relay} = Logex.compile_file("function-blocks/fan_relay.ld")

tags = """
var_input  eye   bool
var_input  slot  int
var_output lamp  bool
var s1    seal
var f1    fan_relay
var gates gate[4]
"""

rungs = [
  "xic s1 ote lamp",
  "xic s1.RUN ote lamp",
  "xic s1.running ote lamp",
  "xic s1.speed ote lamp",
  "xic s1.run.0 ote lamp",
  "xic f1.run_on.dn ote lamp",
  "xic eye ote s1.start",
  "xic eye ote s1.run",
  "xic gates.kick ote lamp",
  "xic gates[slot].edge ote lamp",
  "xic eye ote gates[slot].open",
  "xic eye ons gates[1].open ote lamp"
]

report.(14, rungs, &Logex.compile(tags <> &1, name: "panel", types: [seal, gate, fan_relay]))
