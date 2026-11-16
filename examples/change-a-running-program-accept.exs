{:ok, motor} = Logex.compile_file("motor.ld")

state = Logex.Runtime.put_inputs(motor, Logex.Runtime.instance(motor), %{"start" => 1})
{outputs, state} = Logex.Runtime.scan(motor, state, 10)
IO.puts("the motor runs  #{inspect(outputs)}")

accepted =
  with {:ok, v2} <- Logex.compile(File.read!("motor_v2.ld"), name: "motor") do
    Logex.Edit.accept(motor, v2, state)
  end

text = fn
  {:ok, _edit, forecast} -> Enum.map_join(forecast, "\n", &inspect/1)
  {:error, diagnostics} -> Enum.map_join(diagnostics, "\n", &Logex.Diagnostic.format/1)
end

IO.puts(text.(accepted))
