# Regenerates test/fixtures/frontend_golden.txt from whatever front end this checkout has:
#
#     mix run test/fixtures/generate_frontend_golden.exs
#
# The fixture pins the front end's observable behaviour — for every source, the parse AST
# and the lexer's end line, or the line of a lex or parse error — and
# test/logex/frontend_golden_test.exs holds the current front end to it. It was first
# generated from the leex/yecc front end, so that replacing that front end could be checked
# against a record the old one wrote.
#
# Regenerate ONLY in a commit that changes the language or this generator on purpose, and
# read the diff: apart from the header line, it lists exactly the inputs whose meaning
# changed. Regenerating to make a red golden test go green is how a parity check stops
# being one.

defmodule FrontendGolden do
  # Kept identical to the normaliser in frontend_golden_test.exs. Locations are reduced to
  # their line, so a front end may carry columns without disturbing the record.
  def result(source) do
    case Logex.Compiler.tokenize(source) do
      {:error, {loc, _module, _reason}, _} ->
        {:lex_error, line(loc)}

      {:ok, tokens, end_line} ->
        case Logex.Compiler.parse(tokens) do
          {:ok, ast} -> {:ok, ast, end_line}
          {:error, {loc, _module, _reason}} -> {:parse_error, line(loc), end_line}
        end
    end
  end

  defp line({line, _column}), do: line
  defp line(line) when is_integer(line), do: line

  # Shapes the rest of the suite exercises thinly or not at all: lone CR, CRLF,
  # blank and whitespace-only lines, token boundaries, every unbalanced shape, and where an
  # error is reported when it is not on line 1. Newline coalescing is invisible here,
  # because the record keeps the AST and not the tokens; frontend_test.exs pins it.
  def curated do
    deep = String.duplicate("( ", 30) <> "xic aa" <> String.duplicate(" )", 30) <> " ote xx"
    many = Enum.map_join(1..20, "\n", &"xic t#{&1} ote o#{&1}")

    [
      "",
      " ",
      "\t",
      "\n",
      "\n\n",
      "\r\n",
      "\r",
      "\r\r",
      " \n ",
      "\n \n\t\n",
      "ote aa",
      "ote aa\n",
      "\note aa",
      "\n\note aa\n\n",
      "ote aa\r\note bb",
      "ote aa\rote bb",
      "ote aa\r\n\r\note bb",
      "ote aa\r\r\note bb",
      "ote aa \t\nxic bb ote cc",
      "  ote aa  ",
      "ote\taa",
      "ote aa\n  \n\t\nxio bb ote cc\n",
      "xic aa\n\n\n( xic bb | xic cc ) ote dd\n\n",
      "ote a",
      "ote _",
      "ote _a1",
      "ote A",
      "ote aA9_",
      "mov 0 aa",
      "mov 007 aa",
      "mov 123456789012345678901234567890 aa",
      "mov 1bst aa",
      "mov 12ab cc",
      "ote bst",
      "ote nxb",
      "ote bnd",
      "xic aa1",
      "1",
      "1 2 3",
      "aa bb cc",
      "@",
      "xic @",
      "xic aa\n@",
      "xic aa\n\n\n@ ote bb",
      "ote a-b",
      "ote a.b",
      "ote a[3]",
      "é",
      "ote é",
      "ote aé",
      "xic aa\nxic bb\n#",
      "ote aa // note",
      "/",
      "\\",
      "\"",
      "'",
      ";",
      ",",
      "$",
      "~",
      "{",
      "}",
      "[",
      "]",
      "\v",
      "\f",
      "\0",
      "( )",
      "( | )",
      "(|)",
      "( | | )",
      "( ( ) )",
      "( xic aa | )",
      "( | xic aa )",
      "( xic aa | xic bb ) ote cc",
      "xic aa ( xic bb | xic cc ) ote dd",
      "( ( xic aa | xic bb ) | xic cc ) ote dd",
      "( mov 1 aa | mov 2 bb ) ( ote cc | ote dd )",
      "((((xic aa))))",
      "( xic aa|xic bb ) ote cc",
      "(xic aa)ote bb",
      "xic aa )",
      "( xic aa",
      "xic aa | ote bb",
      ")",
      "|",
      "(",
      "( xic aa\n)",
      "( xic aa |\nxic bb )",
      "xic aa\n( xic bb",
      "xic aa\n\n)",
      ") ote aa",
      "( ) )",
      "( ( )",
      "xic aa\nxic bb |\nxic cc",
      "\n\n( \n )",
      "ote aa\n\n\n\nxic bb )",
      "ote aa\r\n\r\n( xic bb",
      deep,
      many
    ] ++ signed() ++ based() ++ tag_bits()
  end

  # M3-3 (decision 97): negative literals, a sign glued to its digits. Added after the rest,
  # so the record's other entries keep their places and the diff is these alone.
  defp signed do
    [
      "move -5 aa",
      "move -0 aa",
      "move -007 aa",
      "move -2147483648 aa",
      "move -123456789012345678901234567890 aa",
      "-5",
      "-",
      "move - 5 aa",
      "move --5 aa",
      "move +5 aa",
      "move -aa bb",
      "move -5aa bb",
      "move -5_ bb",
      "ote a-5",
      "ote aa -5",
      "move 5-3 aa",
      "move -5-3 aa",
      "xic t1.dn-5",
      "(-5)",
      "( -5 | -6 ) ote aa",
      "( xic aa |-1)",
      "xic aa\n-5 ote bb",
      "xic aa\r\nmove -5 bb\n\nmove 7-x cc",
      "eq aa -1 ote bb // -2"
    ]
  end

  # M5-7 (decision 149): based literals, `16#` and `2#`, and `_` between digits, each with
  # the refusals around it. Added after the rest, and recorded first by the front end before
  # them, so that the diff of the commit that lands them is these entries alone.
  defp based do
    [
      "move 16#ff aa",
      "move 16#FF aa",
      "move 16#Ff aa",
      "move 16#ffff aa",
      "move 16#0 aa",
      "move 16#ffff_ffff_ffff_ffff aa",
      "move 2#1010_0000 aa",
      "move 2#0 aa",
      "move 1_000 aa",
      "move 1_000_000 aa",
      "move -1_000 aa",
      "eq 16#7fff_ffff aa",
      "( move 16#1 a | move 2#1 b )",
      "move 8#17 aa",
      "move 10#5 aa",
      "move 016#ff aa",
      "move 1_6#ff aa",
      "move 16#-1 aa",
      "move -16#1 aa",
      "move 16#_ff aa",
      "move 16#ff_ aa",
      "move 1__0 aa",
      "move 1_ aa",
      "move _1 aa",
      "move 1.5_ aa",
      "move 5U aa",
      "move 5L aa",
      "move 1.5L aa",
      "move 16# aa",
      "move 2#102 aa",
      "move 16#fg aa",
      "move 16#ff#1 aa",
      "move 16#ff-1 aa",
      "move 1_000bst aa",
      "move 16 #ff aa",
      "#ff",
      "xic a.16#f",
      "xic aa\nmove 16#z bb"
    ]
  end

  # M5-9 (decision 160): a bit number held in a tag, `status.[n]`, one name token whose last
  # part is a tag's name in brackets, with the shapes around it that stay refused. Added after
  # the rest, and recorded first by the front end before it, so that the diff of the commit
  # that lands it is these entries alone.
  defp tag_bits do
    [
      "xic status.[n] ote aa",
      "xic drive_faults.[sel] ote fault_lamp",
      "ote status.[n]",
      "xic t1.acc.[n]",
      "xic s.[_n2]",
      "( xic s.[n] | xio s.[m] ) ote aa",
      "xic aa\nxic status.[n]\nmove s.[i] bb",
      "xic s.[3]",
      "xic s.[-1]",
      "xic s.[]",
      "xic s.[n",
      "xic s.[n.m]",
      "xic s.[n]x",
      "xic s.[n].x",
      "xic s.[n].3",
      "xic s.[n][m]",
      "xic s.[n].[m]",
      "xic s.[ n ]",
      "xic s[n]",
      "xic .[n]",
      "xic s.[n]-5",
      "xic s.[n](",
      "xic s.[n]|"
    ]
  end

  # Seeded, so the file is reproducible. Half are drawn from the grammar with whitespace
  # styles scattered through them, so that many parse and their line numbers are
  # non-trivial; half are token soup, so that the error paths are exercised too.
  def random do
    :rand.seed(:exsss, {1, 2, 3})
    grammar = for _ <- 1..400, do: routine()
    soup = for _ <- 1..900, do: soup()
    grammar ++ soup
  end

  @names ~w(aa bb start motor stop _t1 Z9 bst)
  @mnemonics ~w(xic xio ote otl otu mov)
  @gaps [" ", " ", " ", "  ", "\t", " \t "]
  @breaks ["\n", "\n", "\r\n", "\n\n", "\n \n", "\r\n\r\n", "\n\t\n"]

  defp routine do
    rungs = for _ <- 1..Enum.random(1..3), do: rung(2)
    lead = Enum.random(["", "", "\n", "\r\n", " \n"])
    tail = Enum.random(["", "", "\n", "\r\n", "\n\n"])
    lead <> join(rungs, fn -> Enum.random(@breaks) end) <> tail
  end

  defp join([first | rest], sep_fun), do: Enum.reduce(rest, first, &(&2 <> sep_fun.() <> &1))
  defp join([], _), do: ""

  defp rung(depth),
    do: Enum.map_join(1..Enum.random(1..3), Enum.random(@gaps), fn _ -> element(depth) end)

  defp element(0), do: leaf()
  defp element(depth), do: if(:rand.uniform(4) == 1, do: group(depth - 1), else: leaf())

  defp leaf do
    Enum.random([
      Enum.random(@mnemonics) <> Enum.random(@gaps) <> Enum.random(@names),
      Enum.random(@mnemonics) <> Enum.random(@gaps) <> Enum.random(["0", "7", "042", "12"])
    ])
  end

  defp group(depth) do
    legs = for _ <- 1..Enum.random(1..3), do: leg(depth)
    gap = Enum.random(["", " ", "  "])
    "(" <> gap <> Enum.join(legs, gap <> "|" <> gap) <> gap <> ")"
  end

  defp leg(depth), do: if(:rand.uniform(5) == 1, do: "", else: rung(depth))

  @soup ["xic", "xio", "ote", "mov", "aa", "bb", "_t1", "0", "7", "042", "1bst"] ++
          ["(", "|", ")", "@", "é", "\n", "\r\n", "\r", "\t"]

  defp soup do
    for(_ <- 1..Enum.random(1..12), do: Enum.random(@soup))
    |> Enum.map_join(fn t -> Enum.random(["", " ", " ", "  "]) <> t end)
  end
