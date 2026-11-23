{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# The script writes these files into a new directory, with a copy of lamp.ld. They are
# not in examples/, because most of them do not compile.
lamp = "\nprogram l1 lamp\n  l1.on 0\n"

files = %{
  "lamp_relay.ld" =>
    "function_block lamp_relay\nvar_input on bool\nvar_output lamp bool\nxic on ote lamp\n",
  "blink.ld" => "var_input on bool\nvar_output lamp bool\nxic on ote lammp\n",
  "missing.logex" => "program l1 lamq\n  l1.on 0\n",
  "relay.logex" => "program r1 lamp_relay\n  r1.on 0\n",
  "blinks.logex" => "program b1 blink\n  b1.on 0\nprogram b2 blink\n  b2.on 0\n",
  "line_2.txt" => lamp,
  ".logex" => lamp,
  "line-2.logex" => "program l1 lamb\n  l1.on 0\n",
  "task.logex" => lamp
}

dir = Path.join(System.tmp_dir!(), "configuration-file-#{System.pid()}")
File.rm_rf!(dir)
File.mkdir_p!(dir)
for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
File.cp!("configuration-file/lamp.ld", Path.join(dir, "lamp.ld"))
File.mkdir_p!(Path.join(dir, "folder.logex"))

File.cd!(dir, fn ->
  names =
    ~w(missing.logex relay.logex blinks.logex line_2.txt .logex line-2.logex none.logex folder.logex task.logex)

  report.(126, names, &Logex.Configuration.compile_file/1)
end)

File.rm_rf!(dir)
