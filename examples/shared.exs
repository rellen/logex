{:ok, line} = Logex.Configuration.compile_file("line.logex")

run = fn label, steps ->
  IO.puts(label)

  Enum.reduce(steps, Logex.Runtime.start(line), fn {now, inputs}, rt ->
    {rt, out, events} = Logex.Runtime.cycle(rt, min(now, 10), inputs)
    ran = for {:ran, _task, instance, _now} <- events, do: instance
    IO.puts("  t=#{String.pad_leading("#{now}", 2)}  k1=#{out["k1"]} k2=#{out["k2"]}  ran #{Enum.join(ran, ", ")}")
    rt
  end)
end

start = %{"pb_start_1" => 1, "pb_start_2" => 1}
release = %{"pb_start_1" => 0, "pb_start_2" => 0}

rt =
  run.("e-stop held from 50 ms:", [
    {0, start}, {10, release}, {20, %{}}, {30, %{}}, {40, %{}}, {50, %{"estop" => 1}}, {60, %{}}
  ])

IO.inspect(for(path <- ~w(estop c1.estop c2.estop c2.fault), do: Logex.Runtime.get!(rt, path)),
  label: "estop c1.estop c2.estop c2.fault"
)

run.("e-stop pressed for 10 ms at 20 ms:", [
  {0, start}, {10, release}, {20, %{"estop" => 1}}, {30, %{"estop" => 0}}, {40, %{}}, {50, %{}}
])

{:error, diagnostics} = Logex.Configuration.compile_file("wrong.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
