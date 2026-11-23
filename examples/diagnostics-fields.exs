{dir, _binding} = Code.eval_file("diagnostics/wrong.exs")
{:error, diagnostics} = File.cd!(dir, fn -> Logex.compile_file("wrong/conveyor.ld") end)
File.rm_rf!(dir)

IO.puts("The first diagnostic:")
IO.inspect(hd(diagnostics))

IO.puts("Each diagnostic, as Logex.Diagnostic.format/1 gives it:")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
