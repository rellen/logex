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
    ] ++
      signed() ++
      based() ++
      tag_bits() ++
      literal_bits() ++
      reals() ++
      tiny_reals() ++
      arrays() ++
      element_bits() ++
      instance_arrays()
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

  # A literal in the brackets, `status.[4]`, Logix's spelling of `status.4` (M5-9's fourth
  # question, answered on 2026-10-23), in each spelling of a number, and the brackets that
  # begin as a number and hold no one number. Added after the rest, and recorded first by
  # the front end before it, so that the diff of the commit that lands it is these entries
  # alone.
  defp literal_bits do
    [
      "xic status.[4] ote aa",
      "xic s.[03] ote s.[15]",
      "xic s.[16#3]",
      "xic s.[16#F] ote aa",
      "xic s.[2#11]",
      "xic s.[1_0]",
      "xic s.[-0]",
      "xic t1.acc.[1]",
      "( xic s.[2] | xio s.[n] ) ote aa",
      "xic s.[3x]",
      "xic s.[3",
      "xic s.[3 ]",
      "xic s.[8#3]",
      "xic s.[16#3#]",
      "xic s.[-16#3]",
      "xic s.[1__0]",
      "xic s.[-]",
      "xic s.[3]x",
      "xic s.[3].4",
      "xic s.[3]-5"
    ]
  end

  # M5-10 (decision 149): real literals, digits, a `.`, digits and an optional exponent, a
  # sign glued to them, and the forms decision 149 refuses, `1.`, `.5`, `1e5`, `1.5e+3` and
  # Logix's `1.5L`, with `_` between digits and a real beside a tag's `.` parts. Added after
  # the rest, and recorded first by the front end before them, so that the diff of the
  # commit that lands them is these entries alone.
  defp reals do
    [
      "move 37.5 fan_speed",
      "move -0.25 aa",
      "move 1.5e3 aa",
      "move 1.5E-3 aa",
      "move 0.0 aa",
      "move -0.0 aa",
      "move 1.0e20 aa",
      "move 1_000.5 aa",
      "move 1.000_5 aa",
      "move 1.5e1_0 aa",
      "move 007.5 aa",
      "gt fan_speed 37.5 ote aa",
      "( gt aa 1.5 | lt aa -1.5 ) ote bb",
      "sqrt -4.0 root",
      "move 37.5\nmove 1.25 bb",
      "move 1. aa",
      "move .5 aa",
      "move 1e5 aa",
      "move 1.5e+3 aa",
      "move 1.5L aa",
      "move 1.5e aa",
      "move 1.5e- aa",
      "move 1.5x aa",
      "move 1.5.2 aa",
      "move 1._5 aa",
      "move 1_.5 aa",
      "move 1.5_ aa",
      "move 16#f.5 aa",
      "move 1.0e400 aa",
      "move a-1.5 aa",
      "xic fan_speed.3 ote aa",
      "xic fan_speed.[3] ote aa"
    ]
  end

  # M5-10's second question: a real literal nearer 0.0 than an lreal's smallest normal
  # value, and one no float holds, `1.0e-400`, beside a zero written with an exponent and
  # an lreal's smallest normal, the edge. Added after the rest, and recorded first by the
  # front end before the question's answer, so that the diff of the commit that lands it
  # is these entries alone.
  defp tiny_reals do
    [
      "move 1.0e-40 aa",
      "move 1.0e-310 aa",
      "move -1.0e-320 aa",
      "move 4.9e-324 aa",
      "move 2.225073858507201e-308 aa",
      "move 2.2250738585072014e-308 aa",
      "move 1.0e-400 aa",
      "move 1_0.0e-4_00 aa",
      "move 0.0e-400 aa",
      "move -0.0e-999 aa",
      "gt aa 1.0e-310 ote bb"
    ]
  end

  # M5-11 (decision 151): arrays, a declaration's type word with its sizes, `real[8]`, an
  # initial list, an element with its subscripts, one to three, a literal or a tag's name
  # in any spelling of a number, an element's member, bit or path below an instance, and
  # the brackets that stay refused. Added after the rest, and recorded first by the front
  # end before them, so that the diff of the commit that lands them is these entries alone.
  defp arrays do
    [
      "var temps real[8]",
      "var grid int[4,8]",
      "var cube int[2,3,4]",
      "var limits int[3] 10 20 30",
      "var cells int[2,2,2,2]",
      "xic edge[2] ote lamps[0]",
      "move weights[3] total",
      "move grid[1,7] x",
      "move cube[0,1,2] x",
      "xic flags[slot]",
      "move grid[i,7] x",
      "xic w[16#a]",
      "xic w[1_0]",
      "xic w[-1]",
      "xic w[007]",
      "ons edge[2]",
      "( xic a[0] | xio a[1] ) ote b[2]",
      "move m1.temps[3] x",
      "xic w[2].3",
      "xic w[2].[n]",
      "xic t[2].dn",
      "xic aa\nmove b[1,2] cc",
      "xic a[1](",
      "xic a[]",
      "xic a[1",
      "xic a[1,]",
      "xic a[,1]",
      "xic a[ 1]",
      "xic a[1 ]",
      "xic a[1, 2]",
      "xic a[1.5]",
      "xic a[x.y]",
      "xic a[3x]",
      "xic a[8#3]",
      "xic a[1][2]",
      "xic a[1]x",
      "xic a [1]",
      "xic a[1]-5",
      "xic a.3[2]",
      "xic a[1].",
      "xic a[1]]"
    ]
  end

  # The maintainer's answers of 2026-10-23 (M5-11's second question): a bit of an
  # element, a literal one or one a tag numbers, in every spelling a bit takes, as a
  # contact, a coil and a one-shot's storage bit, and the shapes that stay refused. Added
  # after the rest, and recorded first by the front end before the answer, so that the diff
  # of the commit that lands it is these entries alone.
  defp element_bits do
    [
      "xic faults[2].3 ote lamp",
      "xic faults[02].15 ote lamp",
      "xic grid[1,2].[n] ote lamp",
      "xic faults[2].[16#3] ote lamp",
      "xic faults[2].[03] ote lamp",
      "ote faults[2].3",
      "ons edge[1].0 ote x",
      "osr edge[1].0 pulse[0].1",
      "move faults[2].3 x",
      "xic faults[2].3.4",
      "xic faults[2].[n].1",
      "xic faults[2].[n",
      "xic faults[2].[]",
      "xic faults[2]. [n]",
      "xic faults[2] .3",
      "xic faults[2].[3x]"
    ]
  end

  # M5-14 (decision 154): arrays of instances, a declaration's sized type word of a
  # function block type, an element run by literal subscripts, and a member of an element
  # read and written by literal subscripts or through a tag subscript, a bit of one among
  # them, and the shapes that stay refused. Added after the rest, and recorded first by the
  # front end before M5-14, which reads them all already, so that the diff of the commit
  # that lands it is these entries alone.
  defp instance_arrays do
    [
      "var lane_t ton[4]\nxic go ton lane_t[2] 500",
      "var lanes seal[2,3]\ncal lanes[1,2] go q",
      "xic lane_t[slot].dn ote lamp",
      "move 0 lane_c[i].pv",
      "add lane_c[1].cv 1 lane_c[16#1].pv",
      "xic lane_c[1].cv.3 ote q",
      "xic lane_c[i].cv.[n] ote q",
      "xic grid_t[1,j].tt ote q",
      "xic lane_t[2].dn.x",
      "xic lane_t[2]..dn",
      "xic lane_t[2].dn[1]",
      "xic lane_t[2] .dn",
      "xic lane_t[2]. dn"
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
