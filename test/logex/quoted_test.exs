defmodule Logex.QuotedTest do
  @moduledoc """
  Decision 586 (RV-32; the maintainer, 2026-11-23, RV-31's question 3): every refusal of
  the host contract that quotes a value the host gave quotes it through the one cut of
  decisions 583 to 585, `Logex.Lexer`'s: a number past 10,000 characters by its first 24
  and how many it has, never made whole, and any other value as `inspect/1` shows it,
  with its limits, each long number in it cut. Before it, `Logex.Configuration.new!(10 **
  100_000)` quoted a hundred thousand digits, and every refusal below with it, some 90 ms
  and 100 KB each; a global brought to `new!/1` with `line: 10 ** 1_000_000` took 9 s and
  a megabyte.

  The census: each refusal reached with `10 ** 100_000`, or a value that holds it, its
  message pinned whole, the cut written `@cut`, a test a module or two; the growth of a
  sample across the modules, a refusal of `10 ** 1_000_000` and of a list of a million
  elements against one of a small value in the same run; and `lib/`'s syntax trees, in
  which `inspect/1` is called by the cut alone.

  Since RV-33 (decisions 610, 613 and 616): a refusal of many mistakes, a line each,
  tells the first hundred and how many more, each pinned whole at 100 mistakes and at
  101, its cost and text at 100,000 held to its own at 1,000; a name or a location past
  4,096 bytes cut where a refusal quotes it, pinned at 4,096 bytes and 4,097, its cost at
  a megabyte held to a short one's; and `instance/1` refusing a struct where a map is
  due, which escaped as Protocol.UndefinedError.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime, Scan}
  alias Logex.Configuration.{Global, Task}
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  @moduletag :tmp_dir

  @cut "100000000000000000000000… (100001 characters)"
  @negative "-10000000000000000000000… (100002 characters)"
  @quoted "`100000000000000000000000…` (100001 characters)"
  @nines "999999999999999999999999… (100000 characters)"

  # A clock whose state is the two answers it gives, its time and its wall clock's.
  defmodule Clock do
    @moduledoc false
    @behaviour Logex.Runner.Clock
    @impl true
    def now_ms({now, _wall}), do: now
    @impl true
    def wake_at(_clock, _pid, _message, _at), do: make_ref()
    @impl true
    def cancel(_clock, _timer), do: :ok
    @impl true
    def wall_ms({_now, wall}), do: wall
  end

  # An adapter whose check/3 gives what its options say.
  defmodule Adapter do
    @moduledoc false
    @behaviour Logex.IO
    @impl true
    def check(_device, _points, opts), do: Keyword.fetch!(opts, :checked)
    @impl true
    def init(_device, _points, _opts), do: {:ok, nil}
    @impl true
    def read(state), do: {:ok, %{}, state}
    @impl true
    def write(_values, state), do: {:ok, state}
  end

  @source """
  var_input start bool
  var_input speed dint
  var_input rate real
  var_input steps dint[3]
  var_output lamp bool
  var total dint
  var rated real
  var t1 ton
  var retain kept dint

  xic start ton t1 100
  xic t1.dn ote lamp
  xic start add total 1 total
  """

  @tally """
  var_input eye bool
  var_output full bool
  var_external count dint
  var boxes ctu

  xic eye ctu boxes 3
  xic boxes.q ote full
  """

  @config """
  var_global eye_1 bool at panel.i.0
  var_global case_full bool
  var_global count dint 0
  var_global temps dint[2] at panel.i.1

  program t1 tally
    t1.eye eye_1
    t1.full case_full
  """

  setup %{tmp_dir: dir} do
    {:ok, p} = Logex.compile(@source, name: "p")
    c = config()
    {_runner, opened} = runner([])

    %{
      big: 10 ** 100_000,
      dir: dir,
      p: p,
      s: Runtime.instance(p),
      scan: %Scan{now: 0, first: true},
      c: c,
      rt: Runtime.start(c),
      opened: opened
    }
  end

  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  defp config do
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    {:ok, c} = Configuration.compile("plant", @config, %{"tally" => tally})
    c
  end

  # A runner of the plant on the manual clock, and the sim of its panel.
  defp runner(opts) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(clock: clock)

    {:ok, runner} =
      Runner.start_link(
        [configuration: config(), io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock}] ++
          opts
      )

    {runner, panel}
  end

  defp forces(dir, name), do: [forces: Path.join(dir, name)]

  # A program edited by hand: `name`'s type changed, as runtime_test.exs's retyped/3.
  defp retyped(p, name, type), do: %{p | tags: Map.update!(p.tags, name, &%{&1 | type: type})}

  # Every instruction's line made `line`.
  defp lined(p, line), do: %{p | rungs: relined(p.rungs, line)}

  defp relined(list, line) when is_list(list), do: Enum.map(list, &relined(&1, line))
  defp relined({:rung, elements}, line), do: {:rung, relined(elements, line)}
  defp relined({:branches, legs}, line), do: {:branches, relined(legs, line)}
  defp relined({symbol, _line, operands}, line) when is_atom(symbol), do: {symbol, line, operands}
  defp relined(other, _line), do: other

  # The located array's line made `line`, the last of the globals.
  defp relined_global(%{name: "temps"} = global, line), do: %{global | line: line}
  defp relined_global(global, _line), do: global

  # Each refusal's message pinned whole, and short.
  defp told(rows) do
    for {label, fun, message} <- rows do
      error = assert_raise ArgumentError, fun
      assert {label, error.message} == {label, message}
      assert byte_size(error.message) < 400, label
    end
  end

  describe "every refusal of the host contract quotes a long number cut (decision 586)" do
    test("Logex's and Logex.Configuration's", ctx, do: told(host_rows(ctx)))
    test("Logex.Runtime's of a lone instance", ctx, do: told(instance_rows(ctx)))
    test("Logex.Runtime's of a program edited by hand", ctx, do: told(edited_rows(ctx)))
    test("Logex.Runtime's of a resource", ctx, do: told(resource_rows(ctx)))
    test("Logex.Edit's and Logex.Configuration.Edit's", ctx, do: told(edits_rows(ctx)))
    test("Logex.IO's and Logex.Runner's", ctx, do: told(runner_rows(ctx)))

    test("Logex.IO.Sim's, the clocks' and Logex.Tag's", ctx, do: told(tools_rows(ctx)))

    # RV-32's review, F1 to F4, F6 and F8: a program's name, a struct that shows itself, the
    # sim's own count, a name that is no text, and two long numbers that cut alike.
    test("what the review of RV-32 found", ctx, do: told(review_rows(ctx)))

    # RV-32's review, F4: `Logex.Declarations.check/1` tells every rule a tag breaks, not
    # only its name, so a name that is no UTF-8 text is quoted in each of them, which
    # `Logex.Tag.new!/5`, stopping at the name, never shows.
    test "Logex.Declarations.check/1 quotes a name that is no text in every message" do
      bad = opaque("ab" <> <<255>> <> "c")
      input = %Logex.Tag{name: bad, type: :bool, section: :var_input, initial: 1}
      counted = %Logex.Tag{name: bad, type: :dint, section: :var, initial: opaque(:x)}

      assert Logex.Declarations.check(input) == [
               "<<97, 98, 255, 99>> is not a tag name",
               "<<97, 98, 255, 99>> is a var_input: its value comes from outside, so it " <>
                 "takes no initial value"
             ]

      assert Logex.Declarations.check(counted) == [
               "<<97, 98, 255, 99>> is not a tag name",
               "the initial value of <<97, 98, 255, 99>> must be an integer, found :x"
             ]
    end

    # RV-32's review, F3: a struct that writes itself out with more terms than the cut
    # looks through, `@looked`, is shown field by field whatever it holds, so that a long
    # number past them is never written whole; `inspect/1`'s limit shows 196 of its list.
    test "a struct too large to look through is shown field by field", %{big: big} do
      pre = List.duplicate(0, 300) ++ [big]
      version = opaque(%{__struct__: Version, major: 1, minor: 0, patch: 0, pre: pre, build: nil})

      shown =
        "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:, " <>
          "globals:, instances: and connections:, got: %Version{major: 1, minor: 0, " <>
          "patch: 0, pre: [#{Enum.join(List.duplicate("0", 196), ", ")}, ...], ...}"

      assert_raise ArgumentError, shown, fn -> Configuration.new!(version) end
    end

    # A line a program edited by hand gives that is no integer, a tuple or a text, is
    # quoted as `inspect/1` shows it, where `"#{line}"` raised Protocol.UndefinedError out
    # of the refusal for a tuple (decision 612).
    test "a line that is no integer, quoted as inspect/1 shows it", %{p: p, s: s, scan: scan} do
      at = fn line -> lined(retyped(p, "total", :bool), opaque(line)) end

      declared =
        &%{p | tags: Map.update!(p.tags, "lamp", fn tag -> %{tag | line: opaque(&1)} end)}

      told([
        {"an op's line, a scan's", fn -> Runtime.call(at.({:a, 1}), s, %{"start" => 1}, scan) end,
         "a scan's `add` on line {:a, 1} computes in the type of `total`, a bool, which is " <>
           "no integer type: the program was edited by hand after it was handed in and checked"},
        {"an op's line, handed in", fn -> Runtime.instance(at.("7")) end,
         ~s|`p`'s `add` on line "7" computes in the type of `total`, a bool, which is no | <>
           "integer type: `p` was edited by hand after it compiled"},
        {"a tag's line", fn -> Runtime.put_inputs(declared.({:a, 1}), s, %{"lamp" => 1}) end,
         "input `lamp` is a var_output (declared on line {:a, 1}), not a var_input: only " <>
           "a var_input is set from outside"}
      ])
    end
  end

  # What RV-32's review found quoted whole, written raw or raised: F1, a program's name, a
  # number or a tuple, which `"#{name}"` wrote whole or raised Protocol.UndefinedError
  # for; F2, the sim's own count; F3, a struct that shows itself, its integers written
  # whole; F4, a name that is no UTF-8 text, written raw; F6, the refusals no row reached;
  # F8, two long numbers whose cuts read alike, told apart by how far.
  defp review_rows(%{big: big, p: p, s: s, scan: scan, c: c, rt: rt}) do
    o = &opaque/1
    bad = o.("ab" <> <<255>> <> "c")
    date = o.(%{__struct__: Date, year: big, month: 1, day: 1, calendar: Calendar.ISO})
    {:ok, tally} = Logex.compile(@tally, name: "tally")

    time =
      o.(%{
        __struct__: Time,
        hour: big,
        minute: 0,
        second: 0,
        microsecond: {0, 0},
        calendar: Calendar.ISO
      })

    version = o.(%{__struct__: Version, major: 1, minor: 0, patch: 0, pre: [big], build: nil})
    takes = "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:, "
    dated = "%Date{year: #{@cut}, month: 1, day: 1, calendar: Calendar.ISO}"
    by_hand = "where its tags do not hold it: `p` was edited by hand after it compiled\n"

    kept =
      "`p`'s retained paths do not hold `kept`, where its tags hold it: `p` was edited by " <>
        "hand after it compiled"

    [
      {"F1 put_inputs/3 a program's name",
       fn -> Runtime.put_inputs(%{p | name: o.(big)}, s, %{"start" => 1}) end,
       "this state is an instance of `p`, not of #{@cut}"},
      {"F1 call/4 a program's name that is a tuple",
       fn -> Runtime.call(%{p | name: o.({:a, big})}, s, %{}, scan) end,
       "this state is an instance of `p`, not of {:a, #{@cut}}"},
      {"F1 restart/3 a program's name", fn -> Runtime.restart(%{p | name: o.(big)}, s, :cold) end,
       "this state is an instance of `p`, not of #{@cut}"},
      {"F1 Edit.accept/3 the running program's name",
       fn -> Logex.Edit.accept(%{p | name: o.(big)}, p, s) end,
       "the candidate is `p`, but the running program is #{@cut}: an edit keeps the " <>
         "program's name"},
      {"F1 Edit.accept/3 the candidate's name that is a tuple",
       fn -> Logex.Edit.accept(p, %{p | name: o.({:a, big})}, s) end,
       "the candidate is {:a, #{@cut}}, but the running program is `p`: an edit keeps " <>
         "the program's name"},
      {"F2 Sim.set/3 past a long count",
       fn -> Sim.set(elem(Sim.start_link(inputs: o.(big)), 1), [2 * big], 1) end,
       "the sim has #{@cut} inputs, at the addresses [0] to [#{@nines}], got: " <>
         "[200000000000000000000000… (100001 characters)]"},
      {"F6 Sim.set/3 a long address past a short count",
       fn -> Sim.set(elem(Sim.start_link(inputs: 2), 1), [o.(big)], 1) end,
       "the sim has 2 inputs, at the addresses [0] to [1], got: [#{@cut}]"},
      {"F3 new!/1 a Date", fn -> Configuration.new!(date) end,
       takes <> "globals:, instances: and connections:, got: #{dated}"},
      {"F3 new!/1 a Time, which raised Inspect.Error", fn -> Configuration.new!(time) end,
       takes <>
         "globals:, instances: and connections:, got: %Time{hour: #{@cut}, minute: 0, " <>
         "second: 0, microsecond: {0, 0}, calendar: Calendar.ISO}"},
      # The look takes a tuple apart: a long number in one is found there.
      {"F3 new!/1 a Time whose microsecond holds it",
       fn -> Configuration.new!(o.(%{time | hour: 0, microsecond: {big, 6}})) end,
       takes <>
         "globals:, instances: and connections:, got: %Time{hour: 0, minute: 0, " <>
         "second: 0, microsecond: {#{@cut}, 6}, calendar: Calendar.ISO}"},
      {"F3 put_inputs/3 a Date", fn -> Runtime.put_inputs(p, s, %{"start" => date}) end,
       "input `start` is a bool: only 0 or 1 fit, found #{dated}"},
      {"F3 Logex.compile/2 a Version in a list", fn -> Logex.compile([version], name: "p") end,
       "Logex.compile/2 takes source text as a binary, got: [%Version{major: 1, minor: " <>
         "0, patch: 0, pre: [#{@cut}], build: nil}]"},
      {"F4 Global.new!/3 a name and a type", fn -> Global.new!(bad, o.("x")) end,
       "<<97, 98, 255, 99>> cannot name a global: a name is a letter or `_`, then " <>
         "letters, digits or `_`\nglobal <<97, 98, 255, 99>> has type \"x\": a global " <>
         "is :bool, :sint, :int, :dint, :lint, :usint, :uint, :udint, :ulint, :real, " <>
         ":lreal, :byte, :word, :dword or :lword, or an array of one of them, as in " <>
         "`{:array, :int, [8]}`, its sizes a list of one integer a dimension"},
      # Its options are judged before its name, each refusal of them naming it.
      {"F4 Global.new!/3 the options of a name", fn -> Global.new!(bad, :bool, o.(:x)) end,
       "the options of <<97, 98, 255, 99>> are a keyword list of `initial:`, `at:`, " <>
         "`retain: true` or `non_retain: true`, found :x"},
      {"F4 Global.new!/3 an option of a name", fn -> Global.new!(bad, :bool, o.(retain: 1)) end,
       "`retain:` for <<97, 98, 255, 99>> takes true or false, found 1"},
      {"F4 Global.new!/3 a location", fn -> Global.new!("g", :bool, at: bad) end,
       "global `g` is at <<97, 98, 255, 99>>, which is not a location: a location is a " <>
         "device, `i` for an input or `q` for an output, then an address, as in " <>
         "`panel.i.0` or `panel.q.3`"},
      {"F4 Tag.new!/5 the options of a name",
       fn -> Logex.Tag.new!(bad, :bool, :var, nil, o.(:x)) end,
       "the options of <<97, 98, 255, 99>> are a keyword list, `retain: true` or " <>
         "`non_retain: true`, found :x"},
      {"F4 compile/3 a type's key",
       fn -> Configuration.compile("plant", @config, %{bad => tally}) end,
       "the program under <<97, 98, 255, 99>> is named `tally`"},
      {"F4 IO.bind!/2 a device's name", fn -> Logex.IO.bind!(c, %{bad => Sim}) end,
       "the device <<97, 98, 255, 99>> is bound, but no point is at it\nno adapter is " <>
         "bound to the device `panel`, which `eye_1` (panel.i.0) and `temps[0]` to " <>
         "`temps[1]` (panel.i.1 to panel.i.2) are at"},
      {"F4 instance/2 an image's program",
       fn -> Runtime.instance(p, %{Runtime.retained(p, s) | program: bad}) end,
       "the image's `program` is <<97, 98, 255, 99>>, which names no program\nthe " <>
         "retained image is of program <<97, 98, 255, 99>>, and this program is `p`: an " <>
         "image starts only an instance of the program it was taken from"},
      {"F4 check/1 a task's name, quoted beside a global's line",
       fn -> Configuration.check(%{c | tasks: [%Task{name: bad, interval: 10, line: 1}]}) end,
       "<<97, 98, 255, 99>> cannot name a task: a name is a letter or `_`, then " <>
         "letters, digits or `_`\nglobal `eye_1` is on line 1, as task <<97, 98, 255, " <>
         "99>> is: a configuration's lines are all nil, as from Elixir, or rise in each " <>
         "list, one element a line"},
      {"F4 instance/1 a program's name that is no text, its retained paths edited",
       fn -> Runtime.instance(%{p | name: bad, retained: []}) end,
       "<<97, 98, 255, 99>>'s retained paths do not hold `kept`, where its tags hold it: " <>
         "<<97, 98, 255, 99>> was edited by hand after it compiled"},
      {"F4 instance/1 a program's name that is no text, a tag retyped",
       fn -> Runtime.instance(retyped(%{p | name: bad}, "total", :bool)) end,
       "<<97, 98, 255, 99>>'s `add` on line 13 computes in the type of `total`, a bool, " <>
         "which is no integer type: <<97, 98, 255, 99>> was edited by hand after it compiled"},
      {"F4 put_inputs/3 a state's type", fn -> Runtime.put_inputs(p, %{s | type: bad}, %{}) end,
       "this state is an instance of <<97, 98, 255, 99>>, not of `p`"},
      {"F4 instance/1 a retained path that is no text, of a program edited by hand",
       fn -> Runtime.instance(%{p | retained: [bad]}) end,
       "`p`'s retained paths hold <<97, 98, 255, 99>>, " <> by_hand <> kept},
      {"F3 instance/1 a retained path that is a Date, of a program edited by hand",
       fn -> Runtime.instance(%{p | retained: [date]}) end,
       "`p`'s retained paths hold #{dated}, " <> by_hand <> kept},
      {"F6 and F8 call/4 a timer's last and the instance's now, both long",
       fn ->
         state = %{put_in(s.env["t1"]["last"], o.(big + 5)) | now: o.(big)}
         Runtime.call(p, state, %{}, %{scan | now: big})
       end,
       "state.env holds `t1.last` outside its type: it is a clock, and #{@cut} is " <>
         "later than the instance's now, #{@cut}, by 5"},
      {"F8 call/4 a scan's time gone backwards, both long",
       fn -> Runtime.call(p, %{s | now: o.(big + 5)}, %{}, %{scan | now: o.(big)}) end,
       "time went backwards: this scan is at #{@cut} ms, but the instance was last " <>
         "scanned at #{@cut} ms, 5 ms later"},
      {"F6 Configuration.Edit.test/3 the resource's generation",
       fn ->
         {:ok, edit, _report} = Configuration.Edit.accept(rt, c)
         Configuration.Edit.test(edit, %{rt | generation: o.(big)})
       end,
       "this edit expects the resource at generation 0, but it is at generation " <>
         "#{@cut}: the edit has ended, or another edit has stepped since"}
    ]
  end

  # the refusals of `Logex` and `Logex.Configuration`.
  defp host_rows(%{big: big}) do
    o = &opaque/1

    [
      {"Logex.compile/2 source", fn -> Logex.compile(o.(big), name: "p") end,
       "Logex.compile/2 takes source text as a binary, got: #{@cut}"},
      {"Logex.compile/2 name", fn -> Logex.compile("", name: o.(big)) end,
       "a program's name is a string, got: #{@cut}"},
      {"Logex.compile/2 options", fn -> Logex.compile("", o.(big)) end,
       "Logex.compile/2 takes a name and, where the source uses function " <>
         "blocks, their types, as in Logex.compile(source, name: \"motor\", types: " <>
         "[seal]), got: #{@cut}"},
      {"Logex.compile/2 types", fn -> Logex.compile("", name: "p", types: o.(big)) end,
       "types must be a list of function block types from Logex.compile/2, " <>
         "got: #{@cut}"},
      {"Logex.compile/2 a type", fn -> Logex.compile("", name: "p", types: [o.(big)]) end,
       "types must be function block types from Logex.compile/2, got: #{@cut}"},
      {"Logex.compile_file/1", fn -> Logex.compile_file(o.(big)) end,
       "Logex.compile_file/1 takes a path as a binary, got: #{@cut}"},
      {"Logex.compile_files/1", fn -> Logex.compile_files(o.([big])) end,
       "Logex.compile_files/1 takes a list of paths as binaries, got: [#{@cut}]"},
      {"Configuration.new!/1 no keyword list", fn -> Configuration.new!(o.(big)) end,
       "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, " <>
         "tasks:, globals:, instances: and connections:, got: #{@cut}"},
      {"Configuration.new!/1 a list no keyword list", fn -> Configuration.new!(o.([big])) end,
       "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, " <>
         "tasks:, globals:, instances: and connections:, got: [#{@cut}]"},
      {"Configuration.new!/1 an element's line",
       fn ->
         Configuration.new!(name: "c", globals: [%Global{name: "g", type: :bool, line: o.(big)}])
       end,
       "global `g` from Elixir has no line, got: #{@cut}\nthis configuration " <>
         "declares no `program`: it would run nothing"},
      {"Configuration.new!/1 programs no list",
       fn -> Configuration.new!(name: "c", programs: o.(big)) end,
       "programs: must be a list of %Logex.Program{} from Logex.compile/2, " <>
         "got: #{@cut}\nthis configuration declares no `program`: it would run " <>
         "nothing"},
      {"Configuration.new!/1 a program",
       fn -> Configuration.new!(name: "c", programs: [o.(big)]) end,
       "programs: #{@cut} is not a %Logex.Program{} from Logex.compile/2\nthis " <>
         "configuration declares no `program`: it would run nothing"},
      {"Configuration.compile/3 source", fn -> Configuration.compile("c", o.(big), []) end,
       "Logex.Configuration.compile/3 takes source text as a binary, got: " <>
         "#{@cut}"},
      {"Configuration.compile_file/1", fn -> Configuration.compile_file(o.(big)) end,
       "Logex.Configuration.compile_file/1 takes a path as a binary, got: " <>
         "#{@cut}"},
      {"Configuration.initial/1 no global", fn -> Configuration.initial(o.(big)) end,
       "expected a %Logex.Configuration.Global{} whose initial value is an " <>
         "integer, a real's a number, or nil, got: #{@cut}"},
      {"Configuration.initial/1 a misfit",
       fn -> Configuration.initial(%Global{name: "g", type: :dint, initial: o.(big)}) end,
       "global `g` is a dint: #{@quoted} is outside -2147483648 to 2147483647"},
      {"Configuration.initial/1 a list of no size",
       fn ->
         Configuration.initial(%Global{name: "g", type: {:array, :dint, [2]}, initial: [o.(big)]})
       end,
       "expected an initial list of 2 values for an array of 2 dints, got: " <>
         "[#{@cut}]"},
      {"Configuration.initial/1 a list's misfit",
       fn ->
         Configuration.initial(%Global{
           name: "g",
           type: {:array, :dint, [2]},
           initial: [1, o.(big)]
         })
       end,
       "expected an initial list of values for an array of 2 dints, each a " <>
         "value a dint holds, got: [1, #{@cut}]"},
      {"Configuration.watchdog/1",
       fn -> Configuration.watchdog(%Task{name: "t", interval: 10, watchdog: o.(big)}) end,
       "expected a %Logex.Configuration.Task{} whose watchdog is 1 to " <>
         "2147483647 ms or nil, got: %Logex.Configuration.Task{name: \"t\", " <>
         "single: nil, interval: 10, priority: nil, watchdog: #{@cut}, continuous: " <>
         "false, line: nil}"}
    ]
  end

  # `Logex.Runtime`'s of a lone instance.
  defp instance_rows(%{big: big, p: p, s: s, scan: scan}) do
    o = &opaque/1

    [
      {"Runtime.instance/1", fn -> Runtime.instance(o.(big)) end,
       "expected a %Logex.Program{} from Logex.compile/2, got: #{@cut}"},
      {"Runtime.instance/2 image", fn -> Runtime.instance(p, o.(big)) end,
       "a retained image is a map of `program`, `kinds` and `values`, as " <>
         "Logex.Runtime.retained/2 gives one, got: #{@cut}"},
      {"Runtime.instance/2 image's program",
       fn -> Runtime.instance(p, %{program: o.(big), kinds: %{}, values: %{}}) end,
       "the image's `program` is #{@cut}, which names no program"},
      {"Runtime.instance/2 image's kinds path",
       fn -> Runtime.instance(p, %{program: "p", kinds: %{o.(big) => "ton"}, values: %{}}) end,
       "`kinds` holds #{@cut}, which is no path"},
      {"Runtime.instance/2 image's values path",
       fn ->
         Runtime.instance(p, %{program: "p", kinds: %{}, values: %{o.(big) => {:dint, 1}}})
       end, "`values` holds #{@cut}, which is no path"},
      {"Runtime.instance/2 image's entry",
       fn -> Runtime.instance(p, %{program: "p", kinds: %{}, values: %{"kept" => o.(big)}}) end,
       "`values` holds `kept` as #{@cut}, which is no {type, value}"},
      {"Runtime.instance/2 image's type",
       fn ->
         Runtime.instance(p, %{program: "p", kinds: %{}, values: %{"kept" => {o.(big), 1}}})
       end,
       "`values` holds `kept` of the type #{@cut}, which is no type of a " <>
         "retained value: an elementary type's atom, or {:array, type, sizes}"},
      {"Runtime.instance/2 image's kind",
       fn -> Runtime.instance(p, %{program: "p", kinds: %{"t1" => o.(big)}, values: %{}}) end,
       "`kinds` holds `t1` as #{@cut}, which is no kind of instance: a " <>
         "built-in's or a block's name, or {:array, name, sizes}"},
      {"Runtime.call/4 state", fn -> Runtime.call(p, o.(big), %{}, scan) end,
       "expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: #{@cut}"},
      {"Runtime.call/4 state.type", fn -> Runtime.call(p, %{s | type: o.(big)}, %{}, scan) end,
       "state.type must be a program name, got: #{@cut}"},
      {"Runtime.call/4 state.env", fn -> Runtime.call(p, %{s | env: o.(big)}, %{}, scan) end,
       "state.env must be a map of tag names to values, got: #{@cut}"},
      {"Runtime.call/4 state.now", fn -> Runtime.call(p, %{s | now: o.(-big)}, %{}, scan) end,
       "state.now must be a non-negative integer of milliseconds, got: #{@negative}"},
      {"Runtime.call/4 state.first", fn -> Runtime.call(p, %{s | first: o.(big)}, %{}, scan) end,
       "state.first must be true or false, got: #{@cut}"},
      {"Runtime.call/4 state.switched",
       fn -> Runtime.call(p, %{s | switched: o.(big)}, %{}, scan) end,
       "state.switched must be true or false, got: #{@cut}"},
      {"Runtime.call/4 state.ons_blocked",
       fn -> Runtime.call(p, %{s | ons_blocked: o.(big)}, %{}, scan) end,
       "state.ons_blocked must be a list of storage bit names, got: #{@cut}"},
      {"Runtime.call/4 state.faults",
       fn -> Runtime.call(p, %{s | faults: o.(big)}, %{}, scan) end,
       "state.faults must be a list of %Logex.Fault{}, got: #{@cut}"},
      {"Runtime.call/4 a dint's value",
       fn -> Runtime.call(p, put_in(s.env["total"], o.(big)), %{}, scan) end,
       "state.env holds `total` outside its type: it is a dint, and #{@cut} is " <>
         "outside -2147483648 to 2147483647"},
      {"Runtime.call/4 a bool's value",
       fn -> Runtime.call(p, put_in(s.env["start"], o.([big])), %{}, scan) end,
       "state.env holds `start` outside its type: it is a bool, and only 0 or " <>
         "1 fit, found [#{@cut}]"},
      {"Runtime.call/4 a dint's no integer",
       fn -> Runtime.call(p, put_in(s.env["total"], o.([big])), %{}, scan) end,
       "state.env holds `total` outside its type: it is a dint, and its value " <>
         "must be an integer, found [#{@cut}]"},
      {"Runtime.call/4 a real's no float",
       fn -> Runtime.call(p, put_in(s.env["rated"], o.(big)), %{}, scan) end,
       "state.env holds `rated` outside its type: it is a real, and its value " <>
         "must be a float, found #{@cut}"},
      {"Runtime.call/4 an array's shape",
       fn -> Runtime.call(p, put_in(s.env["steps"], o.(big)), %{}, scan) end,
       "state.env holds `steps` outside its type: it is an array of 3 dints, " <>
         "and its value must be a tuple of 3 elements, found #{@cut}"},
      {"Runtime.call/4 an instance's no map",
       fn -> Runtime.call(p, put_in(s.env["t1"], o.(big)), %{}, scan) end,
       "state.env holds `t1` outside its type: it is a ton, and its value must " <>
         "be a map of its members, found #{@cut}"},
      {"Runtime.call/4 a timer's last later",
       fn -> Runtime.call(p, put_in(s.env["t1"]["last"], o.(big)), %{}, scan) end,
       "state.env holds `t1.last` outside its type: it is a clock, and #{@cut} " <>
         "is later than the instance's now, 0"},
      {"Runtime.call/4 scan", fn -> Runtime.call(p, s, %{}, o.(big)) end,
       "expected a %Logex.Scan{}, got: #{@cut}"},
      {"Runtime.call/4 scan.now", fn -> Runtime.call(p, s, %{}, %{scan | now: o.(-big)}) end,
       "scan.now must be a non-negative integer of milliseconds, got: #{@negative}"},
      {"Runtime.call/4 scan.first", fn -> Runtime.call(p, s, %{}, %{scan | first: o.(big)}) end,
       "scan.first must be true or false, got: #{@cut}"},
      {"Runtime.call/4 scan.ons_blocked",
       fn -> Runtime.call(p, s, %{}, %{scan | ons_blocked: o.(big)}) end,
       "scan.ons_blocked is the runtime's, taken from the instance: a host " <>
         "leaves it out, got: #{@cut}"},
      {"Runtime.call/4 scan.tags", fn -> Runtime.call(p, s, %{}, %{scan | tags: o.(big)}) end,
       "scan.tags is the runtime's, taken from the program: a host leaves it " <>
         "out, got: #{@cut}"},
      {"Runtime.call/4 scan.units", fn -> Runtime.call(p, s, %{}, %{scan | units: o.(big)}) end,
       "scan.units is the runtime's, taken from the program: a host leaves it " <>
         "out, got: #{@cut}"},
      {"Runtime.call/4 scan.reals", fn -> Runtime.call(p, s, %{}, %{scan | reals: o.(big)}) end,
       "scan.reals is the runtime's, taken from the program: a host leaves it " <>
         "out, got: #{@cut}"},
      {"Runtime.call/4 scan.blocks", fn -> Runtime.call(p, s, %{}, %{scan | blocks: o.(big)}) end,
       "scan.blocks is the runtime's, taken from the program: a host leaves it " <>
         "out, got: #{@cut}"},
      {"Runtime.call/4 time went backwards",
       fn -> Runtime.call(p, %{s | now: o.(big)}, %{}, %{scan | now: o.(big - 1)}) end,
       "time went backwards: this scan is at #{@nines} ms, but the instance was " <>
         "last scanned at #{@cut} ms"},
      {"Runtime.scan/3 elapsed_ms", fn -> Runtime.scan(p, s, o.(-big)) end,
       "elapsed_ms must be a non-negative integer of milliseconds, got: #{@negative}"},
      {"Runtime.put_inputs/3 inputs", fn -> Runtime.put_inputs(p, s, o.(big)) end,
       "inputs must be a map of var_input names to values, as in %{\"start\" => " <>
         "1}, got: #{@cut}"},
      {"Runtime.put_inputs/3 a key", fn -> Runtime.put_inputs(p, s, %{o.(big) => 1}) end,
       "input #{@cut} is not a tag name: inputs are keyed by tag name, as a " <>
         "string, as in %{\"start\" => 1}"},
      {"Runtime.put_inputs/3 a dint's misfit",
       fn -> Runtime.put_inputs(p, s, %{"speed" => o.(big)}) end,
       "input `speed` is a dint: #{@cut} is outside -2147483648 to 2147483647"},
      {"Runtime.put_inputs/3 a bool's misfit",
       fn -> Runtime.put_inputs(p, s, %{"start" => o.(big)}) end,
       "input `start` is a bool: only 0 or 1 fit, found #{@cut}"},
      {"Runtime.put_inputs/3 a real's misfit",
       fn -> Runtime.put_inputs(p, s, %{"rate" => o.(big)}) end,
       "input `rate` is a real: #{@cut} is beyond a real's range, " <>
         "-3.4028234663852886e38 to 3.4028234663852886e38"},
      {"Runtime.put_inputs/3 a dint's no integer",
       fn -> Runtime.put_inputs(p, s, %{"speed" => o.([big])}) end,
       "input `speed` is a dint: its value must be an integer, found [#{@cut}]"},
      {"Runtime.put_inputs/3 a real's no number",
       fn -> Runtime.put_inputs(p, s, %{"rate" => o.([big])}) end,
       "input `rate` is a real: its value must be a number, found [#{@cut}]"},
      {"Runtime.put_inputs/3 an array's shape",
       fn -> Runtime.put_inputs(p, s, %{"steps" => o.(big)}) end,
       "input `steps` is an array of 3 dints: its value must be a list of 3 " <>
         "elements, found #{@cut}"},
      {"Runtime.put_inputs/3 a tag's line",
       fn ->
         Runtime.put_inputs(
           %{p | tags: Map.update!(p.tags, "lamp", &%{&1 | line: o.(big)})},
           s,
           %{"lamp" => 1}
         )
       end,
       "input `lamp` is a var_output (declared on line #{@cut}), not a " <>
         "var_input: only a var_input is set from outside"},
      {"Runtime.restart/3 mode", fn -> Runtime.restart(p, s, o.(big)) end,
       "restart takes :cold or :warm, got: #{@cut}"},
      {"Runtime.restart/3 a retained path",
       fn -> Runtime.restart(%{p | retained: [o.(big)]}, s, :warm) end,
       "a warm restart keeps the retained path #{@cut}, which is no path: the " <>
         "program was edited by hand after it was handed in and checked"},
      {"Runtime.restart/3 the retained paths",
       fn -> Runtime.restart(%{p | retained: o.(big)}, s, :warm) end,
       "a warm restart reads retained paths that are no list of paths, got: " <>
         "#{@cut}: the program was edited by hand after it was handed in and " <>
         "checked"}
    ]
  end

  # `Logex.Runtime`'s of a program edited by hand, where it is handed in and where a scan
  # reaches what the hand changed.
  defp edited_rows(%{big: big, p: p, s: s, scan: scan}) do
    o = &opaque/1

    [
      {"Runtime.call/4 an op's line",
       fn -> Runtime.call(lined(retyped(p, "total", :bool), big), s, %{"start" => 1}, scan) end,
       "a scan's `add` on line #{@cut} computes in the type of `total`, a bool, " <>
         "which is no integer type: the program was edited by hand after it was " <>
         "handed in and checked"},
      {"Runtime.call/4 the units",
       fn -> Runtime.call(%{p | units: o.(big)}, s, %{"start" => 1}, scan) end,
       "a scan's `ton` on line 11 reads the unit of `t1` from units that are " <>
         "no map, got: #{@cut}: the program was edited by hand after it was handed " <>
         "in and checked"},
      {"Runtime.instance/1 blocks", fn -> Runtime.instance(%{p | blocks: o.(big)}) end,
       "`p`'s block types are no map of the types it holds by name, got: " <>
         "#{@cut}: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 an op's line",
       fn -> Runtime.instance(lined(retyped(p, "total", :bool), big)) end,
       "`p`'s `add` on line #{@cut} computes in the type of `total`, a bool, " <>
         "which is no integer type: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 a tag's type",
       fn -> Runtime.instance(retyped(p, "total", o.(big))) end,
       "`p`'s `add` on line 13 computes in the type of `total`, #{@cut}, which " <>
         "is no integer type: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 units", fn -> Runtime.instance(%{p | units: o.(big)}) end,
       "`p`'s units are neither nil nor a map of timer names to units, got: " <>
         "#{@cut}: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 a unit", fn -> Runtime.instance(%{p | units: %{"t1" => o.(big)}}) end,
       "`p`'s units give `t1` #{@cut} a millisecond, where a ton adds 1 to its " <>
         "`acc` each millisecond, which takes no unit: `p` was edited by hand " <>
         "after it compiled"},
      {"Runtime.instance/1 retained", fn -> Runtime.instance(%{p | retained: o.(big)}) end,
       "`p`'s retained paths are neither nil nor a list of paths, got: #{@cut}: " <>
         "`p` was edited by hand after it compiled"},
      {"Runtime.instance/1 reals", fn -> Runtime.instance(%{p | reals: o.(big)}) end,
       "`p`'s reals are neither nil nor a map of tag names to real types, got: " <>
         "#{@cut}: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 a real",
       fn -> Runtime.instance(%{p | reals: %{"rated" => o.(big)}}) end,
       "`p`'s reals give `rate` no real type, where it is a real: `p` was " <>
         "edited by hand after it compiled\n`p`'s reals give `rated` the type " <>
         "#{@cut}, where it is a real: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 arrays", fn -> Runtime.instance(%{p | arrays: o.(big)}) end,
       "`p`'s arrays are neither nil nor a map of tag names to array types, " <>
         "got: #{@cut}: `p` was edited by hand after it compiled"},
      {"Runtime.instance/1 an array",
       fn -> Runtime.instance(%{p | arrays: %{"steps" => o.(big)}}) end,
       "`p`'s arrays give `steps` the type #{@cut}, where it is an array of 3 " <>
         "dints: `p` was edited by hand after it compiled"}
    ]
  end

  # `Logex.Runtime`'s of a resource.
  defp resource_rows(%{big: big, c: c, rt: rt}) do
    o = &opaque/1

    [
      {"Runtime.start/1", fn -> Runtime.start(o.(big)) end,
       "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, " <>
         "got: #{@cut}"},
      {"Runtime.start/2 image", fn -> Runtime.start(c, o.(big)) end,
       "a resource's retained image is a map of `configuration`, `globals`, " <>
         "`instances` and `triggers`, as Logex.Runtime.retained/1 gives one, " <>
         "got: #{@cut}"},
      {"Runtime.start/2 image's configuration",
       fn ->
         Runtime.start(c, %{configuration: o.(big), globals: %{}, instances: %{}, triggers: %{}})
       end,
       "the retained image is of configuration #{@cut}, and this configuration " <>
         "is `plant`: an image starts only the configuration it was taken from"},
      {"Runtime.start/2 image's globals",
       fn ->
         Runtime.start(c, %{
           configuration: "plant",
           globals: o.(big),
           instances: %{},
           triggers: %{}
         })
       end, "the retained image's `globals` are no map, got: #{@cut}"},
      {"Runtime.start/2 image's trigger",
       fn ->
         Runtime.start(c, %{
           configuration: "plant",
           globals: %{},
           instances: %{},
           triggers: %{"eye_1" => o.(big)}
         })
       end,
       "`triggers` holds \"eye_1\" at #{@cut}, which is no last sample of a " <>
         "trigger, a bool's value"},
      {"Runtime.cycle/3 resource", fn -> Runtime.cycle(o.(big), 0, %{}) end,
       "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: #{@cut}"},
      {"Runtime.cycle/3 elapsed_ms", fn -> Runtime.cycle(rt, o.(-big), %{}) end,
       "elapsed_ms must be a non-negative integer of milliseconds, got: #{@negative}"},
      {"Runtime.cycle/3 inputs", fn -> Runtime.cycle(rt, 0, o.(big)) end,
       "inputs must be a map of input-point names to values, as in " <>
         "%{\"pb_start_1\" => 1}, got: #{@cut}"},
      {"Runtime.cycle/3 a key", fn -> Runtime.cycle(rt, 0, %{o.(big) => 1}) end,
       "input #{@cut} is not a point name: inputs are keyed by input-point name, " <>
         "as a string, as in %{\"pb_start_1\" => 1}"},
      {"Runtime.cycle/3 a bool's misfit", fn -> Runtime.cycle(rt, 0, %{"eye_1" => o.(big)}) end,
       "input `eye_1` is a bool: only 0 or 1 fit, found #{@cut}"},
      {"Runtime.cycle/3 a global's misfit",
       fn -> Runtime.cycle(%{rt | globals: Map.put(rt.globals, "count", o.(big))}, 0, %{}) end,
       "runtime.globals holds `count` outside its type: it is a dint, and " <>
         "#{@cut} is outside -2147483648 to 2147483647"},
      {"Runtime.cycle/3 a global's line",
       fn ->
         lined = %{c | globals: Enum.map(c.globals, &relined_global(&1, o.(big)))}
         Runtime.cycle(Runtime.start(lined), 0, %{"temps" => [1, 2], "temps[0]" => 1})
       end,
       "inputs `temps` and `temps[0]` each set `temps`, an array of 2 dints " <>
         "(line #{@cut}): a call sets an array whole or by its elements, not both"},
      {"Runtime.restart/2 mode", fn -> Runtime.restart(rt, o.(big)) end,
       "restart takes :cold or :warm, got: #{@cut}"},
      {"Runtime.get/2 path", fn -> Runtime.get(rt, o.(big)) end,
       "#{@cut} is not an access path: a global, or a program instance, its tag " <>
         "and the members below it, joined by `.`, as in \"m1.t1.acc\""}
    ]
  end

  # `Logex.Edit`'s and `Logex.Configuration.Edit`'s.
  defp edits_rows(%{big: big, p: p, s: s, c: c, rt: rt}) do
    o = &opaque/1

    [
      {"Edit.accept/3 running", fn -> Logex.Edit.accept(o.(big), p, s) end,
       "expected a %Logex.Program{} from Logex.compile/2, got: #{@cut}"},
      {"Edit.test/2 edit", fn -> Logex.Edit.test(o.(big), s) end,
       "expected a %Logex.Edit{} from Logex.Edit.accept/3, got: #{@cut}"},
      {"Configuration.Edit.accept/3 elapsed_ms",
       fn -> Configuration.Edit.accept(rt, c, o.(-big)) end,
       "elapsed_ms must be a non-negative integer of milliseconds, got: #{@negative}"},
      {"Configuration.Edit.test/3 edit", fn -> Configuration.Edit.test(o.(big), rt) end,
       "expected a %Logex.Configuration.Edit{} from " <>
         "Logex.Configuration.Edit.accept/2, got: #{@cut}"},
      {"Configuration.Edit.test/3 generation",
       fn ->
         {:ok, edit, _report} = Configuration.Edit.accept(rt, c)
         Configuration.Edit.test(%{edit | generation: o.(big)}, rt)
       end,
       "this edit expects the resource at generation #{@cut}, but it is at " <>
         "generation 0: the edit has ended, or another edit has stepped since"}
    ]
  end

  # `Logex.IO`'s and `Logex.Runner`'s.
  defp runner_rows(%{big: big, dir: dir, c: c}) do
    o = &opaque/1

    [
      {"IO.points/1", fn -> Logex.IO.points(o.(big)) end,
       "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, " <>
         "got: #{@cut}"},
      {"IO.bind!/2 io", fn -> Logex.IO.bind!(c, o.(big)) end,
       "io binds each device by its name to its adapter, a map such as " <>
         "%{\"panel\" => MyApp.PanelIO}, got: #{@cut}"},
      {"IO.bind!/2 a device's name", fn -> Logex.IO.bind!(c, %{o.(big) => Sim}) end,
       "io names each device by a string, got: #{@cut}\nno adapter is bound to " <>
         "the device `panel`, which `eye_1` (panel.i.0) and `temps[0]` to " <>
         "`temps[1]` (panel.i.1 to panel.i.2) are at"},
      {"IO.bind!/2 an adapter", fn -> Logex.IO.bind!(c, %{"panel" => o.(big)}) end,
       "the device `panel` is bound to #{@cut}: an adapter is a module that " <>
         "implements Logex.IO, or {module, options}"},
      {"IO.bind!/2 an adapter's check",
       fn -> Logex.IO.bind!(c, %{"panel" => {Adapter, checked: o.(big)}}) end,
       "the device `panel` is bound to `Logex.QuotedTest.Adapter`, whose check/3 gives a " <>
         "list of messages, got: #{@cut}"},
      {"IO.bind!/2 an adapter's options",
       fn -> Logex.IO.bind!(c, %{"panel" => {Sim, o.(big)}}) end,
       "the device `panel`'s adapter options are a keyword list, got: #{@cut}"},
      {"Runner.start_link/1 options", fn -> Runner.start_link(o.(big)) end,
       "Logex.Runner.start_link/1 takes a keyword list of options, " <>
         "configuration:, io:, clock:, poll:, overhead:, idle:, write_limit:, " <>
         "open:, forces:, retain:, retain_period:, start: and name:, got: #{@cut}"},
      {"Runner.start_link/1 clock",
       fn -> Runner.start_link(configuration: c, io: %{}, clock: o.(big)) end,
       "the runner's clock: is {module, clock}, a module that implements " <>
         "Logex.Runner.Clock and the clock its callbacks take, got: #{@cut}"},
      {"Runner.start_link/1 poll",
       fn -> Runner.start_link(configuration: c, io: %{"panel" => Sim}, poll: o.(big)) end,
       "the runner's poll: is a whole number of milliseconds, 1 to 2147483647, " <>
         "got: #{@cut}"},
      {"Runner.start_link/1 overhead",
       fn -> Runner.start_link(configuration: c, io: %{"panel" => Sim}, overhead: o.(big)) end,
       "the runner's overhead: is the share of the time kept for its own work, " <>
         "a whole number of percent from 10 to 90, got: #{@cut}"},
      {"Runner.start_link/1 forces",
       fn -> Runner.start_link(configuration: c, io: %{"panel" => Sim}, forces: o.(big)) end,
       "the runner's forces: is the path of the file its forces are kept in, a " <>
         "string, got: #{@cut}"},
      {"Runner.start_link/1 retain",
       fn -> Runner.start_link(configuration: c, io: %{"panel" => Sim}, retain: o.(big)) end,
       "the runner's retain: is the path of the file its retained values are " <>
         "kept in, a string, got: #{@cut}"},
      {"Runner.start_link/1 start",
       fn -> Runner.start_link(configuration: c, io: %{"panel" => Sim}, start: o.(big)) end,
       "the runner's start: is :warm, a fresh start from its store, or :cold, " <>
         "from the configuration's initial values, got: #{@cut}"},
      {"Runner.start_link/1 retain_period",
       fn ->
         Runner.start_link(configuration: c, io: %{"panel" => Sim}, retain_period: o.(big))
       end,
       "the runner's retain_period: is how often it writes its store, a whole " <>
         "number of ms from 100 to 3600000, got: #{@cut}"},
      {"Runner.start_link/1 open",
       fn ->
         Runner.start_link(
           configuration: c,
           io: %{"panel" => {Sim, sim: elem(Sim.start_link(), 1)}},
           open: o.(big)
         )
       end,
       "the runner's open: is how long a device's opening may take, a whole " <>
         "number of milliseconds from 1 to 2147483647, or a map of device names " <>
         "to one, got: #{@cut}"},
      {"Runner.start_link/1 steps",
       fn ->
         Runner.start_link(
           configuration: c,
           io: %{"panel" => {Sim, sim: elem(Sim.start_link(), 1)}},
           steps: o.(big)
         )
       end,
       "the runner's steps: is a module with cycle_steps/3, cycle_step/2 and " <>
         "cycle_outputs/1, standing in for Logex.Runtime's, got: #{@cut}"},
      {"Runner.start_link/1 a clock's time",
       fn -> Runner.start_link(configuration: c, io: %{}, clock: {Clock, {o.(big), 0}}) end,
       "the runner's clock `Logex.QuotedTest.Clock` gave #{@cut} from now_ms/1: a clock's " <>
         "time is a whole number of milliseconds from -9223372036854775808 to " <>
         "9223372036854775807"},
      {"Runner.start_link/1 a clock's answer",
       fn -> Runner.start_link(configuration: c, io: %{}, clock: {Clock, {o.([big]), 0}}) end,
       "the runner's clock `Logex.QuotedTest.Clock` gave [#{@cut}] from now_ms/1: a clock's " <>
         "time is a whole number of milliseconds"},
      {"Runner.force/3 an array's shape",
       fn -> Runner.force(elem(runner(forces(dir, "shape")), 0), "temps", o.(big)) end,
       "`temps` is an array of 2 dints, forced to a list of 2 elements in the " <>
         "elements' order, got: #{@cut}"},
      {"Runner.start_link/1 a wall clock's time",
       fn ->
         Runner.start_link(
           configuration: c,
           io: %{},
           clock: {Clock, {0, o.(big)}},
           retain: Path.join(dir, "store")
         )
       end,
       "the runner's clock `Logex.QuotedTest.Clock` gave #{@cut} from wall_ms/1: a store's " <>
         "header is written at the wall clock's time, a whole number of " <>
         "milliseconds since the Unix epoch from year 0 to year 9999"},
      {"Runner.status/1 runner", fn -> Runner.status(o.(big)) end,
       "expected a runner from Logex.Runner.start_link/1, got: #{@cut}"},
      {"Runner.restart/2 mode", fn -> Runner.restart(elem(runner([]), 0), o.(big)) end,
       "a runner restarts :cold or :warm, got: #{@cut}"},
      {"Runner.subscribe/2 kinds", fn -> Runner.subscribe(elem(runner([]), 0), o.(big)) end,
       "a runner's events are subscribed by a list of their kinds, among " <>
         ":overlap, :fault, :trip, :restart, :edit, :retain, :forces, :ran and " <>
         ":round, got: #{@cut}"},
      {"Runner.force/3 a name",
       fn -> Runner.force(elem(runner(forces(dir, "name")), 0), o.(big), 1) end,
       "a force names an input point by its name, a string, as in \"eye_1\", " <>
         "got: #{@cut}"},
      {"Runner.force/3 a misfit",
       fn -> Runner.force(elem(runner(forces(dir, "misfit")), 0), "eye_1", o.(big)) end,
       "`eye_1` is a bool, forced to 0 or 1, got: #{@cut}"},
      {"Runner: a request",
       fn ->
         {:raise, error} = GenServer.call(elem(runner([]), 0), o.(big))
         raise error
       end,
       "Logex.Runner has no request #{@cut}: a runner is called through get/2, " <>
         "get!/2, status/1, subscribe/2, unsubscribe/1, force/3, unforce/2, " <>
         "unforce_all/1, accept/2, test/1, untest/1, assemble/1, cancel/1, " <>
         "restart/2 and stop/2"}
    ]
  end

  # `Logex.IO.Sim`'s, the clocks' and `Logex.Tag`'s.
  defp tools_rows(%{big: big, c: c, opened: opened}) do
    o = &opaque/1

    [
      {"Sim.set/3 an opened sim's address", fn -> Sim.set(opened, o.(big), 1) end,
       "a runner has opened the simulated device #{inspect(opened)} for the device " <>
         "`panel`: an input's address is the configuration's text from then on, " <>
         "\"panel.i.0\", got: #{@cut}"},
      {"Sim.start_link/1 options", fn -> Sim.start_link(o.(big)) end,
       "Logex.IO.Sim takes a keyword list of options, reports:, clock:, wait:, " <>
         "inputs:, outputs: and writes:, got: #{@cut}"},
      {"Sim.start_link/1 inputs", fn -> Sim.start_link(inputs: o.(-big)) end,
       "Logex.IO.Sim's inputs: is how many points it has, 1 or more, or nil " <>
         "for as many as it is given, got: #{@negative}"},
      {"Sim.start_link/1 writes", fn -> Sim.start_link(writes: o.(-big)) end,
       "Logex.IO.Sim's writes: is how many writes it keeps, its newest, 1 or " <>
         "more, got: #{@negative}"},
      {"Sim.start_link/1 reports", fn -> Sim.start_link(reports: o.(big)) end,
       "Logex.IO.Sim's reports: is true or false, got: #{@cut}"},
      {"Sim.start_link/1 wait", fn -> Sim.start_link(wait: o.(big)) end,
       "Logex.IO.Sim's wait: is a whole number of milliseconds, 1 to " <>
         "4294967295, the longest the VM waits, got: #{@cut}"},
      {"Sim.set/3 sim", fn -> Sim.set(o.(big), [0], 1) end,
       "expected a simulated device from Logex.IO.Sim.start_link/1, got: #{@cut}"},
      {"Sim.set/3 address", fn -> Sim.set(elem(Sim.start_link(), 1), o.(big), 1) end,
       "an address is a list of whole numbers, 0 or more, as `panel.i.1.3`'s " <>
         "is [1, 3], got: #{@cut}"},
      {"Sim.set/3 value", fn -> Sim.set(elem(Sim.start_link(), 1), [0], o.([big])) end,
       "a point's value is a number, got: [#{@cut}]"},
      {"Sim.set/2 values", fn -> Sim.set(elem(Sim.start_link(), 1), o.(big)) end,
       "values go by address, a map of addresses to numbers, got: #{@cut}"},
      {"Sim.fail/3 callback", fn -> Sim.fail(elem(Sim.start_link(), 1), o.(big), :raise) end,
       "Logex.IO.Sim fails one of its callbacks, :init, :read, :write, :report " <>
         "or :close, got: #{@cut}"},
      {"Sim.fail/3 failure", fn -> Sim.fail(elem(Sim.start_link(), 1), :read, o.(big)) end,
       "a failure is {:error, reason}, :raise, :throw, :exit, :hang, {:delay, " <>
         "ms} with ms 0 or more, or, for a read or a report, {:value, address, " <>
         "value}, got: #{@cut}"},
      {"Sim.check/3 sim", fn -> Logex.IO.bind!(c, %{"panel" => {Sim, sim: o.(big)}}) end,
       "the device `panel`'s adapter options: expected a simulated device from " <>
         "Logex.IO.Sim.start_link/1, got: #{@cut}"},
      {"Sim.init/3 points", fn -> Sim.init("panel", o.(big), sim: elem(Sim.start_link(), 1)) end,
       "Logex.IO.Sim opens a device given its points, a list of " <>
         "%Logex.IO.Point{}, got: #{@cut}"},
      {"Clock.receiver!/1", fn -> Logex.Runner.Clock.receiver!(o.(big)) end,
       "a timer wakes a process, given by its pid, got: #{@cut}"},
      {"Clock.time!/1", fn -> Logex.Runner.Clock.time!(o.([big])) end,
       "a timer's time is a whole number of milliseconds on its clock, got: " <>
         "[#{@cut}]"},
      {"Clock.timer!/1", fn -> Logex.Runner.Clock.timer!(o.(big)) end,
       "a timer is cancelled by the reference wake_at/4 gave it, got: #{@cut}"},
      {"Manual.start_link/1 options", fn -> Manual.start_link(o.(big)) end,
       "the manual clock takes a keyword list of options, now: and wait:, got: " <>
         "#{@cut}"},
      {"Manual.start_link/1 now", fn -> Manual.start_link(now: o.([big])) end,
       "the manual clock's now: is a whole number of milliseconds, got: " <>
         "[#{@cut}]"},
      {"Manual.start_link/1 wait", fn -> Manual.start_link(wait: o.(big)) end,
       "the manual clock's wait: is a whole number of milliseconds, 1 to " <>
         "4294967295, the longest the VM waits, got: #{@cut}"},
      {"Manual.advance/2 ms", fn -> Manual.advance(elem(Manual.start_link(), 1), o.(-big)) end,
       "advance/2 moves the clock on by a whole number of milliseconds, 0 or " <>
         "more, got: #{@negative}"},
      {"Manual.now_ms/1 clock", fn -> Manual.now_ms(o.(big)) end,
       "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, " <>
         "got: #{@cut}"},
      {"Tag.new!/5 options", fn -> Logex.Tag.new!("g", :bool, :var, nil, o.(big)) end,
       "the options of `g` are a keyword list, `retain: true` or `non_retain: " <>
         "true`, found #{@cut}"}
    ]
  end

  describe "a refusal of many mistakes tells the first hundred and a count (decision 610)" do
    # Decision 610 (RV-33; the maintainer, 2026-11-24, RV-32's question 1): a refusal of the
    # host contract that tells a line a mistake tells the first hundred, in the order it
    # tells them, and one line that counts the rest, where `put_inputs/3` told 100,000 keys
    # a bridge sent by mistake in 9.6 MB. Each such refusal at 100 mistakes and at 101, its
    # message pinned whole: `lines.(n)` is the n lines it tells, written out here, in its
    # order.
    defp pad(i), do: String.pad_leading(Integer.to_string(i), 3, "0")

    defp hundred(rows) do
      for {label, refuse, lines} <- rows, n <- [100, 101] do
        error = assert_raise ArgumentError, fn -> refuse.(n) end
        assert {label, n, error.message} == {label, n, at_most(n, lines.(n))}
      end
    end

    defp at_most(100, lines), do: Enum.join(lines, "\n")

    defp at_most(101, lines),
      do: Enum.join(Enum.take(lines, 100) ++ ["and 1 more mistake, not listed"], "\n")

    defp each(n, line), do: Enum.map(1..n, line)

    defp unknown(i, takes),
      do: "unknown option :k#{pad(i)} for `g`: #{takes}"

    defp unknowns(n), do: for(i <- 1..n, do: {:"k#{pad(i)}", true})

    @tag_takes "Logex.Tag.new!/5 takes `retain:` and `non_retain:`"
    @global_takes "Logex.Configuration.Global.new!/3 takes `initial:`, `at:`, `retain:` and " <>
                    "`non_retain:`"

    # A program of `n` dint tags, each added to on a rung of its own.
    defp adding(n, name) do
      source =
        Enum.map_join(1..n, "\n", &"var t#{pad(&1)} dint") <>
          "\nvar_input start bool\n\n" <>
          Enum.map_join(1..n, "\n", &"xic start add t#{pad(&1)} 1 t#{pad(&1)}") <> "\n"

      {:ok, p} = Logex.compile(source, name: name)
      p
    end

    # The same program edited by hand after it compiled, every `t` tag made a bool.
    defp unaddable(p),
      do: %{
        p
        | tags: Map.new(p.tags, &boolean/1)
      }

    defp boolean({"t" <> _ = name, tag}), do: {name, %{tag | type: :bool}}
    defp boolean(entry), do: entry

    defp computes(n, name),
      do:
        each(
          n,
          &("`#{name}`'s `add` on line #{n + 2 + &1} computes in the type of `t#{pad(&1)}`, a " <>
              "bool, which is no integer type: `#{name}` was edited by hand after it compiled")
        )

    defp twice(n),
      do: %Configuration{
        name: "c",
        globals: List.duplicate(%Global{name: "g", type: :bool}, n)
      }

    defp declared_twice(n),
      do:
        List.duplicate("`g` is declared twice: the first is a global", n - 1) ++
          ["this configuration declares no `program`: it would run nothing"]

    defp plant(globals) do
      {:ok, tally} = Logex.compile(@tally, name: "tally")

      {:ok, c} =
        Configuration.compile(
          "plant",
          "var_global eye_1 bool at panel.i.0\nvar_global case_full bool\n" <>
            "var_global count dint 0\n#{globals}\n\nprogram t1 tally\n  t1.eye eye_1\n" <>
            "  t1.full case_full\n",
          %{"tally" => tally}
        )

      c
    end

    # A resource whose instance reads `n` globals, each through a connection, and the
    # global `count` its var_external names, every one of them made `:x` by hand.
    defp misread(n) do
      source =
        Enum.map_join(1..n, "\n", &"var_input v#{pad(&1)} dint") <>
          "\nvar_input start bool\nvar_external count dint\nvar_output lamp bool\n\n" <>
          "xic start ote lamp\n"

      {:ok, reader} = Logex.compile(source, name: "reader")

      text =
        Enum.map_join(1..n, "\n", &"var_global g#{pad(&1)} dint") <>
          "\nvar_global count dint 0\n\nprogram i1 reader\n" <>
          Enum.map_join(1..n, "\n", &"  i1.v#{pad(&1)} g#{pad(&1)}") <> "\n  i1.start 0\n"

      {:ok, c} = Configuration.compile("plant", text, %{"reader" => reader})
      rt = Runtime.start(c)
      %{rt | globals: Map.new(rt.globals, fn {name, _value} -> {name, :x} end)}
    end

    defp held_outside(name),
      do:
        "runtime.globals holds `#{name}` outside its type: it is a dint, and its value must " <>
          "be an integer, found :x"

    test "Logex.Tag's and Logex.Configuration's" do
      hundred([
        {"Tag.new!/5's options", &Logex.Tag.new!("g", :bool, :var, nil, unknowns(&1)),
         &each(&1, fn i -> unknown(i, @tag_takes) end)},
        {"Tag.new!/5's options, both qualifiers among them",
         &Logex.Tag.new!(
           "g",
           :bool,
           :var,
           nil,
           unknowns(&1 - 1) ++ [retain: true, non_retain: true]
         ),
         &(each(&1 - 1, fn i -> unknown(i, @tag_takes) end) ++
             [
               "`g` takes `retain: true` or `non_retain: true`, not both, as a declaration " <>
                 "takes `retain` or `non_retain`, not both"
             ])},
        {"Global.new!/3's options", &Global.new!("g", :bool, unknowns(&1)),
         &each(&1, fn i -> unknown(i, @global_takes) end)},
        {"Global.new!/3's options, both qualifiers among them",
         &Global.new!("g", :bool, unknowns(&1 - 1) ++ [retain: true, non_retain: true]),
         &(each(&1 - 1, fn i -> unknown(i, @global_takes) end) ++
             [
               "`g` takes `retain: true` or `non_retain: true`, not both, as a `var_global` " <>
                 "line takes `retain` or `non_retain`, not both"
             ])},
        {"Configuration.new!/1",
         fn n ->
           Configuration.new!(
             name: "c",
             globals: for(i <- 1..(n - 1), do: %Global{name: "g#{pad(i)}", type: :bool, line: 1})
           )
         end,
         &(each(&1 - 1, fn i -> "global `g#{pad(i)}` from Elixir has no line, got: 1" end) ++
             ["this configuration declares no `program`: it would run nothing"])},
        {"Configuration.check/1",
         fn n ->
           Configuration.check(%Configuration{
             name: "c",
             globals: for(i <- 1..n, do: %Global{name: "g#{pad(i)}", type: :bool, retain: 3})
           })
         end,
         &each(&1, fn i ->
           "unknown qualifier 3 on global `g#{pad(i)}`: logex has :retain and :non_retain, " <>
             "or nil for none"
         end)},
        {"Runtime.start/1, a configuration's diagnostics", &Runtime.start(twice(&1)),
         &declared_twice/1},
        {"IO.bind!/2, a configuration's diagnostics", &Logex.IO.bind!(twice(&1), %{}),
         &declared_twice/1}
      ])
    end

    test "Logex.IO.bind!/2's", %{c: c} do
      hundred([
        {"devices keyed by number",
         &Logex.IO.bind!(
           c,
           Map.put(Map.new(1..&1, fn i -> {i, Sim} end), "panel", {Adapter, checked: []})
         ), &each(&1, fn i -> "io names each device by a string, got: #{i}" end)},
        {"devices bound that no point is at",
         &Logex.IO.bind!(
           c,
           Map.put(
             Map.new(1..&1, fn i -> {"d#{pad(i)}", Sim} end),
             "panel",
             {Adapter, checked: []}
           )
         ), &each(&1, fn i -> "the device `d#{pad(i)}` is bound, but no point is at it" end)}
      ])
    end

    test "Logex.Runtime's of a lone instance", %{p: p, s: s, scan: scan} do
      {:ok, wide} =
        Logex.compile(
          "var_input big dint[101]\nvar_input start bool\nvar_output lamp bool\n\n" <>
            "xic start ote lamp\n",
          name: "wide"
        )

      hundred([
        {"put_inputs/3, keys that are no text",
         &Runtime.put_inputs(p, s, Map.new(1..&1, fn i -> {i, 1} end)),
         &each(&1, fn i ->
           "input #{i} is not a tag name: inputs are keyed by tag name, as a string, as in " <>
             ~s|%{"start" => 1}|
         end)},
        {"put_inputs/3, names no tag has",
         &Runtime.put_inputs(p, s, Map.new(1..&1, fn i -> {"k#{pad(i)}", 1} end)),
         &[
           "input `k001` is not declared: the var_inputs are `rate`, `speed`, `start`, `steps`"
           | each(&1 - 1, fn i -> "input `k#{pad(i + 1)}` is not declared" end)
         ]},
        {"put_inputs/3, elements each set twice",
         fn n ->
           keys = for i <- 0..(n - 1), key <- ["big[#{i}]", "big[0#{i}]"], into: %{}, do: {key, 1}
           Runtime.put_inputs(wide, Runtime.instance(wide), keys)
         end,
         &each(&1, fn i ->
           "inputs `big[0#{i - 1}]` and `big[#{i - 1}]` each set `big[#{i - 1}]`, an element " <>
             "of `big`, an array of 101 dints (declared on line 1): a call sets each element once"
         end)},
        {"call/4, a state's values outside their types",
         fn n ->
           p = adding(n, "p")
           state = Runtime.instance(p)
           state = %{state | env: Map.new(state.env, &unvalued/1)}
           Runtime.call(p, state, %{}, scan)
         end,
         &each(&1, fn i ->
           "state.env holds `t#{pad(i)}` outside its type: it is a dint, and its value must " <>
             "be an integer, found :x"
         end)},
        {"instance/1, a program edited by hand", &Runtime.instance(unaddable(adding(&1, "e"))),
         &computes(&1, "e")},
        {"instance/2, an image's paths",
         fn n ->
           Runtime.instance(p, %{
             Runtime.retained(p, s)
             | values: Map.new(1..n, fn i -> {"1x#{pad(i)}", 1} end)
           })
         end, &each(&1, fn i -> ~s|`values` holds "1x#{pad(i)}", which is no path| end)},
        {"Edit.accept/3, a candidate edited by hand",
         fn n ->
           e = adding(n, "e")
           Logex.Edit.accept(e, unaddable(e), Runtime.instance(e))
         end, &computes(&1, "e")}
      ])
    end

    defp unvalued({"t" <> _ = name, _value}), do: {name, :x}
    defp unvalued(entry), do: entry

    test "Logex.Runtime's of a resource", %{rt: rt, c: c} do
      hundred([
        {"cycle/3, keys that are no text",
         &Runtime.cycle(rt, 0, Map.new(1..&1, fn i -> {i, 1} end)),
         &each(&1, fn i ->
           "input #{i} is not a point name: inputs are keyed by input-point name, as a " <>
             ~s|string, as in %{"pb_start_1" => 1}|
         end)},
        {"cycle/3, names no point has",
         &Runtime.cycle(rt, 0, Map.new(1..&1, fn i -> {"k#{pad(i)}", 1} end)),
         &[
           "input `k001` is not an input point: the input points are `eye_1` and `temps[0]` " <>
             "to `temps[1]`"
           | each(&1 - 1, fn i -> "input `k#{pad(i + 1)}` is not an input point" end)
         ]},
        {
          "cycle/3, points each set twice",
          fn n ->
            wide = Runtime.start(plant("var_global temps dint[101] at panel.i.1"))

            keys =
              for i <- 0..(n - 1), key <- ["temps[#{i}]", "temps[0#{i}]"], into: %{}, do: {key, 1}

            Runtime.cycle(wide, 0, keys)
          end,
          # In the order of the points' names, `temps[10]` before `temps[1]`'s `]`.
          &for(
            i <- Enum.sort_by(0..(&1 - 1), fn i -> "temps[#{i}]" end),
            do:
              "inputs `temps[0#{i}]` and `temps[#{i}]` each set `temps[#{i}]`, an input point " <>
                "of `temps`, an array of 101 dints (line 4): a call sets each point once"
          )
        },
        {"cycle/3, arrays set whole and by their elements",
         fn n ->
           arrays = Enum.map_join(1..n, "\n", &"var_global a#{pad(&1)} dint[1] at panel.i.#{&1}")
           keys = for i <- 1..n, into: %{}, do: {"a#{pad(i)}", [1]}
           keys = Map.merge(keys, for(i <- 1..n, into: %{}, do: {"a#{pad(i)}[0]", 1}))
           Runtime.cycle(Runtime.start(plant(arrays)), 0, keys)
         end,
         &each(&1, fn i ->
           "inputs `a#{pad(i)}` and `a#{pad(i)}[0]` each set `a#{pad(i)}`, an array of 1 dint " <>
             "(line #{3 + i}): a call sets an array whole or by its elements, not both"
         end)},
        {"cycle/3, globals a connection reads outside their types",
         &Runtime.cycle(misread(&1 - 1), 0, %{}),
         &[held_outside("count") | each(&1 - 1, fn i -> held_outside("g#{pad(i)}") end)]},
        {"start/2, an image's globals",
         fn n ->
           image = Runtime.retained(rt)
           Runtime.start(c, %{image | globals: Map.new(1..n, &{"1x#{pad(&1)}", {:dint, 0}})})
         end, &each(&1, fn i -> ~s|`globals` holds "1x#{pad(i)}", which names no global| end)},
        {"Configuration.Edit.accept/2, a program type edited by hand",
         fn n ->
           e = adding(n, "e")
           {:ok, ce} = Configuration.compile("plant", "program i1 e\n  i1.start 0\n", %{"e" => e})
           running = Runtime.start(ce)
           edited = %{running | config: %{running.config | programs: %{"e" => unaddable(e)}}}
           Configuration.Edit.accept(edited, ce)
         end, &computes(&1, "e")}
      ])
    end

    # A step refused by its instance's state, a line a tag, tells its var_external's global
    # alone, by that global: the state's count is none of the step's (decision 610).
    test "a step's refusal takes no count from a state's refusal" do
      source =
        Enum.map_join(1..101, "\n", &"var t#{pad(&1)} dint") <>
          "\nvar_input start bool\nvar_external count dint\nvar_output lamp bool\n\n" <>
          "xic start ote lamp\n"

      {:ok, program} = Logex.compile(source, name: "e")

      {:ok, c} =
        Configuration.compile(
          "plant",
          "var_global count dint 0\n\nprogram i1 e\n  i1.start 0\n",
          %{
            "e" => program
          }
        )

      rt = Runtime.start(c)
      state = rt.instances["i1"]
      state = %{state | env: Map.new(state.env, &unvalued/1)}

      rt = %{
        rt
        | instances: Map.put(rt.instances, "i1", state),
          globals: Map.put(rt.globals, "count", :x)
      }

      assert_raise ArgumentError, held_outside("count"), fn -> Runtime.cycle(rt, 0, %{}) end
    end

    # A step's refusal tells a copy-in's lines among its var_externals', so it counts the
    # copy-in's past its own hundred too: 101 globals a connection reads and `count`,
    # which a var_external names, told as the first hundred of 102 and a count of 2, where
    # the copy-in's count line was dropped and its one past the hundred lost.
    test "a step's refusal counts what a copy-in's did not list" do
      lines = [held_outside("count") | each(99, fn i -> held_outside("g#{pad(i)}") end)]

      assert_raise ArgumentError,
                   Enum.join(lines ++ ["and 2 more mistakes, not listed"], "\n"),
                   fn -> Runtime.cycle(misread(101), 0, %{}) end
    end
  end

  describe "a refusal of many mistakes costs near its count, its text the hundred's (decision 610)" do
    # Each refusal of 100,000 mistakes against the same of 1,000, in the same run, in
    # reductions, the least of three: its message the first hundred lines and a count,
    # pinned whole, two bytes longer than the 1,000's; its cost no more than 120 times the
    # 1,000's, its count's; and each mistake past the hundred costing less than three
    # quarters of one among them, so that its line, its quoted value and its did-you-mean
    # are never made (RV-32 measured `put_inputs/3` of 100,000 keys at 0.4 s and 9.6 MB).
    defp spent(fun) do
      parent = self()

      Enum.min(
        for _ <- 1..3 do
          spawn(fn ->
            {:reductions, before} = Process.info(self(), :reductions)
            message = refusal(fun)
            {:reductions, later} = Process.info(self(), :reductions)
            send(parent, {:spent, later - before, message})
          end)

          receive do
            {:spent, count, message} -> {count, message}
          end
        end
      )
    end

    defp refusal(fun) do
      fun.()
      :taken
    rescue
      error in ArgumentError -> error.message
    end

    test "put_inputs/3, cycle/3 and IO.bind!/2", %{p: p, s: s, rt: rt, c: c} do
      rows = [
        {"put_inputs/3, keys that are no text", &Runtime.put_inputs(p, s, &1),
         &Map.new(1..&1, fn i -> {i, 1} end),
         fn i ->
           "input #{i} is not a tag name: inputs are keyed by tag name, as a string, as in " <>
             ~s|%{"start" => 1}|
         end},
        {"put_inputs/3, names no tag has", &Runtime.put_inputs(p, s, &1),
         &Map.new(1..&1, fn i -> {"k#{String.pad_leading("#{i}", 6, "0")}", 1} end),
         &named_line(
           &1,
           "is not declared",
           ": the var_inputs are `rate`, `speed`, `start`, `steps`"
         )},
        {"put_inputs/3, elements of no array", &Runtime.put_inputs(p, s, &1),
         &Map.new(1..&1, fn i -> {"k#{String.pad_leading("#{i}", 6, "0")}[0]", 1} end),
         &element_line/1},
        {"cycle/3, keys that are no text", &Runtime.cycle(rt, 0, &1),
         &Map.new(1..&1, fn i -> {i, 1} end),
         fn i ->
           "input #{i} is not a point name: inputs are keyed by input-point name, as a " <>
             ~s|string, as in %{"pb_start_1" => 1}|
         end},
        {"cycle/3, names no point has", &Runtime.cycle(rt, 0, &1),
         &Map.new(1..&1, fn i -> {"k#{String.pad_leading("#{i}", 6, "0")}", 1} end),
         &named_line(
           &1,
           "is not an input point",
           ": the input points are `eye_1` and `temps[0]` to `temps[1]`"
         )},
        {"IO.bind!/2, devices keyed by number", &Logex.IO.bind!(c, &1),
         &Map.put(Map.new(1..&1, fn i -> {i, Sim} end), "panel", {Adapter, checked: []}),
         &"io names each device by a string, got: #{&1}"},
        {"IO.bind!/2, devices bound that no point is at", &Logex.IO.bind!(c, &1),
         &Map.put(
           Map.new(1..&1, fn i -> {"d#{String.pad_leading("#{i}", 6, "0")}", Sim} end),
           "panel",
           {Adapter, checked: []}
         ),
         &"the device `d#{String.pad_leading("#{&1}", 6, "0")}` is bound, but no point is at it"}
      ]

      for {label, refuse, mistakes, line} <- rows do
        {one, _} = spent(fn -> refuse.(mistakes.(1)) end)
        {hundred, _} = spent(fn -> refuse.(mistakes.(100)) end)
        {thousand, few} = spent(fn -> refuse.(mistakes.(1_000)) end)
        {many, told} = spent(fn -> refuse.(mistakes.(100_000)) end)

        assert {label, told} ==
                 {label,
                  Enum.join(
                    Enum.map(1..100, line) ++ ["and 99900 more mistakes, not listed"],
                    "\n"
                  )}

        assert {label, byte_size(told)} == {label, byte_size(few) + 2}
        assert many <= 120 * thousand, "#{label}: #{many} reductions, against #{thousand}"

        assert (many - thousand) / 99_000 < 0.75 * (hundred - one) / 99,
               "#{label}: #{(many - thousand) / 99_000} a mistake past the hundred, " <>
                 "against #{(hundred - one) / 99} among them"
      end
    end

    defp named_line(1, told, listed), do: "input `k000001` #{told}#{listed}"

    defp named_line(i, told, _listed),
      do: "input `k#{String.pad_leading("#{i}", 6, "0")}` #{told}"

    defp element_line(1),
      do:
        ~s|input "k000001[0]" is not declared: the var_inputs are `rate`, `speed`, `start`, `steps`|

    defp element_line(i),
      do: ~s|input "k#{String.pad_leading("#{i}", 6, "0")}[0]" is not declared|
  end

  describe "a text past 4,096 bytes is cut where a refusal quotes it (decision 613)" do
    # Decision 613 (RV-33; the maintainer, 2026-11-24, RV-32's question 4): a name or a
    # location a refusal quotes past 4,096 bytes, `inspect/1`'s `printable_limit`, is cut
    # there, at a character's boundary, and told it was cut and how long it was, where a
    # bridge's megabyte of a key was quoted whole, a megabyte in the operator's log after
    # some 2 s; a text of 4,096 bytes is whole. A text a refusal shows as a value, a type's
    # text among them, is cut as `inspect/1` cuts it (decision 585).
    @types "logex has :bool, :sint, :int, :dint, :lint, :usint, :uint, :udint, :ulint, " <>
             ":real, :lreal, :byte, :word, :dword, :lword, Logex.FbType.ctd(), " <>
             "Logex.FbType.ctd_int(), Logex.FbType.ctd_lint(), Logex.FbType.ctd_udint(), " <>
             "Logex.FbType.ctd_ulint(), Logex.FbType.ctu(), Logex.FbType.ctu_int(), " <>
             "Logex.FbType.ctu_lint(), Logex.FbType.ctu_udint(), Logex.FbType.ctu_ulint(), " <>
             "Logex.FbType.ctud(), Logex.FbType.ctud_int(), Logex.FbType.ctud_lint(), " <>
             "Logex.FbType.ctud_udint(), Logex.FbType.ctud_ulint(), Logex.FbType.rto(), " <>
             "Logex.FbType.rto_ltime(), Logex.FbType.tof(), Logex.FbType.tof_ltime(), " <>
             "Logex.FbType.ton(), Logex.FbType.ton_ltime(), Logex.FbType.tp() and " <>
             "Logex.FbType.tp_ltime()"

    @var_inputs "the var_inputs are `rate`, `speed`, `start`, `steps`"

    defp a(n), do: String.duplicate("a", n)

    defp texts(%{p: p, s: s, rt: rt, c: c}),
      do: [
        {"put_inputs/3, a key", &Runtime.put_inputs(p, s, %{&1 => 1}),
         &"input #{&1} is not declared: #{@var_inputs}"},
        {"get!/2, a path", &Runtime.get!(rt, &1),
         &"#{&1} is neither a global nor a program instance"},
        {"IO.bind!/2, a device's name",
         &Logex.IO.bind!(c, %{&1 => Sim, "panel" => {Adapter, checked: []}}),
         &"the device #{&1} is bound, but no point is at it"}
      ]

    test "a name of 4,096 bytes whole, and of 4,097 cut and told how long", ctx do
      whole = "`#{a(4_096)}`"
      cut = "`#{a(4_096)}…` (4097 bytes)"

      for {label, refuse, message} <- texts(ctx),
          {text, quoted} <- [{a(4_096), whole}, {a(4_097), cut}] do
        error = assert_raise ArgumentError, fn -> refuse.(opaque(text)) end
        assert {label, error.message} == {label, message.(quoted)}
      end

      # A type's text is a value: whole at 4,096 bytes, and past them cut as `inspect/1`
      # cuts it, as it was (decision 585), now without its did-you-mean's 13 s.
      assert_raise ArgumentError, ~s|unknown type "#{a(4_096)}": #{@types}|, fn ->
        Logex.Tag.new!("x", opaque(a(4_096)))
      end

      assert_raise ArgumentError, ~s|unknown type "#{a(4_096)}" <> ...: #{@types}|, fn ->
        Logex.Tag.new!("x", opaque(a(4_097)))
      end
    end

    test "cut at a character's boundary, and a binary that is no text shown as one", %{c: c} do
      # 4,095 bytes and a two-byte character: the cut's 4,096th byte is the character's
      # first, which it drops.
      assert_raise ArgumentError,
                   "the device `#{a(4_095)}…` (4097 bytes) is bound, but no point is at it",
                   fn ->
                     Logex.IO.bind!(c, %{
                       opaque(a(4_095) <> "é") => Sim,
                       "panel" => {Adapter, checked: []}
                     })
                   end

      bytes = <<255>> <> a(5_000)

      assert_raise ArgumentError,
                   "the device #{inspect(bytes)} is bound, but no point is at it",
                   fn ->
                     Logex.IO.bind!(c, %{opaque(bytes) => Sim, "panel" => {Adapter, checked: []}})
                   end

      assert Logex.Lexer.quoted_text(a(4_096)) == "`#{a(4_096)}`"
      assert Logex.Lexer.quoted_text(a(1_000_000)) == "`#{a(4_096)}…` (1000000 bytes)"
    end

    # Each refusal's message pinned whole, a cut text's 4,096 bytes and its line beside it.
    defp cut_told(rows) do
      for {label, fun, message} <- rows do
        error = assert_raise ArgumentError, fun
        assert {label, error.message} == {label, message}
        assert byte_size(error.message) < 4_400, label
      end
    end

    # Every line that quotes a key, a path or a configuration's name or location quotes it
    # through the cut: an element's key with a subscript of 5,000 digits, which a number
    # of 10,000 characters may be, a global's name, and a location.
    test "a key, a global's name and a location past 4,096 bytes, each line cut" do
      {:ok, wide} =
        Logex.compile(
          "var_input big dint[101]\nvar_input start bool\nvar_output lamp bool\n\n" <>
            "xic start ote lamp\n",
          name: "wide"
        )

      s = Runtime.instance(wide)
      zeros = String.duplicate("0", 5_000)
      cut = &"`#{binary_part(&1, 0, 4_096)}…` (#{byte_size(&1)} bytes)"
      big = "an array of 101 dints (declared on line 1)"
      by_hand = &Runtime.put_inputs(wide, s, &1)
      long = a(5_000)

      cut_told([
        {"an element set twice", fn -> by_hand.(%{"big[0]" => 1, "big[#{zeros}]" => 1}) end,
         "inputs #{cut.("big[#{zeros}]")} and `big[0]` each set `big[0]`, an element of " <>
           "`big`, #{big}: a call sets each element once"},
        {"a subscript outside", fn -> by_hand.(%{"big[#{zeros}200]" => 1}) end,
         "input #{cut.("big[#{zeros}200]")}'s subscript 200 is outside the elements of " <>
           "`big`, 0 to 100: `big` is #{big}"},
        {"two subscripts", fn -> by_hand.(%{"big[#{zeros}1,2]" => 1}) end,
         "input #{cut.("big[#{zeros}1,2]")} names an element of `big`, #{big}, by 2 " <>
           "subscripts, where it takes 1, one a dimension, as in `big[0]`"},
        {"a name with a `.`", fn -> Global.new!(long <> ".b", :bool) end,
         "#{cut.(long <> ".b")} cannot name a global: `.` is kept for a path, as in " <>
           "`m1.start`, and a location, as in `panel.i.0`"},
        {"a name with brackets", fn -> Global.new!(long <> "[1]", :bool) end,
         "#{cut.(long <> "[1]")} cannot name a global: brackets are kept for an element's " <>
           "subscripts, as in `m1.temps[3]`"},
        {"an input point's initial value",
         fn -> Global.new!(long, :bool, at: "panel.i.0", initial: 1) end,
         "#{cut.(long)} is an input point: its value comes from the input image, so it takes " <>
           "no initial value"},
        {"an output point's initial value",
         fn -> Global.new!(long, :bool, at: "panel.q.0", initial: 1) end,
         "#{cut.(long)} is an output point: it takes no initial value, and is 0 until its " <>
           "driver writes it"},
        {"a located global retained",
         fn -> Global.new!(long, :bool, at: "panel.i.0", retain: true) end,
         "#{cut.(long)} is an input point, and a located global takes no `retain`: an input " <>
           "point is read again at every start, and an output point starts at 0 until logic " <>
           "writes it"},
        {"a located array's initial list",
         fn -> Global.new!(long, {:array, :dint, [2]}, at: "panel.i.0", initial: [1, 2]) end,
         "#{cut.(long)} is an array of input points, `panel.i.0` to `panel.i.1`: their " <>
           "values come from the input image, so it takes no initial list"},
        {"a location not as written", fn -> Global.new!("g", :bool, at: "panel.I.#{zeros}0") end,
         "#{cut.("panel.I.#{zeros}0")} is not a location as written: a location's `i` or `q` " <>
           "is lowercase and its address has no leading zero, so it is written `panel.i.0`"}
      ])
    end

    # A megabyte's refusal against a short one's, in reductions, the least of three, in the
    # same run: no more than the short one's and twice what the call reads of the text, the
    # cut's own look at its first 4,096 bytes and what the call does with any text it is
    # given, a split at `.` and, for an access path, its lexing; its message the 4,097
    # bytes' but for the count. RV-32 measured 0.85 to 13 s at a megabyte, each a
    # did-you-mean's Jaro distance or the name lexed for its quoting.
    test "a megabyte's refusal costs what a short one's does and the cut's", ctx do
      huge = a(1_000_000)
      short = a(10)
      {cut, _} = spent(fn -> Logex.Lexer.quoted_text(huge) end)
      {shown, _} = spent(fn -> Logex.Lexer.inspected(huge) end)
      {split, _} = spent(fn -> String.split(huge, ".") end)
      {lexed, _} = spent(fn -> Logex.Lexer.tokenize(huge) end)

      rows =
        Enum.zip(texts(ctx), [cut + split, cut + split + lexed, cut]) ++
          [
            {{"Tag.new!/5, a type's text", &Logex.Tag.new!("x", &1),
              &"unknown type #{&1}: #{@types}"}, shown}
          ]

      for {{label, refuse, _message}, own} <- rows do
        {small, _} = spent(fn -> refuse.(opaque(short)) end)
        {many, told} = spent(fn -> refuse.(opaque(huge)) end)
        {_, cut_short} = spent(fn -> refuse.(opaque(a(4_097))) end)

        assert {label, told} ==
                 {label, String.replace(cut_short, "(4097 bytes)", "(1000000 bytes)")}

        assert many <= small + 2 * own,
               "#{label}: #{many} reductions, against #{small} and #{own}"
      end
    end
  end

  describe "instance/1 refuses a struct where a map is due (decision 616)" do
    # Decision 616 (RV-33; the maintainer, 2026-11-24, RV-32's question 7): a program edited
    # by hand that holds a struct where a map is due, its tag table, its blocks, its
    # arrays, units or reals, is refused where it is handed in, a pinned ArgumentError,
    # where a `Date` or a `Time` in its tags or blocks raised Protocol.UndefinedError,
    # Elixir's message, 100 KB with a long year; a field logex's own check took for a map
    # of names is a line of its own. `put_inputs/3` and `call/4` take the program's shape
    # alone, as before: a program edited after `instance/1` is trusted.
    test "a Date or a Time in a program's tags, blocks, arrays, units or reals", %{p: p, big: big} do
      date = ~D[2026-11-24]
      long = opaque(%{__struct__: Date, year: big, month: 1, day: 1, calendar: Calendar.ISO})

      time =
        opaque(%{
          __struct__: Time,
          hour: big,
          minute: 0,
          second: 0,
          microsecond: {0, 0},
          calendar: Calendar.ISO
        })

      by_hand = ": `p` was edited by hand after it compiled"
      shown = "%Date{year: #{@cut}, month: 1, day: 1, calendar: Calendar.ISO}"

      told([
        {"tags, a Date", fn -> Runtime.instance(%{p | tags: opaque(date)}) end,
         "`p`'s tags are no map of its tags by name, got: ~D[2026-11-24]" <> by_hand},
        {"tags, a long year", fn -> Runtime.instance(%{p | tags: long}) end,
         "`p`'s tags are no map of its tags by name, got: #{shown}" <> by_hand},
        {"tags, a Time", fn -> Runtime.instance(%{p | tags: time}) end,
         "`p`'s tags are no map of its tags by name, got: %Time{hour: #{@cut}, minute: 0, " <>
           "second: 0, microsecond: {0, 0}, calendar: Calendar.ISO}" <> by_hand},
        {"blocks, a long year", fn -> Runtime.instance(%{p | blocks: long}) end,
         "`p`'s block types are no map of the types it holds by name, got: #{shown}" <> by_hand},
        {"blocks, a Date", fn -> Runtime.instance(%{p | blocks: opaque(date)}) end,
         "`p`'s block types are no map of the types it holds by name, got: ~D[2026-11-24]" <>
           by_hand},
        {"arrays, a Date", fn -> Runtime.instance(%{p | arrays: opaque(date)}) end,
         "`p`'s arrays are neither nil nor a map of tag names to array types, got: " <>
           "~D[2026-11-24]" <> by_hand},
        {"units, a Date", fn -> Runtime.instance(%{p | units: opaque(date)}) end,
         "`p`'s units are neither nil nor a map of timer names to units, got: ~D[2026-11-24]" <>
           by_hand},
        {"reals, a MapSet",
         fn -> Runtime.instance(%{p | reals: opaque(MapSet.new(["rate"]))}) end,
         "`p`'s reals are neither nil nor a map of tag names to real types, got: " <>
           ~s|MapSet.new(["rate"])| <> by_hand}
      ])
    end
  end

  describe "a hostile value wherever the host contract takes one (RV-32's review, F7)" do
    # A walk over the host contract's arguments and the fields of the structs it checks,
    # each given in turn a long number, a tuple, a list and a struct that hold one, a
    # `Date` and a `Time` that write one out themselves, a name that is no UTF-8 text, and
    # since decision 613 a text of 100,000 bytes: every refusal an ArgumentError, its message text and under 5,000 bytes, so
    # that an integer or a name a refusal writes out itself, `"#{n}"`, which no walk of
    # the syntax trees can tell from a word, is found here wherever a host can reach it.
    # A program built or edited by hand is outside the contract but where a check names it
    # (`Logex.Runtime`'s moduledoc), so its fields are walked at `instance/1` alone, and
    # what escapes there is listed in `@outside` with its reason. None does: since
    # decision 616 (RV-33) `instance/1`'s shape check refuses a struct where a map is due,
    # a `Date` or a `Time` in a program's tag table or its blocks, which it took for a map
    # and its check then walked as one (Protocol.UndefinedError), each pinned below. A tag
    # of the table that is a struct is not walked here (`PLAN.md`'s "RV-33 as built",
    # question 4).
    @outside %{}

    # The fields the walk gives a value that nothing reads where it is walked: a
    # program's name is the instance's type, taken as it is; its file, source and warnings
    # and a configuration's warnings are what the compile gave, read by no check.
    @unread [
      "check/1 configuration.warnings",
      "instance/1 program.file",
      "instance/1 program.name",
      "instance/1 program.source",
      "instance/1 program.warnings"
    ]

    defp hostile(big) do
      [
        long: big,
        negative: -big,
        tuple: {:a, big},
        listed: [big],
        no_text: "ab" <> <<255>> <> "c",
        date: %{__struct__: Date, year: big, month: 1, day: 1, calendar: Calendar.ISO},
        time: %{
          __struct__: Time,
          hour: big,
          minute: 0,
          second: 0,
          microsecond: {0, 0},
          calendar: Calendar.ISO
        },
        in_list: [%{__struct__: Date, year: big, month: 1, day: 1, calendar: Calendar.ISO}],
        # Decision 613: a text past 4,096 bytes, a name or a location among them, cut.
        long_text: String.duplicate("a", 100_000)
      ]
    end

    defp fielded(struct, call),
      do:
        for(
          field <- Map.keys(Map.from_struct(struct)),
          do: {field, &call.(Map.put(struct, field, &1))}
        )

    defp callers(%{p: p, s: s, scan: scan, c: c, rt: rt}) do
      {:ok, tally} = Logex.compile(@tally, name: "tally")
      global = hd(c.globals)
      task = %Task{name: "main", interval: 10, line: 1}
      checked = &Configuration.check/1

      [
        {"Global.new!/3 name", &Global.new!(&1, :bool)},
        {"Global.new!/3 name and type", &Global.new!(&1, "x")},
        {"Global.new!/3 type", &Global.new!("g", &1)},
        {"Global.new!/3 location", &Global.new!("g", :bool, at: &1)},
        {"Global.new!/3 initial", &Global.new!("g", :dint, initial: &1)},
        {"Tag.new!/5 name", &Logex.Tag.new!(&1, :bool)},
        {"Tag.new!/5 name and options", &Logex.Tag.new!(&1, :bool, :var, nil, :x)},
        {"Tag.new!/5 type", &Logex.Tag.new!("x", &1)},
        {"Tag.new!/5 initial", &Logex.Tag.new!("x", :dint, :var, &1)},
        {"compile/2 source", &Logex.compile(&1, name: "p")},
        {"compile/2 name", &Logex.compile(@source, name: &1)},
        {"compile/2 a type's key", &Logex.compile(@source, name: "p", types: %{&1 => tally})},
        {"compile_file/1", &Logex.compile_file/1},
        {"Configuration.compile/3 name",
         &Configuration.compile(&1, @config, %{"tally" => tally})},
        {"Configuration.compile/3 text",
         &Configuration.compile("plant", &1, %{"tally" => tally})},
        {"Configuration.compile/3 a type's key",
         &Configuration.compile("plant", @config, %{&1 => tally})},
        {"Configuration.compile_file/1", &Configuration.compile_file/1},
        {"put_inputs/3 a key", &Runtime.put_inputs(p, s, %{&1 => 1})},
        {"put_inputs/3 a value", &Runtime.put_inputs(p, s, %{"start" => &1})},
        {"put_inputs/3 a program's name", &Runtime.put_inputs(%{p | name: &1}, s, %{})},
        {"call/4 a program's name", &Runtime.call(%{p | name: &1}, s, %{}, scan)},
        {"restart/3 a program's name", &Runtime.restart(%{p | name: &1}, s, :cold)},
        {"restart/3 mode", &Runtime.restart(p, s, &1)},
        {"instance/2 image", &Runtime.instance(p, &1)},
        {"instance/2 an image's program",
         &Runtime.instance(p, %{Runtime.retained(p, s) | program: &1})},
        {"cycle/3 a key", &Runtime.cycle(rt, 0, %{&1 => 1})},
        {"cycle/3 a value", &Runtime.cycle(rt, 0, %{"eye_1" => &1})},
        {"get/2", &Runtime.get(rt, &1)},
        {"get!/2", &Runtime.get!(rt, &1)},
        {"Edit.accept/3 the running program's name", &Logex.Edit.accept(%{p | name: &1}, p, s)},
        {"Edit.accept/3 the candidate's name", &Logex.Edit.accept(p, %{p | name: &1}, s)},
        {"IO.bind!/2 a device's name", &Logex.IO.bind!(c, %{&1 => Sim})},
        {"IO.bind!/2 an adapter's options", &Logex.IO.bind!(c, %{"panel" => {Sim, &1}})},
        {"Sim.set/3 a value", &Sim.set(elem(Sim.start_link(), 1), [0], &1)},
        {"Sim.set/3 an address", &Sim.set(elem(Sim.start_link(inputs: 2), 1), &1, 1)},
        {"Sim.start_link/1 inputs", &Sim.start_link(inputs: &1)}
      ] ++
        for(
          {field, call} <- fielded(s, &Runtime.call(p, &1, %{}, scan)),
          do: {"call/4 state.#{field}", call}
        ) ++
        for(
          {field, call} <- fielded(scan, &Runtime.call(p, s, %{}, &1)),
          do: {"call/4 scan.#{field}", call}
        ) ++
        for(
          {field, call} <- fielded(p, &Runtime.instance/1),
          do: {"instance/1 program.#{field}", call}
        ) ++
        for({field, call} <- fielded(c, checked), do: {"check/1 configuration.#{field}", call}) ++
        for(
          {field, call} <- fielded(global, &checked.(%{c | globals: [&1 | tl(c.globals)]})),
          do: {"check/1 global.#{field}", call}
        ) ++
        for(
          {field, call} <- fielded(hd(c.instances), &checked.(%{c | instances: [&1]})),
          do: {"check/1 instance.#{field}", call}
        ) ++
        for(
          {field, call} <- fielded(hd(c.connections), &checked.(%{c | connections: [&1]})),
          do: {"check/1 connection.#{field}", call}
        ) ++
        for(
          {field, call} <- fielded(task, &checked.(%{c | tasks: [&1]})),
          do: {"check/1 task.#{field}", call}
        )
    end

    # One call in a process of its own, which a sim or a runner it starts is linked to.
    defp outcome(call, value) do
      {pid, ref} =
        spawn_monitor(fn ->
          Process.flag(:trap_exit, true)
          exit({:told, told(call, value)})
        end)

      receive do
        {:DOWN, ^ref, :process, ^pid, {:told, outcome}} -> outcome
      after
        60_000 -> {:no_answer, Process.exit(pid, :kill)}
      end
    end

    defp told(call, value) do
      call.(value)
      :taken
    rescue
      error -> {error.__struct__, Exception.message(error)}
    end

    # A refusal's bound, 5,000 bytes, and one of a text of 100,000 bytes twice that: a value
    # that holds the text shows its first 4,096 bytes, as `inspect/1` does, beside the rest
    # of the value, `compile/2`'s map of types among them (decisions 585 and 613).
    defp longest(:long_text), do: 10_000
    defp longest(_kind), do: 5_000

    test "every refusal an ArgumentError whose message is short text", ctx do
      outcomes =
        for {label, call} <- callers(ctx), {kind, value} <- hostile(ctx.big) do
          {label, kind, outcome(call, opaque(value))}
        end

      refused =
        for {label, kind, {ArgumentError, message}} <- outcomes, do: {label, kind, message}

      for {label, kind, message} <- refused do
        assert {label, kind, String.valid?(message)} == {label, kind, true}
        assert {label, kind, byte_size(message) < longest(kind)} == {label, kind, true}
      end

      escaped =
        for {label, kind, {module, _message}} <- outcomes,
            module != ArgumentError,
            into: %{},
            do: {{label, kind}, module}

      assert escaped == @outside

      # Its reach: every caller refuses some hostile value, and most of what it is given.
      refusing = MapSet.new(for {label, _kind, _message} <- refused, do: label)
      callers = MapSet.new(for {label, _call} <- callers(ctx), do: label)
      assert MapSet.difference(callers, refusing) == MapSet.new(@unread)
      assert length(refused) > 500
    end
  end

  describe "a check that succeeds builds no refusal's text" do
    # Since RV-32's review a name a refusal quotes is looked at, whether it is UTF-8
    # text, which a refusal pays and a check that succeeds should not: so
    # `Logex.Configuration`'s checks of what a configuration says, `of_word/2` and
    # `counted/2`, take their message as a function, called only where it is told. Read
    # from its syntax tree: each call's message is an `fn`.
    # A clause's head is no call: its body is walked, its head passed over, a guard's too.
    defp messages({:defp, meta, [{:when, _, [{name, _, _} | _]} | body]}, acc)
         when name in [:of_word, :counted],
         do: {{:defp, meta, body}, acc}

    defp messages({:defp, meta, [{name, _, _} | body]}, acc) when name in [:of_word, :counted],
      do: {{:defp, meta, body}, acc}

    defp messages({name, meta, [_said, message]} = node, acc) when name in [:of_word, :counted],
      do: {node, [{name, meta[:line], match?({:fn, _, _}, message)} | acc]}

    defp messages(node, acc), do: {node, acc}

    test "Logex.Configuration's checks take their message as a function" do
      {:ok, ast} = Code.string_to_quoted(File.read!("lib/logex/configuration.ex"))
      {_ast, calls} = Macro.prewalk(ast, [], &messages/2)

      calls =
        for {name, line, lazy} <- calls, name in [:of_word, :counted], do: {name, line, lazy}

      assert length(calls) >= 10
      assert for({name, line, false} <- calls, do: {name, line}) == []
    end
  end

  describe "a refusal of a huge value costs no more than a small one's and the cut's" do
    # Counted in reductions, the least of three, a refusal of 10 ** 1_000_000 and of a
    # list of a million elements against one of -7, in the same run, each bound the small
    # refusal's cost and twice the cut's own of the same value: whatever else a refusal
    # does, it does not grow with the value. Before decision 586 each made the number's
    # text whole, some 9 s at a million digits.
    defp cost(fun) do
      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    defp refused(fun) do
      %ArgumentError{message: message} = catch_error(fun.())
      message
    end

    test "a sample across the host contract's modules", %{c: c, s: s} do
      o = &opaque/1
      huge = 10 ** 1_000_000
      long = Enum.to_list(1..1_000_000)

      sample = [
        {"Logex.compile/2", &Logex.compile(o.(&1), name: "p")},
        {"Logex.Configuration.new!/1", &Configuration.new!(o.(&1))},
        {"Logex.Configuration.new!/1, an element's line",
         &Configuration.new!(name: "c", globals: [%Global{name: "g", type: :bool, line: o.(&1)}])},
        {"Logex.Configuration.compile/3", &Configuration.compile("c", o.(&1), %{})},
        {"Logex.Configuration.compile_file/1", &Configuration.compile_file(o.(&1))},
        {"Logex.Configuration.initial/1",
         &Configuration.initial(%Global{name: "g", type: :bool, initial: o.(&1)})},
        {"Logex.Configuration.watchdog/1",
         &Configuration.watchdog(%Task{name: "t", interval: 10, watchdog: o.(&1)})},
        {"Logex.Runtime.instance/1", &Runtime.instance(o.(&1))},
        {"Logex.Runtime.start/1", &Runtime.start(o.(&1))},
        {"Logex.Edit.test/2", &Logex.Edit.test(o.(&1), s)},
        {"Logex.IO.bind!/2", &Logex.IO.bind!(c, o.(&1))},
        {"Logex.Runner.start_link/1",
         &Runner.start_link(configuration: c, io: %{}, clock: o.(&1))},
        {"Logex.IO.Sim.start_link/1", &Sim.start_link(o.(&1))},
        {"Logex.Tag.new!/5", &Logex.Tag.new!("g", :bool, :var, nil, o.(&1))}
      ]

      cut = cost(fn -> Logex.Lexer.inspected(huge) end)
      listed = cost(fn -> Logex.Lexer.inspected(long) end)

      for {name, refuse} <- sample do
        small = cost(fn -> catch_error(refuse.(-7)) end)

        for {value, own} <- [{huge, cut}, {long, listed}] do
          spent = cost(fn -> catch_error(refuse.(value)) end)

          assert spent <= small + 2 * own,
                 "#{name}: #{spent} reductions, against #{small} and the cut's #{own}"

          # A list as `inspect/1` shows one, to its limit of 200 elements.
          assert byte_size(refused(fn -> refuse.(value) end)) < 1_200, name
        end
      end
    end
  end

  describe "lib/ shows a value only through the one cut" do
    # Every `inspect/1,2` lib/ calls, by its syntax trees: none but the cut's own, in
    # `Logex.Lexer.inspected/2`, so that a refusal written from now on quotes a value
    # through it or is red here, outside the host contract too (decision 611). Since
    # RV-32's review, F7: only `Logex.Lexer`'s own `inspected` is passed over, and
    # `inspect` reached through `apply/3`, `Function.capture/3` or the `Inspect`
    # protocol's modules is found as a call of it is.
    @lexer "lib/logex/lexer.ex"

    defp inspects({:def, _, [{:inspected, _, _} | _]}, acc, @lexer), do: {nil, acc}

    defp inspects({:inspect, meta, args} = node, acc, file) when is_list(args),
      do: {node, [{file, meta[:line]} | acc]}

    defp inspects({{:., _, [Kernel, :inspect]}, meta, _args} = node, acc, file),
      do: {node, [{file, meta[:line]} | acc]}

    defp inspects(
           {{:., _, [{:__aliases__, _, [:Kernel]}, :inspect]}, meta, _args} = node,
           acc,
           file
         ),
         do: {node, [{file, meta[:line]} | acc]}

    defp inspects(
           {{:., _, [{:__aliases__, _, [:Inspect | _]}, _fun]}, meta, _args} = node,
           acc,
           file
         )
         when file != @lexer,
         do: {node, [{file, meta[:line]} | acc]}

    defp inspects({:/, _, [{:inspect, meta, context}, arity]} = node, acc, file)
         when is_atom(context) and is_integer(arity),
         do: {node, [{file, meta[:line]} | acc]}

    defp inspects({call, meta, args} = node, acc, file) when is_list(args) and call != :.,
      do: {node, applied(Enum.any?(args, &kernel?/1) and :inspect in args, meta, acc, file)}

    defp inspects(node, acc, _file), do: {node, acc}

    defp kernel?({:__aliases__, _, [:Kernel]}), do: true
    defp kernel?(Kernel), do: true
    defp kernel?(_arg), do: false

    defp applied(true, meta, acc, file), do: [{file, meta[:line]} | acc]
    defp applied(false, _meta, acc, _file), do: acc

    defp found(source, file) do
      {:ok, ast} = Code.string_to_quoted(source)
      {_ast, found} = Macro.prewalk(ast, [], &inspects(&1, &2, file))
      found
    end

    test "no inspect/1 in lib/ but Logex.Lexer.inspected/2's" do
      called =
        for file <- Path.wildcard("lib/**/*.ex"),
            hit <- found(File.read!(file), file),
            do: hit

      assert called == []

      # The cut's own call is there, and the walk would find a call outside it.
      assert found(File.read!(@lexer), @lexer) == []

      assert File.read!(@lexer) =~
               "do: inspect(value, [inspect_fun: &inspected_part/2] ++ options)"

      for {planted, source} <- [
            {"called", "def f(x), do: raise(ArgumentError, inspect(x))"},
            {"captured", "Enum.map(xs, &inspect/1)"},
            {"remote", "def f(x), do: Kernel.inspect(x)"},
            {"applied", "def f(x), do: apply(Kernel, :inspect, [x])"},
            {"applied by Erlang", "def f(x), do: :erlang.apply(Kernel, :inspect, [x])"},
            {"captured by name", "def f, do: Function.capture(Kernel, :inspect, 1)"},
            {"the protocol", "def f(x), do: Inspect.inspect(x, %Inspect.Opts{})"},
            {"an algebra", "def f(x), do: Inspect.Algebra.to_doc(x, %Inspect.Opts{})"}
          ] do
        assert {planted, [{planted, 1}]} == {planted, found(source, planted)}
      end

      # Another module's own `inspected` is no cut: only the lexer's is passed over.
      assert [{"other", 1}] ==
               found("def inspected(x), do: inspect(x)", "other")
    end
  end
end
