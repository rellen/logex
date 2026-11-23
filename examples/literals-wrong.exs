declarations = """
var_input  eye     bool
var_input  status  word
var_input  hz      real
var_input  level   dint
var_output fault   bool
var_output code    word
var_output rpm     real
var_output flow    lreal
var_output trim    int
var_output count   uint
var        blocked ton
var        cure    ton_ltime
var        boxes   ctu_int
var        s1      seal
"""

{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n" <>
      "( xic start | xic run ) xio stop ote run",
    name: "seal"
  )

compile = fn text -> Logex.compile(declarations <> text, name: "wrong", types: [seal]) end

groups = [
  {"Integer literals",
   [
     "move +5 trim",
     "move - 5 trim",
     "move 5-3 trim",
     "move 5U trim",
     "move 1__0 trim",
     "move 1_ trim"
   ]},
  {"Based integer literals",
   [
     "move 8#17 trim",
     "move -16#1 trim",
     "move 16#-1 trim",
     "move 16#ff# trim",
     "move 16#_ff trim",
     "move 16#fg trim",
     "move 2#102 trim",
     "move 0x1f trim"
   ]},
  {"Real literals",
   [
     "move 1. rpm",
     "move .5 rpm",
     "move 1e5 rpm",
     "move 1.5e+3 rpm",
     "move 1.5e rpm",
     "move 1.5L rpm",
     "move 1.0e309 flow"
   ]},
  {"Where a literal can go",
   [
     "xic 1 ote fault",
     "xic eye ote 1",
     "move 5 trim 6",
     "xic eye ton 5 30_000",
     "xic eye ton blocked level",
     "cal s1 eye 0 1"
   ]},
  {"The type of the place",
   [
     "move 2 fault",
     "move 16#ffff trim",
     "move -1 code",
     "move 1.0 trim",
     "move 16777217 rpm",
     "move 3.5e38 rpm",
     "move 1.0e-38 rpm",
     "move 1.0e-400 flow",
     "add count -1 count",
     "shl code 1.0 code",
     "dint_to_int 2147483648 trim",
     "eq count 65536 ote fault",
     "gt hz 1.0e-40 ote fault",
     "eq 18446744073709551616 5 ote fault",
     "gt 1.0e-310 0.0 ote fault",
     "cal s1 2 0 fault"
   ]},
  {"Presets",
   [
     "xic eye ton blocked -1",
     "xic eye ton blocked 1.5",
     "xic eye ton cure 9223372036854775808",
     "xic eye ctu boxes 40000"
   ]},
  {"Literals that logex refuses for an instruction",
   [
     "div trim 0 trim",
     "div hz -0.0 rpm",
     "sqrt -4.0 rpm",
     "shl code -1 code"
   ]},
  {"Limits",
   [
     {"move <a 1 and 10,000 zeros> flow", "move 1" <> String.duplicate("0", 10_000) <> " flow"},
     "move 0.0e10000 rpm"
   ]},
  {"Forms that logex does not have",
   [
     "move int#5 trim",
     "xic eye ton blocked T#5s",
     "move true fault",
     "move 'a' trim"
   ]}
]

shown = fn
  {text, _source} -> text
  text -> text
end

source = fn
  {_text, source} -> source
  source -> source
end

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

{printed, _next} =
  Enum.map_reduce(groups, 1, fn {section, texts}, first ->
    lines =
      for {text, number} <- Enum.with_index(texts, first) do
        {:error, diagnostics} = compile.(source.(text))
        head = String.pad_leading("#{number}", 2) <> "  " <> shown.(text)
        [head | Enum.map(diagnostics, &wrap.(Logex.Diagnostic.format(&1)))]
      end

    {Enum.join(List.flatten([section | lines]), "\n"), first + length(texts)}
  end)

IO.puts(Enum.join(printed, "\n\n"))
