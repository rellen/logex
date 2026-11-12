{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the program's name, and compile_file/1 would name this one `motor_v2`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

scan = fn state, program, elapsed, label, inputs ->
  state = Logex.Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Logex.Runtime.scan(program, state, elapsed)
  IO.puts("t=#{String.pad_leading("#{state.now}", 4)}  #{label}  #{inspect(outputs)}")
  state
end

step = fn {edit, state, report}, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
  {edit, state}
end

state =
  Logex.Runtime.instance(motor)
  |> scan.(motor, 10, "start pressed ", %{"start" => 1})
  |> scan.(motor, 10, "start released", %{"start" => 0})

{:ok, edit, _forecast} = Logex.Edit.accept(motor, v2, state)
{edit, state} = step.(Logex.Edit.test(edit, state), "test")

state =
  state
  |> scan.(Logex.Edit.running(edit), 10, "under test    ", %{})
  |> scan.(Logex.Edit.running(edit), 2000, "under test    ", %{})

{edit, state} = step.(Logex.Edit.untest(edit, state), "untest")
state = scan.(state, Logex.Edit.running(edit), 10, "untested      ", %{})
{edit, state} = step.(Logex.Edit.test(edit, state), "test")
{motor, state} = step.(Logex.Edit.assemble(edit, state), "assemble")

state
|> scan.(motor, 10, "stop pressed  ", %{"stop" => 1})
|> scan.(motor, 10, "start pressed ", %{"stop" => 0, "start" => 1})
