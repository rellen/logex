# The script runs fan_panel.ld as m1 and lanes.ld as m2 in a configuration, for 3
# cycles of 10 ms. Then it reads each access path with Logex.Runtime.get/2. It prints
# the value, or the message of the error in lines of 80 characters or fewer.
{:ok, fan_panel} = Logex.compile_file("function-blocks/fan_panel.ld")
{:ok, lanes} = Logex.compile_file("lanes.ld")

text = """
task fast interval 10 priority 1
program m1 fan_panel with fast
  m1.motor_1 1
  m1.motor_2 0
program m2 lanes with fast
  m2.eye[0] 0
  m2.eye[1] 0
  m2.eye[2] 1
  m2.eye[3] 0
  m2.lane 2
"""

{:ok, plant} =
  Logex.Configuration.compile("plant", text, %{"fan_panel" => fan_panel, "lanes" => lanes})

runtime =
  Enum.reduce([0, 10, 10], Logex.Runtime.start(plant), fn ms, runtime ->
    {runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, ms, %{})
    runtime
  end)

wrap = fn message ->
  message
  |> String.split(" ")
  |> Enum.chunk_while(
    "     ",
    fn
      word, line when byte_size(line) + byte_size(word) < 80 -> {:cont, line <> " " <> word}
      word, line -> {:cont, line, "      " <> word}
    end,
    fn line -> {:cont, line, ""} end
  )
end

show = fn
  {:ok, value} -> ["      " <> inspect(value)]
  {:error, message} -> wrap.(message)
end

paths = [
  "m1.f1.fan",
  "m1.f1.motor",
  "m1.f1",
  "m1.f1.run_on",
  "m1.f1.run_on.acc",
  "m2.lane_t[2].acc",
  "m2.lane_t[2].last",
  "m2.lane_t[2]",
  "m2.lane_t",
  "m2.lane_t[lane].acc",
  "m2.gates[2].kick",
  "m2.gates[2].edge"
]

for path <- paths, do: IO.puts(Enum.join([path | show.(Logex.Runtime.get(runtime, path))], "\n"))
