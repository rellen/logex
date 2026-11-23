alias Logex.Runtime

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")

names = ["total_boxes", "t1.boxes.cv", "t1.full", "case_full"]

show = fn resource, label ->
  values = Enum.map_join(names, "  ", &"#{&1}=#{Runtime.get!(resource, &1)}")
  IO.puts("#{label}  #{values}")
  resource
end

# Each box is 1 cycle with the eye on and 1 cycle with the eye off, 10 ms each.
boxes = fn resource, n ->
  Enum.reduce(1..n, resource, fn _box, resource ->
    {resource, _outputs, _events} = Runtime.cycle(resource, 10, %{"eye_1" => 1})
    {resource, _outputs, _events} = Runtime.cycle(resource, 10, %{"eye_1" => 0})
    resource
  end)
end

# The first cycle is the first scan, which finds no rising edge.
# Run it before the first box comes.
{resource, _outputs, _events} = Runtime.cycle(Runtime.start(plant), 0, %{})
resource = resource |> boxes.(4) |> show.("4 boxes     ")

resource
|> Runtime.restart(:warm)
|> show.("warm restart")
|> boxes.(2)
|> show.("2 more boxes")

resource |> Runtime.restart(:cold) |> show.("cold restart")

image = Runtime.retained(resource)
{fresh, dropped} = Runtime.start(plant, image)
show.(fresh, "from image  ")
IO.inspect(dropped)
