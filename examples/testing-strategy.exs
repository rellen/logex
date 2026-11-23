# A walk with an oracle: 200 scans of motor.ld, each with random inputs. The oracle
# restates rung 1 from its text alone. It knows nothing of how logex runs the rung.
#
#   ( xic start | xic motor ) xio stop ote motor
defmodule Oracle do
  # The next value of motor, and the case of the rung that gives it.
  def motor(_start, _motor, 1), do: {0, :stop_pressed}
  def motor(1, _motor, 0), do: {1, :start_pressed}
  def motor(0, 1, 0), do: {1, :sealed_in}
  def motor(0, 0, 0), do: {0, :idle}
end

defmodule Walk do
  @cases [:start_pressed, :sealed_in, :stop_pressed, :idle]

  # The same seed gives the same 200 inputs to each program.
  def run(program, seed) do
    :rand.seed(:exsss, seed)
    first = {Logex.Runtime.instance(program), 0, 0, Map.new(@cases, &{&1, 0})}
    {_state, _motor, differences, reach} = Enum.reduce(1..200, first, &step(program, &1, &2))
    {differences, Enum.map_join(@cases, ", ", &"#{&1} #{reach[&1]}")}
  end

  # 1 scan. The oracle starts from the value of motor that logex gave at the scan before.
  defp step(program, _n, {state, motor, differences, reach}) do
    inputs = %{"start" => :rand.uniform(2) - 1, "stop" => :rand.uniform(2) - 1}
    state = Logex.Runtime.put_inputs(program, state, inputs)
    {outputs, state} = Logex.Runtime.scan(program, state)
    {expected, rung_case} = Oracle.motor(inputs["start"], motor, inputs["stop"])
    difference = abs(outputs["motor"] - expected)
    {state, outputs["motor"], differences + difference, Map.update!(reach, rung_case, &(&1 + 1))}
  end
end

{:ok, motor} = Logex.compile_file("motor.ld")

# A changed program: the contact on stop is open where motor.ld has it closed.
text = String.replace(File.read!("motor.ld"), "xio stop", "xic stop")
{:ok, changed} = Logex.compile(text, name: "changed")

for {name, program} <- [{"motor.ld", motor}, {"changed", changed}] do
  {differences, reach} = Walk.run(program, {1, 2, 3})
  IO.puts("#{name}: #{differences} differences in 200 scans")
  IO.puts("  reach: #{reach}")
end
