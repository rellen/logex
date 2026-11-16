declarations = """
var_input start bool
var_input stop bool
var_output motor bool
var status word
var weights int[8]
var t1 ton
var sel int
var lane_t ton[3]
"""

program = fn text -> Logex.compile(declarations <> text, name: "wrong") end
block = fn text -> Logex.compile(text, name: "seal") end

groups = [
  {"Lines", program,
   [
     "xic start xio stop\note motor",
     "( )",
     "xic start ote motor\nvar late bool"
   ]},
  {"Characters, spaces and comments", program,
   [
     "xic start ote motor;",
     "move +5 sel",
     "xic(start) ote motor"
   ]},
  {"Rungs", program,
   [
     "move 1bst sel",
     "move 5-3 sel",
     "start ote motor",
     "5 ote motor",
     "xic start ote motor stop",
     "move 5",
     "xic start ton t1 100 ote motor"
   ]},
  {"Branches", program,
   [
     "( xic start | xic motor\nxio stop ote motor",
     "( xic start | xic motor xio stop ote motor",
     "xic start ) ote motor",
     "xic start | xic motor ote motor"
   ]},
  {"Names", program,
   [
     "var stop.pb bool",
     "var late[3] bool"
   ]},
  {"Element", program,
   [
     "move weights [1] sel",
     "move weights[1, 2] sel",
     "move weights[1][2] sel",
     "move weights[8] sel",
     "move weights[status] sel",
     "move weights sel"
   ]},
  {"Member", program,
   [
     "xic t1.DN ote motor",
     "xic start.dn ote motor",
     "xic t1.dn.x ote motor"
   ]},
  {"Bit", program,
   [
     "xic status.16 ote motor",
     "xic start.0 ote motor",
     "xic status. [3] ote motor",
     "xic status.[ 3] ote motor",
     "xic status.[3x] ote motor",
     "xic status.[3].1 ote motor",
     "xic status.[status] ote motor"
   ]},
  {"Names that must have literal numbers", program,
   [
     "xic start ton lane_t[sel] 30",
     "ons status.[sel] ote motor",
     "xic start osr motor status.[sel]"
   ]},
  {"Labels", program,
   [
     "xic start jmp t1.dn",
     "xic start jmp weights[0]",
     "xic start jmp 5",
     "xic start jmp bool",
     "xic start jmp done",
     "xic start lbl done ote motor",
     "lbl done ote motor\nxic start jmp done",
     "xic start jmp done\nlbl done ote motor\nlbl done ote motor",
     "xic start jmp done\nlbl Done ote motor\nlbl done ote motor"
   ]},
  {"Case and reserved words", program,
   [
     "xic Start ote motor",
     "var Motor bool",
     "var ote bool",
     "var bool bool",
     "var var_input bool"
   ]},
  {"Kinds of file: the first line of a function block", block,
   [
     "var_input start bool\nvar_output run bool\nfunction_block seal\nxic start ote run",
     "function_block\nvar_output run bool\note run",
     "function_block Seal\nvar_output run bool\note run"
   ]},
  {"Kinds of file: the name of the file", &Logex.compile_file/1,
   [
     "motor.txt",
     "motor.logex"
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
