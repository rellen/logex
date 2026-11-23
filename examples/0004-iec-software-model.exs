# The configuration file makes 3 instances of 2 program types and puts them on 2 tasks.
{:ok, line} = Logex.Configuration.compile_file("0004-iec-software-model/line.logex")

for {name, program} <- line.programs do
  IO.puts("program type #{name}, block types #{inspect(Map.keys(program.blocks))}")
end

# 1 cycle each 10 ms. The task fast runs c1 and p1 in each cycle, slow runs c2 each 50 ms.
cycle = fn {rt, now}, elapsed, inputs ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, _task, instance, _now} <- events, do: instance
  boxes = Logex.Runtime.get!(rt, "p1.boxes.cv")
  IO.puts("t=#{now + elapsed}  k1=#{out["k1"]} k2=#{out["k2"]}  boxes=#{boxes}  ran #{Enum.join(ran, " ")}")
  {rt, now + elapsed}
end

# Each instance has its own state: c1.s1 and c2.s1 are 2 instances of the block seal.
seals = fn {rt, now} ->
  IO.puts("       c1.s1.run=#{Logex.Runtime.get!(rt, "c1.s1.run")} c2.s1.run=#{Logex.Runtime.get!(rt, "c2.s1.run")}")
  {rt, now}
end

# Run 1: the e-stop goes to 1 at 40 ms and stays 1.
{Logex.Runtime.start(line), 0}
|> cycle.(0, %{"pb_start_1" => 1, "pb_start_2" => 1})
|> cycle.(10, %{"pb_start_1" => 0, "pb_start_2" => 0, "eye" => 1})
|> cycle.(10, %{"eye" => 0})
|> cycle.(10, %{"eye" => 1})
|> cycle.(10, %{"estop" => 1})
|> seals.()
|> cycle.(10, %{"pb_reset" => 1})
|> seals.()

# Run 2: the e-stop is 1 for 10 ms only, from 10 ms to 20 ms. The task slow does not run then.
IO.puts("run 2")

{Logex.Runtime.start(line), 0}
|> cycle.(0, %{"pb_start_1" => 1, "pb_start_2" => 1})
|> cycle.(10, %{"pb_start_1" => 0, "pb_start_2" => 0, "estop" => 1})
|> cycle.(10, %{"estop" => 0})
|> cycle.(10, %{})
|> cycle.(10, %{})
|> cycle.(10, %{})

print = fn {:error, [diagnostic | _]} -> IO.puts(Logex.Diagnostic.format(diagnostic)) end

# A rung writes the inputs r and pv of a counter, and never its count cv.
print.(Logex.compile("var e bool\nvar boxes ctu\nxic e ctu boxes 3\nmove 5 boxes.cv\n", name: "m"))

# A program has 1 routine, and no subroutine to call.
print.(Logex.compile("var e bool\nxic e jsr fill\n", name: "m"))

# A block reaches no global: it takes a value through a var_input.
block = "function_block b\nvar_input i bool\nvar_output o bool\nvar_external g bool\nxic i xic g ote o\n"
print.(Logex.compile(block, name: "b"))

# 2 instances share a value only through a global. Each var_input has a connection.
text = File.read!("0004-iec-software-model/line.logex")
linked = String.replace(text, "c2.start pb_start_2", "c2.start c1.motor")
print.(Logex.Configuration.compile("line", linked, line.programs))
unconnected = String.replace(text, "  c2.stop  0\n", "")
print.(Logex.Configuration.compile("line", unconnected, line.programs))
