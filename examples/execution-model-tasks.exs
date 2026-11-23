# The program types of the cases, by name, for Logex.Configuration.compile/3.
programs =
  for name <- ~w(lamp conveyor), into: %{} do
    {:ok, program} = Logex.compile_file("execution-model/#{name}.ld")
    {name, program}
  end

cases = [
  {"An event task",
   """
   task stops single estop priority 0
   var_global estop bool at panel.i.0
   program l1 lamp with stops
   """,
   [{0, %{}}, {10, %{"estop" => 1}}, {10, %{}}, {10, %{"estop" => 0}}, {10, %{"estop" => 1}}]},
  {"A trigger that is 1 in the first cycle",
   """
   task stops single estop priority 0
   var_global estop bool at panel.i.0
   program l1 lamp with stops
   """,
   [{0, %{"estop" => 1}}, {10, %{}}, {:restart, :cold}, {10, %{}}, {:restart, :warm}, {10, %{}}]},
  {"A trigger with the initial value 1",
   """
   task stops single trip priority 0
   var_global trip bool 1
   program l1 lamp with stops
   """, [{0, %{}}, {10, %{}}, {:restart, :warm}, {10, %{}}]},
  {"A retained trigger",
   """
   task stops single trip priority 0
   var_global retain trip bool 1
   program l1 lamp with stops
   """, [{0, %{}}, {:restart, :warm}, {10, %{}}, {:restart, :cold}, {10, %{}}]},
  {"A trigger that a program writes",
   """
   task belts interval 10 priority 2
   task stops single running priority 1
   var_global estop bool at panel.i.0
   var_global pb_start bool at panel.i.1
   var_global running bool
   program c1 conveyor with belts
     c1.start pb_start
     c1.motor running
   program l1 lamp with stops
   """, [{0, %{}}, {10, %{"pb_start" => 1}}, {10, %{}}]},
  {"An event task with an interval",
   """
   task stops single estop interval 20 priority 0
   var_global estop bool at panel.i.0
   program l1 lamp with stops
   """,
   [
     {0, %{}},
     {10, %{}},
     {10, %{}},
     {5, %{"estop" => 1}},
     {10, %{}},
     {10, %{}},
     {10, %{"estop" => 0}},
     {10, %{}}
   ]},
  {"Late cycles of an event task with an interval",
   """
   task stops single estop interval 20 priority 0
   var_global estop bool at panel.i.0
   program l1 lamp with stops
   """, [{0, %{}}, {65, %{}}, {65, %{"estop" => 1}}, {10, %{}}, {45, %{"estop" => 0}}]},
  {"The sequence of the due tasks",
   """
   task stops single estop priority 1
   task belts interval 10 priority 1
   task fans  interval 10 priority 1
   task lamps interval 10 priority 0
   var_global estop bool at panel.i.0
   program l1 lamp with stops
   program l2 lamp with belts
   program l3 lamp with fans
   program l4 lamp with lamps
   program l5 lamp with belts
   """, [{0, %{}}, {15, %{"estop" => 1}}]},
  {"A late first cycle",
   """
   task belts interval 10 priority 1
   program l1 lamp with belts
   """, [{35, %{}}, {10, %{}}]},
  {"The continuous task",
   """
   task belts interval 10 priority 1
   task main continuous
   program l1 lamp with main
   program l2 lamp with belts
   program l3 lamp
   """, [{0, %{}}, {5, %{}}]},
  {"No continuous task",
   """
   task stops single estop priority 0
   var_global estop bool at panel.i.0
   program l1 lamp
   program l2 lamp with stops
   """, [{0, %{}}, {5, %{"estop" => 1}}]},
  {"A restart",
   """
   task belts interval 10 priority 1
   program l1 lamp with belts
   """, [{0, %{}}, {7, %{}}, {:restart, :cold}, {0, %{}}, {10, %{}}]}
]

event = fn
  {:ran, task, instance, _now} -> "ran #{task}:#{instance}"
  {:overlap, task, missed} -> "overlap #{task} #{missed}"
end

runs = fn
  [] -> "no run"
  events -> Enum.map_join(events, ", ", event)
end

step = fn
  {:restart, mode}, {resource, now} ->
    IO.puts("  restart/2 #{inspect(mode)}")
    {Logex.Runtime.restart(resource, mode), now}

  {elapsed, inputs}, {resource, now} ->
    {resource, _outputs, events} = Logex.Runtime.cycle(resource, elapsed, inputs)
    ran = runs.(events)
    due = inspect(Logex.Runtime.next_due_in(resource))
    IO.puts("  t=#{now + elapsed} #{inspect(inputs)}: #{ran} (next due in #{due})")
    {resource, now + elapsed}
end

for {{title, text, steps}, number} <- Enum.with_index(cases, 1) do
  {:ok, configuration} = Logex.Configuration.compile("line", text, programs)
  IO.puts("#{number}. #{title}")
  {resource, _now} = Enum.reduce(steps, {Logex.Runtime.start(configuration), 0}, step)
  IO.puts("  overlaps/1: #{inspect(Logex.Runtime.overlaps(resource))}")
end
