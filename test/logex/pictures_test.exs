Code.require_file("../../scripts/pictures.exs", __DIR__)

defmodule Logex.PicturesTest do
  @moduledoc """
  The pictures a script makes (decision 546 (d)), `scripts/pictures.exs`: a ladder drawing
  from a program's text and a timing diagram from a run. Every `.ld` file under `examples/`
  is drawn; a drawing's elements are its program's, each with its tag; a diagram's values
  are a run's, made again here, and never its description's; a picture is an SVG with a
  title and a description, text as text, no script and nothing fetched. And the hold:
  each picture a page shows carries a mark that names its source, and its file under
  `guides/assets/` is what its script gives today, so that a picture cannot go stale; a
  file there no page's mark names is refused, and so are two marks that name one file and
  differ in its source. `scripts/draw.exs`, the command a writer runs, is run as a writer
  runs it, in a small tree of the test's own.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir
  @root Path.expand("../..", __DIR__)
  # The `elixir` beside the Elixir the suite runs on, or else the one on the path.
  @elixir Enum.find(
            [
              Path.expand(Path.join([:code.lib_dir(:elixir), "..", "..", "bin", "elixir"])),
              System.find_executable("elixir")
            ],
            &File.exists?(to_string(&1))
          )

  defp in_root(fun), do: File.cd!(@root, fun)

  describe "a ladder drawing" do
    test "every .ld file under examples/ is drawn" do
      files = Path.wildcard(Path.join(@root, "examples/**/*.ld"))
      assert length(files) > 30

      for path <- files do
        assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg(Path.relative_to(path, @root)) end)
        assert well_made?(svg), path
      end
    end

    test "motor.ld's rungs are read as a controls engineer draws them: a branch of two " <>
           "contacts, a closed contact and a coil; latch and unlatch coils; a box" do
      assert {:ok, rungs} = in_root(fn -> Pictures.Rung.rungs("examples/motor.ld") end)

      assert Enum.map(rungs, & &1.elements) == [
               [
                 {:branches, [[{:contact, :open, "start"}], [{:contact, :open, "motor"}]]},
                 {:contact, :closed, "stop"},
                 {:coil, "", "motor"}
               ],
               [{:contact, :open, "motor"}, {:coil, "", "run_lamp"}],
               [{:contact, :open, "overtemp"}, {:coil, "L", "fault"}],
               [{:contact, :open, "reset"}, {:coil, "U", "fault"}],
               [{:contact, :open, "fault"}, {:box, "move", [{"", "0"}, {"to", "speed_sp"}]}]
             ]

      assert Enum.map(rungs, & &1.text) == [
               "( xic start | xic motor ) xio stop ote motor",
               "xic motor ote run_lamp",
               "xic overtemp otl fault",
               "xic reset otu fault",
               "xic fault move 0 speed_sp"
             ]
    end

    test "a timer is a box with its instance and its preset, a one-shot stands in the " <>
           "rung with its storage bit, a call names each member it wires, a rung keeps " <>
           "the comment above it" do
      rungs = fn file -> elem(in_root(fn -> Pictures.Rung.rungs("examples/#{file}") end), 1) end

      assert [[_, {:box, "ton", [{"", "t1"}, {"preset", "3000"}]}], _, shot, _] =
               Enum.map(rungs.("delay.ld"), & &1.elements)

      assert shot == [{:contact, :open, "go"}, {:shot, "ons", "s1"}, {:coil, "", "pulse"}]

      # A pulse coil has its storage bit and its pulse bit, each named for what it is.
      assert [[_, {:pulse, "P", "s1", "step"}, {:coil, "", "held_lamp"}], _, falling] =
               Enum.map(rungs.("step.ld"), & &1.elements)

      assert falling == [{:contact, :open, "eye"}, {:pulse, "N", "s2", "box_left"}]

      assert [
               {:box, "cal",
                [{"", "s1"}, {"start", "start_1"}, {"stop", "stop"}, {"run", "belt_1"}]}
             ] =
               hd(rungs.("belts.ld")).elements

      assert hd(rungs.("jog.ld")).note == "in auto, jump over the manual section"
      assert [%{note: ""} | _] = rungs.("motor.ld")
    end

    test "the picture draws each element once: its tag, its symbol, the two rails, each " <>
           "rung's number, and says each rung in its description" do
      assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg("examples/motor.ld") end)

      count = fn text -> length(String.split(svg, text)) - 1 end
      assert count.(~s(class="rail")) == 2

      assert for(
               tag <- ~w(start stop overtemp reset run_lamp speed_sp),
               do: count.(">#{tag}</text>")
             ) == [1, 1, 1, 1, 1, 1]

      assert {count.(">motor</text>"), count.(">fault</text>")} == {3, 3}
      assert {count.(">L</text>"), count.(">U</text>"), count.(">move</text>")} == {1, 1, 1}
      assert for(n <- 1..5, do: count.(~s(text-anchor="end">#{n}</text>))) == [1, 1, 1, 1, 1]
      assert svg =~ "<title id=\"title\">Ladder diagram of motor.ld</title>"

      assert svg =~
               "5 rungs between two power rails. Rung 1: ( xic start | xic motor ) xio stop " <>
                 "ote motor. Rung 2: xic motor ote run_lamp."
    end

    # seal.ld's one rung, `( xic start | xic run ) xio stop ote run`: the wire from the
    # left rail, to the coil and to the right rail, 3 lines; the branch, its 2 verticals
    # and for each leg a contact's 4 lines and the leg's 2 joins, 14; the wire after it;
    # the closed contact, 4 lines and its slash; and the coil, 2 wires and 2 arcs.
    test "a drawing's lines are its elements': an open contact's four, a closed contact's " <>
           "five, a coil's two wires and two arcs, a branch's verticals and joins" do
      assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg("examples/seal.ld") end)
      count = fn text -> length(String.split(svg, text)) - 1 end

      assert {count.(~s(<line class="ink")), count.(~s(<path class="ink"))} ==
               {3 + 14 + 1 + 5 + 2, 2}

      assert {count.(~s(<rect class="box")), count.(~s(class="op"))} == {0, 0}

      assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg("examples/delay.ld", [1, 3]) end)
      count = fn text -> length(String.split(svg, text)) - 1 end
      # A timer's box and its rule; a one-shot's small box.
      assert {count.(~s(<rect class="box")), count.(">ton</text>"), count.(">ons</text>")} ==
               {2, 1, 1}

      assert {count.(">preset</text>"), count.(">3000</text>"), count.(">s1</text>")} == {1, 1, 1}
    end

    test "a pulse coil is drawn with its pulse bit over it and its storage bit named under it" do
      assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg("examples/step.ld") end)
      count = fn text -> length(String.split(svg, text)) - 1 end

      assert {count.(">P</text>"), count.(">N</text>"), count.(">box_left</text>")} == {1, 1, 1}
      assert count.(~s(>storage <tspan class="tag">s1</tspan></text>)) == 1
      assert count.(~s(>storage <tspan class="tag">s2</tspan></text>)) == 1
      refute svg =~ ">s1 step<"
    end

    # A coil's two arcs start 6 pixels each side of its middle: the coils that end
    # motor.ld's first four rungs, a short tag over one and a long tag over another, have
    # one middle.
    test "the coils that end the rungs stand in one column at the right rail, a tag wider " <>
           "than the coil ending with it" do
      assert {:ok, svg} = in_root(fn -> Pictures.Rung.svg("examples/motor.ld") end)
      arcs = for [_, x] <- Regex.scan(~r/<path class="ink" d="M (\d+) /, svg), do: x
      assert [left, right] = Enum.uniq(arcs)
      assert {length(arcs), String.to_integer(right) - String.to_integer(left)} == {8, 12}
      assert svg =~ ~r/text-anchor="end">run_lamp<\/text>/
      assert svg =~ ~r/text-anchor="middle">motor<\/text>/
    end

    test "a rung's comment is cut into lines no wider than the rungs, and widens no drawing",
         %{tmp_dir: dir} do
      assert Pictures.Rung.wrapped("in auto, jump over the manual section", 20) ==
               ["in auto, jump over", "the manual section"]

      assert Pictures.Rung.wrapped("a-word-longer-than-a-line and one", 10) ==
               ["a-word-longer-than-a-line", "and one"]

      assert Pictures.Rung.wrapped("", 10) == []

      program = "var_input a bool\nvar_output b bool\n\nxic a ote b\n"
      comment = "// " <> String.duplicate("a long comment on a short rung ", 6)
      commented = String.replace(program, "xic a", comment <> "\nxic a")
      File.write!(Path.join(dir, "bare.ld"), program)
      File.write!(Path.join(dir, "noted.ld"), commented)

      assert {:ok, bare} = Pictures.Rung.svg(Path.join(dir, "bare.ld"))
      assert {:ok, noted} = Pictures.Rung.svg(Path.join(dir, "noted.ld"))

      width = fn svg ->
        hd(Regex.run(~r/<svg [^>]*width="(\d+)"/, svg, capture: :all_but_first))
      end

      assert width.(noted) == width.(bare)
      assert length(String.split(noted, ~s(class="note dim"))) - 1 == 5
    end

    test "a file that does not compile is refused with what logex says of it, its line",
         %{tmp_dir: dir} do
      path = Path.join(dir, "wrong.ld")
      File.write!(path, "var_input a bool\nvar_output b bool\n\nxic a ote lamp\n")

      assert Pictures.Rung.svg(path) ==
               {:error,
                "#{path}: line 4: `lamp` is not declared: a picture is drawn of a program " <>
                  "that compiles"}
    end

    test "rungs can be drawn alone, by their numbers; a number the file has no rung for, " <>
           "and a file that does not compile, are refused" do
      assert {:ok, one} = in_root(fn -> Pictures.Rung.svg("examples/motor.ld", [3]) end)
      assert one =~ "1 rung between two power rails. Rung 3: xic overtemp otl fault.</desc>"
      refute one =~ ">start</text>"

      assert in_root(fn -> Pictures.Rung.svg("examples/motor.ld", [2, 9]) end) ==
               {:error, "examples/motor.ld has 5 rungs, and no rung 9"}

      assert in_root(fn -> Pictures.Rung.svg("examples/gone.ld") end) ==
               {:error, "examples/gone.ld: no such file or directory"}

      assert in_root(fn -> Pictures.Rung.svg("mix.exs") end) ==
               {:error,
                "mix.exs: `mix.exs` is not a `.ld` file: Logex.compile_file/1 compiles a " <>
                  "program or a function block from its `.ld` file: a picture is drawn of a " <>
                  "program that compiles"}
    end
  end

  describe "a timing diagram" do
    @description %{
      title: "A timer",
      program: "delay.ld",
      step: 500,
      scans: 10,
      inputs: %{"go" => [{2, 1}, {9, 0}]},
      show: ["go", "t1.acc", "t1.dn", "lamp"]
    }

    # The same run, made here through the host contract alone.
    defp oracle(description) do
      {:ok, program} = Logex.compile_file(Path.join([@root, "examples", description.program]))

      {envs, _} =
        Enum.map_reduce(1..description.scans, Logex.Runtime.instance(program), fn scan, state ->
          inputs =
            for {tag, changes} <- description.inputs,
                {^scan, value} <- changes,
                into: %{},
                do: {tag, value}

          state = Logex.Runtime.put_inputs(program, state, inputs)
          {_, state} = Logex.Runtime.scan(program, state, description.step)
          {state.env, state}
        end)

      envs
    end

    test "each signal's values are the run's, scan by scan, and a timer's preset is read " <>
           "from the run" do
      assert {:ok, run} = in_root(fn -> Pictures.Timing.run(@description) end)
      envs = oracle(@description)

      assert run.values == [
               {"go", Enum.map(envs, & &1["go"])},
               {"t1.acc", Enum.map(envs, & &1["t1"]["acc"])},
               {"t1.dn", Enum.map(envs, & &1["t1"]["dn"])},
               {"lamp", Enum.map(envs, & &1["lamp"])}
             ]

      assert Enum.map(envs, & &1["t1"]["acc"]) == [0, 0, 500, 1000, 1500, 2000, 2500, 3000, 0, 0]
      assert Enum.map(envs, & &1["lamp"]) == [0, 0, 0, 0, 0, 0, 0, 1, 0, 0]
      assert run.presets == %{"t1.acc" => 3000}
      assert run.kinds == %{"go" => :bool, "t1.acc" => :number, "t1.dn" => :bool, "lamp" => :bool}
    end

    test "the picture says the run in its description, marks the preset and names each " <>
           "signal",
         %{} do
      path = Path.join(System.tmp_dir!(), "timing-#{System.unique_integer([:positive])}.exs")
      File.write!(path, inspect(@description))
      assert {:ok, svg} = in_root(fn -> Pictures.Timing.svg(path) end)
      File.rm!(path)

      assert well_made?(svg)
      assert svg =~ "<title id=\"title\">A timer</title>"

      assert svg =~
               "10 scans, 500 ms a scan. Each signal after each scan, from scan 1: go: 0, 1, " <>
                 "1, 1, 1, 1, 1, 1, 0, 0. t1.acc: 0, 0, 500, 1000, 1500, 2000, 2500, 3000, 0, " <>
                 "0 (preset 3000). t1.dn: 0, 0, 0, 0, 0, 0, 0, 1, 0, 0. lamp: 0, 0, 0, 0, 0, " <>
                 "0, 0, 1, 0, 0.</desc>"

      assert svg =~ ">preset 3000</text>"
      for signal <- @description.show, do: assert(svg =~ ">#{signal}</text>")
    end

    test "a description with a key too many, a time that is none, a signal the program " <>
           "does not have and a file that is not there are refused" do
      refused = fn description ->
        path = Path.join(System.tmp_dir!(), "timing-#{System.unique_integer([:positive])}.exs")
        File.write!(path, inspect(description))
        result = in_root(fn -> Pictures.Timing.svg(path) end)
        File.rm!(path)
        {:error, why} = result
        String.replace(why, path, "it")
      end

      assert refused.(Map.put(@description, :values, %{"lamp" => [1]})) ==
               "it: a description has the keys :title, :program, :step, :scans, :inputs, :show, and no other"

      assert refused.(%{@description | step: 0}) ==
               "it: step is a number of milliseconds, 1 or more, and scans a number from 1 to 200"

      assert refused.(%{@description | show: ["go", "t9.acc", "lmap"]}) ==
               "delay.ld has no tag or member `t9.acc`, `lmap` whose value is a number"

      assert in_root(fn -> Pictures.Timing.svg("guides/assets/gone.timing.exs") end) ==
               {:error, "guides/assets/gone.timing.exs is not there"}
    end
  end

  # An SVG a page can show anywhere: a title and a description, its own panel, text as
  # text, no script, and nothing it would fetch.
  defp well_made?(svg) do
    String.starts_with?(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\"") and
      svg =~ ~r/<title id="title">[^<]+<\/title>\n<desc id="description">[^<]+<\/desc>/ and
      svg =~ ~s(role="img" aria-labelledby="title description") and
      svg =~ ~s(<rect class="panel") and svg =~ "<text" and
      not (svg =~ ~r/<script|href=|url\(|@import|@font-face|<image|<foreignObject/)
  end

  describe "a page's pictures" do
    test "a mark names the picture on the line below it: a rung drawing, some rungs of " <>
           "one, a timing diagram" do
      text = """
      # A page

      <!-- rung: motor.ld -->
      ![The motor program.](../assets/motor.svg)

      <!-- rung: motor.ld 1 3 -->
      ![Two rungs.](../assets/motor-two.svg)

      <!-- timing: delay.timing.exs -->
      ![The lamp.](../assets/delay.svg)

      ![A badge](https://example.com/badge.svg)
      """

      assert Pictures.of("guides/tutorials/a.md", text) ==
               {[
                  {4, "guides/assets/motor.svg", "rung", "motor.ld", []},
                  {7, "guides/assets/motor-two.svg", "rung", "motor.ld", [1, 3]},
                  {10, "guides/assets/delay.svg", "timing", "delay.timing.exs", []}
                ], []}
    end

    test "a picture with no mark, a mark with no picture and a picture outside " <>
           "guides/assets/ are problems" do
      text = """
      ![A drawing by hand](../assets/hand.svg)

      <!-- rung: motor.ld -->

      The picture is late.

      <!-- rung: motor.ld -->
      ![The motor program.](motor.svg)

      <!-- timing: delay.timing.exs -->
      ![The lamp.](../assets/delay.png)
      """

      assert Pictures.of("guides/tutorials/a.md", text) ==
               {[],
                [
                  "guides/tutorials/a.md:1: a picture with no `rung` or `timing` mark on the " <>
                    "line above it: a script makes every picture",
                  "guides/tutorials/a.md:4: no picture follows the `rung` mark above this line",
                  "guides/tutorials/a.md:8: a picture a script makes is an .svg under guides/assets/",
                  "guides/tutorials/a.md:11: a picture a script makes is an .svg under guides/assets/"
                ]}
    end

    test "a mark and a picture inside a code block are a page's text, shown, and not read" do
      text = """
      To name a picture, write its mark on the line above it:

      ```markdown
      <!-- rung: motor.ld -->

      ![A drawing by hand](../assets/hand.png)

      <!-- timing: delay.timing.exs -->
      ```

      ~~~
      ![No mark](../assets/hand.svg)
      ~~~
      """

      assert Pictures.of("guides/tutorials/a.md", text) == {[], []}
    end

    # The pages the pictures are held on: README and every page that is not a legacy
    # document, as the examples are.
    defp pages do
      {listed, _} = Code.eval_file(Path.join(@root, "docs/pages.exs"))
      for {path, kind, _group} <- listed, kind != :legacy or path == "README.md", do: path
    end

    test "two marks that name one file and differ in its source are a problem of the " <>
           "second, with the first's place; the same picture on two pages is none" do
      first = {"guides/tutorials/a.md", {4, "guides/assets/motor.svg", "rung", "motor.ld", []}}
      same = {"guides/howto/b.md", {9, "guides/assets/motor.svg", "rung", "motor.ld", []}}
      some = {"guides/howto/c.md", {7, "guides/assets/motor.svg", "rung", "motor.ld", [1]}}
      other = {"guides/howto/c.md", {12, "guides/assets/motor.svg", "timing", "m.timing.exs", []}}
      apart = {"guides/howto/c.md", {15, "guides/assets/seal.svg", "rung", "seal.ld", []}}

      assert Pictures.clashes([first, same, apart]) == []

      assert Pictures.clashes([first, same, some, other, apart]) == [
               "guides/howto/c.md:12: guides/assets/motor.svg is drawn here from `timing: " <>
                 "m.timing.exs` and at guides/tutorials/a.md:4 from `rung: motor.ld`: one file " <>
                 "is one picture, so give this picture another file name",
               "guides/howto/c.md:7: guides/assets/motor.svg is drawn here from `rung: motor.ld " <>
                 "1` and at guides/tutorials/a.md:4 from `rung: motor.ld`: one file is one " <>
                 "picture, so give this picture another file name"
             ]
    end

    test "each picture a page shows is what its script gives today, and its marks are sound" do
      read =
        for page <- pages(), do: {page, Pictures.of(page, File.read!(Path.join(@root, page)))}

      assert Pictures.clashes(
               for({page, {pictures, _}} <- read, picture <- pictures, do: {page, picture})
             ) == []

      for {page, {pictures, problems}} <- read do
        assert problems == []

        for {line, svg, _kind, _source, _rungs} = picture <- pictures do
          at = "#{page}:#{line}: #{svg}: run `mix run scripts/draw.exs #{page}`"
          assert {:ok, drawn} = in_root(fn -> Pictures.draw(picture) end), at
          assert {at, File.read(Path.join(@root, svg))} == {at, {:ok, drawn}}
        end
      end
    end

    test "guides/assets/ holds the pictures the pages' marks name and the descriptions " <>
           "they are drawn from, and no other file" do
      named =
        for page <- pages(),
            {_line, svg, kind, source, _rungs} <-
              elem(Pictures.of(page, File.read!(Path.join(@root, page))), 0),
            path <- [svg | for("timing" <- [kind], do: "guides/assets/" <> source)],
            uniq: true,
            do: path

      on_disk =
        for path <- Path.wildcard(Path.join(@root, "guides/assets/**")),
            File.regular?(path),
            do: Path.relative_to(path, @root)

      assert Enum.sort(on_disk) == Enum.sort(named)
    end
  end

  describe "scripts/draw.exs" do
    @lesson "# A\n\n<!-- rung: motor.ld -->\n![The motor.](../assets/motor.svg)\n\n" <>
              "<!-- timing: delay.timing.exs -->\n![The lamp.](../assets/delay.svg)\n"
    @recipe "# B\n\n<!-- rung: motor.ld -->\n![The motor.](../assets/motor.svg)\n"

    # A small tree of the test's own: a list of three pages, two of them with pictures, one
    # picture shown on both, and the sources the repository ships.
    defp tree(dir, pages \\ %{}) do
      files =
        Map.merge(
          %{
            "docs/pages.exs" =>
              ~S|[{"README.md", :legacy, :first}, {"guides/tutorials/a.md", :tutorial, "Tutorials"}, | <>
                ~S|{"guides/howto/b.md", :howto, "How-to guides"}]|,
            "README.md" => "# A project\n",
            "guides/tutorials/a.md" => @lesson,
            "guides/howto/b.md" => @recipe
          },
          pages
        )

      for {path, text} <- files do
        File.mkdir_p!(Path.dirname(Path.join(dir, path)))
        File.write!(Path.join(dir, path), text)
      end

      for path <- ["examples/motor.ld", "examples/delay.ld", "guides/assets/delay.timing.exs"] do
        File.mkdir_p!(Path.dirname(Path.join(dir, path)))
        File.cp!(Path.join(@root, path), Path.join(dir, path))
      end
    end

    # The script run in `dir` as `mix run` runs it, this build's code on its path: the
    # lines it printed, and its exit code.
    defp draw(dir, args) do
      {out, code} =
        System.cmd(
          to_string(@elixir),
          ["-pa", Mix.Project.compile_path(), Path.join(@root, "scripts/draw.exs") | args],
          cd: dir,
          stderr_to_stdout: true
        )

      {String.split(out, "\n", trim: true), code}
    end

    test "it draws each picture the pages' marks name, says which it drew and which were " <>
           "already what it gives, and draws what scripts/pictures.exs gives",
         %{tmp_dir: dir} do
      tree(dir)

      assert draw(dir, []) ==
               {[
                  "drawn guides/assets/motor.svg",
                  "drawn guides/assets/delay.svg",
                  "same guides/assets/motor.svg"
                ], 0}

      assert {:ok, motor} = in_root(fn -> Pictures.Rung.svg("examples/motor.ld") end)
      assert File.read!(Path.join(dir, "guides/assets/motor.svg")) == motor

      assert File.read!(Path.join(dir, "guides/assets/delay.svg")) ==
               File.read!(Path.join(@root, "guides/assets/delay.svg"))

      assert draw(dir, ["guides/howto/b.md"]) == {["same guides/assets/motor.svg"], 0}
    end

    test "--check draws nothing: a picture that is not what the script gives, or is not " <>
           "there, is a problem of each page that shows it, and the exit code is 1",
         %{tmp_dir: dir} do
      tree(dir)
      assert {_, 0} = draw(dir, [])

      assert draw(dir, ["--check"]) ==
               {List.duplicate("same guides/assets/motor.svg", 2)
                |> List.insert_at(1, "same guides/assets/delay.svg"), 0}

      motor = Path.join(dir, "guides/assets/motor.svg")
      File.write!(motor, "<svg/>")

      stale = fn page ->
        "draw: #{page}:4: guides/assets/motor.svg is not what its script gives: run `mix run scripts/draw.exs #{page}`"
      end

      assert draw(dir, ["--check"]) ==
               {[
                  "same guides/assets/delay.svg",
                  stale.("guides/tutorials/a.md"),
                  stale.("guides/howto/b.md")
                ], 1}

      assert File.read!(motor) == "<svg/>"

      File.rm!(motor)
      assert draw(dir, ["--check", "guides/howto/b.md"]) == {[stale.("guides/howto/b.md")], 1}
      refute File.exists?(motor)
    end

    test "two marks that name one file and differ in its source stop the drawing, on " <>
           "whichever page the writer names, and nothing is drawn",
         %{tmp_dir: dir} do
      tree(dir, %{"guides/howto/b.md" => String.replace(@recipe, "motor.ld", "motor.ld 1")})

      clash =
        "draw: guides/howto/b.md:4: guides/assets/motor.svg is drawn here from `rung: " <>
          "motor.ld 1` and at guides/tutorials/a.md:4 from `rung: motor.ld`: one file is one " <>
          "picture, so give this picture another file name"

      assert draw(dir, ["guides/tutorials/a.md"]) == {[clash], 1}
      assert draw(dir, ["--check"]) == {[clash], 1}
      refute File.exists?(Path.join(dir, "guides/assets/motor.svg"))
    end

    test "a mark that is wrong and a source that does not compile are a problem with the " <>
           "page and the line, and what logex says of the source",
         %{tmp_dir: dir} do
      page =
        "# A\n\n![By hand.](../assets/hand.svg)\n\n<!-- rung: wrong.ld -->\n![Wrong.](../assets/wrong.svg)\n"

      tree(dir, %{"guides/tutorials/a.md" => page})
      wrong = "var_input a bool\nvar_output b bool\n\nxic a ote lamp\n"
      File.write!(Path.join(dir, "examples/wrong.ld"), wrong)

      assert draw(dir, ["guides/tutorials/a.md"]) ==
               {[
                  "draw: guides/tutorials/a.md:3: a picture with no `rung` or `timing` mark on " <>
                    "the line above it: a script makes every picture",
                  "draw: guides/tutorials/a.md:6: examples/wrong.ld: line 4: `lamp` is not " <>
                    "declared: a picture is drawn of a program that compiles"
                ], 1}

      refute File.exists?(Path.join(dir, "guides/assets/wrong.svg"))
    end

    test "--rung and --timing draw one picture to a file, for a look", %{tmp_dir: dir} do
      tree(dir)
      assert draw(dir, ["--rung", "examples/motor.ld", "one.svg", "3"]) == {["drawn one.svg"], 0}
      assert {:ok, one} = in_root(fn -> Pictures.Rung.svg("examples/motor.ld", [3]) end)
      assert File.read!(Path.join(dir, "one.svg")) == one

      assert draw(dir, ["--timing", "guides/assets/delay.timing.exs", "two.svg"]) ==
               {["drawn two.svg"], 0}

      assert File.read!(Path.join(dir, "two.svg")) ==
               File.read!(Path.join(@root, "guides/assets/delay.svg"))

      assert draw(dir, ["--rung", "examples/motor.ld", "three.svg", "9"]) ==
               {["draw: examples/motor.ld has 5 rungs, and no rung 9"], 1}

      refute File.exists?(Path.join(dir, "three.svg"))
    end
  end
end
