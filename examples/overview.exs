source = File.read!("motor.ld")

# The lexer: text to tokens. Each token has its line and its column.
{:ok, tokens, _end_line} = Logex.Lexer.tokenize(source)

line_of = fn
  {_kind, {line, _column}} -> line
  {_kind, {line, _column}, _text} -> line
end

# Rung 1 is line 10 of motor.ld. Lines 1 to 8 are declarations.
rung_1 = Enum.filter(tokens, fn token -> line_of.(token) == 10 end)
IO.inspect(Enum.take(rung_1, 3), label: "tokens")

# The parser: tokens to the parse tree. Each leaf has its line only.
# The parser makes 1 list of words for each line that is not empty,
# and a declaration is such a line also. Line 10 is the 9th, at index 8.
{:ok, {:routine, {:rungs, lines}}} = Logex.Parser.parse(tokens)
IO.inspect(Enum.at(lines, 8), label: "tree  ", width: 70)

# The compiler: the parse tree to a program type, each rung as IR.
{:ok, motor} = Logex.compile_file("motor.ld")
[ir | _] = motor.rungs
IO.inspect(ir, label: "IR    ", width: 70)

# The runtime: 1 scan of 1 instance. The time that passed is 0 by default.
state = Logex.Runtime.instance(motor)
state = Logex.Runtime.put_inputs(motor, state, %{"start" => 1})
{outputs, _state} = Logex.Runtime.scan(motor, state)
IO.inspect(outputs, label: "scan  ")
