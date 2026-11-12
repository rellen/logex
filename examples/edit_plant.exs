{:ok, line} = Logex.Configuration.compile_file("trip.logex")
{:ok, v2} = Logex.Configuration.compile_file("v2/trip.logex")

cycle = fn rt, elapsed, label, inputs ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
  # `horn` is a global of the candidate's alone.
  horn = fn
    {:ok, value} -> " horn=#{value}"
    {:error, _reason} -> ""
  end

  IO.puts("#{label}k1=#{out["k1"]} k1_at_trip=#{Logex.Runtime.get!(rt, "k1_at_trip")}#{horn.(Logex.Runtime.get(rt, "horn"))}  ran #{Enum.join(ran, ", ")}")
  rt
end

step = fn {edit, rt, report}, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
  {edit, rt}
end

rt =
  Logex.Runtime.start(line)
  |> cycle.(0, "t=  0  started           ", %{"pb_start_1" => 1})
  |> cycle.(10, "t= 10  released          ", %{"pb_start_1" => 0})

{:ok, edit, _forecast} = Logex.Configuration.Edit.accept(rt, v2)
{edit, rt} = step.(Logex.Configuration.Edit.test(edit, rt), "test")

rt =
  rt
  |> cycle.(5, "t= 15  under test        ", %{})
  |> cycle.(5, "t= 20  e-stop rises      ", %{"estop" => 1})

{edit, rt} = step.(Logex.Configuration.Edit.untest(edit, rt), "untest")

rt =
  rt
  |> cycle.(10, "t= 30  released, reset   ", %{"estop" => 0, "pb_reset" => 1})
  |> cycle.(10, "t= 40  e-stop rises      ", %{"estop" => 1, "pb_reset" => 0})

{edit, rt} = step.(Logex.Configuration.Edit.test(edit, rt), "test")
{_line, rt} = step.(Logex.Configuration.Edit.assemble(edit, rt), "assemble")
_rt = cycle.(rt, 5, "t= 45  assembled         ", %{"estop" => 0})

try do
  Logex.Configuration.Edit.untest(edit, rt)
rescue
  error in ArgumentError -> IO.puts(error.message)
end

{:ok, moved} = Logex.Configuration.compile_file("moved/trip.logex")
{:error, diagnostics} = Logex.Configuration.Edit.accept(Logex.Runtime.start(line), moved)
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
