alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")

start = fn options ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(clock: clock)

  Runner.start_link(
    [configuration: plant, io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock}] ++
      options
  )
end

attempt = fn fun ->
  try do
    fun.()
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

# A file written by hand, with CRLF line ends and other spellings of a number.
File.write!("packing.forces", "eye 01\r\npb_reset 2#0")
{:ok, runner} = start.(forces: "packing.forces")
IO.inspect(Runner.status(runner).forces, label: "forces")
IO.inspect(File.read!("packing.forces"), label: "before")
:ok = Runner.force(runner, "pb_start_1", 1)
IO.inspect(File.read!("packing.forces"), label: "after ")
:ok = Runner.unforce_all(runner)
IO.inspect(File.read!("packing.forces"), label: "none  ")
:ok = Runner.stop(runner)

# A file that the start refuses: each line that is wrong.
File.write!(
  "packing.forces",
  "eye 1 // blocked\nk1 1\npb_reset 2\npb_start_1 1_0\n\nestop 1\nestop 0\nnosuch 1\n"
)

attempt.(fn -> start.(forces: "packing.forces") end)

# A directory in the place of the file.
File.rm!("packing.forces")
File.mkdir!("packing.forces")
{:ok, runner} = start.(forces: "packing.forces")
IO.inspect(Runner.status(runner).forces_unread, label: "forces_unread")
IO.inspect(Runner.force(runner, "eye", 1), label: "force")
File.rmdir!("packing.forces")
IO.inspect(Runner.force(runner, "eye", 1), label: "force")
IO.inspect(Runner.status(runner).forces_unread, label: "forces_unread")
:ok = Runner.stop(runner)

# No forces file.
File.rm!("packing.forces")
{:ok, runner} = start.([])
attempt.(fn -> Runner.force(runner, "eye", 1) end)
:ok = Runner.stop(runner)
attempt.(fn -> start.(forces: :packing) end)
