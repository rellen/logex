# A mutation table for rung 1 of motor.ld. Each mutant changes 1 rule of the rung. Each
# test checks 1 fact of the motor. A mutant that no test fails is SURVIVED.
#
#   ( xic start | xic motor ) xio stop ote motor
defmodule Tests do
  alias Logex.Runtime

  # Runs 1 scan for each map of inputs and gives the outputs of the last scan.
  def outputs(program, steps) do
    Enum.reduce(steps, {%{}, Runtime.instance(program)}, fn inputs, {_outputs, state} ->
      inputs = Map.merge(%{"start" => 0, "stop" => 0}, inputs)
      Runtime.scan(program, Runtime.put_inputs(program, state, inputs))
    end)
    |> elem(0)
  end

  # Each test gives true when the program passes it.
  def passes(program, "a scan gives motor"),
    do: Map.has_key?(outputs(program, [%{"start" => 1}]), "motor")

  def passes(program, "start runs motor"),
    do: outputs(program, [%{"start" => 1}])["motor"] == 1

  def passes(program, "motor stays on"),
    do: outputs(program, [%{"start" => 1}, %{}])["motor"] == 1

  def passes(program, "stop stops motor"),
    do: outputs(program, [%{"start" => 1}, %{}, %{"stop" => 1}])["motor"] == 0
end

defmodule Table do
  # 1 line: the program and the tests that fail on it.
  def row({kind, name, program}, tests) do
    failed = Enum.reject(tests, &Tests.passes(program, &1))
    IO.puts("  #{String.pad_trailing(name, 16)} #{verdict(kind, failed)}")
  end

  defp verdict(:original, []), do: "passes each test"
  defp verdict(:mutant, []), do: "SURVIVED"
  defp verdict(_kind, failed), do: "fails: " <> Enum.join(failed, ", ")
end

source = File.read!("motor.ld")
rung = "( xic start | xic motor ) xio stop ote motor"

# Each mutant changes 1 rule of the rung. The list comes from the rung, not from the tests.
mutants = [
  {"no seal-in leg", "xic start xio stop ote motor"},
  {"xic stop", "( xic start | xic motor ) xic stop ote motor"},
  {"no stop contact", "( xic start | xic motor ) ote motor"},
  {"otl motor", "( xic start | xic motor ) xio stop otl motor"}
]

texts =
  [{:original, "motor.ld", source}] ++
    for {name, changed} <- mutants, do: {:mutant, name, String.replace(source, rung, changed)}

programs =
  Enum.map(texts, fn {kind, name, text} ->
    {:ok, program} = Logex.compile(text, name: "motor")
    {kind, name, program}
  end)

first = ["a scan gives motor", "start runs motor", "motor stays on"]

IO.puts("1. The tests written with the rung")
for program <- programs, do: Table.row(program, first)

IO.puts("2. A test added for the survivors")
for program <- programs, do: Table.row(program, first ++ ["stop stops motor"])
