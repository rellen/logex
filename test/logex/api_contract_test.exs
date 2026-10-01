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
  """
  use ExUnit.Case, async: true

  alias Logex.{Diagnostic, Instance, Program, Runtime, Scan, Tag}

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
    "only a timer has members",
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

  test "compile/2 never raises for any source, and its diagnostics are in line order" do
    results = for _ <- 1..600, do: Logex.compile(source(), name: "p")

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

  test "the runtime refuses every host mistake with a documented ArgumentError, accepts " <>
         "every call without one, and nothing else escapes" do
    programs =
      Stream.repeatedly(fn -> Logex.compile(source(), name: "p") end)
      |> Stream.flat_map(fn
        {:ok, program} -> [program]
        {:error, _} -> []
      end)
      |> Enum.take(40)

    assert length(programs) == 40
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
  defp attempt(fun) do
    result = fun.()
    assert fun.() == result, "the same call gave two results"
    {:ok, result}
  rescue
    error in ArgumentError ->
      kind = Enum.find(@refusals, &String.starts_with?(error.message, &1))
      assert kind, "undocumented refusal: #{error.message}"
      Process.put(:refused, MapSet.put(Process.get(:refused, MapSet.new()), kind))
      :refused
  end
end
