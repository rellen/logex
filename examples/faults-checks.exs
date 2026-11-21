# The tags of each case. Each case is 1 program: these lines and its rungs.
tags = """
var_input  run     bool
var_input  zone    int
var_input  sel     int
var_input  boxes   dint
var_input  minutes dint
var_output lamp    bool
var_output rate    dint
var_output belt_sp int
var        lamps   bool[4]
var        status  word
var        words   word[4]
var        grid    int[2,3]
var        speeds  int[4]
var        rates   dint[4]
"""

cases = [
  {"xic run xic status.[sel] ote lamp", %{"run" => 0, "sel" => 16}},
  {"xic run xic status.[sel] ote lamp", %{"run" => 1, "sel" => 16}},
  {"xic run otl lamps[zone]", %{"run" => 0, "zone" => 9}},
  {"xic run ote lamps[zone]", %{"run" => 0, "zone" => 9}},
  {"xic run div boxes minutes rate", %{"run" => 0, "minutes" => 0}},
  {"xio run jmp skip\nxic lamps[zone] ote lamp\nlbl skip", %{"run" => 0, "zone" => 9}},
  {"xic words[zone].[sel] ote lamp", %{"zone" => 9, "sel" => 16}},
  {"xic words[zone].[sel] ote lamp", %{"zone" => 1, "sel" => 16}},
  {"move grid[1,zone] belt_sp", %{"zone" => 3}},
  {"move speeds[zone] speeds[sel]", %{"zone" => 9, "sel" => 16}},
  {"div boxes minutes rates[zone]", %{"minutes" => 0, "zone" => 9}},
  {"( xic lamps[zone] | xic status.[sel] ) ote lamp", %{"zone" => 9, "sel" => 16}}
]

# Prints each fault of a scan, or "no fault".
report = fn
  [] ->
    IO.puts("   no fault")

  faults ->
    for fault <- faults do
      IO.puts(
        "   #{inspect(fault.kind)} #{inspect(fault.instruction)} read #{inspect(fault.read)}"
      )
    end
end

for {{rungs, inputs}, number} <- Enum.with_index(cases, 1) do
  {:ok, program} = Logex.compile(tags <> rungs, name: "case")
  state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), inputs)
  {_outputs, state} = Logex.Runtime.scan(program, state)
  given = Enum.map_join(Enum.sort(inputs), " ", fn {name, value} -> "#{name}=#{value}" end)
  IO.puts("#{number}. #{String.replace(rungs, "\n", " / ")}   #{given}")
  report.(state.faults)
end
