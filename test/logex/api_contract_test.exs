defmodule Logex.ApiContractTest do
  @moduledoc """
  M1-5's contract, over seeded random programs and random host calls. A mistake in the
  source is a returned diagnostic; a mistake by the host is an `ArgumentError` whose
  message is one of the documented kinds; a call without one is accepted; and nothing else
  ever escapes. The seed is fixed, so a failure reproduces.

  A property pins only what its generator reaches, so each test asserts its reach: every
  stage's diagnostics, and every kind of refusal a host can cause.

  M1-6: the programs hold timers, one-shots, members and comparisons. Every accepted scan
  is checked against an oracle for `ton` and `ons`, and every accepted call is made twice
  and must give the same result, since the runtime is a pure function of its arguments.
  A timer's invariants hold right after its `ton` runs, and a member written below the
  `ton` takes effect at the next scan, so the generated `ton` comes last: at the end of the
  scan the oracle sees the timer as its `ton` left it. The reach assertions cover every
  M1-6 diagnostic and warning, and what a timer and a one-shot do.

  OE-1: a third walk takes online edits (`Logex.Edit`) between its scans, the candidates
  drawn from one vocabulary so that two programs share their names, and now and then
  swaps a program without an edit (a plain swap), so a state holds what does not fit.
  Every host mistake it makes is refused with a documented message, and every step it may
  take is accepted, made twice and gives the same result. The writes each report lists,
  applied to the state before the step, give the state after it, and each kind of entry is
  checked against the rule restated from the two programs' text. Each held output is
  checked independently of the edit too: one the program that runs next does not show
  against the host's own image of its outputs, the latest value each scan gave it, and
  one it still shows against what its next scan gives, unless a restart comes first. Its
  reach covers every report kind, every refusal and every oracle.

  Its timers (decision 23, fixes F1 and F6): each switch's `.pre`, `.dn` forecasts and
  resumes are checked against the rules restated from the text, with the walk's own
  record of what the edit's last switch left and found. Three oracles do not restate
  those rules: no scan but a plain swap's lets a timer gain more than the scan's own time,
  as one caught up after a switch would (§4.9's Resume rule); the scan right after a
  switch does to `.dn` what the switch forecast; and a test then an untest with no scan
  between leaves the original's tags as they were, a timer the test resumed included, but
  for what either switch started, found from the two programs' text and the state and
  never from the reports, and its next scan's outputs with them (fixes F1 and F11). Right
  after a switch that resumed a timer, the walk often switches back at once, and now and
  then restarts first, which starts the timer again, so that the switch back must give
  no resume back.

  Its one-shots (decision 21, fixes F2, F3 and F7): each switch's block list is checked
  against the rule restated from the text, with the walk's own record of which side of
  the edit last scanned and what an earlier edit left pending. Two oracles do not restate
  it (F11): a one-shot pulses only if the previous scan ran the same `ons` rung text with
  its condition 0, which the rung writes to a tag of its own, wherever the program scanned
  writes the bit through its `ons` alone; and the round trip leaves the block list as it
  found it too, but before a first scan, which blocks every `ons`. Now and then a host
  finalises an edit at one boundary and takes another before any scan, so a block is
  still pending.

  M2-1: a fourth walk runs configurations as resources, through `start/1`, `cycle/3`,
  `get/2`, `next_due_in/1`, `overlaps/1` and `restart/2`. Every accepted cycle is checked
  against a model that restates the scheduler's rules and scans each instance through
  `call/4` alone, and against an oracle that knows nothing of how due tasks are found:
  every period of a task up to now is either run or counted as missed. Every host mistake
  is refused with a documented message, a configuration started with one mistake is
  refused whether the mistake is the host's or one a text could make, and every accepted
  call is made twice and gives the same result. Its reach covers every refusal and what
  the scheduler must be seen to do.

  M2-5: a fifth walk takes online edits of programs that hold user function blocks, a
  block inside a block among them, drawn from versions that change a block's body, add
  and drop its members and timers, and change a member's kind, which accept refuses. Its
  oracles: the writes each report lists, applied by path, rebuild the state; a switch
  leaves every member of the program it starts present at every depth, and a prune none
  but the kept program's; a test then an untest with no scan between gives back every
  value neither switch started, a timer's `last` included, found from the reports' starts
  alone; and on any scan that runs a one-shot one or two levels down, whose chain of rungs,
  from the program's `cal` to the body's `ons` rung, differs in its text from the one it
  last ran under, the one-shot passes no power: on the scan right after a switch, or on a
  later one, where its instance's `cal` was false until then (decision 32).
  """
  use ExUnit.Case, async: true

  alias Logex.{Diagnostic, Edit, Instance, Program, Runtime, Scan, Tag}

  @words ~w(var var_input var_output bool dint xic xio ote otl otu move a b c start stop Motor) ++
           ~w(ton ons eq ne lt gt le ge t1 t1.dn t1.acc t1.pre t1.zz t1.et a.b s1 n d.3) ++
           ["(", "|", ")", "0", "1", "7", "1200", "3000000000", "retain", "\n", "\n"]

  # Words that are lex errors: in a soup they end the compile at the lexer.
  @lex_errors ["@", "1bst"]

  # Declaration mistakes a soup of words almost never assembles.
  @declaration_mistakes [
    "var ( xic a ) bool",
    "var d ( xic a )",
    "var e bool ( xic a )",
    "var a bool",
    "var retain r bool",
    "var bool dint",
    "var f bool 7",
    "var g dint 3000000000",
    "var h bool 1 2",
    "var_input i bool 0",
    "var t2 ton 5",
    "var_output t3 ton",
    "var ton",
    "var t4.x bool"
  ]

  # M1-6 rung mistakes, one or more for each diagnostic in @m16_diagnostics, which a soup of
  # words rarely assembles: most need a declared timer, which a soup declares half the time.
  @rung_mistakes [
    "xic a ton t1 5 ton t1 6",
    "ote t1.dn",
    "xic t1.zz ote a",
    "xic a.b ote a",
    "xic d.3 ote a",
    "move t1.acc.x n",
    "move t1 n",
    "xic a ton t1 n",
    "ton t1 3000000000",
    "ton a 5",
    "eq a n ote a",
    "gt n 3000000000 ote a",
    "xic t9.dn ote a",
    "xic a ton t1 5 ote a",
    "xic a ons s1 ote b\nxio a ons s1"
  ]

  # M1-6's diagnostics, by a fragment of each, that the compile test must reach.
  @m16_diagnostics [
    "is already run by the `ton`",
    "but logic may write only",
    "is not a member of",
    "only an instance of a function block has members",
    "bit access is not supported yet",
    "goes too deep",
    "name one of its members",
    "takes its preset as a number",
    "takes a preset of 0 to",
    "`ton` runs a ton, but",
    "`eq` reads a dint, but",
    "`gt` reads a dint: `3000000000`",
    "`t9` is not declared",
    "follows `ton t1` on its path",
    "is already the storage bit of the `ons`",
    "not an initial value on its declaration",
    "an instance is the program's own",
    "needs a tag name before the type `ton`"
  ]

  # And its warnings, which only a program that compiles gets.
  @m16_warnings [
    "compares two literals",
    "the storage bit of the `ons`",
    "no `ton` runs it"
  ]

  @junk [
    0,
    1,
    2,
    -1,
    1.0,
    nil,
    true,
    :x,
    "s",
    [],
    %{},
    {1},
    <<255>>,
    2_147_483_648,
    %Scan{now: 0, first: true}
  ]

  # A var_input's values either side of its type's edges.
  @edges %{
    bool: [0, 1, 0, 1, 2, 1.0, true],
    dint: [0, -2_147_483_648, 2_147_483_647, -2_147_483_649, 2_147_483_648, 1.0, %{}]
  }

  # The documented kinds of refusal, by their first words. A scan's block list, which only
  # the runtime fills in (OE-1), is a kind of its own, so the walk is seen to reach it.
  @refusals [
    "input ",
    "inputs must be",
    "scan.ons_blocked",
    "scan.",
    "state.",
    "time went backwards",
    "expected a %Logex.",
    "elapsed_ms must be",
    "restart takes",
    "this state is an instance"
  ]

  # What the M1-6 oracle must see a timer and a one-shot do, at least once each.
  @behaviours [:idle, :timing, :done, :clamped, :negative_preset, :fired, :held_first]

  setup do
    :rand.seed(:exsss, {2026, 9, 29})
    :ok
  end

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # A third of the time a well-formed program, so the success path and its warnings are
  # reached. Otherwise a soup of words after the declarations, one of them malformed: a soup
  # that lexes and parses reaches validation, and one with a lex-error word ends at the
  # lexer. The compile test asserts that every stage is reached.
  defp source, do: source(:rand.uniform(3))

  defp source(1) do
    inputs = Enum.filter(~w(start stop), fn _ -> :rand.uniform(2) == 1 end)
    bools = inputs ++ ~w(a b c)
    # Half the programs time and one-shot on `go`, a third of those also moving into the
    # timer's members; and a third carry one of the M1-6 warnings' cases. A timed program
    # has the dint input, which it moves into its timer's .pre.
    timed? = :rand.uniform(2) == 1
    dint_input = Enum.filter(["var_input sp dint"], fn _ -> timed? or :rand.uniform(2) == 1 end)
    members? = timed? and :rand.uniform(3) == 1
    warned = if :rand.uniform(3) == 1, do: [pick(warned())], else: []

    declarations =
      Enum.map(inputs, &"var_input #{&1} bool") ++
        dint_input ++
        Enum.map(~w(a b c), &"#{pick(~w(var var_output))} #{&1} bool") ++
        ["var_output n dint 7"] ++
        if(timed?,
          do: [
            "var_input go bool",
            "var t1 ton",
            "var s1 bool",
            "var_output p bool"
          ],
          else: []
        ) ++
        Enum.flat_map(warned, &elem(&1, 0))

    outputs =
      ["ote #{pick(~w(a b c))}", "otl #{pick(~w(a b c))}", "otu a", "move 5 n", "move 1 b"] ++
        ["( xic a | ) ote c", "eq n 7 ote b", "lt n #{pick([5, 7, 9])} ote c"] ++
        if(timed?, do: ["ge t1.acc #{pick([0, 5, 20])} ote c", "xic t1.dn ote b"], else: [])

    rungs =
      for _ <- 1..:rand.uniform(5) do
        contacts =
          Enum.map_join(1..:rand.uniform(3), " ", fn _ ->
            "#{pick(~w(xic xio))} #{pick(bools)}"
          end)

        "#{contacts} #{pick(outputs)}"
      end

    moves = Enum.map(dint_input, fn _ -> "xic a move sp n" end)

    # A dint input moved into .pre while `go` is off, so while the timer is reset, keeps the
    # exact oracle below true; it may be negative, which times as 0.
    member_moves =
      if(members?, do: ["xic a move #{pick([3, 50])} t1.pre", "xic b move 0 t1.acc"], else: []) ++
        if timed?, do: ["xio go move sp t1.pre"], else: []

    # The one-shot and the timer come last, so the oracle sees them as they left them: a
    # timer's invariants hold right after its `ton` runs. Nothing follows the `ton`.
    timing =
      if timed?,
        do: ["xic go ons s1 ote p", "xic go ton t1 #{pick([0, 10, 25, 5000])}"],
        else: []

    Enum.join(
      declarations ++
        rungs ++ moves ++ Enum.flat_map(warned, &elem(&1, 1)) ++ member_moves ++ timing,
      "\n"
    )
  end

  defp source(2), do: soup(@words)
  defp source(3), do: soup(@words ++ @lex_errors)

  # Programs that compile with an M1-6 warning: declarations, then rungs.
  defp warned,
    do: [
      {[], ["eq 1 #{pick([1, 2])} ote c"]},
      {["var s2 bool"], ["xic a ons s2 ote b", "xio a ote s2"]},
      {["var t2 ton"], ["xic t2.dn ote c"]}
    ]

  defp soup(words) do
    lines =
      for _ <- 1..:rand.uniform(6) do
        Enum.map_join(1..:rand.uniform(7), " ", fn _ -> pick(words) end)
      end

    declarations =
      for name <- ~w(a b c start stop), :rand.uniform(3) > 1 do
        "#{pick(~w(var var_input var_output))} #{name} #{pick(~w(bool bool dint))}"
      end ++
        Enum.filter(["var t1 ton", "var s1 bool", "var n dint", "var d dint"], fn _ ->
          :rand.uniform(2) == 1
        end)

    mistakes = [pick(@declaration_mistakes)] ++ lines ++ [pick(@rung_mistakes)]
    Enum.join(declarations ++ mistakes, "\n")
  end

  # Its draws are sized from the rate of its rarest diagnostics, "goes too deep", "is
  # already run by the `ton`" and "is already the storage bit of the `ons`", each given for
  # about one source in 120 over the seeds {n, 77, 7}, n from 1 to 60. At 600 sources a
  # run, 4 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and {7, n, 2026}, n to 100,
  # missed one. At 2,000 each is expected more than 15 times a run, and the reach holds at
  # this seed and, in its place, at each of {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n from
  # 1 to 100, every fragment given for 7 sources a run or more.
  test "compile/2 never raises for any source, and its diagnostics are in line order" do
    results = for _ <- 1..2000, do: Logex.compile(source(), name: "p")

    reached =
      for result <- results, into: MapSet.new() do
        case result do
          {:ok, %Program{name: "p", warnings: warnings}} ->
            assert warnings == Enum.sort_by(warnings, & &1.line)
            :ok

          {:error, [%Diagnostic{stage: stage} | _] = diagnostics} ->
            assert Enum.all?(
                     diagnostics,
                     &match?(%Diagnostic{line: line} when is_integer(line) and line > 0, &1)
                   )

            assert diagnostics == Enum.sort_by(diagnostics, & &1.line)
            stage
        end
      end

    assert reached == MapSet.new([:ok, :lex, :parse, :validate])

    errors = for {:error, diagnostics} <- results, d <- diagnostics, do: d.message
    warnings = for {:ok, program} <- results, w <- program.warnings, do: w.message

    for {fragment, messages} <-
          Enum.map(@m16_diagnostics, &{&1, errors}) ++ Enum.map(@m16_warnings, &{&1, warnings}) do
      assert Enum.any?(messages, &String.contains?(&1, fragment)),
             "no source reached the message containing #{inspect(fragment)}"
    end
  end

  # Its draws are sized from the rate of its rarest behaviour, a clamped timer, seen in
  # about one program in nine over the seeds {n, 77, 7}, n from 1 to 60. At 40 programs a
  # run, 4 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and {7, n, 2026}, n to 100,
  # missed one atom: a clamped timer, a negative preset or the "scan.ons_blocked" refusal.
  # At 150 a clamped timer is expected more than 15 times a run, and the reach holds at
  # this seed and, in its place, at each of {n, 77, 7}, {n, 1, 1} and {7, n, 2026}, n from
  # 1 to 100, every atom reached by 5 programs a run or more.
  test "the runtime refuses every host mistake with a documented ArgumentError, accepts " <>
         "every call without one, and nothing else escapes" do
    programs =
      Stream.repeatedly(fn -> Logex.compile(source(), name: "p") end)
      |> Stream.flat_map(fn
        {:ok, program} -> [program]
        {:error, _} -> []
      end)
      |> Enum.take(150)

    assert length(programs) == 150
    assert Enum.any?(programs, &match?(%{tags: %{"sp" => %Tag{section: :var_input}}}, &1))
    assert Enum.any?(programs, &match?(%{tags: %{"t1" => %Tag{type: %Logex.FbType{}}}}, &1))
    assert Enum.any?(programs, &String.contains?(&1.source, "move 0 t1.acc"))

    for program <- programs do
      # Another program's instance, for the owner check.
      {:ok, other} = Logex.compile(program.source, name: "q")
      walk(program, Runtime.instance(other), Runtime.instance(program), steps(program))
    end

    # "state." is left out: only an instance edited by hand, outside the contract, gets it.
    assert Process.get(:refused, MapSet.new()) == MapSet.new(@refusals -- ["state."])
    assert Process.get(:behaviours, MapSet.new()) == MapSet.new(@behaviours)
  end

  # A timed program walks longer, so a timer is seen through its edges: a preset set while
  # it is reset and then timed, a gap long enough to clamp.
  defp steps(%Program{tags: %{"go" => _}}), do: 90
  defp steps(_program), do: 30

  # Random operations on one instance. Each says whether it is a host mistake, and the
  # runtime must agree: refuse it if so, accept it if not.
  defp walk(_program, _other, _state, 0), do: :ok

  defp walk(program, other, state, n) do
    {mistake?, call} = operation(program, other, state)

    case attempt(call) do
      {:ok, %Instance{} = next} ->
        refute mistake?, "a host mistake was accepted"
        assert next.now >= state.now
        walk(program, other, next, n - 1)

      :refused ->
        assert mistake?, "a call without a host mistake was refused"
        walk(program, other, state, n - 1)
    end
  end

  defp operation(program, other, state), do: operation(:rand.uniform(7), program, other, state)

  defp operation(1, program, _other, state) do
    inputs = inputs(program)
    {bad_inputs?(program, inputs), fn -> Runtime.put_inputs(program, state, inputs) end}
  end

  defp operation(2, program, _other, state) do
    elapsed = pick([0, 0, 5, 10, 25, 5000, 10_000_000_000, -1, 1.5, nil])

    {not (is_integer(elapsed) and elapsed >= 0),
     fn -> scanned(program, state, %{}, Runtime.scan(program, state, elapsed)) end}
  end

  defp operation(3, program, _other, state) do
    inputs = inputs(program)

    scan = %Scan{
      now: state.now + pick([0, 3, 10, 4990, 10_000_000_000, -1]),
      first: pick([state.first, state.first, not state.first])
    }

    {bad_inputs?(program, inputs) or scan.now < state.now or scan.first != state.first,
     fn -> scanned(program, state, inputs, Runtime.call(program, state, inputs, scan)) end}
  end

  defp operation(4, program, _other, state) do
    mode = pick([:cold, :warm, :hot])
    {mode == :hot, fn -> Runtime.restart(program, state, mode) end}
  end

  defp operation(5, program, other, state) do
    args = [
      pick([program, :x, %{}]),
      pick([state, other, %{}, nil]),
      pick([%{}, [], nil]),
      pick([
        %Scan{now: state.now, first: state.first},
        %Scan{now: state.now, first: state.first, ons_blocked: ["s1"]},
        0,
        nil
      ])
    ]

    {args != [program, state, %{}, %Scan{now: state.now, first: state.first}],
     fn -> scanned(program, state, %{}, apply(Runtime, :call, args)) end}
  end

  # The other entry points, given a bad program, state or inputs map.
  defp operation(6, program, other, state) do
    p = pick([program, program, :x, nil])
    s = pick([state, state, other, nil, %{}])
    inputs = pick([%{}, %{}, [], nil])

    case :rand.uniform(4) do
      1 ->
        {p != program, fn -> kept(Runtime.instance(p), state) end}

      2 ->
        {[p, s, inputs] != [program, state, %{}], fn -> Runtime.put_inputs(p, s, inputs) end}

      3 ->
        {[p, s] != [program, state], fn -> scanned(program, state, %{}, Runtime.scan(p, s)) end}

      4 ->
        {[p, s] != [program, state], fn -> Runtime.restart(p, s, :cold) end}
    end
  end

  # M1-6: a timed program's `go` held or dropped, so its timer and one-shot run often.
  # Dropping `go` often sets a new preset for `xio go move sp t1.pre`, sometimes negative.
  defp operation(7, %Program{tags: %{"go" => _} = tags} = program, _other, state) do
    inputs = go(pick([1, 1, 0]), Map.has_key?(tags, "sp"))
    {false, fn -> Runtime.put_inputs(program, state, inputs) end}
  end

  defp operation(7, program, other, state), do: operation(1, program, other, state)

  defp go(0, true), do: %{"go" => 0, "sp" => pick([-5, -5, 40])}
  defp go(go, _sp?), do: %{"go" => go}

  # A new instance is checked and set aside: the walk goes on with its own.
  defp kept(%Instance{now: 0, first: true}, state), do: state

  # The contract's own words: only a declared var_input, a bool 0 or 1, a dint in 32 bits.
  defp bad_inputs?(program, inputs), do: Enum.any?(inputs, &bad_input?(program.tags, &1))

  defp bad_input?(tags, {key, value}), do: not fits?(Map.get(tags, key), value)

  defp fits?(%Tag{section: :var_input, type: :bool}, value), do: value in [0, 1]

  defp fits?(%Tag{section: :var_input, type: :dint}, value),
    do: is_integer(value) and value in -2_147_483_648..2_147_483_647//1

  defp fits?(_tag, _value), do: false

  defp scanned(program, {outputs, %Instance{} = state}) do
    var_outputs = for {name, %{section: :var_output}} <- program.tags, do: name
    assert Enum.sort(Map.keys(outputs)) == Enum.sort(var_outputs)
    assert Enum.all?(Map.values(outputs), &is_integer/1)
    state
  end

  # A scan whose state before it is known: the M1-6 oracle, then the checks above.
  defp scanned(program, before, inputs, {outputs, %Instance{} = later} = result) do
    timed(program, before, Map.merge(before.env, inputs), outputs, later)
    scanned(program, result)
  end

  defp timed(%Program{tags: %{"go" => _}} = program, before, env, outputs, later) do
    go = env["go"]

    # ons: power once a rise is seen, never on the first scan; the bit follows `go`.
    fires = go == 1 and before.env["s1"] == 0 and not before.first
    assert outputs["p"] == if(fires, do: 1, else: 0)
    assert later.env["s1"] == go
    behaviour(:fired, fires)
    behaviour(:held_first, before.first and go == 1)

    # ton, whose rung is last: the timer as its ton left it, `last` stamped on every run.
    t1 = later.env["t1"]
    assert Enum.sort(Map.keys(t1)) == ~w(acc dn en last pre tt)
    assert t1["en"] == go
    assert t1["last"] == later.now
    timer(go, program, before.env["t1"], t1)
  end

  defp timed(_program, _before, _env, _outputs, _later), do: :ok

  defp timer(1, program, was, t1) do
    limit = max(t1["pre"], 0)
    assert t1["acc"] in 0..limit//1
    assert t1["dn"] == if(t1["acc"] == limit, do: 1, else: 0)
    assert t1["tt"] == 1 - t1["dn"]
    behaviour(if(t1["dn"] == 1, do: :done, else: :timing), true)
    behaviour(:negative_preset, t1["pre"] < 0)
    exact(String.contains?(program.source, "move 0 t1.acc"), was, t1, limit)
  end

  defp timer(0, _program, _was, t1) do
    assert %{"acc" => 0, "dn" => 0, "tt" => 0} = t1
    behaviour(:idle, true)
  end

  # Where no rung writes a member, .acc is exactly the delta formula's: nothing on the scan
  # that first sees the rung true, then the time since the ton last ran, added to .acc
  # floored at 0, and capped.
  defp exact(true, _was, _t1, _limit), do: :ok

  defp exact(false, was, t1, limit) do
    delta = if was["en"] == 1, do: t1["last"] - was["last"], else: 0
    assert t1["acc"] == min(max(was["acc"], 0) + delta, limit)
    behaviour(:clamped, was["acc"] + delta > limit and delta > 1_000_000)
  end

  defp behaviour(_name, false), do: :ok

  defp behaviour(name, true),
    do: Process.put(:behaviours, MapSet.put(Process.get(:behaviours, MapSet.new()), name))

  defp inputs(program) do
    var_inputs = for {name, %Tag{section: :var_input}} <- program.tags, do: name
    names = Map.keys(program.tags) ++ ["zz", "Start", "t1.dn", <<255>>, :start, 7]
    Map.new(1..:rand.uniform(3), fn _ -> pair(:rand.uniform(2), var_inputs, names, program) end)
  end

  # Half the pairs set a var_input near its type's edges, so a good input map is common.
  defp pair(1, [_ | _] = var_inputs, _names, program) do
    name = pick(var_inputs)
    {name, pick(@edges[program.tags[name].type])}
  end

  defp pair(_, _var_inputs, names, _program),
    do: {pick(names), pick([0, 1, 1, 0, 2_147_483_647] ++ @junk)}

  # Records each documented kind of refusal it sees, for the reach assertion. An accepted
  # call is made twice and must give the same result: nothing in the runtime reads a clock
  # or any state but its arguments (docs/organisation.md §4.6).
  defp attempt(fun, refusals \\ @refusals, key \\ :refused) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      kind = Enum.find(refusals, &String.starts_with?(error.message, &1))
      assert kind, "undocumented refusal: #{error.message}"
      reached(key, kind)
      :refused
  end

  defp reached(key, name),
    do: Process.put(key, MapSet.put(Process.get(key, MapSet.new()), name))

  # ---- OE-1: the walk with online edits -------------------------------------------------

  # The refusals an edit gives, and the runtime's that it passes on, by their first words.
  @edit_refusals [
    "expected a %Logex.",
    "the candidate is",
    "this state is an instance",
    "state.",
    "test takes",
    "untest takes",
    "assemble takes",
    "cancel takes"
  ]

  @report_kinds [
    :added,
    :dn_drops,
    :dn_rises,
    :held,
    :initial_changed,
    :input,
    :ons_blocked,
    :preset,
    :preset_kept,
    :pruned,
    :resume_undone,
    :resumed,
    :unread
  ]

  @timer_kinds [:dn_drops, :dn_rises, :preset, :preset_kept, :resume_undone, :resumed]

  # What the walk must see happen, and its oracles check, at least once each.
  @edit_reach [
    :diagnosed,
    :forecast,
    :plain_swap,
    :misfit,
    :stale,
    :initial_started,
    :initial_input,
    :restart_in_edit,
    :second_test,
    :held_point,
    :held_shown,
    :held_shown_scan,
    :assembled,
    :cancelled_accepted,
    :cancelled_untested,
    :pre_followed,
    :pre_outright,
    :pre_frozen,
    :pre_restored,
    :undo_after_restart,
    :resumed_scan,
    :dn_scan,
    :round_trip,
    :round_trip_timer,
    :round_trip_resumed,
    :round_trip_started,
    :round_trip_ons,
    :ons_new,
    :ons_changed,
    :ons_written,
    :ons_untouched,
    :ons_same_side,
    :ons_pending,
    :ons_switch_edge,
    :ons_blocked_edge
  ]

  @allowed %{
    test: [:accepted, :untested],
    untest: [:testing],
    assemble: [:testing],
    cancel: [:accepted, :untested]
  }

  # One vocabulary, so two draws share their names: `start` and `stop` move between
  # var_input and var, `a`, `b` and `c` between var and var_output, `n`'s initial value
  # changes, and `r` and `t1` change type now and then, which a plain swap leaves in the
  # state and an edit refuses. Decision 29's exceptions are reached too: `n` is left out one
  # time in three, so a state can lack it where both programs declare it, and a switch
  # starts it at a changed initial value; and `sp` takes an initial value now and then, and
  # moves between var and var_input, so one whose initial value changes becomes an input.
  # `s1` is a var_output driven by a one-shot's storage bit, and `cn` the one-shot's
  # condition, which the rung writes just before it; `s1` is declared now and then with no
  # `ons` on it, and written now and then by another instruction after the `ons`, as only a
  # program with a warning can.
  defp edit_source do
    inputs = Enum.flat_map(~w(start stop), &declared(&1, pick(~w(var_input var_input var none))))
    sp = pick(["var_input sp dint", "var sp dint", "var sp dint 5", nil])
    bools = Enum.map(~w(a b c), &{&1, pick(~w(var var_output var_output))})
    r = pick([:bool, :dint, nil])
    t1 = pick([:ton, :ton, :bool, nil])
    ons = pick([nil, nil, :tags, :rung, :rung, :written])

    declarations =
      Enum.map(inputs, fn {name, section} -> "#{section} #{name} bool" end) ++
        Enum.reject([sp], &is_nil/1) ++
        Enum.map(bools, fn {name, section} -> "#{section} #{name} bool" end) ++
        Enum.take(["var_output n dint #{pick(["", "7", "9"])}"], pick([0, 1, 1])) ++
        typed("r", r) ++ typed("t1", t1) ++ timer_input(t1) ++ ons_tags(ons)

    writable =
      ~w(a b c) ++
        for({name, "var"} <- inputs, do: name) ++
        for({name, :bool} <- [{"r", r}, {"t1", t1}], do: name)

    readable = writable ++ for({name, "var_input"} <- inputs, do: name) ++ timer_bit(t1)

    rungs =
      for _ <- 1..:rand.uniform(4) do
        "#{pick(~w(xic xio))} #{pick(readable)} #{pick(~w(ote ote otl otu))} #{pick(writable)}"
      end ++
        Enum.filter(["xic #{pick(readable)} move #{pick(["5", "7"] ++ sp_word(sp))} n"], fn _ ->
          :rand.uniform(2) == 1
        end) ++
        moves_into("r", r) ++
        ons_rungs(ons, readable) ++ preset_rung(t1, readable, sp) ++ timer_rung(t1)

    Enum.join(declarations ++ rungs, "\n")
  end

  defp declared(_name, "none"), do: []
  defp declared(name, section), do: [{name, section}]

  defp typed(_name, nil), do: []
  defp typed(name, type), do: ["var #{name} #{type}"]

  defp timer_input(:ton), do: ["var_input go bool"]
  defp timer_input(_t1), do: []

  defp timer_bit(:ton), do: ["t1.dn"]
  defp timer_bit(_t1), do: []

  # A timer no `ton` runs keeps whatever a plain swap left under its name, as a misfit.
  defp timer_rung(:ton),
    do: Enum.take(["xic go ton t1 #{pick([30, 5000])}"], :rand.uniform(3) - 1)

  defp timer_rung(_t1), do: []

  # Logic that changes the timer's `.pre`, so a switch finds one that is not a preset.
  defp preset_rung(:ton, readable, sp),
    do:
      Enum.take(
        ["xic #{pick(readable)} move #{pick(["40", "7"] ++ sp_word(sp))} t1.pre"],
        :rand.uniform(2) - 1
      )

  defp preset_rung(_t1, _readable, _sp), do: []

  defp ons_tags(nil), do: []
  defp ons_tags(_ons), do: ["var_output s1 bool", "var_output p bool", "var cn bool"]

  defp ons_rungs(:rung, readable), do: ["xic #{pick(readable)} ote cn ons s1 ote p"]

  defp ons_rungs(:written, readable),
    do: ons_rungs(:rung, readable) ++ ["xic #{pick(readable)} #{pick(~w(otu otl ote))} s1"]

  defp ons_rungs(_ons, _readable), do: []

  defp sp_word(nil), do: []
  defp sp_word(_sp), do: ["sp"]

  defp moves_into(name, :dint), do: ["move 3 #{name}"]
  defp moves_into(_name, _type), do: []

  defp edit_program do
    case Logex.compile(edit_source(), name: "p") do
      {:ok, program} -> program
      {:error, _} -> edit_program()
    end
  end

  defp variant(%Program{source: source}) do
    {declarations, rungs} = Enum.split_with(String.split(source, "\n"), &(&1 =~ ~r/^var/))
    n = "var_output n dint #{pick(["", "7", "9"])}"
    declarations = Enum.map(declarations, &String.replace(&1, ~r/^var_output n dint.*/, n))
    ton = "ton t1 #{pick([0, 30, 5000])}"
    rungs = Enum.map(drop_one(rungs), &String.replace(&1, ~r/ton t1 \d+/, ton))

    case Logex.compile(Enum.join(declarations ++ rungs, "\n"), name: "p") do
      {:ok, program} -> program
      {:error, _} -> edit_program()
    end
  end

  defp without_ton(%Program{source: source}) do
    lines = Enum.reject(String.split(source, "\n"), &(&1 =~ ~r/ ton t1 /))
    {:ok, program} = Logex.compile(Enum.join(lines, "\n"), name: "p")
    program
  end

  # The running program with a `ton` on its timer, where it declares one and runs none.
  defp with_ton(%Program{source: source} = p),
    do: with_ton(source =~ ~r/^var t1 ton$/m and not (source =~ ~r/ ton t1 /), p)

  defp with_ton(true, %Program{source: source}) do
    {:ok, program} = Logex.compile(source <> "\nxic go ton t1 #{pick([30, 5000])}", name: "p")
    program
  end

  defp with_ton(false, p), do: variant(p)

  defp drop_one([]), do: []
  defp drop_one(rungs), do: List.delete_at(rungs, :rand.uniform(length(rungs)) - 1)

  defp edit_attempt(fun), do: attempt(fun, @edit_refusals, :edit_refused)

  test "an online edit refuses every host mistake with a documented ArgumentError, and " <>
         "each step gives the report its rules and its writes say" do
    :rand.seed(:exsss, {2026, 10, 1})

    # Its rarer cases, a resume undone after a restart or a round trip that resumed a timer,
    # come up a few times a run, so the reach is measured beyond the seeds the draw was
    # tuned on: 200 walks missed an atom at 4 of the seeds 1 to 60, and 400 at none.
    for _ <- 1..400 do
      program = edit_program()
      {:ok, other} = Logex.compile(program.source, name: "q")

      walk = %{
        p: program,
        s: Runtime.instance(program),
        e: nil,
        o: nil,
        c: nil,
        points: %{},
        shows: %{},
        pre: %{},
        timed: [],
        round: nil,
        scanned: nil,
        prev: nil
      }

      edit_walk(Map.put(walk, :other, Runtime.instance(other)), 60)
    end

    assert Process.get(:edit_refused, MapSet.new()) == MapSet.new(@edit_refusals)
    assert Process.get(:kinds, MapSet.new()) == MapSet.new(@report_kinds)
    assert Process.get(:edit_reach, MapSet.new()) == MapSet.new(@edit_reach)
  end

  defp edit_walk(w, 0), do: w
  defp edit_walk(w, n), do: edit_walk(edit_op(op(w, :rand.uniform(12)), w), n - 1)

  # The operation that follows, as the walk or a trial run draws it; but right after a
  # switch that resumed a timer, half the time a scan, which must not catch the timer up; a
  # quarter of the time the switch back with no scan between, which gives the resume back;
  # and a quarter a restart, which starts the timer again, and then the switch back, which
  # then gives nothing back (fix F11). Resumes are rare, and a resume this edit's last
  # switch made is what each of the three needs.
  defp op(%{e: nil}, otherwise), do: otherwise
  defp op(w, otherwise), do: op(Edit.stage(w.e), names(w.timed, :resumed), otherwise)

  defp op(stage, [_ | _], _otherwise) when stage in [:testing, :untested],
    do: pick([1, 1, :back, :restart_back])

  defp op(_stage, _resumed, otherwise), do: otherwise

  defp edit_op(:back, w), do: step(back(Edit.stage(w.e)), w)
  defp edit_op(:restart_back, w), do: edit_op(:back, edit_op(10, w))

  defp edit_op(op, w) when op <= 4, do: edit_scan(w, :running)

  # One candidate in seven is a new program; the rest are the running program changed: with
  # one rung dropped, and `n`'s initial value and the timer's preset redrawn, so the two
  # keep their types, a value a plain swap left is reached, and the timer's `ton` changes
  # its preset; three in seven with its `ton` dropped, so the `ton` goes and comes back
  # while the timer is timing, which its untest resumes; or two in seven with it given
  # back, so a test resumes the timer, where it declares one and runs none (and otherwise
  # as the first). Two times in three a test and an untest with no scan between follow at
  # once, so an untest gives a resume back (fix F11).
  defp edit_op(op, %{e: nil, p: p} = w) when op in [5, 6],
    do:
      pick([&Function.identity/1, &there_and_back/1, &there_and_back/1]).(
        accept(
          pick([
            edit_program(),
            variant(p),
            without_ton(p),
            without_ton(p),
            without_ton(p),
            with_ton(p),
            with_ton(p)
          ]),
          w
        )
      )

  defp edit_op(op, w) when op in 5..9, do: step(pick([:test, :untest, :assemble, :cancel]), w)

  defp edit_op(10, %{p: p, s: s} = w) do
    {:ok, s} = edit_attempt(fn -> Runtime.restart(p, s, :cold) end)
    edit_reach(:restart_in_edit, w.e != nil)
    %{w | s: s, timed: [], round: nil, shows: %{}}
  end

  # A plain swap, within the runtime's contract while no edit is open: a scan of another
  # program over the state. An edit often follows, and is accepted only against a program
  # that has run the state: a variant of it, which keeps its types, so a value the swap
  # left that does not fit is reached; or the program swapped out, whose tags the state
  # still holds.
  defp edit_op(11, %{e: nil, p: old} = w) do
    edit_reach(:plain_swap, true)
    swapped = edit_scan(%{w | p: edit_program()}, :plain_swap)
    candidate = pick([variant(swapped.p), old])
    pick([&edit_op(1, &1), &accept(candidate, &1), &step(:test, accept(candidate, &1))]).(swapped)
  end

  # With an edit open, a trial run: a test, a scan of the candidate, an untest and a scan
  # of the original, each step refused where the stage does not allow it; or a test and an
  # untest with no scan between. A timer whose `ton` the candidate drops is then given it
  # back while it was timing. Or the edit is finalised at one boundary, a test and an
  # assemble, and another taken before any scan, so a one-shot it blocked is still pending
  # (fix F2).
  defp edit_op(11, w), do: pick([&trial/1, &trial/1, &there_and_back/1, &again/1]).(w)

  # A host mistake: a renamed candidate, another program's state, a bad state, something
  # that is not a program or an edit, or an edit given another program's state.
  defp edit_op(12, %{p: p, s: s} = w) do
    {:ok, renamed} = Logex.compile(p.source, name: "q")
    {candidate, step} = {edit_program(), pick([:test, :untest, :assemble, :cancel])}

    {junk, bad} =
      {pick([nil, %{}, renamed.rungs]), pick([%{s | switched: nil}, %{s | now: -1}, nil])}

    not_edit = pick([junk, p])

    calls =
      [
        fn -> Edit.accept(p, renamed, s) end,
        fn -> Edit.accept(p, candidate, w.other) end,
        fn -> Edit.accept(junk, p, s) end,
        fn -> Edit.accept(p, junk, s) end,
        fn -> Edit.accept(p, p, bad) end,
        fn -> apply(Edit, step, [not_edit, s]) end,
        fn -> Edit.running(not_edit) end,
        fn -> Edit.stage(not_edit) end
      ] ++ open_mistakes(w, step, bad)

    assert :refused = edit_attempt(pick(calls))
    w
  end

  defp open_mistakes(%{e: nil}, _step, _bad), do: []

  defp open_mistakes(%{e: edit} = w, step, bad),
    do: [fn -> Edit.test(edit, w.other) end, fn -> apply(Edit, step, [edit, bad]) end]

  defp trial(w) do
    w = step(:untest, edit_op(1, step(:test, w)))
    edit_op(op(w, 1), w)
  end

  defp back(:testing), do: :untest
  defp back(:untested), do: :test

  defp there_and_back(w), do: step(:untest, step(:test, w))

  defp again(w) do
    w = step(:assemble, step(:test, w))
    step(:test, accept(variant(w.p), w))
  end

  # A scan of the program the host runs, with inputs that fit: the host's image of its
  # outputs takes what the scan gives. A plain swap's scan catches a frozen timer up, as
  # it always has, so only another is held to the bound on what a timer gains.
  defp edit_scan(%{p: p} = w, scan) do
    inputs =
      for {name, %Tag{section: :var_input, type: type}} <- p.tags,
          :rand.uniform(2) == 1,
          into: %{},
          do: {name, pick(@edges[type] |> Enum.take(2))}

    elapsed = pick([0, 10, 25, 5000])
    {:ok, s} = edit_attempt(fn -> Runtime.put_inputs(p, w.s, inputs) end)
    {:ok, {outputs, later}} = edit_attempt(fn -> Runtime.scan(p, s, elapsed) end)
    assert Enum.sort(Map.keys(outputs)) == outputs_of(p)
    assert later.switched == false
    timed!(scan, p, s, later, w.timed)
    pulsed!(scan, p, s, later, outputs, w.prev)
    shown_scan!(scan, outputs, w.shows)
    prev = %{rung: ons_line(p), cn: later.env["cn"]}

    %{
      w
      | s: later,
        points: Map.merge(w.points, outputs),
        timed: [],
        round: nil,
        prev: prev,
        shows: %{}
    }
  end

  defp accept(candidate, %{p: p, s: s} = w),
    do: edit_accepted(edit_attempt(fn -> Edit.accept(p, candidate, s) end), candidate, w)

  defp edit_accepted({:ok, {:ok, edit, forecast}}, candidate, %{p: p, s: s} = w) do
    report!(forecast)
    assert {_, _, ^forecast} = Edit.test(edit, s)
    assert Edit.stage(edit) == :accepted and Edit.running(edit) == p
    edit_reach(:forecast, true)
    %{w | e: edit, o: p, c: candidate, pre: %{}, scanned: nil}
  end

  defp edit_accepted({:ok, {:error, diagnostics}}, candidate, %{p: p} = w) do
    assert Enum.all?(diagnostics, &match?(%Diagnostic{stage: :edit, severity: :error}, &1))
    assert Enum.map(diagnostics, & &1.line) == Enum.sort(Enum.map(diagnostics, & &1.line))
    cited = for d <- diagnostics, do: d.message |> String.split("`") |> Enum.at(1)

    retyped =
      for {name, %Tag{type: type}} <- candidate.tags,
          match?(%Tag{}, p.tags[name]) and p.tags[name].type != type,
          do: name

    assert Enum.sort(cited) == Enum.sort(retyped) and retyped != []
    edit_reach(:diagnosed, true)
    w
  end

  defp step(name, %{e: nil, s: s} = w) do
    assert :refused = edit_attempt(fn -> apply(Edit, name, [nil, s]) end)
    w
  end

  defp step(name, %{e: edit, s: s} = w) do
    stage = Edit.stage(edit)
    result = edit_attempt(fn -> apply(Edit, name, [edit, s]) end)
    stepped(name, stage, stage in @allowed[name], result, w)
  end

  defp stepped(_name, _stage, false, result, w) do
    assert result == :refused, "a step at the wrong stage was accepted"
    w
  end

  defp stepped(name, stage, true, {:ok, {next, later, report}}, %{s: before} = w)
       when name in [:test, :untest] do
    report!(report)

    assert later == %{
             before
             | env: rebuilt(before.env, report),
               switched: true,
               ons_blocked: names(report, :ons_blocked)
           }

    to = Edit.running(next)
    switched!(w.p, to, before, later, report, {name, stage})
    held!(w.p, to, report, later, w.points)
    pre = timers!(w.p, to, before, later, report, w.pre)
    scanned = ons!(sides(name, w), before, later, report, w.scanned)
    edit_reach(:second_test, name == :test and stage == :untested)
    round = round_trip!(name, w.round, {w.p, to, stage}, before, later, report)

    timed =
      for {kind, _, _} = entry <- report, kind in [:dn_drops, :dn_rises, :resumed], do: entry

    %{
      w
      | e: next,
        s: later,
        p: to,
        pre: pre,
        timed: timed,
        round: round,
        scanned: scanned,
        shows: shown(report, to)
    }
  end

  defp stepped(:cancel, :accepted, true, {:ok, {program, later, report}}, %{s: before} = w) do
    assert {program, later, report} == {w.o, before, []}
    edit_reach(:cancelled_accepted, true)
    %{w | e: nil, p: program, round: nil}
  end

  defp stepped(name, _stage, true, {:ok, {kept, later, report}}, %{s: before} = w) do
    report!(report)
    dropped = dropped(name, w)
    assert kept == Edit.running(w.e)
    assert later == %{before | env: rebuilt(before.env, report)}
    assert Enum.sort(Map.keys(later.env)) == Enum.sort(Map.keys(kept.tags))

    assert for({:pruned, tag, value} <- report, do: {tag, value}) ==
             Enum.sort(
               for {tag, value} <- before.env, not Map.has_key?(kept.tags, tag), do: {tag, value}
             )

    held!(dropped, kept, report, before, w.points)
    edit_reach(pruned(name), true)
    %{w | e: nil, s: later, p: kept, round: nil, shows: shown(report, kept)}
  end

  defp dropped(:assemble, w), do: w.o
  defp dropped(:cancel, w), do: w.c

  defp pruned(:assemble), do: :assembled
  defp pruned(:cancel), do: :cancelled_untested

  defp report!(report) do
    assert report == Enum.sort(report)
    keys = for {kind, name, _detail} <- report, do: {kind, name}
    assert keys == Enum.uniq(keys)

    for {kind, name, _detail} <- report do
      assert kind in @report_kinds and is_binary(name)
      reached(:kinds, kind)
    end
  end

  # The writes a report lists, applied to a state's env.
  defp rebuilt(env, report), do: Enum.reduce(report, env, &write/2)

  defp write({kind, name, value}, env) when kind in [:added, :input],
    do: Map.put(env, name, value)

  defp write({:preset, name, {_from, to}}, env), do: put_in(env, [name, "pre"], to)
  defp write({:resumed, name, gap}, env), do: update_in(env, [name, "last"], &(&1 + gap))
  defp write({:resume_undone, name, gap}, env), do: update_in(env, [name, "last"], &(&1 - gap))
  defp write({:pruned, name, _value}, env), do: Map.delete(env, name)
  defp write(_fact, env), do: env

  # A switch's rules, restated from the two programs: which tags start, at what value,
  # which inputs go live or unread, and which initial values changed.
  defp switched!(from, to, before, later, report, {name, stage}) do
    first_test? = name == :test and stage == :accepted
    initial = Program.initial_env(to)

    started = starts(from, to, before.env, first_test?)
    inputs = var_inputs(to)
    assert names(report, :added) == Enum.sort(started -- inputs)

    assert names(report, :input) ==
             Enum.sort(
               Enum.uniq((inputs -- var_inputs(from)) ++ (started -- (started -- inputs)))
             )

    assert names(report, :unread) == Enum.sort(var_inputs(from) -- inputs)

    for {kind, tag, value} <- report, kind in [:added, :input, :unread] do
      assert value == Map.get(later.env, tag, 0)
      assert kind == :unread or value == entry_value(tag in started, initial, before.env, tag)
    end

    old = Program.initial_env(from)

    changed =
      for {tag, %Tag{type: type}} <- to.tags,
          type in [:bool, :dint],
          match?(%Tag{type: ^type}, from.tags[tag]),
          old[tag] != initial[tag],
          do: tag

    reported = for tag <- changed, tag not in started, tag not in inputs, do: tag

    assert for({:initial_changed, _, _} = entry <- report, do: entry) ==
             Enum.sort(for tag <- reported, do: {:initial_changed, tag, {old[tag], initial[tag]}})

    edit_reach(:initial_started, Enum.any?(changed, &(&1 in started)))
    edit_reach(:initial_input, Enum.any?(changed, &(&1 in inputs and &1 not in started)))

    edit_reach(
      :misfit,
      first_test? and
        Enum.any?(started, &(Map.has_key?(before.env, &1) and Map.has_key?(from.tags, &1)))
    )

    edit_reach(
      :stale,
      first_test? and
        Enum.any?(started, &(Map.has_key?(before.env, &1) and not Map.has_key?(from.tags, &1)))
    )
  end

  # The tags a switch starts at their initial value, from the text and the state: one the
  # state lacks, and at the first test one the candidate adds or whose value does not fit.
  defp starts(from, to, env, first_test?),
    do:
      for(
        {tag, declared} <- to.tags,
        not Map.has_key?(env, tag) or
          (first_test? and
             (not Map.has_key?(from.tags, tag) or not typed_as?(declared, env[tag]))),
        do: tag
      )

  # A tag started holds its initial value; any other the value it held, a section change
  # included (decision 25).
  defp entry_value(true, initial, _env, tag), do: initial[tag]
  defp entry_value(false, _initial, env, tag), do: env[tag]

  defp typed_as?(%Tag{type: :bool}, value), do: value in [0, 1]

  defp typed_as?(%Tag{type: :dint}, value),
    do: is_integer(value) and value in -2_147_483_648..2_147_483_647//1

  defp typed_as?(%Tag{}, %{} = timer), do: Enum.sort(Map.keys(timer)) == ~w(acc dn en last pre tt)
  defp typed_as?(%Tag{}, _value), do: false

  # Decision 20 restated from the text, and F4 checked against the host's own image: a
  # held output is one of either program's outputs that the program stopped (or dropped)
  # wrote, and the program kept does not write as an output. One the program kept shows
  # holds the state's value, and every such one is reported; one it does not show holds
  # what the host last received for it, and is reported only when the edit knows it.
  defp held!(stopped, kept, report, state, points) do
    expected =
      for tag <- Enum.uniq(outputs_of(stopped) ++ outputs_of(kept)),
          writes?(stopped, tag),
          not (tag in outputs_of(kept) and writes?(kept, tag)),
          do: tag

    reported = names(report, :held)
    assert reported -- expected == []
    assert Enum.filter(expected, &(&1 in outputs_of(kept))) -- reported == []

    for {:held, tag, value} <- report do
      held_value(tag in outputs_of(kept), tag, value, state, points)
    end
  end

  defp held_value(true, tag, value, state, _points) do
    assert value == Map.get(state.env, tag, 0)
    edit_reach(:held_shown, true)
  end

  defp held_value(false, tag, value, _state, points) do
    assert Map.fetch(points, tag) == {:ok, value}
    edit_reach(:held_point, true)
  end

  # F4, independently of the edit: a held output the program that runs next still shows is
  # what that program's next scan gives the host, unless a restart comes first.
  defp shown(report, kept),
    do: for({:held, tag, value} <- report, tag in outputs_of(kept), into: %{}, do: {tag, value})

  defp shown_scan!(:running, outputs, shows) do
    assert Map.take(outputs, Map.keys(shows)) == shows
    edit_reach(:held_shown_scan, shows != %{})
  end

  defp shown_scan!(_plain_swap, _outputs, _shows), do: :ok

  defp writes?(program, tag),
    do:
      Regex.match?(
        ~r/(^|\s)((ote|otl|otu|ons) #{tag}|move \S+ #{tag})(\s|$)/m,
        program.source
      )

  # Decision 23 and fixes F1 and F6, restated from the two programs' text: each timer
  # either program declares, as the start rules left it, takes the `.pre` the walk's own
  # record of the edit's last switch, or the presets, say; is reported so; and resumes where it
  # was timing and not run since. Returns the record for the next switch: for each timer,
  # the `.pre` this switch left and the one it found.
  defp timers!(from, to, before, later, report, record) do
    started = rebuilt(before.env, for({k, _, _} = e <- report, k in [:added, :input], do: e))
    timers = Enum.uniq(timers_of(from) ++ timers_of(to))

    {expected, record} =
      Enum.reduce(timers, {[], %{}}, fn tag, {expected, next} ->
        timer!(
          started[tag],
          {tag, ton_of(from, tag), ton_of(to, tag)},
          {later, before.switched},
          record[tag],
          {expected, next}
        )
      end)

    assert for({kind, _, _} = entry <- report, kind in @timer_kinds, do: entry) ==
             Enum.sort(expected)

    record
  end

  # A timer's map may lack members: a plain swap that writes `t1.pre` where the program
  # swapped out held a bool leaves `%{"pre" => 40}`, which no `ton` has run since.
  defp timer!(%{"pre" => pre} = was, {tag, from, to}, {later, switched}, undo, {expected, next}) do
    {how, target} = pre_target(undo, pre, from, to)
    now = later.now
    edit_reach(:undo_after_restart, switched and found?(undo) and was["last"] != now)
    {was, undone} = resume_undone(was, undo, switched, now, tag)
    resumed? = to != nil and was["en"] == 1 and was["last"] < now
    moved = Map.put(was, "pre", target)
    assert later.env[tag] == if(resumed?, do: Map.put(moved, "last", now), else: moved)

    entries =
      preset_entries(tag, pre, target, to, was) ++
        undone ++ if(resumed?, do: [{:resumed, tag, now - was["last"]}], else: [])

    edit_reach(how, target != pre or how == :pre_frozen)
    {entries ++ expected, Map.put(next, tag, {target, pre, if(resumed?, do: was["last"])})}
  end

  defp timer!(_not_a_timer, _timer, _later, _undo, acc), do: acc

  # Where this edit's last switch resumed the timer and no scan has run since, its `last`,
  # still at `now`, goes back to the one that switch found; not after a restart, which
  # started the timer again.
  defp resume_undone(%{"last" => now} = was, {_, _, last}, true, now, tag) when last != nil,
    do: {Map.put(was, "last", last), [{:resume_undone, tag, now - last}]}

  defp resume_undone(was, _undo, _switched, _now, _tag), do: {was, []}

  defp found?({_, _, last}), do: last != nil
  defp found?(nil), do: false

  defp pre_target({pre, found, _last}, pre, _from, _to), do: {:pre_restored, found}
  defp pre_target(_undo, pre, from, nil) when from != nil and pre != 0, do: {:pre_frozen, pre}
  defp pre_target(_undo, pre, _from, nil), do: {:frozen_unseen, pre}
  defp pre_target(_undo, _pre, nil, to), do: {:pre_outright, to}
  defp pre_target(_undo, from, from, to), do: {:pre_followed, to}
  defp pre_target(_undo, pre, _from, _to), do: {:kept, pre}

  defp preset_entries(_tag, pre, pre, to, _was) when to in [nil, pre], do: []
  defp preset_entries(tag, pre, pre, to, _was), do: [{:preset_kept, tag, {pre, to}}]

  defp preset_entries(tag, pre, target, nil, _was), do: [{:preset, tag, {pre, target}}]

  defp preset_entries(tag, pre, target, _to, was),
    do: [{:preset, tag, {pre, target}} | dn_forecast(tag, was, target)]

  defp dn_forecast(tag, %{"dn" => 1, "acc" => acc}, pre) when max(acc, 0) < pre,
    do: [{:dn_drops, tag, {max(acc, 0), pre}}]

  defp dn_forecast(tag, %{"dn" => 0, "en" => 1, "acc" => acc}, pre) when max(acc, 0) >= pre,
    do: [{:dn_rises, tag, {max(acc, 0), pre}}]

  defp dn_forecast(_tag, _was, _pre), do: []

  # The timers a program declares, and the preset of the `ton` that runs one, from its text.
  defp timers_of(program),
    do: for([_, tag] <- Regex.scan(~r/^var (\S+) ton$/m, program.source), do: tag)

  defp ton_of(program, tag) do
    case Regex.run(~r/(^|\s)ton #{tag} (\d+)/, program.source) do
      [_, _, preset] -> String.to_integer(preset)
      nil -> nil
    end
  end

  # Independent of the rules, a scan's timers against `ton` itself. Resume: no scan lets
  # a timer its program runs gain more than the scan's own time, as one caught up after a
  # switch would; reached where the last switch resumed the timer, and catching up would
  # have broken the bound. F6: the scan right after a switch, with the timer's rung true and
  # its `.pre` as the switch left it, drops `.dn` where the switch said it would, unless
  # `.pre` - `.acc` ms passed, and raises it where the switch said it would (forecast!/5).
  defp timed!(:plain_swap, _program, _before, _later, _timed), do: :ok

  defp timed!(:running, program, before, later, timed) do
    dt = later.now - before.now

    for tag <- timers_of(program), ton_of(program, tag) != nil do
      was = acc_of(before.env[tag])
      timer = later.env[tag]
      assert timer["acc"] <= was + dt

      edit_reach(
        :resumed_scan,
        tag in names(timed, :resumed) and timer["en"] == 1 and was + dt < max(timer["pre"], 0)
      )

      for {kind, ^tag, {acc, pre}} <- timed, kind in [:dn_drops, :dn_rises] do
        forecast!(kind, {acc, pre}, before.env[tag], timer, dt)
      end
    end
  end

  # A forecast speaks of the timer as the switch left it, a drop of a `.dn` at 1 and a rise
  # of one at 0, and is borne out by the next scan wherever the rung is true and `.pre` as
  # it was.
  defp forecast!(kind, {acc, pre}, was, timer, dt) do
    assert {was["dn"], acc, pre} == {dn_before(kind), acc_of(was), was["pre"]}

    if timer["en"] == 1 and timer["pre"] == pre and (kind == :dn_rises or dt < pre - acc) do
      assert timer["dn"] == 1 - dn_before(kind)
      edit_reach(:dn_scan, true)
    end
  end

  defp dn_before(:dn_drops), do: 1
  defp dn_before(:dn_rises), do: 0

  defp acc_of(%{"acc" => acc}), do: max(acc, 0)
  defp acc_of(_not_a_timer), do: 0

  # F1 and F11, independent of the rules and of the reports: a test then an untest with no
  # scan between leaves the original's tags as they were, and so its next scan's outputs, a
  # timer the test resumed included, but for the writes no untest undoes, found from the
  # two programs' text and the state: a tag either switch started, which the state lacked
  # or (at a first test) held a value of the wrong type for, at its initial value. A test
  # starts the round; an untest that follows it at once ends it; a scan, a restart,
  # accept, assemble and cancel clear it, through the walk.
  defp round_trip!(:test, _round, {from, to, stage}, before, _later, report) do
    started = starts(from, to, before.env, stage == :accepted)
    {before, report, Map.merge(before.env, Map.take(Program.initial_env(to), started))}
  end

  defp round_trip!(:untest, nil, _programs, _before, _later, _report), do: nil

  defp round_trip!(:untest, {was, tested, kept}, {_from, original, _stage}, before, later, report) do
    lacked = for {tag, _} <- original.tags, not Map.has_key?(before.env, tag), do: tag
    initial = Program.initial_env(original)
    expected = %{was | env: Map.merge(kept, Map.take(initial, lacked))}
    tags = Map.keys(original.tags)
    assert Map.take(later.env, tags) == Map.take(expected.env, tags)
    # Before a first scan, which blocks every `ons`, the list makes no difference.
    assert later.ons_blocked == was.ons_blocked or was.first
    {outputs, _} = Runtime.scan(original, expected, 10)
    assert {^outputs, _} = Runtime.scan(original, later, 10)
    edit_reach(:round_trip, true)

    edit_reach(
      :round_trip_timer,
      Enum.any?(tested ++ report, &(elem(&1, 0) in [:preset, :preset_kept]))
    )

    edit_reach(:round_trip_resumed, names(tested, :resumed) != [])

    edit_reach(
      :round_trip_started,
      Enum.any?(original.tags, fn {tag, _} ->
        not Map.has_key?(was.env, tag) and Map.has_key?(kept, tag) and kept[tag] != initial[tag]
      end)
    )

    edit_reach(:round_trip_ons, names(tested, :ons_blocked) != [])
    nil
  end

  # Decision 21 and fixes F2, F3 and F7, restated from the two programs' text, with the
  # walk's own record of which side of the edit left the storage bits and what is pending
  # against it: `s1` is blocked where the program started has its `ons`, unless the side
  # that last scanned is the one started, or has that `ons` in the same rung text and
  # writes `s1` no other way; or where it is pending and the program started has its
  # `ons`. Returns the record for the next switch.
  defp ons!({stops, sides}, before, later, report, scanned) do
    {last, pending} = scanned = ons_basis(scanned, before, stops)
    to = sides[started(stops)]
    {own, how} = own_blocks(last == stops, sides[last], to, before)
    kept = for "s1" <- pending, ons_line(to) != nil, do: "s1"
    assert names(report, :ons_blocked) == Enum.sort(Enum.uniq(own ++ kept))

    for {:ons_blocked, bit, value} <- report, do: assert(value == later.env[bit])

    edit_reach(how, how != :none)
    edit_reach(:ons_pending, own == [] and kept != [])
    scanned
  end

  defp sides(:test, w), do: {:original, %{original: w.o, candidate: w.c}}
  defp sides(:untest, w), do: {:candidate, %{original: w.o, candidate: w.c}}

  defp started(:original), do: :candidate
  defp started(:candidate), do: :original

  defp ons_basis(_known, %Instance{switched: false}, stops), do: {stops, []}
  defp ons_basis(nil, %Instance{ons_blocked: pending}, stops), do: {stops, pending}
  defp ons_basis(known, _state, _stops), do: known

  defp own_blocks(false, _last, to, _before), do: {[], same_side(ons_line(to))}

  defp own_blocks(true, last, to, before),
    do: own_ons(ons_line(last), ons_line(to), elsewhere?(last), Map.has_key?(before.env, "s1"))

  defp same_side(nil), do: :none
  defp same_side(_rung), do: :ons_same_side

  defp own_ons(_rung, nil, _elsewhere?, _existing?), do: {[], :none}
  defp own_ons(nil, _rung, _elsewhere?, true), do: {["s1"], :ons_new}
  defp own_ons(nil, _rung, _elsewhere?, false), do: {["s1"], :none}
  defp own_ons(rung, rung, true, _existing?), do: {["s1"], :ons_written}
  defp own_ons(rung, rung, false, _existing?), do: {[], :ons_untouched}
  defp own_ons(_rung, _changed, _elsewhere?, _existing?), do: {["s1"], :ons_changed}

  # The rung of the program's `ons`, as its text, and whether anything else writes `s1`.
  defp ons_line(program),
    do: Enum.find(String.split(program.source, "\n"), &String.contains?(&1, " ons s1 "))

  defp elsewhere?(program),
    do: Regex.match?(~r/(^|\s)((ote|otl|otu) s1|move \S+ s1)(\s|$)/m, program.source)

  # F11, independent of the rules: a one-shot pulses only if the previous scan ran the same
  # `ons` rung text with its condition 0. Read where the program scanned writes `s1` through
  # its `ons` alone, as a one-shot's own scans then bear it out, and not at a plain swap's
  # scan, which nothing blocks. Reached by a real edge on the scan right after a switch,
  # and by a block that kept a would-be pulse off.
  defp pulsed!(:plain_swap, _program, _state, _later, _outputs, _prev), do: :ok

  defp pulsed!(:running, program, state, later, outputs, prev),
    do: pulse!(ons_line(program), elsewhere?(program), state, later, outputs, prev)

  defp pulse!(nil, _elsewhere?, _state, _later, _outputs, _prev), do: :ok
  defp pulse!(_rung, true, _state, _later, _outputs, _prev), do: :ok

  defp pulse!(rung, false, state, _later, %{"p" => 1}, prev) do
    assert %{rung: ^rung, cn: 0} = prev
    edit_reach(:ons_switch_edge, state.switched)
  end

  defp pulse!(_rung, false, state, later, %{"p" => 0}, _prev),
    do:
      edit_reach(
        :ons_blocked_edge,
        "s1" in state.ons_blocked and later.env["cn"] == 1 and state.env["s1"] == 0 and
          not state.first
      )

  defp names(report, kind), do: for({^kind, name, _} <- report, do: name)

  defp var_inputs(program),
    do: Enum.sort(for {name, %Tag{section: :var_input}} <- program.tags, do: name)

  defp outputs_of(program),
    do: Enum.sort(for {name, %Tag{section: :var_output}} <- program.tags, do: name)

  defp edit_reach(name, true), do: reached(:edit_reach, name)

  defp edit_reach(_name, false), do: :ok

  # ---- M2-1: the walk over a configuration -----------------------------------------------

  # The refusals of a resource's calls, by the words that tell their kinds apart. Each line
  # of a refusal is one problem, and each must be one of these: the first whose words it
  # holds, so an instance's unknown tag, "is a program instance of `motor`, which declares
  # no", is told from the instance named whole by coming first.
  @config_refusals [
    {:runtime, "expected a %Logex.Runtime{} from Logex.Runtime.start/1"},
    {:elapsed, "elapsed_ms must be"},
    {:inputs, "inputs must be a map of input-point names"},
    {:key, "is not a point name"},
    {:output_point, "is an output point"},
    {:unlocated, "is a global with no location"},
    {:reaches, "reaches into the program instance"},
    {:no_point, "is not an input point"},
    {:bool, "is a bool: only 0 or 1 fit"},
    {:dint, "is a dint: its value must be an integer"},
    {:dint_range, "does not fit in 32 bits"},
    {:path, "is not an access path"},
    {:neither, "is neither a global nor a program instance"},
    {:too_deep, "goes too deep"},
    {:instance_key, "`, not an input point"},
    {:task, "is a task, not"},
    {:configuration, "is the configuration's name"},
    {:no_tag, "which declares no"},
    {:whole_instance, "is a program instance of `"},
    {:whole_block, "an access path names one of its members"},
    {:internal_member, "an access path reads only its public members"},
    {:no_member, "is not a member of"},
    {:mode, "restart takes :cold or :warm"},
    # start/1 checks its configuration again: a host's mistake that check/1 raises, or a
    # diagnostic it gives, formatted.
    {:negative, "a priority is 0, the highest, to 65535, found -"},
    {:priority, "a priority is 0, the highest, to 65535"},
    {:interval, "an interval is 1 to 2147483647 ms"},
    {:lines, "a configuration's lines are all nil"},
    {:line, "a line is a positive integer"}
  ]

  # What the walk must see the scheduler do, at least once each.
  @config_reach [
    :ran_task,
    :ran_taskless,
    :overlap,
    :overlap_many,
    :no_task_due,
    :elapsed_zero,
    :priority_order,
    :due_time_order,
    :read_back,
    :constant,
    :copy_out_seen,
    :first_scan_ons,
    :timer_done,
    :infinity,
    :restart,
    :image_kept
  ]

  # The program types a configuration of the walk draws from: a contact, a latch, a timer
  # with a dint preset and output, and a one-shot.
  @types %{
    "relay" => "var_input in bool\nvar_output out bool\nxic in ote out",
    "latch" =>
      "var_input set bool\nvar_input reset bool\nvar_output q bool\nxic set otl q\nxic reset otu q",
    "timer" =>
      "var_input go bool\nvar_input sp dint\nvar_output done bool\nvar_output acc dint\n" <>
        "var t1 ton\nxio go move sp t1.pre\nxic t1.dn ote done\nmove t1.acc acc\nxic go ton t1 30",
    "pulse" => "var_input in bool\nvar_output out bool\nvar s bool\nxic in ons s ote out"
  }

  # The globals: input points, output points and unlocated globals, bool and dint.
  @points [
    {"i0", :bool, "panel.i.0"},
    {"i1", :bool, "panel.i.1"},
    {"i2", :bool, "panel.i.2"},
    {"d0", :dint, "drive.i.0"},
    {"o0", :bool, "panel.q.0"},
    {"o1", :bool, "panel.q.1"},
    {"o2", :bool, "panel.q.2"},
    {"a0", :dint, "drive.q.0"},
    {"g0", :bool, nil},
    {"g1", :bool, nil},
    {"n0", :dint, nil}
  ]

  # The one global with an initial value, which a restart puts back.
  @initials %{"n0" => 7}

  # Its draws are sized from the rate of its rarest atom, `:due_time_order`, seen in about
  # one configuration in 26 over the seeds {n, 77, 7}, n from 1 to 60. At 150
  # configurations a run, 1 of the 260 seeds {n, 77, 7}, n to 60, and {n, 1, 1} and
  # {7, n, 2026}, n to 100, missed it. At 400 it is expected more than 15 times a run, and
  # the reach holds at this seed and, in its place, at each of {n, 77, 7}, {n, 1, 1} and
  # {7, n, 2026}, n from 1 to 100, every atom reached by 7 configurations a run or more.
  test "a resource refuses every host mistake with a documented ArgumentError, accepts " <>
         "every call without one, and runs as its rules say" do
    programs =
      Map.new(@types, fn {name, source} ->
        {:ok, program} = Logex.compile(source, name: name)
        {name, program}
      end)

    :rand.seed(:exsss, {2026, 10, 2})

    for _ <- 1..400 do
      config = configuration(programs)
      model = model(config)
      runtime = Runtime.start(config)
      config_walk(config, runtime, model, 50)
    end

    expected = MapSet.new(Enum.map(@config_refusals, &elem(&1, 0)))
    assert Process.get(:config_refused, MapSet.new()) == expected
    assert Process.get(:config_reach, MapSet.new()) == MapSet.new(@config_reach)
  end

  defp configuration(programs) do
    tasks =
      for name <- Enum.take(Enum.shuffle(~w(fast mid slow)), :rand.uniform(4) - 1),
          do: %Logex.Configuration.Task{
            name: name,
            interval: pick([5, 10, 15, 30]),
            priority: pick([0, 1, 2, 2, 65_535])
          }

    # Names drawn in a random order, so that declaration order is not name order, and no
    # order a name gives can pass for the one the configuration declares.
    instances =
      for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4 m5)), :rand.uniform(4)),
          do: %Logex.Configuration.Instance{
            name: name,
            type: pick(Map.keys(programs)),
            task: pick([nil | Enum.map(tasks, & &1.name)])
          }

    globals =
      for {name, type, at} <- @points,
          do: %Logex.Configuration.Global{
            name: name,
            type: type,
            at: at,
            initial: @initials[name]
          }

    {connections, _driven} =
      Enum.flat_map_reduce(instances, MapSet.new(), fn instance, driven ->
        program = programs[instance.type]
        tags = program.tags |> Map.values() |> Enum.sort_by(& &1.name)

        ins =
          for %Tag{section: :var_input} = tag <- tags,
              do: %Logex.Configuration.Connection{
                instance: instance.name,
                member: tag.name,
                to: source_for(tag.type)
              }

        Enum.flat_map_reduce(
          for(%Tag{section: :var_output} = tag <- tags, do: tag),
          driven,
          fn tag, driven ->
            sinks =
              for {name, type, at} <- @points,
                  type == tag.type,
                  at == nil or String.contains?(at, ".q."),
                  name not in driven,
                  :rand.uniform(2) == 1,
                  do: name

            outs =
              for sink <- Enum.take(sinks, 2),
                  do: %Logex.Configuration.Connection{
                    instance: instance.name,
                    member: tag.name,
                    to: sink
                  }

            {outs, Enum.reduce(outs, driven, &MapSet.put(&2, &1.to))}
          end
        )
        |> then(fn {outs, driven} -> {ins ++ outs, driven} end)
      end)

    Logex.Configuration.new!(
      name: "plant",
      programs: Map.values(programs),
      tasks: tasks,
      globals: globals,
      instances: instances,
      connections: connections
    )
  end

  # A var_input's source: a global of its type, an output point read back among them, or a
  # constant.
  defp source_for(:bool), do: pick(~w(i0 i1 i2 i0 i1 o0 g0 g1) ++ [0, 1])
  defp source_for(:dint), do: pick(["d0", "d0", "n0", "a0", 0, 40, 25])

  # The walk's own model of a resource, from the rules in Logex.Runtime's moduledoc and
  # docs/organisation.md §4.6, each instance scanned by Runtime.call/4 alone: the input
  # image and every global, each instance's state, and each task's next due time, which
  # is a multiple of its interval since every task is due at 0.
  defp model(config),
    do: %{
      now: 0,
      globals: Map.new(config.globals, &{&1.name, Map.get(@initials, &1.name, 0)}),
      states: Map.new(config.instances, &{&1.name, Runtime.instance(config.programs[&1.type])}),
      anchor: Map.new(config.tasks, &{&1.name, 0}),
      next: Map.new(config.tasks, &{&1.name, 0}),
      overlaps: Map.new(config.tasks, &{&1.name, 0}),
      runs: Map.new(config.tasks, &{&1.name, 0}),
      cycles: 0
    }

  # A restart, from the rules alone: the clock and the input points kept, every other
  # global at its initial value, each instance through restart/3, and every task anchored
  # at the kept clock, with nothing run or missed since.
  defp model_restart(config, model, mode),
    do: %{
      model
      | globals:
          Map.new(model.globals, fn {name, value} ->
            {name, kept(name in input_points(), value, Map.get(@initials, name, 0))}
          end),
        states:
          Map.new(model.states, fn {name, state} ->
            {name, Runtime.restart(config.programs[state.type], state, mode)}
          end),
        anchor: Map.new(config.tasks, &{&1.name, model.now}),
        next: Map.new(config.tasks, &{&1.name, model.now}),
        overlaps: Map.new(config.tasks, &{&1.name, 0}),
        runs: Map.new(config.tasks, &{&1.name, 0})
    }

  defp kept(true, value, _initial), do: value
  defp kept(false, _value, initial), do: initial

  defp input_points, do: for({name, _, at} <- @points, at != nil, at =~ ".i.", do: name)

  defp model_cycle(config, model, elapsed, inputs) do
    now = model.now + elapsed
    globals = Map.merge(model.globals, inputs)

    due =
      config.tasks
      |> Enum.with_index()
      |> Enum.filter(fn {task, _} -> model.next[task.name] <= now end)
      |> Enum.sort_by(fn {task, index} -> {task.priority, model.next[task.name], index} end)
      |> Enum.map(&elem(&1, 0))

    model = %{model | now: now, globals: globals, cycles: model.cycles + 1}

    {model, events} =
      Enum.reduce(due, {model, []}, fn task, {model, events} ->
        # The periods since its due time, up to now, are the multiples of its interval
        # from its anchor in that span: one runs, and the rest are missed.
        anchor = model.anchor[task.name]
        periods = div(now - anchor, task.interval)
        missed = periods - div(model.next[task.name] - anchor, task.interval)

        model = %{
          model
          | next: Map.put(model.next, task.name, anchor + (periods + 1) * task.interval),
            overlaps: Map.update!(model.overlaps, task.name, &(&1 + missed)),
            runs: Map.update!(model.runs, task.name, &(&1 + 1))
        }

        events = if missed > 0, do: [{:overlap, task.name, missed} | events], else: events

        Enum.reduce(
          for(i <- config.instances, i.task == task.name, do: i),
          {model, events},
          &model_scan(config, &1, task.name, &2)
        )
      end)

    {model, events} =
      Enum.reduce(
        for(i <- config.instances, i.task == nil, do: i),
        {model, events},
        &model_scan(config, &1, :none, &2)
      )

    outputs =
      for {name, _type, at} <- @points,
          at != nil and String.contains?(at, ".q."),
          into: %{},
          do: {name, model.globals[name]}

    {model, outputs, Enum.reverse(events)}
  end

  defp model_scan(config, instance, task, {model, events}) do
    program = config.programs[instance.type]
    mine = for c <- config.connections, c.instance == instance.name, do: c
    section = fn c -> program.tags[c.member].section end

    inputs =
      for c <- mine,
          section.(c) == :var_input,
          into: %{},
          do: {c.member, if(is_binary(c.to), do: model.globals[c.to], else: c.to)}

    state = model.states[instance.name]

    {outputs, state} =
      Runtime.call(program, state, inputs, %Scan{now: model.now, first: state.first})

    globals =
      for c <- mine, section.(c) == :var_output, reduce: model.globals do
        globals -> Map.put(globals, c.to, outputs[c.member])
      end

    {%{model | states: Map.put(model.states, instance.name, state), globals: globals},
     [{:ran, task, instance.name, model.now} | events]}
  end

  defp config_walk(_config, _runtime, _model, 0), do: :ok

  defp config_walk(config, runtime, model, n) do
    case config_operation(:rand.uniform(8), config, runtime) do
      {:cycle, mistake?, elapsed, inputs} ->
        case config_attempt(fn -> Runtime.cycle(runtime, elapsed, inputs) end) do
          {:ok, {next, outputs, events}} ->
            before = model
            refute mistake?, "a host mistake was accepted: #{inspect({elapsed, inputs})}"

            {model, expected_outputs, expected_events} =
              model_cycle(config, model, elapsed, inputs)

            assert events == expected_events
            assert outputs == expected_outputs
            assert Runtime.overlaps(next) == model.overlaps
            observe(config, {before, model}, events, elapsed)
            check_model(config, next, model)
            config_walk(config, next, model, n - 1)

          :refused ->
            assert mistake?,
                   "a call without a host mistake was refused: #{inspect({elapsed, inputs})}"

            config_walk(config, runtime, model, n - 1)
        end

      {:get, mistake?, path} ->
        case config_attempt(fn -> Runtime.get!(runtime, path) end) do
          {:ok, value} ->
            refute mistake?, "a bad path was read: #{inspect(path)}"
            assert value == model_get(config, model, path)
            assert Runtime.get(runtime, path) == {:ok, value}

          :refused ->
            assert mistake?, "a good path was refused: #{inspect(path)}"
            refused_get(runtime, path)
        end

        config_walk(config, runtime, model, n - 1)

      {:bad_runtime, call} ->
        assert config_attempt(call) == :refused
        config_walk(config, runtime, model, n - 1)

      {:start, spoiled} ->
        assert config_attempt(fn -> Runtime.start(spoiled) end) == :refused
        config_walk(config, runtime, model, n - 1)

      {:restart, mistake?, mode} ->
        case config_attempt(fn -> Runtime.restart(runtime, mode) end) do
          {:ok, next} ->
            refute mistake?, "a bad restart was accepted: #{inspect(mode)}"
            model = model_restart(config, model, mode)
            config_reach(:restart, true)

            config_reach(
              :image_kept,
              Enum.any?(input_points(), &(Runtime.get!(next, &1) != 0))
            )

            check_restarted(config, next, model)
            config_walk(config, next, model, n - 1)

          :refused ->
            assert mistake?, "a good restart was refused: #{inspect(mode)}"
            config_walk(config, runtime, model, n - 1)
        end
    end
  end

  # Right after a restart, every task is due at once and every value is the model's.
  defp check_restarted(config, runtime, model) do
    assert Runtime.next_due_in(runtime) == if(config.tasks == [], do: :infinity, else: 0)
    assert Runtime.overlaps(runtime) == model.overlaps
    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value)

    for instance <- config.instances,
        {tag, value} <- model.states[instance.name].env,
        is_integer(value),
        do: assert(Runtime.get!(runtime, "#{instance.name}.#{tag}") == value)
  end

  # Everything the scheduler's rules say a model must also show: the next due time, every
  # global, and every tag of every instance.
  defp check_model(config, runtime, model) do
    next = model.next |> Map.values() |> Enum.min(fn -> nil end)
    expected = if next == nil, do: :infinity, else: next - model.now
    assert Runtime.next_due_in(runtime) == expected
    # After a cycle no task is overdue: each it ran moved past now.
    assert expected == :infinity or expected > 0
    config_reach(:infinity, expected == :infinity)

    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value)

    for instance <- config.instances,
        {tag, value} <- model.states[instance.name].env,
        is_integer(value),
        do: assert(Runtime.get!(runtime, "#{instance.name}.#{tag}") == value)

    # Every period of a task up to now is either run or counted as missed: an oracle that
    # knows nothing of how the scheduler finds them.
    for task <- config.tasks do
      assert model.runs[task.name] + model.overlaps[task.name] ==
               div(model.now - model.anchor[task.name], task.interval) + 1
    end
  end

  defp observe(config, {before, model}, events, elapsed) do
    ran = for {:ran, task, instance, _} <- events, do: {task, instance}
    config_reach(:ran_task, Enum.any?(ran, &(elem(&1, 0) != :none)))
    config_reach(:ran_taskless, Enum.any?(ran, &(elem(&1, 0) == :none)))
    config_reach(:overlap, Enum.any?(events, &match?({:overlap, _, _}, &1)))
    config_reach(:overlap_many, Enum.any?(events, &match?({:overlap, _, m} when m > 1, &1)))
    config_reach(:no_task_due, config.tasks != [] and Enum.all?(ran, &(elem(&1, 0) == :none)))
    config_reach(:elapsed_zero, elapsed == 0 and model.cycles > 1)

    # Priority put a task declared later first; or, at one priority, an earlier due time
    # did.
    declared = config.tasks |> Enum.with_index() |> Map.new(fn {t, i} -> {t.name, {t, i}} end)
    order = for {task, _} <- Enum.dedup_by(ran, &elem(&1, 0)), task != :none, do: declared[task]
    indexes = Enum.map(order, &elem(&1, 1))
    config_reach(:priority_order, indexes != Enum.sort(indexes))

    config_reach(
      :due_time_order,
      Enum.any?(Enum.chunk_every(order, 2, 1, :discard), fn [{a, _}, {b, _}] ->
        a.priority == b.priority and before.next[a.name] < before.next[b.name]
      end)
    )

    config_reach(:read_back, Enum.any?(config.connections, &(&1.to in ~w(o0 a0))) and ran != [])
    config_reach(:constant, Enum.any?(config.connections, &is_integer(&1.to)) and ran != [])

    config_reach(
      :copy_out_seen,
      Enum.any?(
        config.connections,
        &(&1.to in ~w(g0 g1 n0) and model.globals[&1.to] != Map.get(@initials, &1.to, 0))
      )
    )

    config_reach(
      :first_scan_ons,
      Enum.any?(config.instances, &(&1.type == "pulse")) and model.cycles == 1
    )

    config_reach(
      :timer_done,
      Enum.any?(model.states, fn {_, s} -> match?(%{"t1" => %{"dn" => 1}}, s.env) end)
    )
  end

  defp config_reach(name, true), do: reached(:config_reach, name)
  defp config_reach(_name, false), do: :ok

  defp model_get(config, model, path) do
    case String.split(path, ".") do
      [global] ->
        model.globals[global]

      [instance | members] ->
        get_in(model.states[instance].env, members)
        |> then(&if(&1 == nil, do: 0, else: &1))
        |> tap(fn _ -> assert Enum.any?(config.instances, &(&1.name == instance)) end)
    end
  end

  # get/2 gives the reason get!/2 raises for a path that is a string (decision 41), and
  # raises for one that is not, as get!/2 does.
  defp refused_get(runtime, path) when is_binary(path) do
    error = assert_raise ArgumentError, fn -> Runtime.get!(runtime, path) end
    assert Runtime.get(runtime, path) == {:error, error.message}
  end

  defp refused_get(runtime, path),
    do: assert_raise(ArgumentError, fn -> Runtime.get(runtime, path) end)

  # One operation: a cycle, good or bad; a read, good or bad; or a call on something that
  # is not a runtime.
  defp config_operation(kind, _config, _runtime) when kind in [1, 2, 3] do
    elapsed =
      pick([0, 0, 1, 5, 5, 10, 10, 13, 30, 47, 100] ++ if(kind == 3, do: [-1, 1.5], else: []))

    {inputs, bad?} = config_inputs(kind == 3)
    {:cycle, bad? or not (is_integer(elapsed) and elapsed >= 0), elapsed, inputs}
  end

  defp config_operation(4, config, _runtime) do
    good =
      Enum.map(@points, &elem(&1, 0)) ++
        for instance <- config.instances,
            tag <- Map.keys(config.programs[instance.type].tags),
            tag not in ["t1"],
            do: "#{instance.name}.#{tag}"

    timers =
      for i <- config.instances,
          i.type == "timer",
          m <- ~w(pre acc dn tt en),
          do: "#{i.name}.t1.#{m}"

    {:get, false, pick(good ++ timers)}
  end

  defp config_operation(5, config, _runtime) do
    instance = pick(config.instances).name

    bad =
      [5, "", "a..b", "a b", "zz", "i0.x", instance, "#{instance}.zz", "#{instance}.in.x"] ++
        ["plant" | Enum.map(config.tasks, & &1.name)] ++
        for i <- config.instances,
            i.type == "timer",
            p <- ["t1", "t1.last", "t1.Acc", "t1.acc.x"],
            do: "#{i.name}.#{p}"

    {:get, true, pick(bad)}
  end

  defp config_operation(6, config, _runtime) do
    junk = pick([5, nil, %{}, config])

    {:bad_runtime,
     pick([
       fn -> Runtime.cycle(junk, 0, %{}) end,
       fn -> Runtime.get!(junk, "i0") end,
       fn -> Runtime.get(junk, "i0") end,
       fn -> Runtime.next_due_in(junk) end,
       fn -> Runtime.overlaps(junk) end,
       fn -> Runtime.restart(junk, :cold) end
     ])}
  end

  defp config_operation(7, _config, _runtime) do
    mode = pick([:cold, :warm, :cold, :warm, :hot, nil])
    {:restart, mode not in [:cold, :warm], mode}
  end

  # The configuration started again with one mistake: a negative priority or a line no
  # file gives, which no configuration text can say, or a priority past 65535 or an
  # interval of 0, which a text can (decisions 36 and 37).
  defp config_operation(8, config, _runtime) do
    task = fn interval, priority ->
      %{
        config
        | tasks:
            config.tasks ++
              [%Logex.Configuration.Task{name: "t9", interval: interval, priority: priority}]
      }
    end

    [first | rest] = config.globals

    {:start,
     pick([
       task.(10, -1),
       task.(10, 65_536),
       task.(0, 0),
       %{config | globals: [%{first | line: 3} | rest]},
       %{config | globals: [%{first | line: 0} | rest]}
     ])}
  end

  # Inputs: a few input points with values that fit, and, for a bad step, one mistake.
  defp config_inputs(false) do
    inputs =
      for {name, type, at} <- @points,
          at != nil and String.contains?(at, ".i."),
          :rand.uniform(3) == 1,
          into: %{},
          do: {name, if(type == :bool, do: pick([0, 1]), else: pick([0, 20, 40, -5]))}

    {inputs, false}
  end

  defp config_inputs(true) do
    {good, false} = config_inputs(false)

    bad =
      pick([
        {7, 1},
        {"o0", 1},
        {"g0", 1},
        {"m1.in", 1},
        {"m1", 1},
        {"m2", 1},
        {"fast", 1},
        {"plant", 1},
        {"zz", 1},
        {"i0", 2},
        {"d0", 1.5},
        {"d0", 3_000_000_000}
      ])

    case pick([:pair, :pair, :pair, :list]) do
      :pair -> {Map.put(good, elem(bad, 0), elem(bad, 1)), true}
      :list -> {[{"i0", 1}], true}
    end
  end

  defp config_attempt(fun) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      for line <- String.split(error.message, "\n") do
        kind = Enum.find(@config_refusals, fn {_, words} -> String.contains?(line, words) end)
        assert kind, "undocumented refusal: #{line}"
        reached(:config_refused, elem(kind, 0))
      end

      :refused
  end

  # ---- M2-5: the walk with online edits of programs that hold blocks --------------------

  # Versions of a block `blk`, of a block `wrap` that holds one, and programs that hold
  # either, drawn so that two programs share their names: a body changed in its `ons` rung,
  # a member added with an initial value that changes, a member whose kind changes, and a
  # timer added, dropped or given one of three presets, or whose `.pre` logic moves; `wrap`
  # runs its `blk` always, under
  # a condition, under a one-shot of its own, or not at all; a program runs `x` under a
  # condition or not, holds a `wrap`, or a second `blk` it runs or does not.
  @fb_blk [
    "var e bool\nxic go ons e ote p",
    "var e bool\nxio go ons e ote p",
    "var e bool\nvar n dint 2\nxic go ons e ote p\nxic go move 3 n",
    "var e dint\nxic go move 1 e\nxic go ote p",
    "var t1 ton\nxic go ton t1 50\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 80\nxic t1.dn ote p",
    "var e bool\nvar t1 ton\nxic go ons e ote p\nxic go ton t1 50",
    "var e bool\nvar n dint 5\nxic go ons e ote p\nxic go move 3 n",
    "var e bool\nvar t1 ton\nxic go ons e ote p\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 20\nxic t1.dn ote p",
    "var t1 ton\nxic go ton t1 50\nxic go move 7 t1.pre\nxic t1.dn ote p"
  ]

  @fb_wrap [
    "cal inner a q",
    "xic a cal inner a q",
    "var k bool\nxic a ons k cal inner a q",
    "xic a ote q"
  ]

  @fb_head "var_input g bool\nvar_input h bool\nvar_input en bool\nvar_output p bool\nvar_output q bool\n"

  @fb_programs [
    "var x blk\nxic en cal x g p",
    "var x blk\nvar w wrap\nxic en cal x g p\ncal w h q",
    "var x blk\nvar w wrap\ncal x g p\ncal w h q",
    "var x blk\nvar w wrap\nxic g ote p\ncal w h q",
    "var w wrap\nxic g ote p\nxic en cal w h q",
    "var x blk\nvar w wrap\nvar y blk\nxic en cal x g p\nxic en cal w h q\ncal y h q",
    "var x blk\nvar y blk\nvar w wrap\nxic en cal x g p\ncal w g q"
  ]

  # What the walk must see happen, and its oracles check, at least once each: every switch
  # and prune, a report kind by a path inside an instance, a refused member kind change, a
  # round trip, and a scan right after a switch where an `ons` whose chain of rungs changed
  # ran, one and two levels down.
  @fb_reach [
    :test,
    :untest,
    :assemble,
    :cancel,
    :refused,
    :round_trip,
    :round_trip_timer,
    :ons_x_changed_ran,
    :ons_inner_changed_ran,
    :ons_x_changed_late,
    :ons_inner_changed_late,
    {:nested, :added},
    {:nested, :dn_drops},
    {:nested, :dn_rises},
    {:nested, :initial_changed},
    {:nested, :ons_blocked},
    {:nested, :preset},
    {:nested, :preset_kept},
    {:nested, :pruned},
    {:nested, :resume_undone},
    {:nested, :resumed}
  ]

  # Under which chain of rungs each one-shot last ran, none known yet (below).
  @fb_unknown %{x: :any, inner: :any}

  defp fb_programs do
    for {b, bi} <- Enum.with_index(@fb_blk),
        {wr, wi} <- Enum.with_index(@fb_wrap),
        {pr, pi} <- Enum.with_index(@fb_programs),
        {:ok, blk} =
          Logex.compile("function_block blk\nvar_input go bool\nvar_output p bool\n" <> b,
            name: "blk"
          ),
        {:ok, wrap} =
          Logex.compile(
            "function_block wrap\nvar_input a bool\nvar_output q bool\nvar inner blk\n" <> wr,
            name: "wrap",
            types: [blk]
          ),
        {:ok, program} <- [Logex.compile(@fb_head <> pr, name: "m", types: [blk, wrap])],
        do: {{bi, wi, pi}, program}
  end

  # Its reach holds at this seed and at each of the seeds 1 to 30 in its place. Its rarest
  # atoms, a one-shot two levels down checked on a later scan, a nested `:dn_rises` and a
  # nested `:resume_undone`, came 7 to 18, 6 to 20 and 7 to 32 times a run over those 31,
  # and a nested `:preset_kept` 173 to 302.
  # Drawn as the design pass drew them, 800 walks, two presets, steps mostly past both,
  # and a candidate drawn mostly with the running block's version, a nested `:dn_rises`
  # came one to four times a run, and three seeds of the 30 missed it.
  test "an online edit of a program that holds blocks: each report's writes rebuild the " <>
         "state by path, a switch leaves every member present, a prune leaves no other, a " <>
         "round trip gives every value back, and no one-shot fires on a changed chain" do
    :rand.seed(:exsss, {2026, 10, 2})
    programs = fb_programs()

    for _ <- 1..1600 do
      {key, program} = pick(programs)
      w = %{p: program, s: Runtime.instance(program), e: nil, key: key, c: nil, last: key}
      fb_walk(Map.merge(w, %{round: nil, after: false, wrote: @fb_unknown}), programs, 100)
    end

    assert Process.get(:fb_reach, MapSet.new()) == MapSet.new(@fb_reach)
  end

  defp fb_walk(w, _programs, 0), do: w

  defp fb_walk(w, programs, n),
    do:
      fb_walk(
        fb_op(pick(~w(scan scan scan accept test untest assemble cancel restart)a), w, programs),
        programs,
        n - 1
      )

  defp fb_running(%{e: nil, p: p}), do: p
  defp fb_running(%{e: edit}), do: Edit.running(edit)

  defp fb_key(%{e: nil, key: key}), do: key
  defp fb_key(%{e: edit, key: key, c: c}), do: fb_key(Edit.stage(edit), key, c)
  defp fb_key(:testing, _key, c), do: c
  defp fb_key(_stage, key, _c), do: key

  defp fb_op(:scan, w, _programs) do
    program = fb_running(w)

    inputs =
      for {name, %Tag{section: :var_input}} <- program.tags,
          :rand.uniform(3) == 1,
          into: %{},
          do: {name, pick([0, 1])}

    # Inputs change one time in three and time moves in steps of up to 60 ms, often short,
    # so a timer inside a block is done, or timing between two presets, when an edit moves
    # its `.pre`.
    {_outputs, later} =
      Runtime.scan(
        program,
        Runtime.put_inputs(program, w.s, inputs),
        pick([0, 10, 10, 20, 30, 60])
      )

    wrote = fb_pulses!(w, fb_key(w), later)
    %{w | s: later, round: nil, after: false, last: fb_key(w), wrote: wrote}
  end

  defp fb_op(:restart, w, _programs) do
    s = Runtime.restart(fb_running(w), w.s, pick([:cold, :warm]))
    %{w | s: s, round: nil, wrote: @fb_unknown}
  end

  # A candidate is, a third of the time each, any program, one with the running block's
  # version, or the running one with only its block's version drawn again.
  defp fb_op(:accept, %{e: nil, key: {b, wr, pr}} = w, programs) do
    same_block = for {{^b, _, _}, _} = entry <- programs, do: entry
    same_rest = for {{_, ^wr, ^pr}, _} = entry <- programs, do: entry
    {key, candidate} = pick(pick([programs, same_block, same_rest]))
    fb_accepted(Edit.accept(w.p, candidate, w.s), key, w)
  end

  defp fb_op(:test, w, _programs) when w.e != nil do
    fb_switch(Edit.stage(w.e) in [:accepted, :untested], :test, w)
  end

  defp fb_op(:untest, w, _programs) when w.e != nil do
    fb_switch(Edit.stage(w.e) == :testing, :untest, w)
  end

  defp fb_op(:assemble, w, _programs) when w.e != nil,
    do: fb_prune(Edit.stage(w.e) == :testing, :assemble, w)

  defp fb_op(:cancel, w, _programs) when w.e != nil,
    do: fb_prune(Edit.stage(w.e) in [:accepted, :untested], :cancel, w)

  defp fb_op(_op, w, _programs), do: w

  defp fb_accepted({:ok, edit, _forecast}, key, w), do: %{w | e: edit, c: key, round: nil}

  defp fb_accepted({:error, diagnostics}, _key, w) do
    assert Enum.all?(diagnostics, &match?(%Diagnostic{stage: :edit}, &1))
    fb_reach(:refused)
    w
  end

  defp fb_switch(false, _step, w), do: w

  defp fb_switch(true, step, w) do
    stage = Edit.stage(w.e)
    {edit, later, report} = apply(Edit, step, [w.e, w.s])
    fb_rebuilt!(step, w.s, later, report)
    assert Enum.sort(names(report, :ons_blocked)) == Enum.sort(later.ons_blocked)
    started = Program.initial_env(Edit.running(edit))
    assert fb_missing(fb_leaves(started), later.env) == []
    fb_round!(step, stage, w.round, later, report)
    round = fb_round(step, w.s, report)
    %{w | e: edit, s: later, round: round, after: true}
  end

  defp fb_prune(false, _step, w), do: w

  defp fb_prune(true, step, w) do
    {kept, later, report} = apply(Edit, step, [w.e, w.s])
    fb_rebuilt!(step, w.s, later, report)
    assert fb_missing(fb_leaves(later.env), Program.initial_env(kept)) == []
    key = fb_kept(step, w)
    %{w | e: nil, p: kept, s: later, key: key, round: nil}
  end

  defp fb_kept(:assemble, w), do: w.c
  defp fb_kept(:cancel, w), do: w.key

  # The writes a report lists, applied by path to the state before its step.
  defp fb_rebuilt!(step, before, later, report) do
    fb_reach(step)
    for {kind, name, _} <- report, String.contains?(name, "."), do: fb_reach({:nested, kind})
    assert Enum.reduce(report, before.env, &fb_write/2) == later.env
  end

  defp fb_path(name), do: String.split(name, ".")

  defp fb_write({kind, name, value}, env) when kind in [:added, :input],
    do: put_in(env, Enum.map(fb_path(name), &Access.key(&1, %{})), value)

  defp fb_write({:preset, name, {_from, to}}, env), do: put_in(env, fb_path(name) ++ ["pre"], to)

  defp fb_write({:resumed, name, gap}, env),
    do: update_in(env, fb_path(name) ++ ["last"], &(&1 + gap))

  defp fb_write({:resume_undone, name, gap}, env),
    do: update_in(env, fb_path(name) ++ ["last"], &(&1 - gap))

  defp fb_write({:pruned, name, _value}, env) do
    {parent, [leaf]} = Enum.split(fb_path(name), -1)
    fb_drop(parent, leaf, env)
  end

  defp fb_write(_fact, env), do: env

  defp fb_drop([], leaf, env), do: Map.delete(env, leaf)
  defp fb_drop(parent, leaf, env), do: update_in(env, parent, &Map.delete(&1, leaf))

  defp fb_leaves(map, prefix \\ []),
    do:
      Enum.flat_map(map, fn
        {key, %{} = inner} -> fb_leaves(inner, prefix ++ [key])
        {key, value} -> [{prefix ++ [key], value}]
      end)

  defp fb_missing(leaves, env), do: for({path, _} <- leaves, get_in(env, path) == nil, do: path)

  # A test then an untest with no scan between leaves every value as it was, but for what
  # either switch started, found from the reports' starts alone: a timer included.
  defp fb_round(:test, before, report), do: {before, report}
  defp fb_round(:untest, _before, _report), do: nil

  defp fb_round!(:untest, :testing, {before, tested}, later, untested) do
    started =
      for {kind, name, _} <- tested ++ untested, kind in [:added, :input], do: fb_path(name)

    changed =
      for {path, value} <- fb_leaves(before.env),
          not Enum.any?(started, &List.starts_with?(path, &1)),
          get_in(later.env, path) != value,
          do: {path, value}

    assert changed == []
    fb_reach(:round_trip)

    timer? = Enum.any?(fb_leaves(before.env), fn {path, _} -> List.last(path) == "last" end)
    fb_reach(:round_trip_timer, timer?)
  end

  defp fb_round!(_step, _stage, _round, _later, _report), do: :ok

  # Decision 21's oracle, from the programs' text alone: a one-shot of `blk` that runs
  # under a chain of rungs, from the program's `cal` down to the body's `ons` rung, other
  # than the one it last ran under passes no power; and `blk`'s output, where only that
  # rung writes it, is then 0. The chain is each rung's text: the `ons` rung of each
  # version, or none. Under which chain each one-shot last ran is known from the walk
  # alone: none after a start or a restart, whose first run fires (PLAN M2-5, `first` is
  # the program's), and unknown where a `wrap` runs its `blk` under a one-shot of its own.
  # It fails where a block is used up by a scan whose `cal` was false (a pulse after it).
  @fb_ons_text %{
    0 => "xic go ons e ote p",
    1 => "xio go ons e ote p",
    2 => "xic go ons e ote p",
    6 => "xic go ons e ote p",
    7 => "xic go ons e ote p",
    8 => "xic go ons e ote p"
  }

  # The versions whose output only the `ons` rung writes.
  @fb_observable [0, 1, 2, 6, 7]

  defp fb_pulses!(%{s: %Instance{first: true}, wrote: wrote}, {_b, wr, pr} = key, later),
    do: %{
      x: fb_ran(fb_x_ran(pr, later.env), fb_x_chain(key), wrote.x),
      inner: fb_ran(fb_inner_ran(wr, pr, later.env), fb_inner_chain(key), wrote.inner)
    }

  defp fb_pulses!(%{wrote: wrote, after: switched}, {b, wr, pr} = key, later) do
    body = b in @fb_observable
    x_ran = fb_x_ran(pr, later.env)
    x_chain = fb_x_chain(key)
    late = fb_late(switched, :ons_x_changed_late)

    fb_pulse!(
      [:ons_x_changed_ran | late],
      body && x_ran == true,
      wrote.x not in [:any, x_chain],
      later.env["x"]
    )

    inner_ran = fb_inner_ran(wr, pr, later.env)
    inner_chain = fb_inner_chain(key)
    late = fb_late(switched, :ons_inner_changed_late)

    fb_pulse!(
      [:ons_inner_changed_ran | late],
      body && inner_ran == true,
      wrote.inner not in [:any, inner_chain],
      later.env["w"]["inner"]
    )

    %{x: fb_ran(x_ran, x_chain, wrote.x), inner: fb_ran(inner_ran, inner_chain, wrote.inner)}
  end

  # A pulse checked on a later scan than the one right after a switch, its `cal` false on
  # those between.
  defp fb_late(true, _atom), do: []
  defp fb_late(false, atom), do: [atom]

  # Whether each instance's body ran: true, false, or :unknown where it ran under a
  # one-shot of `wrap`'s own.
  defp fb_x_ran(pr, env), do: pr == 2 or (pr in [0, 1, 5, 6] and env["en"] == 1)

  defp fb_inner_ran(wr, pr, env) when wr in [0, 1],
    do: fb_wrap_ran(pr, env) and (wr == 0 or env["w"]["a"] == 1)

  defp fb_inner_ran(2, pr, env), do: fb_wrap_ran(pr, env) and :unknown
  defp fb_inner_ran(_wr, _pr, _env), do: false

  defp fb_ran(true, chain, _wrote), do: chain
  defp fb_ran(false, _chain, wrote), do: wrote
  defp fb_ran(:unknown, _chain, _wrote), do: :any

  defp fb_wrap_ran(pr, _env) when pr in [1, 2, 3, 6], do: true
  defp fb_wrap_ran(pr, env) when pr in [4, 5], do: env["en"] == 1
  defp fb_wrap_ran(_pr, _env), do: false

  defp fb_pulse!(atoms, ran, true, %{"p" => p}) when ran in [true] do
    assert p == 0
    Enum.each(atoms, &fb_reach/1)
  end

  defp fb_pulse!(_atom, _ran, _changed, _instance), do: :ok

  defp fb_x_chain({b, _wr, pr}),
    do: {Enum.at(~w(xen xen bare none xnone xen xen), pr), Map.get(@fb_ons_text, b)}

  defp fb_inner_chain({b, wr, pr}),
    do: {Enum.at(~w(none h h h en en g), pr), Enum.at(@fb_wrap, wr), Map.get(@fb_ons_text, b)}

  defp fb_reach(atom), do: reached(:fb_reach, atom)

  defp fb_reach(atom, true), do: fb_reach(atom)
  defp fb_reach(_atom, false), do: :ok
end
