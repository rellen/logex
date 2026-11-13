{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
{:ok, ld} = File.read("tally.ld")
{:ok, text} = File.read("tally.logex")
{:ok, plain} = Logex.compile(String.replace(ld, "var retain boxes", "var boxes"), name: "tally")
{:ok, candidate} = Logex.Configuration.compile("tally", text, %{"tally" => plain})

count = fn rt, label ->
  IO.puts("#{label}  t1.boxes.cv=#{Logex.Runtime.get!(rt, "t1.boxes.cv")}")
  rt
end

rt =
  Enum.reduce([1, 0, 1, 0], Logex.Runtime.start(plant), fn eye, rt ->
    elem(Logex.Runtime.cycle(rt, 10, %{"eye_1" => eye}), 0)
  end)

{:ok, edit, _forecast} = Logex.Configuration.Edit.accept(rt, candidate)
{edit, rt, report} = Logex.Configuration.Edit.test(edit, rt)
IO.puts("test")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
count.(rt, "under test   ")
rt |> Logex.Runtime.restart(:warm) |> count.("warm restart ")

{_edit, rt, report} = Logex.Configuration.Edit.untest(edit, rt)
IO.puts("untest")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
rt |> Logex.Runtime.restart(:warm) |> count.("warm restart ")
