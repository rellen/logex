defmodule Logex.RetainImageTest do
  @moduledoc """
  M6-4 (`PLAN.md`, Milestone 6; `docs/organisation.md` §4.13, decisions 273, 277 and
  282): the retained image. `Logex.Runtime.retained/2` and `retained/1` take every retained
  value of a lone instance or a resource out as plain data, by path, with its type, never
  a timer's `last`; `instance/2` and `start/2` lay an image over a new instance or
  resource by decision 277's matching, giving what they dropped, each once by its path
  with its reason; and every host mistake an image can make is a pinned line. Each rule a
  test that fails when it alone is reverted, the done-when's resource started from an
  image cycling exactly as the original does after a warm restart, and the take-out's
  cost bounded in the retained count.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Instance, Runtime, Scan}

  defp c!(src, types \\ [], name \\ "m") do
    {:ok, program} = Logex.compile(src, name: name, types: types)
    program
  end

  defp block!(src, types \\ []) do
    [_, name | _] = String.split(src, ~r/\s+/, parts: 3)
    {:ok, type} = Logex.compile(src, name: name, types: types)
    type
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # A value the type checker cannot see through, for a host's mistake it would flag.
  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  # Scans `program` from `state` once per entry of `inputs`, `dt` ms apart.
  defp scans(program, state, inputs, dt \\ 10),
    do:
      Enum.reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + dt, first: first})
        state
      end)

  @seal """
  function_block seal
  var_input go bool
  var_output q bool
  var t ton
  var retain k dint
  var non_retain jog bool
  xic go ton t 100
  xic t.dn ote q
  xic go add k 1 k
  xic go ote jog
  """

  @line """
  var_input eye bool
  var_input run bool
  var retain boxes ctu
  var retain lube rto
  var retain total dint
  var retain w dint[3]
  var retain tl ton[2]
  var retain s1 seal
  var gs seal[2]
  var retain sp real
  var count dint
  var fan tof
  var e bool
  var q bool
  xic eye ctu boxes 1000
  xic run rto lube 100000
  xic eye ons e add total 1 total
  xic eye move total w[1]
  xic run ton tl[0] 30
  xic eye ton tl[1] 20
  cal s1 run q
  cal gs[0] eye q
  cal gs[1] run q
  xic run add sp 0.5 sp
  xic eye add count 1 count
  xio run tof fan 40
  """

  defp seal, do: block!(@seal)
  defp line(src \\ @line), do: c!(src, [seal()])

  defp running(program, n \\ 9),
    do:
      scans(
        program,
        Runtime.instance(program),
        for(i <- 1..n, do: %{"eye" => rem(i, 2), "run" => 1})
      )

  describe "retained/2: a lone instance's image (decision 282)" do
    test "gives every retained leaf by its path with its type, each instance on the way its " <>
           "kind, and no timer's last" do
      p = line()
      s = running(p)
      image = Runtime.retained(p, s)

      assert image.program == "m"

      assert image.kinds == %{
               "boxes" => "ctu",
               "lube" => "rto",
               "tl" => {:array, "ton", [2]},
               "s1" => "seal",
               "s1.t" => "ton",
               "gs" => {:array, "seal", [2]}
             }

      assert image.values["total"] == {:dint, 4}
      assert image.values["w"] == {{:array, :dint, [3]}, [0, 4, 0]}
      assert image.values["sp"] == {:real, 4.5}
      assert image.values["boxes.cv"] == {:dint, 4}
      assert image.values["boxes.cu"] == {:bool, 1}
      assert image.values["lube.acc"] == {:dint, 80}
      assert image.values["tl[1].acc"] == {:dint, 0}
      assert image.values["s1.k"] == {:dint, 9}
      assert image.values["s1.t.acc"] == {:dint, 80}
      # `seal`'s own `retain` on `k` retains it in every element of the unmarked `gs`,
      # and its `non_retain` keeps `jog` out of the retained `s1` (decision 270).
      assert image.values["gs[0].k"] == {:dint, 5}
      assert image.values["gs[1].k"] == {:dint, 9}
      refute Map.has_key?(image.values, "s1.jog")
      refute Map.has_key?(image.values, "gs[0].t.acc")
      refute Map.has_key?(image.kinds, "gs[0].t")

      # Unmarked tags are not in it, nor is any timer's `last`, at any depth.
      for path <- ~w(count fan.acc e q eye run), do: refute(Map.has_key?(image.values, path))
      refute Enum.any?(Map.keys(image.values), &String.ends_with?(&1, ".last"))
      assert map_size(image.values) == 6 + 7 + 3 + 2 * 5 + 2 + 5 + 2
    end

    test "a program that retains nothing gives empty maps" do
      p = c!("var_input eye bool\nvar n dint\nxic eye add n 1 n")

      assert Runtime.retained(p, scans(p, Runtime.instance(p), [%{"eye" => 1}])) ==
               %{program: "m", kinds: %{}, values: %{}}
    end

    test "each elementary type and arrays of more dimensions, in a host's form" do
      p =
        c!(
          "var retain b bool 1\nvar retain u usint 200\nvar retain l lint -5\n" <>
            "var retain d word 16#ff\nvar retain r real 0.1\nvar retain x lreal 0.1\n" <>
            "var retain g int[2,3] 1 2 3 4 5 6\nvar retain bs bool[2] 1 0\nvar_input go bool\n" <>
            "xic go ote b"
        )

      assert Runtime.retained(p, Runtime.instance(p)).values == %{
               "b" => {:bool, 1},
               "u" => {:usint, 200},
               "l" => {:lint, -5},
               "d" => {:word, 255},
               "r" => {:real, 0.10000000149011612},
               "x" => {:lreal, 0.1},
               "g" => {{:array, :int, [2, 3]}, [[1, 2, 3], [4, 5, 6]]},
               "bs" => {{:array, :bool, [2]}, [1, 0]}
             }
    end
  end

  describe "instance/2: a lone instance from an image (decisions 273 and 277)" do
    test "the same program's image starts the instance a warm restart gives, each retained " <>
           "timer at the start's now, and it scans as the warm restart does" do
      p = line()
      s = running(p)
      image = Runtime.retained(p, s)
      assert {started, []} = Runtime.instance(p, image)

      warm = Runtime.restart(p, s, :warm)
      assert %Instance{first: true, now: 0, ons_blocked: [], faults: []} = started

      # Each retained timer's `last` is the start's `now`, 0, where the warm restart's is
      # its own `now`; the var_inputs, the host's, start at 0.
      assert started.env["lube"] == %{warm.env["lube"] | "last" => 0}
      assert started.env["s1"]["t"] == %{warm.env["s1"]["t"] | "last" => 0}
      assert elem(started.env["tl"], 0) == %{elem(warm.env["tl"], 0) | "last" => 0}
      assert {started.env["eye"], started.env["run"]} == {0, 0}

      inputs = for i <- 1..20, do: %{"eye" => rem(div(i, 3), 2), "run" => rem(div(i, 5), 2)}

      Enum.reduce(inputs, {started, warm}, fn input, {a, b} ->
        {out_a, a} = Runtime.call(p, a, input, %Scan{now: a.now + 10, first: a.first})
        {out_b, b} = Runtime.call(p, b, input, %Scan{now: b.now + 10, first: b.first})
        assert out_a == out_b
        assert Runtime.retained(p, a) == Runtime.retained(p, b)
        assert Map.delete(a.env, "lube") |> Map.keys() == Map.delete(b.env, "lube") |> Map.keys()
        {a, b}
      end)
    end

    test "a retained timer's last is never in the image, and starts at 0, which decision " <>
           "188 holds the state to" do
      p =
        c!(
          "var_input go bool\nvar retain a ton\nvar retain b tof\nvar retain c tp\n" <>
            "var retain d rto\nvar retain e ton_ltime\nvar retain f ton[2]\n" <>
            "xic go ton a 50\nxic go tof b 50\nxic go tp c 50\nxic go rto d 50\n" <>
            "xic go ton e 50000000\nxic go ton f[1] 50"
        )

      s = scans(p, Runtime.instance(p), List.duplicate(%{"go" => 1}, 3))
      image = Runtime.retained(p, s)
      refute Enum.any?(Map.keys(image.values), &String.ends_with?(&1, ".last"))
      {started, []} = Runtime.instance(p, image)

      for name <- ~w(a b c d e), do: assert(started.env[name]["last"] == 0)
      assert elem(started.env["f"], 1)["last"] == 0
      assert started.env["d"]["acc"] == 20
      # It takes a scan: no `last` later than its `now` (decision 188).
      assert %Instance{} = scans(p, started, [%{"go" => 1}])
      assert scans(p, started, [%{"go" => 1}]).env["d"]["acc"] == 30
    end

    test "a value is kept only where the program declares its path retained, of exactly its " <>
           "type, each mismatch dropped once by its path with its reason" do
      p =
        c!(
          "var_input go bool\nvar retain a dint 5\nvar retain b dint\nvar retain c int\n" <>
            "var retain d int[3]\nvar retain e int[3]\nvar retain f dint\nvar retain g ctu\n" <>
            "var retain h ton\nvar retain i dint 7\nvar retain k dint\nvar retain l ton[2]\n" <>
            "xic go ctu g 9\nxic go ton h 9\nxic go ton l[0] 9\nxic go ton l[1] 9"
        )

      s = Runtime.instance(p)
      s = %{s | env: Map.merge(s.env, %{"a" => 11, "b" => 12, "c" => 13, "f" => 15, "k" => 17})}
      s = %{s | env: %{s.env | "d" => {1, 2, 3}, "e" => {4, 5, 6}}}
      image = Runtime.retained(p, s)

      # Renamed (`b` now `bb`), narrowed, widened, resized, an array's elements retyped, the
      # qualifier removed, an instance retyped, a timer retyped, an initial value changed,
      # and a tag newly retained.
      q =
        c!(
          "var_input go bool\nvar retain a dint 6\nvar retain bb dint\nvar retain c dint\n" <>
            "var retain d int[4]\nvar retain e dint[3]\nvar f dint\nvar retain g ctu_int\n" <>
            "var retain h tof\nvar retain i int\nvar retain k dint\nvar retain l ton[3]\n" <>
            "var retain n dint 3\nxic go ctu g 9\nxic go tof h 9\nxic go ton l[0] 9\n" <>
            "xic go ton l[1] 9\nxic go ton l[2] 9"
        )

      {started, dropped} = Runtime.instance(q, image)

      assert dropped == [
               {"b", :undeclared},
               {"c", {:retyped, :int, :dint}},
               {"d", {:resized, [3], [4]}},
               {"e", {:retyped, {:array, :int, [3]}, {:array, :dint, [3]}}},
               {"f", :unretained},
               {"g", {:retyped, "ctu", "ctu_int"}},
               {"h", {:retyped, "ton", "tof"}},
               {"i", {:retyped, :dint, :int}},
               {"l", {:resized, [2], [3]}}
             ]

      fresh = Runtime.instance(q).env
      # A changed initial value keeps the stored one (decision 44's rule); a path newly
      # retained starts at its initial value, unreported; the rest at theirs.
      assert started.env["a"] == 11
      assert started.env["k"] == 17
      assert started.env["n"] == 3
      assert Map.drop(started.env, ~w(a k)) == Map.drop(fresh, ~w(a k))
    end

    test "a user block's instance is matched member by member: a member added starts at its " <>
           "initial value, one retyped, removed or unretained dropped by its path, the rest kept" do
      old =
        block!(
          "function_block cell\nvar_input go bool\nvar retain k dint\n" <>
            "var retain j dint\nvar retain m dint\nvar retain z dint\nvar retain t ton\n" <>
            "xic go add k 1 k\nxic go add j 1 j\nxic go ton t 9"
        )

      p =
        c!(
          "var_input go bool\nvar retain c cell\nvar retain cs cell[2]\ncal c go\n" <>
            "cal cs[0] go\ncal cs[1] go",
          [old]
        )

      s = scans(p, Runtime.instance(p), List.duplicate(%{"go" => 1}, 3))
      image = Runtime.retained(p, s)

      new =
        block!(
          "function_block cell\nvar_input go bool\nvar retain k dint\n" <>
            "var retain j int\nvar non_retain m dint\nvar retain added dint 4\n" <>
            "var retain t tof\nxic go add k 1 k\nxic go add j 1 j\nxic go tof t 9"
        )

      q =
        c!(
          "var_input go bool\nvar retain c cell\nvar retain cs cell[2]\ncal c go\n" <>
            "cal cs[0] go\ncal cs[1] go",
          [new]
        )

      {started, dropped} = Runtime.instance(q, image)

      assert dropped ==
               for(
                 at <- ["c", "cs[0]", "cs[1]"],
                 reason <- [
                   {"j", {:retyped, :dint, :int}},
                   {"m", :unretained},
                   {"t", {:retyped, "ton", "tof"}},
                   {"z", :undeclared}
                 ],
                 do: {"#{at}.#{elem(reason, 0)}", elem(reason, 1)}
               )

      assert started.env["c"]["k"] == 3
      assert started.env["c"]["added"] == 4
      assert started.env["c"]["j"] == 0
      assert elem(started.env["cs"], 1)["k"] == 3
      assert elem(started.env["cs"], 1)["added"] == 4

      # A block renamed is an instance of another kind: dropped once, nothing under it.
      other =
        block!("function_block cellx\nvar_input go bool\nvar retain k dint\nxic go add k 1 k")

      r =
        c!(
          "var_input go bool\nvar retain c cellx\nvar retain cs cell[2]\ncal c go\n" <>
            "cal cs[0] go\ncal cs[1] go",
          [other, old]
        )

      {_started, dropped} = Runtime.instance(r, image)
      assert dropped == [{"c", {:retyped, "cell", "cellx"}}]
    end

    # Since the review of M6-4: a kind dropped is reported once, and every kind below it,
    # two levels down and more, is passed over in silence, as every value under it is.
    test "a kind dropped silences the kinds two levels and more below it" do
      inner = block!("function_block inner\nvar_input go bool\nvar t ton\nxic go ton t 9")

      mid = block!("function_block mid\nvar_input go bool\nvar c inner\ncal c go", [inner])

      outer =
        block!("function_block outer\nvar_input go bool\nvar b mid\ncal b go", [mid, inner])

      p = c!("var_input go bool\nvar retain a outer\ncal a go", [outer, mid, inner])
      image = Runtime.retained(p, scans(p, Runtime.instance(p), [%{"go" => 1}]))
      assert Map.keys(image.kinds) == ["a", "a.b", "a.b.c", "a.b.c.t"]

      q = c!("var_input go bool\nvar retain a dint\nxic go add a 1 a")
      assert {_started, [{"a", {:retyped, "outer", :dint}}]} = Runtime.instance(q, image)
    end

    # Since the review of M6-4: path order is by segment, an element by its subscripts'
    # values, so `g[2].k` comes before `g[10].k`, in a lone instance's drops and a
    # resource's.
    test "drops are in path order by the subscripts' values, not by the path's text" do
      old = block!("function_block cell\nvar_input go bool\nvar retain k dint\nxic go add k 1 k")
      new = block!("function_block cell\nvar_input go bool\nvar retain k int\nxic go add k 1 k")
      src = "var_input go bool\nvar retain g cell[12]\nvar retain h cell[2,11]\ncal g[0] go"
      p = c!(src, [old])
      image = Runtime.retained(p, Runtime.instance(p))
      {_started, dropped} = Runtime.instance(c!(src, [new]), image)

      assert Enum.map(dropped, &elem(&1, 0)) ==
               for(i <- 0..11, do: "g[#{i}].k") ++
                 for(i <- 0..1, j <- 0..10, do: "h[#{i},#{j}].k")

      config = plant("program m1 motor\nm1.go 0\n", %{"motor" => c!(src, [old], "motor")})
      runtime = Runtime.start(config)
      image = Runtime.retained(runtime)
      changed = plant("program m1 motor\nm1.go 0\n", %{"motor" => c!(src, [new], "motor")})
      {_runtime, dropped} = Runtime.start(changed, image)

      assert Enum.take(Enum.map(dropped, &elem(&1, 0)), 3) == [
               "m1.g[0].k",
               "m1.g[1].k",
               "m1.g[2].k"
             ]

      assert Enum.at(dropped, 10) == {"m1.g[10].k", {:retyped, :dint, :int}}
    end

    test "an instance or a path no longer retained is reported once, nothing under it" do
      p =
        c!(
          "var_input go bool\nvar retain g ctu\nvar retain s1 seal\nvar q bool\nxic go ctu g 9\ncal s1 go q",
          [seal()]
        )

      image = Runtime.retained(p, Runtime.instance(p))

      q =
        c!("var_input go bool\nvar g ctu\nvar s1 seal\nvar q bool\nxic go ctu g 9\ncal s1 go q", [
          seal()
        ])

      # `seal` keeps `k` retained of its own, so `s1` is still on its way, each other
      # member reported by its path, its timer once.
      assert {_started,
              [
                {"g", :unretained},
                {"s1.go", :unretained},
                {"s1.q", :unretained},
                {"s1.t", :unretained}
              ]} =
               Runtime.instance(q, image)

      gone = c!("var_input go bool\nvar_input g bool\nvar s1x bool\nxic go ote s1x")

      assert {_started, [{"g", {:retyped, "ctu", :bool}}, {"s1", :undeclared}]} =
               Runtime.instance(gone, image)
    end

    test "a value of the right type that does not fit it is dropped as a misfit, every " <>
           "other kept" do
      p =
        c!(
          "var_input go bool\nvar retain a dint\nvar retain b bool\nvar retain r real\n" <>
            "var retain x lreal\nvar retain w int[3]\nvar retain y dint\nvar retain g ctu\n" <>
            "var retain z real\nxic go ctu g 9"
        )

      image = Runtime.retained(p, Runtime.instance(p))

      values =
        Map.merge(image.values, %{
          "a" => {:dint, 5_000_000_000},
          "b" => {:bool, 2},
          "r" => {:real, 0.1},
          "x" => {:lreal, 1},
          "w" => {{:array, :int, [3]}, [1, 2]},
          "y" => {:dint, 37.5},
          "g.cv" => {:dint, nil},
          "g.pv" => {:dint, 4},
          "z" => {:real, -0.0}
        })

      {started, dropped} = Runtime.instance(p, %{image | values: values})

      assert dropped ==
               Enum.map(~w(a b g.cv r w x y z), &{&1, :misfit})

      assert started.env["g"]["pv"] == 4
      assert started.env["a"] == 0 and started.env["w"] == {0, 0, 0}

      # An array's element outside its type drops the array whole.
      bad = %{image | values: %{image.values | "w" => {{:array, :int, [3]}, [1, 2, 40000]}}}
      assert {%Instance{env: %{"w" => {0, 0, 0}}}, [{"w", :misfit}]} = Runtime.instance(p, bad)
      good = %{image | values: %{image.values | "w" => {{:array, :int, [3]}, [1, 2, 3]}}}
      assert {%Instance{env: %{"w" => {1, 2, 3}}}, []} = Runtime.instance(p, good)
    end
  end

  # ---- a resource -------------------------------------------------------------------------

  @counter """
  var_input eye bool
  var_input run bool
  var_external total dint
  var_output lamp bool
  var retain boxes ctu
  var retain lube rto
  var retain w dint[3]
  var retain tl ton[2]
  var retain s1 seal
  var retain sp real
  var fan tof
  var e bool
  var n dint
  xic eye ctu boxes 1000
  xic run rto lube 100000
  xic eye ons e add total 1 total
  xic eye move boxes.cv w[1]
  xic run ton tl[0] 30
  xic eye ton tl[1] 20
  cal s1 run lamp
  xic run add sp 0.5 sp
  xio run tof fan 40
  xic eye add n 1 n
  """

  @arming """
  var_input eye bool
  var_input clear bool
  var_external arm bool
  xic eye otl arm
  xic clear otu arm
  """

  @counting """
  var_external arm bool
  var_external hist int[2]
  var retain hits dint
  xic arm add hits 1 hits
  xic arm move 7 hist[1]
  """

  @plant """
  task fast interval 10 priority 1
  task slow interval 50 priority 2
  task ev single arm priority 0
  var_global eye_1 bool at panel.i.0
  var_global run_1 bool at panel.i.1
  var_global clr bool at panel.i.2
  var_global lamp_q bool at panel.q.0
  var_global retain total dint 0
  var_global retain arm bool
  var_global retain hist int[2]
  var_global shown dint
  program m1 counter with fast
    m1.eye eye_1
    m1.run run_1
    m1.lamp lamp_q
  program m2 counter with slow
    m2.eye eye_1
    m2.run run_1
  program a1 arming with fast
    a1.eye eye_1
    a1.clear clr
  program c1 counting with ev
  """

  defp types(counter \\ @counter) do
    %{
      "counter" => c!(counter, [seal()], "counter"),
      "arming" => c!(@arming, [], "arming"),
      "counting" => c!(@counting, [], "counting")
    }
  end

  defp plant(source \\ @plant, types \\ types()) do
    {:ok, config} = Configuration.compile("plant", source, types)
    config
  end

  defp inputs,
    do: %{"eye_1" => pick([0, 1]), "run_1" => pick([0, 1, 1]), "clr" => pick([0, 0, 0, 1])}

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # A cycle's events with each time `shift` earlier.
  defp shifted(events, shift), do: Enum.map(events, &shift(&1, shift))

  defp shift({:ran, task, instance, now}, shift), do: {:ran, task, instance, now - shift}
  defp shift(event, _shift), do: event

  describe "start/2: a resource from an image (decisions 273, 277, 282 and 305)" do
    # PLAN M6-4's done-when: a resource started from another resource's image cycles
    # exactly as the original does after a warm restart, given the same inputs: its
    # outputs, its events at times `now` earlier, every global and every image after.
    test "a resource started from another's image cycles exactly as the original does after " <>
           "a warm restart" do
      :rand.seed(:exsss, {2026, 10, 2904})
      config = plant()

      Enum.reduce(1..12, {Runtime.start(config), 0}, fn _round, {runtime, now} ->
        # A multiple of the slow task's 50 ms, so every instance last ran at `now`.
        count = 5 * :rand.uniform(6)

        runtime =
          Enum.reduce(1..count, runtime, fn _, rt ->
            {rt, _outputs, _events} = Runtime.cycle(rt, 10, inputs())
            rt
          end)

        now = now + 10 * count
        image = Runtime.retained(runtime)
        assert {started, []} = Runtime.start(config, image)

        {warm, _started} =
          Enum.reduce(1..25, {Runtime.restart(runtime, :warm), started}, fn _, {a, b} ->
            given = inputs()
            {a, out_a, events_a} = Runtime.cycle(a, 10, given)
            {b, out_b, events_b} = Runtime.cycle(b, 10, given)
            assert out_a == out_b
            assert shifted(events_a, now) == events_b
            assert Runtime.retained(a) == Runtime.retained(b)

            for g <- ~w(total arm hist shown lamp_q),
                do: assert(Runtime.get!(a, g) == Runtime.get!(b, g))

            {a, b}
          end)

        {warm, now + 250}
      end)
    end

    test "every retained value and global is kept, the trigger of a single put back at 1 " <>
           "fires on no rising edge, and one dropped starts as start/1 has it" do
      config = plant()

      runtime =
        Enum.reduce([1, 0, 1, 0, 1], Runtime.start(config), fn eye, rt ->
          {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_1" => eye, "run_1" => 1, "clr" => 0})
          rt
        end)

      assert Runtime.get!(runtime, "arm") == 1
      assert Runtime.get!(runtime, "c1.hits") == 1
      image = Runtime.retained(runtime)
      assert Map.keys(image.instances) == ~w(c1 m1 m2)

      assert image.globals == %{
               "total" => {:dint, 2},
               "arm" => {:bool, 1},
               "hist" => {{:array, :int, [2]}, [0, 7]}
             }

      {started, []} = Runtime.start(config, image)

      for path <- ~w(total arm hist m1.boxes.cv m1.lube.acc m2.boxes.cv c1.hits),
          do: assert(Runtime.get!(started, path) == Runtime.get!(runtime, path))

      {_started, _, events} =
        Runtime.cycle(started, 10, %{"eye_1" => 0, "run_1" => 0, "clr" => 0})

      refute Enum.any?(events, &match?({:ran, "ev", _, _}, &1))

      # A start of the very configuration with no image runs it: its trigger is 0.
      {:ok, armed} =
        Configuration.compile(
          "plant",
          String.replace(@plant, "var_global retain arm bool", "var_global retain arm bool 1"),
          types()
        )

      {fresh, _, events} =
        Runtime.cycle(Runtime.start(armed), 10, %{"eye_1" => 0, "run_1" => 0, "clr" => 0})

      assert Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))
      _ = fresh

      # Its value dropped, a misfit, the trigger starts at 0 as start/1 has it, so the
      # initial 1 fires.
      misfit = %{Runtime.retained(Runtime.start(armed)) | globals: %{"arm" => {:bool, 2}}}
      {from_misfit, [{"arm", :misfit}]} = Runtime.start(armed, misfit)
      {_, _, events} = Runtime.cycle(from_misfit, 10, %{"eye_1" => 0, "run_1" => 0, "clr" => 0})
      assert Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))
      # Kept at 1, it does not.
      kept = %{misfit | globals: %{"arm" => {:bool, 1}}}
      {from_kept, []} = Runtime.start(armed, kept)
      {_, _, events} = Runtime.cycle(from_kept, 10, %{"eye_1" => 0, "run_1" => 0, "clr" => 0})
      refute Enum.any?(events, &match?({:ran, "ev", _, _}, &1))
    end

    test "an instance, a program type or a global changed is dropped once by its path, each " <>
           "instance's paths after its name" do
      config = plant()

      runtime =
        Enum.reduce(1..4, Runtime.start(config), fn _, rt ->
          {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_1" => 1, "run_1" => 1, "clr" => 0})
          rt
        end)

      image = Runtime.retained(runtime)

      changed =
        @plant
        |> String.replace("var_global retain total dint 0", "var_global retain total lint 0")
        |> String.replace("var_global retain arm bool", "var_global arm bool")
        |> String.replace("var_global retain hist int[2]", "var_global retain hist int[3]")
        |> String.replace("program m2 counter with slow", "program m3 counter with slow")
        |> String.replace("m2.", "m3.")
        |> String.replace(
          "program c1 counting with ev",
          "program c1 arming with ev\n  c1.eye 0\n  c1.clear 0"
        )

      counter =
        String.replace(@counter, "var retain sp real", "var retain sp lreal")
        |> String.replace("var_external total dint", "var_external total lint")

      counting = String.replace(@counting, "var_external hist int[2]", "var_external hist int[3]")
      t = %{types(counter) | "counting" => c!(counting, [], "counting")}
      {:ok, config2} = Configuration.compile("plant", changed, t)

      {started, dropped} = Runtime.start(config2, image)

      assert dropped == [
               {"arm", :unretained},
               {"c1", {:retyped, "counting", "arming"}},
               {"hist", {:resized, [2], [3]}},
               {"m1.sp", {:retyped, :real, :lreal}},
               {"m2", :undeclared},
               {"total", {:retyped, :dint, :lint}}
             ]

      assert Runtime.get!(started, "m1.boxes.cv") == Runtime.get!(runtime, "m1.boxes.cv")
      assert Runtime.get!(started, "m3.boxes.cv") == 0
      assert Runtime.get!(started, "total") == 0

      # A global renamed is no global of the image's name.
      renamed = String.replace(@plant, "retain total dint 0", "retain total2 dint 0")

      assert {_, [{"total", :undeclared}]} =
               Runtime.start(
                 plant(renamed, types(String.replace(@counter, "total", "total2"))),
                 image
               )
    end

    test "retained/1 takes the running program during an edit, no instance set aside, and " <>
           "no instance whose program retains nothing" do
      config = plant()

      runtime =
        Enum.reduce(1..3, Runtime.start(config), fn _, rt ->
          {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_1" => 1, "run_1" => 1, "clr" => 0})
          rt
        end)

      # `a1` retains nothing.
      refute Map.has_key?(Runtime.retained(runtime).instances, "a1")

      candidate =
        plant(
          String.replace(
            @plant,
            "program m2 counter with slow\n  m2.eye eye_1\n  m2.run run_1\n",
            ""
          )
        )

      {:ok, edit, _report} = Logex.Configuration.Edit.accept(runtime, candidate)
      {_edit, tested, _report} = Logex.Configuration.Edit.test(edit, runtime)
      image = Runtime.retained(tested)
      assert Map.keys(image.instances) == ~w(c1 m1)
      assert image.instances["m1"] == Runtime.retained(runtime).instances["m1"]
    end
  end

  describe "the host's mistakes, each a pinned line" do
    defp small,
      do:
        c!(
          "var retain boxes ctu\nvar retain lube rto\nvar retain tl ton[2]\nvar retain d dint\n" <>
            "var_input eye bool\nxic eye ctu boxes 9\nxic eye rto lube 9\nxic eye ton tl[0] 5\n" <>
            "xic eye ton tl[1] 5"
        )

    test "an image that is no lone image, or of another program" do
      p = small()
      good = Runtime.retained(p, Runtime.instance(p))

      raises(
        "a retained image is a map of `program`, `kinds` and `values`, as " <>
          "Logex.Runtime.retained/2 gives one, got: 5",
        fn -> Runtime.instance(p, opaque(5)) end
      )

      raises(
        "a retained image is a map of `program`, `kinds` and `values`, as " <>
          "Logex.Runtime.retained/2 gives one, got: %{program: \"m\"}",
        fn -> Runtime.instance(p, %{program: "m"}) end
      )

      raises(
        "the retained image is of program `q`, and this program is `m`: an image starts only " <>
          "an instance of the program it was taken from",
        fn -> Runtime.instance(p, %{good | program: "q"}) end
      )

      raises(
        "the image's `program` is 7, which names no program",
        fn -> Runtime.instance(p, %{good | program: 7}) end
      )
    end

    test "every entry no image could hold, a line each, kinds first, in path order" do
      p = small()
      good = Runtime.retained(p, Runtime.instance(p))

      kinds =
        Map.merge(good.kinds, %{
          "a..b" => "ton",
          "x" => 5,
          "y" => {:array, "ton", [0]},
          "zz[1]" => "ton",
          7 => "ton"
        })

      values =
        Map.merge(good.values, %{
          "a b" => {:dint, 1},
          "boxes" => {:dint, 1},
          "boxes[1].cv" => {:dint, 1},
          "d" => 5,
          "e" => {:float, 1},
          "f" => {{:array, :dint, [0]}, []},
          "g" => {{:array, :dint, [65_537]}, []},
          "lube.last" => {:dint, 0},
          "q.r" => {:dint, 1},
          "tl.acc" => {:dint, 1},
          "tl[0,1].acc" => {:dint, 1},
          "tl[2].acc" => {:dint, 1},
          # Since the review of M6-4, a subscript that is no digits a line too, where
          # reading it as a number raised, and one not written as its value, `01`.
          "tl[ 1].acc" => {:dint, 1},
          "tl[-1].acc" => {:dint, 1},
          "tl[01].acc" => {:dint, 1},
          "tl[x].acc" => {:dint, 1},
          "w[1]" => {:dint, 1}
        })

      raises(
        Enum.join(
          [
            "`kinds` holds 7, which is no path",
            "`kinds` holds \"a..b\", which is no path",
            "`kinds` holds `x` as 5, which is no kind of instance: a built-in's or a block's " <>
              "name, or {:array, name, sizes}",
            "`kinds` holds `y` as {:array, \"ton\", [0]}, which is no kind of instance: a " <>
              "built-in's or a block's name, or {:array, name, sizes}",
            "`kinds` holds `zz[1]`, an element: an array is retained whole",
            "`values` holds \"a b\", which is no path",
            "`kinds` and `values` both hold `boxes`, which is an instance or a value, never both",
            "`values` holds `boxes[1].cv`, by an element of `boxes`, which is no array of " <>
              "instances",
            "`values` holds `d` as 5, which is no {type, value}",
            "`values` holds `e` of the type :float, which is no type of a retained value: an " <>
              "elementary type's atom, or {:array, type, sizes}",
            "`values` holds `f` of the type {:array, :dint, [0]}, which is no type of a " <>
              "retained value: an elementary type's atom, or {:array, type, sizes}",
            "`values` holds `g` of the type {:array, :dint, [65537]}, which is no type of a " <>
              "retained value: an elementary type's atom, or {:array, type, sizes}",
            "`values` holds `lube.last`, a timer's clock, which no image holds: each retained " <>
              "timer starts at the start's `now`",
            "`values` holds `q.r`, under `q`, which `kinds` does not hold",
            "`values` holds `tl.acc`, under `tl`, an array of instances, by no element",
            "`values` holds \"tl[ 1].acc\", which is no path",
            "`values` holds \"tl[-1].acc\", which is no path",
            "`values` holds `tl[0,1].acc`, by an element outside `tl`'s sizes",
            "`values` holds \"tl[01].acc\", which is no path",
            "`values` holds `tl[2].acc`, by an element outside `tl`'s sizes",
            "`values` holds \"tl[x].acc\", which is no path",
            "`values` holds `w[1]`, an element: an array is retained whole"
          ],
          "\n"
        ),
        fn -> Runtime.instance(p, %{good | kinds: kinds, values: values}) end
      )
    end

    test "a resource's image that is none, of another configuration, or with parts that are " <>
           "none, after the configuration's own check" do
      p = small()

      {:ok, config} =
        Configuration.compile("plant", "var_global retain t dint\nprogram m1 m\n  m1.eye 0", %{
          "m" => p
        })

      image = Runtime.retained(Runtime.start(config))

      raises(
        "a resource's retained image is a map of `configuration`, `globals` and `instances`, " <>
          "as Logex.Runtime.retained/1 gives one, got: 5",
        fn -> Runtime.start(config, opaque(5)) end
      )

      raises(
        "the retained image is of configuration `other`, and this configuration is `plant`: " <>
          "an image starts only the configuration it was taken from",
        fn -> Runtime.start(config, %{image | configuration: "other"}) end
      )

      raises(
        "the retained image's `globals` are no map, got: 5",
        fn -> Runtime.start(config, %{image | globals: 5}) end
      )

      raises(
        Enum.join(
          [
            "`globals` holds 5, which names no global",
            "`globals` holds \"a.b\", which names no global",
            "`globals` holds \"t\" as 4, which is no {type, value}",
            "`instances` holds \"m.1\", which names no instance",
            "instance \"m1\": a retained image is a map of `program`, `kinds` and `values`, " <>
              "as Logex.Runtime.retained/2 gives one, got: 6"
          ],
          "\n"
        ),
        fn ->
          Runtime.start(config, %{
            image
            | globals: %{"a.b" => {:dint, 1}, "t" => 4, 5 => {:dint, 1}},
              instances: %{"m.1" => image.instances["m1"], "m1" => 6}
          })
        end
      )

      # The configuration first, as start/1 checks it.
      raises(
        "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: 5",
        fn -> Runtime.start(opaque(5), image) end
      )
    end

    test "retained/1 and /2 take a resource, and a program with its state, as call/4 does" do
      p = small()

      raises("expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: 5", fn ->
        Runtime.retained(opaque(5))
      end)

      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: 5", fn ->
        Runtime.retained(p, opaque(5))
      end)

      raises("`seal` is " <> Logex.Declarations.not_a_program(seal()), fn ->
        Runtime.retained(seal(), Runtime.instance(p))
      end)

      raises("`seal` is " <> Logex.Declarations.not_a_program(seal()), fn ->
        Runtime.instance(seal(), %{program: "seal", kinds: %{}, values: %{}})
      end)

      # A state of another program is refused as call/4 refuses it.
      q = c!("var retain d dint", [], "q")

      assert_raise ArgumentError, ~r/state/, fn ->
        Runtime.retained(q, Runtime.instance(p))
      end
    end

    # Decision 194's pattern: a program instance/1 checked and then edited by hand is
    # trusted, and a take-out that reaches a retained path its tags do not give raises
    # there; instance/2, which checks the program it is handed as instance/1 does,
    # refuses it first.
    test "a program whose retained paths were edited by hand" do
      p = small()
      s = Runtime.instance(p)
      edited = %{p | retained: ["zz" | p.retained]}

      raises(
        "the retained image reaches the retained path \"zz\", which the program's tags do not " <>
          "give: the program was edited by hand after it was handed in and checked",
        fn -> Runtime.retained(edited, s) end
      )

      assert_raise ArgumentError, ~r/retained paths hold `zz`/, fn ->
        Runtime.instance(edited, Runtime.retained(p, s))
      end
    end
  end

  describe "growth, in reductions" do
    defp reductions(fun) do
      parent = self()

      {_pid, ref} =
        :erlang.spawn_opt(
          fn ->
            {:reductions, before} = Process.info(self(), :reductions)
            fun.()
            {:reductions, later} = Process.info(self(), :reductions)
            send(parent, {:reductions, later - before})
          end,
          [:monitor, min_heap_size: 8_000_000]
        )

      assert_receive {:reductions, r}, 30_000
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 30_000
      r
    end

    # `n` retained dints and an unretained array of `big` elements, in one instance.
    defp sized(n, big) do
      decls = Enum.map_join(1..n, "\n", &"var retain r#{&1} dint #{&1}")

      program =
        c!(
          "var_input go bool\nvar big int[#{big}]\n" <> decls <> "\nxic go move 1 big[0]",
          [],
          "g"
        )

      {:ok, config} = Configuration.compile("plant", "program m1 g\n  m1.go 0", %{"g" => program})
      config
    end

    test "the take-out is bounded in the retained count, whatever else the resource holds" do
      small = Runtime.start(sized(20, 16))
      large = Runtime.start(sized(20, 16_384))
      a = reductions(fn -> Runtime.retained(small) end)
      b = reductions(fn -> Runtime.retained(large) end)
      assert b <= a + 4, "an unretained array of 16 #{a}, of 16384 #{b}"

      r40 = reductions(fn -> Runtime.retained(Runtime.start(sized(40, 16))) end)
      r160 = reductions(fn -> Runtime.retained(Runtime.start(sized(160, 16))) end)
      assert r160 <= 4.4 * r40, "40 retained #{r40}, 160 retained #{r160}"
    end

    test "the matching grows linearly in the image, an array of instances element by element" do
      timers = fn n ->
        p = c!("var_input go bool\nvar retain tl ton[#{n}]\nxic go ton tl[0] 5", [], "t")
        {:ok, config} = Configuration.compile("plant", "program m1 t\n  m1.go 0", %{"t" => p})
        image = Runtime.retained(Runtime.start(config))

        {reductions(fn -> Runtime.start(config, image) end),
         reductions(fn -> Runtime.start(config) end)}
      end

      {with_512, bare_512} = timers.(512)
      {with_2048, bare_2048} = timers.(2048)
      a = with_512 - bare_512
      b = with_2048 - bare_2048
      assert b <= 4.6 * a, "512 timers #{a}, 2048 timers #{b}"

      dints = fn n ->
        config = sized(n, 16)
        image = Runtime.retained(Runtime.start(config))

        reductions(fn -> Runtime.start(config, image) end) -
          reductions(fn -> Runtime.start(config) end)
      end

      d100 = dints.(100)
      d400 = dints.(400)
      assert d400 <= 4.6 * d100, "100 dints #{d100}, 400 dints #{d400}"
    end

    test "a configuration that retains nothing starts from its empty image within a few " <>
           "dozen reductions of start/1" do
      program = c!("var_input go bool\nvar n dint\nxic go add n 1 n", [], "g")

      {:ok, config} =
        Configuration.compile(
          "plant",
          Enum.map_join(1..16, "\n", &"program m#{&1} g\n  m#{&1}.go 0"),
          %{"g" => program}
        )

      image = Runtime.retained(Runtime.start(config))
      assert image == %{configuration: "plant", globals: %{}, instances: %{}}
      plain = reductions(fn -> Runtime.start(config) end)
      from_image = reductions(fn -> Runtime.start(config, image) end)
      assert from_image <= plain + 120, "start/1 #{plain}, start/2 #{from_image}"
      taken = reductions(fn -> Runtime.retained(Runtime.start(config)) end) - plain
      assert taken <= 16 * 16 + 40, "a take-out of 16 instances retaining nothing #{taken}"
    end
  end
end
