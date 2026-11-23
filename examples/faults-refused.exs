# The tags of each rung. Each rung is 1 program: these lines and the rung.
tags = """
var_input  boxes   dint
var_input  drive   word
var_output rate    dint
var_output fan_sp  real
var_output lamp    bool
var_output belt_sp int
var        speeds  int[4]
var        grid    int[2,3]
var        zone    int
"""

rungs = [
  "div boxes 0 rate",
  "mod boxes 0 rate",
  "sqrt -4.0 fan_sp",
  "move speeds[4] belt_sp",
  "move grid[zone,3] belt_sp",
  "xic drive.[16] ote lamp"
]

for rung <- rungs do
  {:error, diagnostics} = Logex.compile(tags <> rung, name: "wrong")
  IO.puts(rung)
  for diagnostic <- diagnostics, do: IO.puts("  " <> Logex.Diagnostic.format(diagnostic))
end
