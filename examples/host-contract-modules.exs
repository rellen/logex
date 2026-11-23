# 1 or 2 wrong calls to the edits, the I/O, the runner and its clocks, and 1 call outside
# the host contract.
# A pid is different at each run, so the script prints each pid as #PID<...>.
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

refused = fn label, call ->
  try do
    call.()
    IO.puts("#{label}: no error")
  rescue
    error in ArgumentError ->
      message = Regex.replace(~r/#PID<[0-9.]+>/, error.message, "#PID<...>")
      IO.puts("#{label}:\n  " <> String.replace(message, "\n", "\n  "))
  end
end

{:ok, motor} = Logex.compile_file("motor.ld")
state = Logex.Runtime.instance(motor)
{:ok, fans} = Logex.Configuration.compile_file("host-contract/fans.logex")

refused.("Logex.Edit.accept/3 with an atom", fn -> Logex.Edit.accept(motor, :motor, state) end)
refused.("Logex.Edit.test/2 with no edit", fn -> Logex.Edit.test(:edit, state) end)

refused.("Logex.Configuration.Edit.accept/3 with no resource", fn ->
  Logex.Configuration.Edit.accept(:fans, fans, 0)
end)

refused.("Logex.IO.points/1 with an atom", fn -> Logex.IO.points(:fans) end)
refused.("Logex.IO.bind!/2 with no adapters", fn -> Logex.IO.bind!(fans, %{}) end)
refused.("Logex.Runner.start_link/1 with no options", fn -> Runner.start_link([]) end)

refused.("Logex.Runner.start_link/1 with the option speed", fn ->
  Runner.start_link(configuration: fans, speed: 1)
end)

refused.("Logex.Runner.status/1 with a name", fn -> Runner.status(:fans) end)
refused.("Logex.Runner.child_spec/1 with :x", fn -> Runner.child_spec(:x) end)
refused.("Logex.IO.Sim.start_link/1 with the option speed", fn -> Sim.start_link(speed: 1) end)
refused.("Logex.IO.Sim.child_spec/1 with :x", fn -> Sim.child_spec(:x) end)

refused.("Logex.Runner.Clock.Manual.start_link/1 with the option start", fn ->
  Manual.start_link(start: 0)
end)

{:ok, clock} = Manual.start_link()
refused.("Logex.Runner.Clock.Manual.advance/2 with -1", fn -> Manual.advance(clock, -1) end)
:ok = GenServer.stop(clock)
refused.("Logex.Runner.Clock.Manual.advance/2 after a stop", fn -> Manual.advance(clock, 1) end)

IO.puts("\nOutside the host contract:")

try do
  Logex.Diagnostic.format(:motor)
rescue
  error -> IO.puts("Logex.Diagnostic.format/1 with an atom: #{inspect(error.__struct__)}")
end
