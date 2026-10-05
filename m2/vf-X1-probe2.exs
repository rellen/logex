dir = Path.expand("../vf-X1-files")
w = fn n, t -> File.write!(Path.join(dir, n), t) end
w.("plain.ld", "var_input x bool\nvar_output z bool\nvar t9 ton\nxic x ton t9 50\nxic t9.dn ote z\n")
w.("four.lxcf", "task ev single go priority 0\nvar_global go bool\nvar_global ix bool at panel.i.0\nprogram p1 plain with ev\np1.x ix\n")
f = fn n -> r = Logex.Configuration.compile_file(Path.join(dir, n)); case r do {:ok, c} -> {:ok, Enum.map(c.warnings, & &1.message)}; {:error, ds} -> {:error, Enum.map(ds, & &1.message)} end end
IO.inspect(f.("four.lxcf"), label: "ton at top level, event task", printable_limit: 300)
IO.inspect(f.("three.lxcf"), label: "ton inside block, event task (writes/1 guarded)", printable_limit: 300)
