# Do 1 scan of a program and print its outputs and faults, or print its diagnostics.
# Each line that it prints starts with the text of label.
show = fn
  label, {:ok, program}, inputs ->
    state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), inputs)
    {outputs, state} = Logex.Runtime.scan(program, state, 10)
    faults = Enum.map(state.faults, & &1.kind)
    IO.puts("#{label}#{inspect(outputs)} faults: #{inspect(faults)}")

  label, {:error, diagnostics}, _inputs ->
    Enum.each(diagnostics, &IO.puts(label <> Logex.Diagnostic.format(&1)))
end

run = fn title, text, inputs ->
  IO.puts(title)
  show.("  ", Logex.compile(text, name: "box_line"), inputs)
end

# The box counter adds 1 to the top of each integer type. ok is the power out of the add.
IO.puts("1. The top of each integer type, plus 1")

tops = [
  sint: 127,
  int: 32767,
  dint: 2_147_483_647,
  lint: 9_223_372_036_854_775_807,
  usint: 255,
  uint: 65535,
  udint: 4_294_967_295,
  ulint: 18_446_744_073_709_551_615
]

for {type, top} <- tops do
  text = """
  var_input box bool
  var_output boxes #{type} #{top}
  var_output ok bool
  xic box add boxes 1 boxes ote ok
  """

  show.("  #{type} #{top} + 1: ", Logex.compile(text, name: "box_line"), %{"box" => 1})
end

run.(
  "2. 0 - 1 in a usint",
  """
  var_input box bool
  var_output boxes usint
  var_output ok bool
  xic box sub boxes 1 boxes ote ok
  """,
  %{"box" => 1}
)

run.(
  "3. 2 ints added into a dint",
  """
  var_input a int
  var_input b int
  var_output total dint
  var_output ok bool
  add a b total ote ok
  """,
  %{"a" => 32767, "b" => 1}
)

run.(
  "4. 1000 * 1000 in an int",
  """
  var_input a int
  var_output area int
  var_output ok bool
  mul a a area ote ok
  """,
  %{"a" => 1000}
)

run.(
  "5. A uint moved into a dint",
  """
  var_input hz uint
  var_output speed dint
  move hz speed
  """,
  %{"hz" => 65535}
)

run.(
  "6. A dint moved into an int",
  """
  var_input level dint
  var_output trim int
  move level trim
  """,
  %{}
)

run.(
  "7. A bool moved into an int",
  """
  var_input run bool
  var_output trim int
  move run trim
  """,
  %{}
)

run.(
  "8. A word added to a uint",
  """
  var_input status word
  var_output hz uint
  add status 1 hz
  """,
  %{}
)

# Each literal is moved into a tag of the type that the line names.
IO.puts("9. A literal that its type cannot hold")

for {type, literal} <- [int: "16#ffff", real: "16777217", dint: "1.5"] do
  text = """
  var_output trim #{type}
  move #{literal} trim
  """

  show.("  #{literal} into #{type}: ", Logex.compile(text, name: "box_line"), %{})
end

# The fan speed is a real. Each conversion writes into an int, and ok is its power out.
IO.puts("10. real_to_int and real_trunc_int of the fan speed")

speeds = [
  real_to_int: 2.5,
  real_to_int: 3.5,
  real_to_int: -2.5,
  real_to_int: 32767.6,
  real_to_int: 40000.7,
  real_trunc_int: 40000.7,
  real_trunc_int: -1.6
]

for {conversion, speed} <- speeds do
  text = """
  var_input speed real
  var_output hz int
  var_output ok bool
  #{conversion} speed hz ote ok
  """

  show.("  #{conversion} #{speed}: ", Logex.compile(text, name: "fan"), %{"speed" => speed})
end

run.(
  "11. dint_to_sint of 129, and word_to_byte of 16#1234",
  """
  var_input n dint
  var_input status word
  var_output trim sint
  var_output low byte
  var_output ok1 bool
  var_output ok2 bool
  dint_to_sint n trim ote ok1
  word_to_byte status low ote ok2
  """,
  %{"n" => 129, "status" => 0x1234}
)

