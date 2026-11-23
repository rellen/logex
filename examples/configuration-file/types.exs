# The program types of the directory configuration-file, by name, for
# Logex.Configuration.compile/3.
for name <- ~w(lamp belt box_count fan_control stop_record), into: %{} do
  {:ok, program} = Logex.compile_file("configuration-file/#{name}.ld")
  {name, program}
end
