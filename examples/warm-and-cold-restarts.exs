alias Logex.Runtime

{:ok, line} = Logex.compile_file("warm-and-cold-restarts/line.ld")

# The columns: eye, boxes.cv, seen.cv, lube.acc and full_lamp.
columns = ["eye", "boxes", "seen", "lube", "lamp"]

show = fn state, label ->
  env = state.env

  values = [
    env["eye"],
    env["boxes"]["cv"],
    env["seen"]["cv"],
    env["lube"]["acc"],
    env["full_lamp"]
  ]

  cells = Enum.zip_with(columns, values, &String.pad_leading("#{&2}", String.length(&1) + 2))
  IO.puts(String.pad_trailing(label, 13) <> Enum.join(cells))
  state
end

# Each scan is 10 ms after the last. The host gives that time.
scan = fn state, inputs ->
  state = Runtime.put_inputs(line, state, inputs)
  {_outputs, state} = Runtime.scan(line, state, 10)
  state
end

IO.puts(String.pad_trailing("", 13) <> Enum.map_join(columns, &("  " <> &1)))

# The motor runs, and 3 boxes pass the eye. The third box stays at the eye.
before =
  Runtime.instance(line)
  |> scan.(%{"motor" => 1})
  |> scan.(%{"eye" => 1})
  |> scan.(%{"eye" => 0})
  |> scan.(%{"eye" => 1})
  |> scan.(%{"eye" => 0})
  |> scan.(%{"eye" => 1})
  |> show.("3 boxes")

Runtime.restart(line, before, :warm)
|> show.("warm restart")
|> scan.(%{})
|> show.("first scan")

Runtime.restart(line, before, :cold)
|> show.("cold restart")
|> scan.(%{})
|> show.("first scan")
|> scan.(%{})
|> show.("second scan")
