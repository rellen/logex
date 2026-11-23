{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# The script writes these 6 files into a new directory, with a copy of lamp_relay.ld and
# lamp_panel.ld. They are not in examples/, because they do not compile.
wrong = %{
  "belt_a.ld" =>
    "function_block belt_a\nvar_input run bool\nvar_output motor bool\n" <>
      "var next belt_b\ncal next run motor\n",
  "belt_b.ld" =>
    "function_block belt_b\nvar_input run bool\nvar_output motor bool\n" <>
      "var next belt_a\ncal next run motor\n",
  "belt_pair.ld" =>
    "var_input run bool\nvar_output motor_1 bool\nvar first belt_a\n" <>
      "cal first run motor_1\n",
  "wrong_panel.ld" =>
    "var_input test_pb bool\nvar_output lamp_1 bool\n" <>
      "var l1 lamp_relay\nvar l2 lamp_rleay\ncal l1 test_pb lamp_1\ncal l2 test_pb lamp_1\n",
  "lamp_board.ld" => "var_input test_pb bool\nvar panel lamp_panel\ncal panel test_pb\n",
  "dryer_panel.ld" =>
    "var_input test_pb bool\nvar_output lamp_1 bool\nvar d1 dryer\ncal d1 test_pb lamp_1\n"
}

dir = Path.join(System.tmp_dir!(), "function-blocks-#{System.pid()}")
File.rm_rf!(dir)
File.mkdir_p!(dir)
for {name, text} <- wrong, do: File.write!(Path.join(dir, name), text)

for name <- ["lamp_relay.ld", "lamp_panel.ld"],
    do: File.cp!("function-blocks/" <> name, Path.join(dir, name))

report.(26, ["function-blocks/lamp_panel.ld"], &Logex.compile_file/1)

File.cd!(dir, fn ->
  files = ["belt_pair.ld", "wrong_panel.ld", "lamp_board.ld", "dryer_panel.ld"]
  report.(27, files, &Logex.compile_file/1)
end)

File.rm_rf!(dir)
