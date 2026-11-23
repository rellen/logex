{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n" <>
      "( xic start | xic run ) xio stop ote run",
    name: "seal"
  )

{:ok, cell} = Logex.compile("function_block cell\nvar t ton[256]\nton t[0] 30", name: "cell")

program = fn text -> Logex.compile(text, name: "wrong", types: [seal, cell]) end
block = fn text -> Logex.compile(text, name: "gate") end

groups = [
  {"Declaration lines", program,
   [
     "var",
     "var motor",
     "var 5 bool",
     "var motor.run bool",
     "var lanes[4] bool",
     "var motor bool 1 0",
     "var motor speed dint",
     "var ote bool",
     "var bool bool",
     "var motor bool\nvar motor dint",
     "var motor bool\nvar Motor bool",
     "var_output motor bool\nxic start ote motor",
     "var_input start bool\nvar_output motor bool\nxic start ote motor\nvar count dint"
   ]},
  {"Sections", program,
   [
     "var_input start bool\nvar_temp stop bool\nvar_output motor bool\n" <>
       "xic start xio stop ote motor",
     "var_input start bool 1",
     "var_input start bool\nvar_output motor bool\nxic motor ote start"
   ]},
  {"var_external", program,
   [
     "var_external estop bool 1",
     "var_external task bool"
   ]},
  {"Sections in the file of a function block", block,
   [
     "function_block gate\nvar_external estop bool\nvar_output kick bool\nxio estop ote kick",
     "function_block gate\nvar_input lanes bool[4]\nvar_output kick bool\nxic lanes[0] ote kick"
   ]},
  {"Qualifiers", program,
   [
     "var_input retain start bool",
     "var_external non_retain estop bool",
     "var retain non_retain count dint",
     "var retain retain count dint",
     "var count retain dint",
     "var retain dint",
     "var retian count dint"
   ]},
  {"Elementary types", program,
   [
     "var count dnt"
   ]},
  {"Function block types", program,
   [
     "var_input t1 ton",
     "var t1 ton 5000",
     "var s1 seal 1",
     "var_input go bool\nvar t1 ton\nxic go ton t1 -1",
     "var_input go bool\nvar c1 ctu_int\nxic go ctu c1 40000"
   ]},
  {"Arrays", program,
   [
     "var cube int[2,2,2,2]",
     "var weights int[0]",
     "var weights int[65537]",
     "var weights int[n]",
     "var grid int[2, 3]",
     "var limits int [3]",
     "var limits int[3] 10 20",
     "var limits int[3] 10 20 40000",
     "var lane_t ton[4] 30 30 30 30",
     "var_output lane_t ton[4]",
     "var row cell[256]"
   ]},
  {"Initial values", program,
   [
     "var run bool 2",
     "var run bool true",
     "var trim sint 128",
     "var mask word -1",
     "var count dint 0.5",
     "var ratio real 16777217",
     "var ratio real 3.5e38",
     "var ratio real 1.0e-46"
   ]},
  {"Widening", program,
   [
     "var_input weight int\nvar_output trim sint\nmove weight trim",
     "var_input level dint\nvar_output count udint\nmove level count",
     "var_input run bool\nvar_output code int\nmove run code",
     "var_input status word\nvar_output code uint\nmove status code",
     "var_input status word\nvar_output speed real\nmove status speed",
     "var_input level dint\nvar_output speed real\nmove level speed"
   ]}
]

wrap = fn message ->
  message
  |> String.split(" ")
  |> Enum.chunk_while(
    "     ",
    fn
      word, line when byte_size(line) + byte_size(word) < 80 -> {:cont, line <> " " <> word}
      word, line -> {:cont, line, "      " <> word}
    end,
    fn line -> {:cont, line, ""} end
  )
end

{shown, _next} =
  Enum.map_reduce(groups, 1, fn {section, compile, texts}, first ->
    lines =
      for {text, number} <- Enum.with_index(texts, first) do
        {:error, diagnostics} = compile.(text)
        head = String.pad_leading("#{number}", 2) <> "  " <> String.replace(text, "\n", "\n    ")
        [head | Enum.map(diagnostics, &wrap.(Logex.Diagnostic.format(&1)))]
      end

    {Enum.join(List.flatten([section | lines]), "\n"), first + length(texts)}
  end)

IO.puts(Enum.join(shown, "\n\n"))
