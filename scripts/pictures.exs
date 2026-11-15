# The pictures a script makes, so that none can be wrong (decision 546 (d);
# docs/style-guide.md): a ladder drawing from a program's text, and a timing diagram from a
# real run. A library, with no command of its own: `mix run scripts/draw.exs` draws a
# page's pictures with it, and test/logex/pictures_test.exs holds each picture a page shows
# to what it gives.
#
# A page names a picture's source on the line straight above the picture:
#
#     <!-- rung: motor.ld -->
#     ![The motor program as a ladder diagram.](../assets/motor.svg)
#
#     <!-- rung: motor.ld 1 3 -->          rungs 1 and 3 alone
#
#     <!-- timing: delay.timing.exs -->
#     ![The lamp comes on 3 s after go.](../assets/delay.svg)
#
# `rung:` names a `.ld` file under examples/. `Pictures.Rung` compiles it, reads its text
# through `Logex.Lexer` and `Logex.Parser`, and draws its rungs as a controls engineer
# expects them: the two rails, a contact `-| |-` for `xic` and `-|/|-` for `xio`, a coil
# `-( )-` for `ote`, `-(L)-` for `otl`, `-(U)-` for `otu`, `-(P)-` and `-(N)-` for the pulse
# coils `osr` and `osf`, a box for every other instruction with its operands, parallel
# branches at any depth as legs between two verticals, each element with its tag, each rung
# with its number and the comment above it in the file.
#
# `timing:` names a description under guides/assets/, an Elixir map:
#
#     %{
#       title: "An on-delay timer",
#       program: "delay.ld",                      # under examples/
#       step: 500,                                # the milliseconds each scan is given
#       scans: 12,                                # how many scans to run
#       inputs: %{"go" => [{1, 1}, {9, 0}]},      # from scan 1, go is 1; from scan 9, 0
#       show: ["go", "t1.acc", "t1.dn", "lamp"]   # the signals, top to bottom
#     }
#
# `Pictures.Timing` runs the program through `Logex.Runtime`, one instance, the inputs set
# before the scan they name, and draws each signal after each scan: a bool as a square
# wave, a number as steps on its own scale, a timer's or a counter's `acc` with its
# preset marked, read from the run as every value is. The description gives the inputs
# and the time; it gives no value of a signal.
#
# Both pictures are an SVG with its own light panel, so that it reads on a light and on a
# dark page, a title and a description for a screen reader, text as text, no script and no
# font or file from elsewhere. A script, not a test: it uses `case` freely.
defmodule Pictures do
  @moduledoc false

  @assets "guides/assets"
  @examples "examples"
  @mark ~r/^\s*<!-- (rung|timing): (\S+)((?: \d+)*) -->\s*$/
  @image ~r/^\s*!\[[^\]]*\]\(([^)\s]+)\)/

  # The pictures a page's marks name, `{line, svg path, kind, source, rungs}`, and what is
  # wrong with its marks, each `<page>:<line>: ...`.
  def of(page, text) do
    lines = text |> String.split("\n") |> Enum.with_index(1)

    {found, problems, _} =
      Enum.reduce(lines, {[], [], nil}, fn {line, n}, {found, problems, mark} ->
        case {mark, Regex.run(@mark, line), Regex.run(@image, line)} do
          {_, [_, kind, source, rungs], _} ->
            {found, problems, {kind, source, numbers(rungs)}}

          {{kind, source, rungs}, nil, [_, target]} ->
            svg = resolve(page, target)

            if String.starts_with?(svg, @assets <> "/") and Path.extname(svg) == ".svg" do
              {[{n, svg, kind, source, rungs} | found], problems, nil}
            else
              {found,
               ["#{page}:#{n}: a picture a script makes is an .svg under #{@assets}/" | problems],
               nil}
            end

          {{kind, _source, _rungs}, nil, nil} ->
            {found,
             ["#{page}:#{n}: no picture follows the `#{kind}` mark above this line" | problems],
             nil}

          {nil, nil, [_, target]} ->
            if String.match?(target, ~r/^[a-z]+:/) do
              {found, problems, nil}
            else
              why =
                "a picture with no `rung` or `timing` mark on the line above it: a script makes every picture"

              {found, ["#{page}:#{n}: #{why}" | problems], nil}
            end

          {nil, nil, nil} ->
            {found, problems, nil}
        end
      end)

    {Enum.reverse(found), Enum.reverse(problems)}
  end

  defp numbers(rungs),
    do: rungs |> String.split(" ", trim: true) |> Enum.map(&String.to_integer/1)

  defp resolve(page, target),
    do: Path.relative_to(Path.expand(Path.join(Path.dirname(page), target), "/"), "/")

  # The text of a picture, or `{:error, why}`.
  def draw({_line, _svg, "rung", source, rungs}),
    do: Pictures.Rung.svg(Path.join(@examples, source), rungs)

  def draw({_line, _svg, "timing", source, _}),
    do: Pictures.Timing.svg(Path.join(@assets, source))

  # ---- what both pictures share ----

  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  # A number as an SVG attribute writes it: an integer where it is one, else one decimal.
  def n(x) when is_integer(x), do: Integer.to_string(x)

  def n(x) when is_float(x),
    do:
      if(Float.round(x, 1) == trunc(x),
        do: Integer.to_string(trunc(x)),
        else: :erlang.float_to_binary(x, decimals: 1)
      )

  # The width of a text in the picture's monospace font, by its characters.
  def width(text, size \\ 12), do: String.length(text) * size * 0.62

  @style """
  <style>
    .panel { fill: #ffffff; stroke: #d0d7de; }
    .ink { stroke: #1f2328; stroke-width: 1.6; fill: none; stroke-linecap: round; stroke-linejoin: round; }
    .rail { stroke: #1f2328; stroke-width: 2.6; stroke-linecap: round; }
    .box { fill: #f6f8fa; stroke: #1f2328; stroke-width: 1.6; }
    .grid { stroke: #d8dee4; stroke-width: 1; }
    .mark { stroke: #bc4c00; stroke-width: 1.4; stroke-dasharray: 5 4; fill: none; }
    .wave { stroke: #0550ae; stroke-width: 2; fill: none; stroke-linejoin: miter; }
    text { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 12px; fill: #1f2328; }
    .tag { fill: #0550ae; }
    .dim { fill: #57606a; font-size: 11px; }
    .op { font-weight: 700; }
    .note { fill: #57606a; font-style: italic; }
    .head { font-weight: 700; font-size: 13px; }
    .marked { fill: #bc4c00; font-size: 11px; }
  </style>
  """

  def svg(width, height, title, description, body) do
    w = n(ceil(width))
    h = n(ceil(height))

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}" role="img" aria-labelledby="title description">
    <title id="title">#{escape(title)}</title>
    <desc id="description">#{escape(description)}</desc>
    #{String.trim_trailing(@style)}
    <rect class="panel" x="0.5" y="0.5" width="#{n(ceil(width) - 1)}" height="#{n(ceil(height) - 1)}" rx="6"/>
    #{body}
    </svg>
    """
  end
end

defmodule Pictures.Rung do
  @moduledoc false
  import Pictures, only: [escape: 1, n: 1, width: 1, width: 2]

  @contacts %{"xic" => :open, "xio" => :closed}
  @coils %{"ote" => "", "otl" => "L", "otu" => "U", "osr" => "P", "osf" => "N"}
  @gap 16
  @leg 12

  # The picture of a `.ld` file's rungs, those numbered in `only` or all, or `{:error, why}`.
  def svg(path, only \\ []) do
    case rungs(path) do
      {:ok, rungs} ->
        chosen =
          for {rung, n} <- Enum.with_index(rungs, 1), only == [] or n in only, do: {n, rung}

        missing = only -- Enum.map(chosen, &elem(&1, 0))

        cond do
          missing != [] ->
            {:error,
             "#{path} has #{length(rungs)} rungs, and no rung #{Enum.join(missing, ", ")}"}

          chosen == [] ->
            {:error, "#{path} has no rung"}

          true ->
            {:ok, picture(Path.basename(path), chosen)}
        end

      {:error, why} ->
        {:error, why}
    end
  end

  # A file's rungs as the picture draws them: each `%{text, note, elements}`, an element
  # `{:contact, kind, tag}`, `{:coil, letter, tags}`, `{:box, mnemonic, rows}` or
  # `{:branches, legs}`.
  def rungs(path) do
    with {:ok, source} <- File.read(path),
         {:ok, compiled} <- Logex.compile_file(path),
         {:ok, tokens, _line} <- Logex.Lexer.tokenize(source),
         {:ok, {:routine, {:rungs, parsed}}} <- Logex.Parser.parse(tokens) do
      program = program(compiled)
      lines = String.split(source, "\n")
      written = Enum.take(parsed, -length(program.rungs))

      {:ok,
       for {{:rung, lowered}, {:rung, elements}} <- Enum.zip(program.rungs, written) do
         line = line(lowered)

         %{
           text: lines |> Enum.at(line - 1) |> String.trim(),
           note: note(lines, line - 1, []),
           elements: series(lowered, elements, program)
         }
       end}
    else
      {:error, why} when is_atom(why) ->
        {:error, "#{path}: #{:file.format_error(why)}"}

      {:error, _} ->
        {:error, "#{path} does not compile: a picture is drawn of a program that does"}
    end
  end

  defp program(%Logex.Program{} = program), do: program
  defp program(%Logex.FbType{body: body}), do: body

  defp line([{:branches, [leg | _]} | rest]), do: line(leg ++ rest)
  defp line([{_symbol, line, _operands} | _]), do: line

  # The comment lines straight above a rung's line, joined.
  defp note(lines, at, acc) do
    case at > 0 and Regex.run(~r/^\s*\/\/\s?(.*)$/, Enum.at(lines, at - 1)) do
      [_, text] -> note(lines, at - 1, [String.trim(text) | acc])
      _ -> Enum.join(acc, " ")
    end
  end

  # A leg as it is compiled beside the leg as it is written: each instruction takes its
  # mnemonic and as many operands from the text as the program gives it.
  defp series([], [], _program), do: []

  defp series([{:branches, lowered} | rest], [{:branches, written} | elements], program) do
    legs = for {low, leg} <- Enum.zip(lowered, written), do: series(low, leg, program)
    [{:branches, legs} | series(rest, elements, program)]
  end

  defp series(
         [{symbol, _line, operands} = instruction | rest],
         [{:name, _, word} | elements],
         program
       ) do
    {given, elements} = Enum.split(elements, length(operands))
    mnemonic = String.downcase(word)

    if mnemonic != Atom.to_string(symbol) or length(given) != length(operands),
      do: raise("the text and the program differ at `#{word}`")

    [
      element(mnemonic, Enum.map(given, &spelled/1), captions(instruction, program))
      | series(rest, elements, program)
    ]
  end

  defp spelled({:name, _, word}), do: word
  defp spelled(literal), do: Logex.Parser.spelling(literal)

  defp element(mnemonic, [tag], _captions) when is_map_key(@contacts, mnemonic),
    do: {:contact, @contacts[mnemonic], tag}

  defp element(mnemonic, tags, _captions) when is_map_key(@coils, mnemonic),
    do: {:coil, @coils[mnemonic], tags}

  defp element("ons", [tag], _captions), do: {:shot, "ons", tag}

  defp element(mnemonic, operands, captions), do: {:box, mnemonic, Enum.zip(captions, operands)}

  # What each operand of a box is: a block's member for a `cal`, else its slot's use.
  defp captions({:cal, _line, [instance | arguments]} = instruction, program) do
    members =
      case type(instance, program) do
        %Logex.FbType{members: members} ->
          for %{role: role, name: name} <- members, role in [:input, :output], do: name

        _ ->
          []
      end

    slots = Logex.Compiler.signature(instruction, program.tags)

    [
      ""
      | for(
          {_argument, at} <- Enum.with_index(arguments),
          do: Enum.at(members, at) || caption(Enum.at(slots, at + 1))
        )
    ]
  end

  defp captions({_symbol, _line, operands} = instruction, program) do
    slots = Logex.Compiler.signature(instruction, program.tags)
    for {_operand, at} <- Enum.with_index(operands), do: caption(Enum.at(slots, at))
  end

  defp type({:name, _, name}, program), do: held(program.tags[name], program)
  defp type({:element, _, array, _index, _name}, program), do: held(program.tags[array], program)
  defp type(_instance, _program), do: nil

  defp held(%{type: type}, program), do: program.blocks[Logex.Program.held_name(type)]
  defp held(_tag, _program), do: nil

  defp caption({:instance, _}), do: ""
  defp caption({:preset, _}), do: "preset"
  defp caption({:write, _}), do: "to"
  defp caption({:label, _}), do: "label"
  defp caption(_slot), do: ""

  # ---- the layout: each element its width, its rise above the wire and its fall below ----

  defp size({:contact, _kind, tag}), do: {even(max(width(tag) + 10, 46)), 30, 14}
  defp size({:coil, _letter, tags}), do: {even(max(width(Enum.join(tags, " ")) + 10, 46)), 30, 14}
  defp size({:shot, _mnemonic, tag}), do: {even(max(width(tag) + 10, 52)), 30, 14}

  defp size({:box, mnemonic, rows}) do
    inner =
      for {caption, operand} <- rows,
          do: width(operand) + if(caption == "", do: 0, else: width(caption, 11) + 8)

    {even(max(Enum.max([width(mnemonic) | inner]) + 20, 60)), 13, 13 + length(rows) * 18 + 6}
  end

  defp size({:branches, legs}) do
    sizes = Enum.map(legs, &size_of_series/1)
    wide = sizes |> Enum.map(&elem(&1, 0)) |> Enum.max()
    {_, rise, fall} = hd(sizes)
    below = for {_, rise, fall} <- tl(sizes), do: rise + fall + 12
    {wide + 2 * @leg, rise, fall + Enum.sum(below)}
  end

  defp size_of_series([]), do: {40, 8, 8}

  defp size_of_series(elements) do
    sizes = Enum.map(elements, &size/1)

    {Enum.sum(Enum.map(sizes, &elem(&1, 0))) + @gap * (length(sizes) - 1),
     sizes |> Enum.map(&elem(&1, 1)) |> Enum.max(), sizes |> Enum.map(&elem(&1, 2)) |> Enum.max()}
  end

  # A width as a whole, even number of pixels, so that every line of the picture is drawn
  # on whole pixels.
  defp even(width), do: 2 * ceil(width / 2)

  # ---- the drawing ----

  defp picture(name, rungs) do
    left = 46
    pad = 22
    sizes = for {_n, rung} <- rungs, do: size_of_series(rung.elements)
    notes = for {_n, rung} <- rungs, do: width(rung.note, 11)
    inner = max(Enum.max(Enum.map(sizes, &elem(&1, 0))) + 2 * pad + 40, 300)
    right = left + even(max(inner, Enum.max(notes) + 12))
    total = right + 18

    {body, bottom} =
      Enum.reduce(Enum.zip(rungs, sizes), {[], 22}, fn {{n, rung}, {wide, rise, fall}},
                                                       {body, y} ->
        noted = if rung.note == "", do: 0, else: 18
        wire = y + noted + rise

        note =
          if rung.note == "",
            do: [],
            else: [
              ~s(<text class="note dim" x="#{n(left + 8)}" y="#{n(y + 12)}">#{escape(rung.note)}</text>)
            ]

        drawn = rung(rung.elements, left, right, wire, wide, pad)

        number =
          ~s(<text class="dim" x="#{n(left - 10)}" y="#{n(wire + 4)}" text-anchor="end">#{n}</text>)

        {body ++ note ++ [number | drawn], wire + fall + 20}
      end)

    rails = [
      ~s(<line class="rail" x1="#{n(left)}" y1="14" x2="#{n(left)}" y2="#{n(bottom - 6)}"/>),
      ~s(<line class="rail" x1="#{n(right)}" y1="14" x2="#{n(right)}" y2="#{n(bottom - 6)}"/>)
    ]

    described =
      "#{length(rungs)} #{if length(rungs) == 1, do: "rung", else: "rungs"} between two power rails. " <>
        Enum.map_join(rungs, " ", fn {n, rung} -> "Rung #{n}: #{rung.text}." end)

    Pictures.svg(
      total,
      bottom + 6,
      "Ladder diagram of #{name}",
      described,
      Enum.join(rails ++ body, "\n")
    )
  end

  # A rung: its elements from the left rail, its last coil or box at the right rail, and
  # the wire between.
  defp rung(elements, left, right, wire, _wide, pad) do
    {flow, last} =
      case List.last(elements) do
        {kind, _, _} = last when kind in [:coil, :box] ->
          {Enum.drop(elements, -1), last}

        _ ->
          {elements, nil}
      end

    {drawn, x} = laid(flow, left + pad, wire)

    case last do
      nil ->
        [wire(left, left + pad, wire), wire(x, right, wire) | drawn]

      last ->
        {wide, _, _} = size(last)
        at = right - pad - wide
        {coil, _} = draw(last, at, wire)

        [
          wire(left, left + pad, wire),
          wire(x, at, wire),
          wire(at + wide, right, wire) | drawn ++ coil
        ]
    end
  end

  # A series drawn from `x` on the wire at `y`: its parts and where it ends.
  defp laid(elements, x, y) do
    {drawn, x} =
      Enum.reduce(elements, {[], x}, fn element, {drawn, x} ->
        {part, wide} = draw(element, x, y)
        {drawn ++ part ++ [wire(x + wide, x + wide + @gap, y)], x + wide + @gap}
      end)

    case elements do
      [] -> {drawn, x}
      _ -> {Enum.drop(drawn, -1), x - @gap}
    end
  end

  defp wire(from, to, y),
    do: ~s(<line class="ink" x1="#{n(from)}" y1="#{n(y)}" x2="#{n(to)}" y2="#{n(y)}"/>)

  defp label(text, x, y, class \\ "tag"),
    do:
      ~s(<text class="#{class}" x="#{n(x)}" y="#{n(y)}" text-anchor="middle">#{escape(text)}</text>)

  defp draw({:contact, kind, tag} = element, x, y) do
    {wide, _, _} = size(element)
    middle = x + wide / 2

    slash =
      if kind == :closed,
        do: [
          ~s(<line class="ink" x1="#{n(middle - 5)}" y1="#{n(y + 9)}" x2="#{n(middle + 5)}" y2="#{n(y - 9)}"/>)
        ],
        else: []

    {[
       label(tag, middle, y - 17),
       wire(x, middle - 7, y),
       ~s(<line class="ink" x1="#{n(middle - 7)}" y1="#{n(y - 11)}" x2="#{n(middle - 7)}" y2="#{n(y + 11)}"/>),
       ~s(<line class="ink" x1="#{n(middle + 7)}" y1="#{n(y - 11)}" x2="#{n(middle + 7)}" y2="#{n(y + 11)}"/>),
       wire(middle + 7, x + wide, y)
     ] ++ slash, wide}
  end

  defp draw({:coil, letter, tags} = element, x, y) do
    {wide, _, _} = size(element)
    middle = x + wide / 2

    inside = if letter == "", do: [], else: [label(letter, middle, y + 4, "op")]

    {[
       label(Enum.join(tags, " "), middle, y - 17),
       wire(x, middle - 11, y),
       ~s(<path class="ink" d="M #{n(middle - 6)} #{n(y - 11)} Q #{n(middle - 16)} #{n(y)} #{n(middle - 6)} #{n(y + 11)}"/>),
       ~s(<path class="ink" d="M #{n(middle + 6)} #{n(y - 11)} Q #{n(middle + 16)} #{n(y)} #{n(middle + 6)} #{n(y + 11)}"/>),
       wire(middle + 11, x + wide, y)
     ] ++ inside, wide}
  end

  defp draw({:shot, mnemonic, tag} = element, x, y) do
    {wide, _, _} = size(element)
    middle = x + wide / 2

    {[
       label(tag, middle, y - 17),
       wire(x, middle - 19, y),
       ~s(<rect class="box" x="#{n(middle - 19)}" y="#{n(y - 10)}" width="38" height="20" rx="3"/>),
       label(mnemonic, middle, y + 4, "op"),
       wire(middle + 19, x + wide, y)
     ], wide}
  end

  defp draw({:box, mnemonic, rows} = element, x, y) do
    {wide, rise, fall} = size(element)

    lines =
      for {{caption, operand}, at} <- Enum.with_index(rows) do
        base = y + 13 + at * 18 + 14

        captioned =
          if caption == "",
            do: [],
            else: [
              ~s(<text class="dim" x="#{n(x + 10)}" y="#{n(base)}">#{escape(caption)}</text>)
            ]

        captioned ++
          [
            ~s(<text class="tag" x="#{n(x + wide - 10)}" y="#{n(base)}" text-anchor="end">#{escape(operand)}</text>)
          ]
      end

    {[
       ~s(<rect class="box" x="#{n(x)}" y="#{n(y - rise)}" width="#{n(wide)}" height="#{n(rise + fall)}" rx="3"/>),
       ~s(<line class="ink" x1="#{n(x)}" y1="#{n(y + 13)}" x2="#{n(x + wide)}" y2="#{n(y + 13)}"/>),
       label(mnemonic, x + wide / 2, y + 4, "op")
     ] ++ List.flatten(lines), wide}
  end

  defp draw({:branches, legs} = element, x, y) do
    {wide, _, _} = size(element)

    {drawn, last} =
      Enum.reduce(Enum.with_index(legs), {[], y}, fn {leg, at}, {drawn, below} ->
        {_, rise, fall} = size_of_series(leg)
        wire = if at == 0, do: y, else: below + 12 + rise
        {parts, to} = laid(leg, x + @leg, wire)
        joined = [wire(x, x + @leg, wire), wire(to, x + wide, wire)]
        {drawn ++ parts ++ joined, wire + fall}
      end)

    bottom = last - elem(size_of_series(List.last(legs)), 2)

    {[
       ~s(<line class="ink" x1="#{n(x)}" y1="#{n(y)}" x2="#{n(x)}" y2="#{n(bottom)}"/>),
       ~s(<line class="ink" x1="#{n(x + wide)}" y1="#{n(y)}" x2="#{n(x + wide)}" y2="#{n(bottom)}"/>)
       | drawn
     ], wide}
  end
end

defmodule Pictures.Timing do
  @moduledoc false
  import Pictures, only: [escape: 1, n: 1, width: 1]

  @keys [:title, :program, :step, :scans, :inputs, :show]

  # The picture of a description's run, or `{:error, why}`.
  def svg(path) do
    with {:ok, description} <- description(path),
         {:ok, run} <- run(description) do
      {:ok, picture(description, run)}
    end
  end

  def description(path) do
    case File.exists?(path) and Code.eval_file(path) do
      false ->
        {:error, "#{path} is not there"}

      {%{} = map, _} ->
        cond do
          Enum.sort(Map.keys(map)) != Enum.sort(@keys) ->
            {:error,
             "#{path}: a description has the keys #{Enum.map_join(@keys, ", ", &inspect/1)}, and no other"}

          not (is_integer(map.step) and map.step > 0 and is_integer(map.scans) and
                   map.scans in 1..200) ->
            {:error,
             "#{path}: step is a number of milliseconds, 1 or more, and scans a number from 1 to 200"}

          true ->
            {:ok, map}
        end

      _ ->
        {:error, "#{path}: a description is a map"}
    end
  end

  # The run: for each signal shown, its value after each scan, and for an `acc` its
  # preset, each read from the instance.
  def run(%{program: name, step: step, scans: scans, inputs: inputs, show: show}) do
    path = Path.join("examples", name)

    with {:ok, %Logex.Program{} = program} <- Logex.compile_file(path) do
      changes =
        for {tag, list} <- inputs,
            {scan, value} <- list,
            reduce: %{},
            do: (acc -> Map.update(acc, scan, %{tag => value}, &Map.put(&1, tag, value)))

      {states, _} =
        Enum.map_reduce(1..scans, Logex.Runtime.instance(program), fn scan, state ->
          state = Logex.Runtime.put_inputs(program, state, Map.get(changes, scan, %{}))
          {_outputs, state} = Logex.Runtime.scan(program, state, step)
          {state.env, state}
        end)

      values = for signal <- show, do: {signal, Enum.map(states, &read(&1, signal))}

      case for {signal, list} <- values, Enum.any?(list, &(not is_number(&1))), do: signal do
        [] ->
          {:ok,
           %{
             values: values,
             kinds: Map.new(show, &{&1, kind(program, &1)}),
             presets:
               for(
                 signal <- show,
                 preset = preset(List.last(states), signal),
                 into: %{},
                 do: {signal, preset}
               )
           }}

        unread ->
          {:error,
           "#{name} has no tag or member `#{Enum.join(unread, "`, `")}` whose value is a number"}
      end
    else
      _ -> {:error, "#{path} does not compile as a program: a diagram is drawn of a run"}
    end
  end

  defp read(env, signal), do: get_in(env, String.split(signal, "."))

  defp kind(program, signal) do
    case String.split(signal, ".") do
      [tag] -> if match?(%{type: :bool}, program.tags[tag]), do: :bool, else: :number
      [_instance, member] -> if member in ~w(acc pre cv pv), do: :number, else: :bool
      _ -> :number
    end
  end

  defp preset(env, signal) do
    case String.split(signal, ".") do
      [instance, "acc"] -> is_map(env[instance]) && env[instance]["pre"]
      _ -> nil
    end
  end

  # ---- the drawing ----

  defp picture(%{title: title, step: step, scans: scans, show: show}, run) do
    gutter = Enum.max(for(signal <- show, do: width(signal))) + 52
    column = max(30, min(56, 620 / scans))
    plot = column * scans
    total = gutter + plot + 24
    top = 44

    {lanes, bottom} =
      Enum.reduce(run.values, {[], top}, fn {signal, values}, {lanes, y} ->
        kind = run.kinds[signal]
        height = if kind == :bool, do: 26, else: 54
        preset = run.presets[signal]
        high = Enum.max([1 | values] ++ if(preset, do: [preset], else: []))
        low = min(0, Enum.min(values))
        level = fn value -> y + height - (value - low) / (high - low) * height end

        points =
          values
          |> Enum.with_index()
          |> Enum.flat_map(fn {value, at} ->
            [{gutter + at * column, level.(value)}, {gutter + (at + 1) * column, level.(value)}]
          end)

        first = {gutter, level.(0)}

        path =
          Enum.map_join([first | points], " ", fn {x, y} ->
            "#{n(Float.round(x * 1.0, 1))},#{n(Float.round(y * 1.0, 1))}"
          end)

        scale =
          if kind == :bool do
            []
          else
            [
              ~s(<text class="dim" x="#{n(gutter - 8)}" y="#{n(y + 4)}" text-anchor="end">#{high}</text>),
              ~s(<text class="dim" x="#{n(gutter - 8)}" y="#{n(y + height + 4)}" text-anchor="end">#{low}</text>)
            ]
          end

        marked =
          if preset do
            [
              ~s(<line class="mark" x1="#{n(gutter)}" y1="#{n(Float.round(level.(preset) * 1.0, 1))}" x2="#{n(gutter + plot)}" y2="#{n(Float.round(level.(preset) * 1.0, 1))}"/>),
              ~s(<text class="marked" x="#{n(gutter + 6)}" y="#{n(Float.round(level.(preset) * 1.0, 1) + 13)}">preset #{preset}</text>)
            ]
          else
            []
          end

        lane =
          [
            ~s(<text class="tag" x="14" y="#{n(y + height / 2 + 4)}">#{escape(signal)}</text>),
            ~s(<line class="grid" x1="#{n(gutter)}" y1="#{n(y + height)}" x2="#{n(gutter + plot)}" y2="#{n(y + height)}"/>)
          ] ++ scale ++ marked ++ [~s(<polyline class="wave" points="#{path}"/>)]

        {lanes ++ lane, y + height + 22}
      end)

    grid =
      for at <- 0..scans do
        x = gutter + at * column

        ~s(<line class="grid" x1="#{n(x)}" y1="#{n(top - 8)}" x2="#{n(x)}" y2="#{n(bottom - 14)}"/>)
      end

    every = max(1, ceil(scans / 12))

    axis =
      for at <- 1..scans, rem(at, every) == 0 do
        x = gutter + (at - 1) * column

        [
          ~s(<text class="dim" x="#{n(x)}" y="#{n(bottom + 2)}" text-anchor="middle">#{at}</text>),
          ~s(<text class="dim" x="#{n(x)}" y="#{n(bottom + 16)}" text-anchor="middle">#{time(at * step)}</text>)
        ]
      end

    labels = [
      ~s(<text class="head" x="14" y="24">#{escape(title)}</text>),
      ~s(<text class="dim" x="14" y="#{n(bottom + 2)}">scan</text>),
      ~s(<text class="dim" x="14" y="#{n(bottom + 16)}">time</text>)
    ]

    described =
      "#{scans} scans, #{step} ms a scan. Each signal after each scan, from scan 1: " <>
        Enum.map_join(run.values, " ", fn {signal, values} ->
          preset = run.presets[signal]

          "#{signal}: #{Enum.join(values, ", ")}#{if preset, do: " (preset #{preset})", else: ""}."
        end)

    Pictures.svg(
      total,
      bottom + 28,
      title,
      described,
      Enum.join(labels ++ grid ++ lanes ++ List.flatten(axis), "\n")
    )
  end

  defp time(ms) when rem(ms, 1000) == 0, do: "#{div(ms, 1000)} s"
  defp time(ms) when ms >= 1000, do: "#{:erlang.float_to_binary(ms / 1000, decimals: 1)} s"
  defp time(ms), do: "#{ms} ms"
end