end

sources = Enum.uniq(FrontendGolden.curated() ++ FrontendGolden.random())

{entries, skipped} =
  Enum.reduce(sources, {[], []}, fn source, {entries, skipped} ->
    try do
      {[{source, FrontendGolden.result(source)} | entries], skipped}
    rescue
      error -> {entries, [{source, error} | skipped]}
    end
  end)

entries = Enum.reverse(entries)
{commit, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])

header = """
# Front-end golden record: one {source, expected} per line, read by
# test/logex/frontend_golden_test.exs. Generated by test/fixtures/generate_frontend_golden.exs
# in a working tree on top of #{String.trim(commit)}, on Elixir #{System.version()} / OTP #{System.otp_release()}.
# expected is {:ok, ast, end_line} | {:lex_error, line} | {:parse_error, line, end_line}.
# Do not edit by hand; read that script before regenerating.
"""

body =
  Enum.map_join(entries, "\n", fn entry ->
    inspect(entry, limit: :infinity, printable_limit: :infinity, pretty: false)
  end)

File.write!("test/fixtures/frontend_golden.txt", header <> body <> "\n")

counts = Enum.frequencies_by(entries, fn {_, r} -> elem(r, 0) end)
IO.puts("#{length(entries)} entries written: #{inspect(counts)}")
IO.puts("#{length(skipped)} skipped because the front end raised:")
Enum.each(skipped, fn {s, e} -> IO.puts("  #{inspect(s)}: #{Exception.message(e)}") end)
