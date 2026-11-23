motor = """
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var fault bool

( xic start | xic motor ) xio stop ote motor
xic motor ote run_lmap
xic overtemp otl stop
xic reset otu Fault
xic Fault mov 0 speed_sp
"""

conveyor = """
var_input start bool
var_input stop bool
var_output motor bool

( xic start | xic motor xio stop ote motor
xic motor ote belt_lamp
"""

print = fn diagnostic -> IO.puts(Logex.Diagnostic.format(diagnostic)) end

report = fn
  name, {:ok, compiled} ->
    IO.puts("#{name} compiles")
    Enum.each(compiled.warnings, print)

  name, {:error, diagnostics} ->
    IO.puts("#{name} does not compile")
    Enum.each(diagnostics, print)
end

report.("motor", Logex.compile(motor, name: "motor"))
report.("conveyor", Logex.compile(conveyor, name: "conveyor"))
report.("read-diagnostics/lamp.ld", Logex.compile_file("read-diagnostics/lamp.ld"))
report.("broken.logex", Logex.Configuration.compile_file("broken.logex"))
