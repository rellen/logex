alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)
options = [configuration: plant, io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock}]

# Each start raises an ArgumentError in this process. The script prints its message.
wrong = fn label, opts ->
  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> IO.puts("#{label}\n  #{Exception.message(error)}")
  end
end

wrong.("no io:", Keyword.delete(options, :io))
wrong.("io: with no panel", Keyword.put(options, :io, %{}))
wrong.("poll: 0", options ++ [poll: 0])
wrong.("overhead: 5", options ++ [overhead: 5])
wrong.("open: for a device that io: does not bind", options ++ [open: %{"drive" => 2000}])
wrong.("start: with no retain:", options ++ [start: :cold])
wrong.("an option twice", options ++ [poll: 10, poll: 20])
wrong.("an unknown option", options ++ [speed: 1])

# The shutdown time of the child spec, in ms, for 1 device.
for extra <- [[], [idle: 1000, poll: 20], [forces: "packing.forces"]] do
  IO.puts("shutdown with #{inspect(extra)}: #{Runner.child_spec(options ++ extra).shutdown}")
end
