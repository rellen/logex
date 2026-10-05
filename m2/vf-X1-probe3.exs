dir = Path.expand("../vf-X1-files")
File.write!(Path.join(dir, "five.lxcf"), "task ev single go priority 0\nvar_global go bool\nvar_global ix bool at panel.i.0\nvar_global qz bool\nprogram p1 pump with ev\np1.x ix\np1.y 0\np1.z qz\n")
r = Logex.Configuration.compile_file(Path.join(dir, "five.lxcf"))
IO.inspect((case r do {:ok, c} -> {:ok, Enum.map(c.warnings, & &1.message)}; {:error, ds} -> {:error, Enum.map(ds, & &1.message)} end), label: "ton inside block, event task (writes/1 guarded)", printable_limit: 300)
