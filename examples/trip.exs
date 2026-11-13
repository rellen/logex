{:ok, line} = Logex.Configuration.compile_file("trip.logex")

steps = [
  {"started             ", 0, %{"pb_start_1" => 1}},
  {"released            ", 10, %{"pb_start_1" => 0}},
  {"e-stop rises        ", 10, %{"estop" => 1}},
  {"held                ", 10, %{}},
  {"released, reset     ", 10, %{"estop" => 0, "pb_reset" => 1}},
  {"restarted           ", 10, %{"pb_reset" => 0, "pb_start_1" => 1}},
  {"e-stop rises again  ", 10, %{"estop" => 1, "pb_start_1" => 0}}
]

Enum.reduce(steps, {Logex.Runtime.start(line), 0}, fn {label, elapsed, inputs}, {rt, now} ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
  at_trip = Logex.Runtime.get!(rt, "k1_at_trip")
  IO.puts("t=#{String.pad_leading("#{now + elapsed}", 2)}  #{label}k1=#{out["k1"]} k1_at_trip=#{at_trip}  ran #{Enum.join(ran, ", ")}")
  {rt, now + elapsed}
end)

{:ok, timed} = Logex.Configuration.compile_file("timed.logex")
Enum.each(timed.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

{:error, diagnostics} = Logex.Configuration.compile_file("wrong_trip.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
