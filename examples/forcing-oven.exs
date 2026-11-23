alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("oven.logex")
{:ok, clock} = Manual.start_link()
{:ok, card} = Sim.start_link(inputs: 8, outputs: 8)
File.rm("oven.forces")

start = fn ->
  Runner.start_link(
    configuration: plant,
    io: %{"card" => {Sim, sim: card}},
    clock: {Manual, clock},
    forces: "oven.forces"
  )
end

listed = fn
  [] -> "none"
  list -> Enum.map_join(list, " ", fn {name, value} -> "#{name}=#{value}" end)
end

forces = fn runner -> listed.(Enum.sort(Runner.status(runner).forces)) end

attempt = fn fun ->
  try do
    fun.()
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

{:ok, runner} = start.()

# 1 element, named with its subscript in 2 other spellings. A real and an integer.
:ok = Runner.force(runner, "zone_t[03]", 0.1)
:ok = Runner.force(runner, "zone_t[16#2]", 37)
IO.puts("forces: " <> forces.(runner))
IO.write("oven.forces:\n" <> File.read!("oven.forces"))

attempt.(fn -> Runner.force(runner, "zone_t[1]", 1.0e40) end)
attempt.(fn -> Runner.force(runner, "zone_t[8]", 1.0) end)
attempt.(fn -> Runner.force(runner, "zone_hot[3]", 1) end)

# The array named whole: a list of 8 values, then an unforce of each element.
attempt.(fn -> Runner.force(runner, "zone_t", [170, 190]) end)
:ok = Runner.force(runner, "zone_t", [170, 170, 170, 170, 190, 190, 190, 190])
IO.puts("forces: " <> forces.(runner))
:ok = Runner.unforce(runner, "zone_t")
IO.puts("forces: " <> forces.(runner))
:ok = Runner.stop(runner)

# A file written by hand: the array whole on 1 line, and spellings of a real.
File.write!("oven.forces", "zone_t 1 2 3 4 5 6 7 8\n")
{:ok, runner} = start.()
IO.puts("forces: " <> forces.(runner))
:ok = Runner.stop(runner)

File.write!(
  "oven.forces",
  "zone_t[0] 1.0e-40\nzone_t[2] 37.50\nzone_t[3] 3.75e1\nzone_t[5] 16#10\n"
)

{:ok, runner} = start.()
IO.puts("forces: " <> forces.(runner))
:ok = Runner.force(runner, "zone_t[6]", 1)
IO.write("oven.forces:\n" <> File.read!("oven.forces"))
:ok = Runner.stop(runner)

File.write!("oven.forces", "zone_t 1 2 3\nzone_hot[0] 1\n")
attempt.(start)
File.rm("oven.forces")