run.(
  "12. dint_to_int with an sint source",
  """
  var_input small sint
  var_output trim int
  dint_to_int small trim
  """,
  %{"small" => -5}
)

run.(
  "13. not of a usint 5 into an int, and not of a bool into a word",
  """
  var_input n usint
  var_input left bool
  var_output wide int
  var_output mask word
  not n wide
  not left mask
  """,
  %{"n" => 5, "left" => 1}
)

# Each line runs 1 instruction on 2 reals, a and b, into the real r. ok is its power out.
IO.puts("14. A real result out of range, too near 0.0, and a divisor of 0.0")

reals = [
  {"mul", 2.0e38, 2.0},
  {"mul", -2.0e38, 2.0},
  {"mul", 1.2e-38, 0.001},
  {"div", 2.0e38, 0.0}
]

for {op, a, b} <- reals do
  text = """
  var_input a real
  var_input b real
  var_output r real
  var_output ok bool
  #{op} a b r ote ok
  """

  show.("  #{op} #{a} #{b}: ", Logex.compile(text, name: "fan"), %{"a" => a, "b" => b})
end

run.(
  "15. A real literal too near 0.0",
  """
  var_output speed real
  move 1.0e-40 speed
  """,
  %{}
)

run.(
  "16. Subscripts from 0, and a bit of an element",
  """
  var_input faults word[4]
  var_output lamp bool
  var_output first word
  xic faults[2].3 ote lamp
  move faults[0] first
  """,
  %{"faults" => [7, 0, 8, 0]}
)

run.(
  "17. The subscript 4 of an array of 4",
  """
  var temps real[4]
  var_output t real
  move temps[4] t
  """,
  %{}
)

run.(
  "18. An array of 65537",
  """
  var weights int[65537]
  var_output w int
  move weights[0] w
  """,
  %{}
)

run.(
  "19. A timer and a one-shot of an array, each through a tag subscript",
  """
  var_input slot dint
  var_input jam bool
  var lane_t ton[4]
  var edge bool[4]
  var_output reject bool
  xic jam ton lane_t[slot] 500
  xic jam ons edge[slot] ote reject
  """,
  %{}
)

# A counter does not wrap. The count starts at 32766, and 2 boxes go past the eye.
IO.puts("20. A ctu_int at the top of its type")

{:ok, counter} =
  Logex.compile(
    """
    var_input eye bool
    var boxes ctu_int
    var_output cv int
    var_output ov bool
    xic eye ctu boxes 32767
    move boxes.cv cv
    xic boxes.ov ote ov
    """,
    name: "boxes"
  )

start = Logex.Runtime.instance(counter)

Enum.reduce([0, 1, 0, 1], put_in(start.env["boxes"]["cv"], 32766), fn eye, state ->
  state = Logex.Runtime.put_inputs(counter, state, %{"eye" => eye})
  {outputs, state} = Logex.Runtime.scan(counter, state, 10)
  IO.puts("  eye #{eye}: #{inspect(outputs)}")
  state
end)

# The preset 5000 of a long timer is in nanoseconds. The 2 scans are 7 ms apart.
IO.puts("21. ton with the preset 5000 on a ton_ltime")

{:ok, jam} =
  Logex.compile(
    """
    var_input jam bool
    var jam_t ton_ltime
    var_output acc lint
    var_output done bool
    xic jam ton jam_t 5000
    move jam_t.acc acc
    xic jam_t.dn ote done
    """,
    name: "jam"
  )

state = Logex.Runtime.put_inputs(jam, Logex.Runtime.instance(jam), %{"jam" => 1})

Enum.reduce([0, 7], state, fn now, state ->
  {outputs, state} = Logex.Runtime.scan(jam, state, now)
  IO.puts("  at #{now} ms: #{inspect(outputs)}")
  state
end)
