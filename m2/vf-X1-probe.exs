dir = Path.expand("../vf-X1-files")
File.rm_rf!(dir); File.mkdir_p!(dir)
w = fn n, t -> File.write!(Path.join(dir, n), t) end
w.("latch.ld", "function_block latch\nvar_input set bool\nvar_input rst bool\nvar_output out bool\nvar t9 ton\n( xic set | xic out ) xio rst ote out\nxic out ton t9 50\n")
w.("pump.ld", "var_input x bool\nvar_input y bool\nvar_output z bool\nvar l1 latch\ncal l1 x y z\n")
show = fn label, f -> r = try do f.() rescue e -> {:raised, e.__struct__, String.slice(Exception.message(e), 0, 160), Enum.take(Enum.map(__STACKTRACE__, &Exception.format_stacktrace_entry/1), 4)} end; IO.inspect(r, label: label, limit: 10, printable_limit: 400) end
show.("pump.ld", fn -> {:ok, p} = Logex.compile_file(Path.join(dir, "pump.ld")); {p.__struct__, Enum.take(p.rungs, 1)} end)
show.("latch.ld", fn -> {:ok, t} = Logex.compile_file(Path.join(dir, "latch.ld")); t.__struct__ end)
w.("one.lxcf", "var_global ix bool at panel.i.0\nvar_global iy bool at panel.i.1\nvar_global qz bool at panel.q.0\nprogram p1 pump\np1.x ix\np1.y iy\np1.z qz\n")
show.("one.lxcf (program with cal)", fn -> Logex.Configuration.compile_file(Path.join(dir, "one.lxcf")) end)
w.("two.lxcf", "var_global ix bool at panel.i.0\nprogram p1 latch\np1.set ix\n")
show.("two.lxcf (program line names block)", fn -> Logex.Configuration.compile_file(Path.join(dir, "two.lxcf")) end)
w.("three.lxcf", "task ev single go priority 0\nvar_global go bool\nvar_global ix bool at panel.i.0\nprogram p1 pump with ev\np1.x ix\n")
show.("three.lxcf (event task, ton inside block)", fn -> Logex.Configuration.compile_file(Path.join(dir, "three.lxcf")) end)
# pure seam
{:ok, pump} = Logex.compile_file(Path.join(dir, "pump.ld"))
show.("compile/3 with pump", fn -> Logex.Configuration.compile("c", "program p1 pump\n", %{"pump" => pump}) end)
