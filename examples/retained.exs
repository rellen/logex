{:ok, plant} = Logex.Configuration.compile_file("tally.logex")

show = fn rt, label ->
  IO.puts("#{label}  total_boxes=#{Logex.Runtime.get!(rt, "total_boxes")} " <>
            "t1.boxes.cv=#{Logex.Runtime.get!(rt, "t1.boxes.cv")} " <>
            "case_full=#{Logex.Runtime.get!(rt, "case_full")}")
  rt
end

boxes = fn rt, n ->
  Enum.reduce(1..n, rt, fn _, rt ->
    {rt, _, _} = Logex.Runtime.cycle(rt, 10, %{"eye_1" => 1})
    {rt, _, _} = Logex.Runtime.cycle(rt, 10, %{"eye_1" => 0})
    rt
  end)
end

{rt, _, _} = Logex.Runtime.cycle(Logex.Runtime.start(plant), 0, %{})

rt =
  rt
  |> boxes.(4)
  |> show.("four boxes   ")
  |> Logex.Runtime.restart(:warm)
  |> show.("warm restart ")
  |> boxes.(1)
  |> show.("first box    ")
  |> boxes.(1)
  |> show.("one more     ")

image = Logex.Runtime.retained(rt)
rt |> Logex.Runtime.restart(:cold) |> show.("cold restart ")

{fresh, []} = Logex.Runtime.start(plant, image)
show.(fresh, "from image   ")

{:ok, ld} = File.read("tally.ld")
{:ok, recounted} = Logex.compile(String.replace(ld, "boxes ctu", "boxes ctu_int"), name: "tally")
{:ok, text} = File.read("tally.logex")
{:ok, recounting} = Logex.Configuration.compile("tally", text, %{"tally" => recounted})
{fresh, dropped} = Logex.Runtime.start(recounting, image)
show.(fresh, "a ctu_int    ")
IO.inspect(dropped)

{:ok, wired} = Logex.Configuration.compile_file("wired.logex")
Enum.each(wired.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

{:error, diagnostics} = Logex.Configuration.compile_file("broken_retain.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
