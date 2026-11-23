# The script prints the points of 2 configurations, 1 line for each point: the device,
# the name, the direction, the address and the type.
show = fn path ->
  {:ok, configuration} = Logex.Configuration.compile_file(path)
  IO.puts(path)

  for {device, points} <- Logex.IO.points(configuration), point <- points do
    address = inspect(point.address, charlists: :as_lists)
    columns = [device, point.name, point.direction, address, point.type]
    line = Enum.map_join(columns, "", &String.pad_trailing("#{&1}", 12))
    IO.puts("  " <> String.trim_trailing(line))
  end
end

show.("packing.logex")
show.("io-adapters/keypad.logex")
