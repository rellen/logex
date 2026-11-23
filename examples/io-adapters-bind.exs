# The script binds the device of packing.logex to a simulated device, and prints each
# binding that bind!/2 gives. Then it gives bind!/2 7 wrong bindings, and prints each
# message.
alias Logex.IO.Sim

{:ok, packing} = Logex.Configuration.compile_file("packing.logex")
{:ok, keypad} = Logex.Configuration.compile_file("io-adapters/keypad.logex")
{:ok, panel} = Sim.start_link()
{:ok, small} = Sim.start_link(inputs: 4)
{:ok, rack} = Sim.start_link()

for {device, adapter, options, points} <- Logex.IO.bind!(packing, %{"panel" => {Sim, sim: panel}}) do
  IO.puts(
    "#{device}: #{inspect(adapter)}, options #{inspect(Keyword.keys(options))}, #{length(points)} points"
  )
end

refused = fn configuration, io ->
  try do
    Logex.IO.bind!(configuration, io)
  rescue
    error in ArgumentError -> IO.puts("\n" <> error.message)
  end
end

refused.(packing, %{})
refused.(packing, %{:panel => Sim, "pannel" => Sim})
refused.(packing, %{"panel" => "Sim"})
refused.(packing, %{"panel" => Enum})
refused.(packing, %{"panel" => Sim})
refused.(packing, %{"panel" => {Sim, sim: small}})
refused.(keypad, %{"rack" => {Sim, sim: rack, reports: true}})
