{:ok, conveyors} = Logex.compile_file("use-arrays-of-instances/conveyors.ld")

text = """
task fast interval 10 priority 1
program m1 conveyors with fast
  m1.start 1
  m1.stop 0
  m1.eye[0] 0
  m1.eye[1] 1
  m1.eye[2] 0
  m1.view 1
"""

{:ok, plant} = Logex.Configuration.compile("plant", text, %{"conveyors" => conveyors})

runtime =
  Enum.reduce([0, 10, 10, 10], Logex.Runtime.start(plant), fn ms, runtime ->
    {runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, ms, %{})
    runtime
  end)

for path <- ["m1.jam[1].acc", "m1.belts[1].run", "m1.jam[1]", "m1.jam[view].acc"] do
  IO.puts(path)
  IO.puts("  #{inspect(Logex.Runtime.get(runtime, path))}")
end
