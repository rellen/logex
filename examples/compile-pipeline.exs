# Print the stage and the message of each diagnostic.
show = fn {:error, diagnostics} ->
  Enum.each(diagnostics, fn d ->
    IO.puts("#{d.stage}: " <> Logex.Diagnostic.format(d))
  end)
end

head = "var_input start bool\nvar_output motor bool\n"

# The loader cannot read a file that is not there.
show.(Logex.compile_file("missing.ld"))

# The lexer stops at the first character it cannot read.
show.(Logex.compile(head <> "xic start @ ote motor\n", name: "motor"))

# The parser stops at its first error: line 4 has a second one.
show.(Logex.compile(head <> "( xic start\n( xic motor\n", name: "motor"))

# The compiler gives each error that it finds, in line order.
show.(Logex.compile(head <> "xic strat ote motor\nxyz start\nxic start ote 5\n", name: "motor"))
