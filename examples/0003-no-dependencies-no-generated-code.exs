# Load the description of logex if no Mix project loaded it.
_ = Application.load(:logex)
IO.puts("logex needs: #{inspect(Application.spec(:logex, :applications))}")

# The file that each module of logex comes from.
modules = Application.spec(:logex, :modules)
files = Enum.map(modules, &to_string(&1.module_info(:compile)[:source]))

from_lib =
  Enum.all?(files, &(String.contains?(&1, "/lib/logex") and String.ends_with?(&1, ".ex")))

IO.puts("each module comes from a .ex file under lib/: #{from_lib}")

# Text to tokens, tokens to a tree, the tree to text, and that text to a tree again.
text = """
( xic start | xic motor ) xio stop ote motor
xic motor ( xio overtemp | ) ote run_lamp
"""

{:ok, tokens, _end_line} = Logex.Lexer.tokenize(text)
{:ok, tree} = Logex.Parser.parse(tokens)
{:routine, {:rungs, [_rung_1, {:rung, [_xic, _motor, group | _]}]}} = tree
IO.puts("the branch of rung 2: #{inspect(group)}")

printed = Logex.Printer.print(tree)
IO.puts(printed)
{:ok, tokens, _end_line} = Logex.Lexer.tokenize(printed)
same = Logex.Parser.parse(tokens) == {:ok, tree}
IO.puts("the printed text reads back as the same tree: #{same}")
